defmodule Icecast.AdapterTest do
  @moduledoc """
  The behaviour every adapter has to implement, run against both of them.
  """

  use ExUnit.Case, async: true

  alias Icecast.Meta

  @moduletag :network

  # A live SomaFM stream, sending `icy-metaint` and an endless body.
  @stream "http://ice1.somafm.com/lush-128-mp3"
  # 200 OK, but an HTML page: no `icy-metaint` header.
  @not_a_stream "https://somafm.com/"
  # 301 to https://somafm.com/, the same HTML page.
  @redirect "http://somafm.com/"
  # `.invalid` is reserved by RFC 2606 and never resolves.
  @unknown_host "http://ice1.somafm.invalid/lush-128-mp3"

  @adapters [Icecast.Adapter.Hackney, Icecast.Adapter.Req]

  for adapter <- @adapters do
    @adapter adapter

    describe "#{inspect(adapter)}.read_meta/2" do
      test "reads the metadata block of a live stream" do
        assert {:ok, %Meta{} = meta} = @adapter.read_meta(@stream)

        assert is_integer(meta.offset) and meta.offset > 0
        assert meta.length > 0
        # the raw block is exactly the announced length
        assert byte_size(meta.raw) == meta.length
        assert meta.string == String.trim(meta.raw, <<0>>)
        assert meta.location == @stream
      end

      test "parses the metadata into a map" do
        assert {:ok, %Meta{data: data}} = @adapter.read_meta(@stream)

        assert %{"StreamTitle" => title} = data
        assert is_binary(title)
        # values are unwrapped from their single quotes
        refute String.starts_with?(title, "'")
        refute String.ends_with?(title, "'")
      end

      test "returns {:error, nil} when the response carries no icy-metaint header" do
        assert {:error, nil} = @adapter.read_meta(@not_a_stream)
      end

      test "returns an error rather than raising on an unresolvable host" do
        assert {:error, _reason} = @adapter.read_meta(@unknown_host)
      end

      test "follows redirects by default" do
        # both adapters default to following the location header; the target is
        # an HTML page, so the read gets that far and then finds no icy-metaint
        assert {:error, nil} = @adapter.read_meta(@redirect)
      end

      test "is reachable through Icecast.read_meta/3" do
        assert {:ok, %Meta{}} = Icecast.read_meta(@stream, [], @adapter)
      end
    end
  end

  test "both adapters read the same stream the same way" do
    assert {:ok, hackney} = Icecast.Adapter.Hackney.read_meta(@stream)
    assert {:ok, req} = Icecast.Adapter.Req.read_meta(@stream)

    # the title can change between the two reads, the shape of the block cannot
    assert hackney.offset == req.offset
    assert hackney.location == req.location
    assert Map.keys(hackney.data) == Map.keys(req.data)
  end
end
