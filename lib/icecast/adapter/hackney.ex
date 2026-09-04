if Code.ensure_loaded?(:hackney) do
  defmodule Icecast.Adapter.Hackney do
    @moduledoc """
    Hackney adapter

    ### Default options

    ```elixir
    [
        follow_redirect: false,
        max_redirects: 5,
        pool: false
    ]
    ```

    ### About pooling

    With hackney 4.x pooling does not offer any advantages for this library because we don't drain the whole body to read the metadata.
    However `pool: true`is supported.
    """

    alias Icecast.Meta

    @behaviour Icecast.Adapter

    @icy_headers [{"Icy-MetaData", "1"}]
    @redirect_status [301, 302, 303, 307, 308]

    @opts_default [
      follow_redirect: true,
      max_redirects: 5
    ]

    @hackney_opts_default [
      pool: false
    ]

    @impl true
    def read_meta(url, adapter_opts \\ []) do
      {opts, hackney_opts} = Keyword.split(adapter_opts, Keyword.keys(@opts_default))
      opts = Keyword.merge(@opts_default, opts)
      hackney_opts = Keyword.merge(@hackney_opts_default, hackney_opts)

      case open_stream(url, opts, hackney_opts, 0) do
        {:error, reason} ->
          {:error, reason}

        {:ok, conn, headers, location} ->
          try do
            case get_offset(headers) do
              nil ->
                {:error, nil}

              offset ->
                case read_meta_block(conn, offset) do
                  {:error, reason} ->
                    {:error, reason}

                  {:ok, meta_length, meta} ->
                    {:ok,
                     %Meta{
                       data: process_meta(meta),
                       offset: offset,
                       length: meta_length,
                       raw: meta,
                       string: String.trim(meta, <<0>>),
                       location: location
                     }}
                end
            end
          rescue
            e -> {:error, e}
          after
            :hackney.close(conn)
          end
      end
    end

    # Open the stream and return the connection *without* reading the body.
    #
    # `:hackney.request/5` (and so `:hackney.get/4`) cannot be used here: since
    # hackney 4 the `with_body` option is gone and the body is always drained
    # into memory before the call returns. On an endless icy stream that never
    # returns. `connect/2` + `send_request/2` gives back the connection right
    # after the response headers, which is what hackney 1 used to do.
    defp open_stream(url, opts, hackney_opts, redirect_count) do
      with {:ok, _count} <- is_max_redirects?(redirect_count, opts),
           {:ok, conn} <- :hackney.connect(url, connect_opts(hackney_opts)),
           {:ok, status, headers, ^conn} <- send_request(conn, request_path(url)) do
        cond do
          status in @redirect_status ->
            :hackney.close(conn)
            follow_redirect(url, headers, opts, hackney_opts, redirect_count)

          status >= 200 and status < 300 ->
            {:ok, conn, headers, url}

          true ->
            :hackney.close(conn)
            {:error, {:status, status}}
        end
      else
        {:error, reason} -> {:error, reason}
        other -> {:error, other}
      end
    end

    # Force HTTP/1.1. hackney defaults to `[http2, http1]` and negotiates h2 over
    # ALPN, but the h2 path is unusable here: `hackney:send_request/2` has no
    # clause for the `{ok, Status, Headers, Body}` that `hackney_conn:request/5`
    # returns on h2 (it raises CaseClauseError), and that reply only comes after
    # the whole body is buffered, which never happens on an endless stream.
    # Icy metadata is an HTTP/1.x convention anyway.
    defp connect_opts(hackney_opts), do: Keyword.put(hackney_opts, :protocols, [:http1])

    # `send_request/2` can raise rather than return an error tuple; keep
    # `read_meta/2` total.
    defp send_request(conn, path) do
      :hackney.send_request(conn, {:get, path, @icy_headers, ""})
    rescue
      e -> {:error, e}
    end

    defp is_max_redirects?(redirect_count, opts) do
      case Keyword.get(opts, :max_redirects, @opts_default[:max_redirects]) do
        max when is_integer(max) and redirect_count > max ->
          {:error, {:max_redirects, redirect_count}}

        _ ->
          {:ok, redirect_count}
      end
    end

    defp follow_redirect(url, headers, opts, hackney_opts, redirect_count) do
      case {Keyword.get(opts, :follow_redirect, false), get_header(headers, "location")} do
        {false, _} ->
          {:error, :redirect}

        {true, nil} ->
          {:error, :invalid_redirection}

        {true, location} ->
          open_stream(
            URI.merge(url, location) |> URI.to_string(),
            opts,
            hackney_opts,
            redirect_count + 1
          )
      end
    end

    # Path (+ query string) to put on the request line.
    defp request_path(url) do
      uri = URI.parse(url)

      case {uri.path || "/", uri.query} do
        {path, nil} -> path
        {path, qs} -> path <> "?" <> qs
      end
    end

    # Read just enough of the audio stream to get the metadata block that follows
    # the first `offset` bytes.
    #
    # Done in two passes so we never pull the worst-case 4080-byte block: first
    # read up to the length byte at `offset`, then read exactly the
    # `length * 16` bytes it announces. Metadata is usually one or two 16-byte
    # blocks, so the second pass is normally already satisfied by the chunk the
    # first one ended on.
    defp read_meta_block(conn, offset) do
      with {:ok, data} <- read_body(conn, [], 0, offset + 1),
           <<_::binary-size(offset), l, _::binary>> <- data,
           meta_length = l * 16,
           {:ok, data} <- read_body(conn, [data], byte_size(data), offset + 1 + meta_length),
           <<_::binary-size(offset), _, meta::binary-size(meta_length), _::binary>> <- data do
        {:ok, meta_length, meta}
      else
        {:error, reason} -> {:error, reason}
        _ -> {:error, :truncated}
      end
    end

    # Stream the body until `needed` bytes have been accumulated. Chunks are kept
    # as a reversed iodata list and flattened once, on the way out.
    defp read_body(_conn, acc, size, needed) when size >= needed do
      {:ok, acc |> Enum.reverse() |> IO.iodata_to_binary()}
    end

    defp read_body(conn, acc, size, needed) do
      case :hackney.stream_body(conn) do
        {:ok, data} -> read_body(conn, [data | acc], size + byte_size(data), needed)
        :done -> {:error, :truncated}
        {:error, reason} -> {:error, reason}
      end
    end

    # Get the byte offset from the `icy-metaint` header.
    defp get_offset(headers) do
      case get_header(headers, "icy-metaint") do
        metaint when is_binary(metaint) ->
          case Integer.parse(String.trim(metaint)) do
            {offset, _} -> offset
            :error -> nil
          end

        _ ->
          nil
      end
    end

    # Response header names keep the casing sent by the server, so match on a
    # lowercased key.
    defp get_header(headers, name) do
      name = String.downcase(name)

      Enum.find_value(headers, fn {key, value} ->
        if String.downcase(to_string(key)) == name, do: to_string(value)
      end)
    end

    # Process the binary meta data into a map.
    defp process_meta(meta) do
      meta
      |> String.trim_trailing(<<0>>)
      |> String.split(";")
      |> Enum.flat_map(fn pair ->
        # `parts: 2` keeps a value that contains "=" (StreamTitle='a=b') in one
        # piece; anything that isn't a key/value pair is dropped rather than
        # raising, so a single malformed field can't lose the whole reading.
        case String.split(pair, "=", parts: 2) do
          [k, v] -> [{k, String.trim(v, "'")}]
          _ -> []
        end
      end)
      |> Enum.into(%{})
    end
  end
end
