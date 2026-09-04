defmodule Icecast.Adapter do
  @moduledoc """
  The adapter specification.
  """

  @type adapter :: module

  @callback read_meta(url :: binary, adapter_opts :: Keyword.t()) ::
              {:ok, Meta.t()} | {:error, term}
end
