if Code.ensure_loaded?(Req) do
  defmodule Icecast.Adapter.Req do
    @moduledoc """
    Req adapter

    A Finch instance can be configured.

    ```elixir
    :icecast, finch: name_of_instance
    ```

    ### Default options

    ```elixir
    [
      headers: [{"Icy-Metadata", "1"}],
      redirect: true,
      max_redirects: 5,
      retry: false,
      decode_body: false,
      cache: false,
      receive_timeout: 5000
    ]
    ```

    ```elixir
    # Only used when no :finch instance is configured
    [
      timeout: 5000
    ]
    ```
    """

    alias Icecast.Meta

    @behaviour Icecast.Adapter

    @timeout 5_000

    @default_opts [
      headers: [{"Icy-Metadata", "1"}],
      redirect: true,
      max_redirects: 5,
      retry: false,
      decode_body: false,
      cache: false,
      receive_timeout: @timeout
    ]

    # Only used when no :finch instance is configured. Note that Req raises if
    # :finch and :connect_options are both set: when a dedicated Finch instance is
    # used, these belong to its own :conn_opts instead.
    @default_connect_options [
      timeout: @timeout
      #      transport_opts: [verify: :verify_none]
    ]

    @impl true
    def read_meta(url, adapter_opts \\ []) do
      opts =
        @default_opts
        |> Keyword.merge(finch_opts())
        |> Keyword.merge(adapter_opts)
        |> Keyword.put(:into, &collect/2)

      case Req.get(url, opts) do
        {:ok, %Req.Response{private: %{shoutcast: acc}}} ->
          build_meta(acc)

        # no `icy-metaint` header, we stopped on the first chunk
        {:ok, %Req.Response{}} ->
          {:error, nil}

        {:error, exception} ->
          {:error, exception}
      end
    rescue
      e ->
        {:error, e}
    end

    # A dedicated Finch instance keeps the (many, short-lived, one-per-host) pools
    # these stream reads create out of the instance the rest of the app uses.
    defp finch_opts() do
      case Application.get_env(:icecast, :finch) do
        nil -> [connect_options: @default_connect_options]
        name -> [finch: name, pool_timeout: @timeout]
      end
    end

    # ----- body collector -----

    # Runs in the calling process, for each body chunk, until we halt.
    defp collect({:data, data}, {req, resp}) do
      case Req.Response.get_private(resp, :shoutcast) do
        nil ->
          case get_offset(resp) do
            nil -> {:halt, {req, resp}}
            offset -> accumulate(new_acc(offset, req), data, req, resp)
          end

        acc ->
          accumulate(acc, data, req, resp)
      end
    end

    defp new_acc(offset, req) do
      %{
        offset: offset,
        location: URI.to_string(req.url),
        chunks: [],
        size: 0,
        # the smallest amount of bytes we know we need: the audio data plus the
        # metadata length byte. Refined once we can read that byte.
        needed: offset + 1,
        length: nil
      }
    end

    defp accumulate(acc, data, req, resp) do
      acc =
        %{acc | chunks: [data | acc.chunks], size: acc.size + byte_size(data)}
        |> resolve_length()

      resp = Req.Response.put_private(resp, :shoutcast, acc)

      if acc.size >= acc.needed do
        {:halt, {req, resp}}
      else
        {:cont, {req, resp}}
      end
    end

    # The `length` byte equals the metadata length / 16, so as soon as we have read
    # it we know exactly where the metadata block ends.
    defp resolve_length(%{length: nil, offset: offset, size: size} = acc) when size > offset do
      <<_::binary-size(^offset), l, _::binary>> = data(acc)
      %{acc | length: l * 16, needed: offset + 1 + l * 16}
    end

    defp resolve_length(acc), do: acc

    defp data(%{chunks: chunks}), do: chunks |> Enum.reverse() |> IO.iodata_to_binary()

    # ----- meta building -----

    defp build_meta(%{length: nil}), do: {:error, nil}

    defp build_meta(%{offset: offset, length: length, location: location} = acc) do
      case data(acc) do
        <<_::binary-size(^offset), _length_byte, meta::binary-size(^length), _::binary>> ->
          {:ok,
           %Meta{
             data: process_meta(meta),
             offset: offset,
             length: length,
             raw: meta,
             string: String.trim(meta, <<0>>),
             location: location
           }}

        # stream ended before the whole metadata block was sent
        _e ->
          {:error, nil}
      end
    end

    # Get the byte offset from the `icy-metaint` header.
    defp get_offset(resp) do
      case Req.Response.get_header(resp, "icy-metaint") do
        [metaint | _] ->
          case Integer.parse(metaint) do
            {offset, _} when offset > 0 -> offset
            _ -> nil
          end

        _ ->
          nil
      end
    end

    # Process the binary meta data into a map.
    defp process_meta(meta) do
      meta
      |> String.trim_trailing(<<0>>)
      |> String.split(";")
      # `parts: 2` because a value can itself contain a "=" (urls, base64...),
      # which made the original implementation crash.
      |> Enum.map(&String.split(&1, "=", parts: 2))
      |> Enum.flat_map(fn
        [k, v] -> [{k, String.trim(v, "'")}]
        _ -> []
      end)
      |> Enum.into(%{})
    end
  end
end
