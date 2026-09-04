defmodule Icecast do
  @moduledoc """
  Read Shoutcast and Icecast metadata

  ## Adapter

  This library provides two adapters:
    - hackney (default)
    - Req

  Other adapters can be added. They should use the Icecast.Adapter behavior

  It is configurable using
  ```elixir
  :icecast, adapter: module
  ```
  Or set on a per call basis using the last argument of read_meta/3
  """

  defmodule Meta do
    defstruct [:offset, :length, :data, :raw, :string, :location]

    @type t :: %__MODULE__{
            data: map,
            offset: integer,
            length: integer,
            raw: binary,
            string: String.t(),
            location: String.t()
          }
  end

  @default_adapter Icecast.Adapter.Hackney

  @doc """
  Get the metadata from a shoutcast or icecast stream.

  ### Parameters

  #### adapter_opts:

  Check each adapter docs for default settings

  #### adapter_module:

      - nil (using default hackney or config setting)
      - Icecast.Adapter.Hackney
      - Icecast.Adapter.Req

    A successful request will return a `%Icecast.Meta{}` struct.

    The `location` field will contain the last redirected url (if any), allowing to skip the cost of redirections on subsequent calls if wanted.

  ## Example:

      iex> Icecast.read_meta("http://ice1.somafm.com/lush-128-mp3")
      {:ok, %Meta{}}

      iex> Icecast.read_meta("http://ice1.somafm.com/lush-128-mp3", [follow_redirect: true, pool: true])
      {:ok, %Meta{}}

      iex> Icecast.read_meta("http://ice1.somafm.com/lush-128-mp3", [follow_redirect: true, pool: true], Icecast.Adapter.Req)
      {:ok, %Meta{}}

  """
  @spec read_meta(binary, adapter_opts :: Keyword.t(), adapter_module :: module | nil) ::
          {:ok, Meta.t()} | {:error, term}
  def read_meta(url, adapter_opts \\ [], adapter_module \\ nil) do
    adapter_module
    |> get_adapter()
    |> apply(:read_meta, [url, adapter_opts])
  end

  @doc false
  @spec get_adapter(adapter :: Icecast.Adapter | nil) :: Icecast.Adapter
  def get_adapter(adapter \\ nil) do
    with nil <- adapter,
         nil <- Application.get_env(:icecast, :adapter) do
      @default_adapter
    end
  end
end
