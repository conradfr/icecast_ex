defmodule Icecast.Adapter.ReqTest do
  use ExUnit.Case, async: true

  # `Req` itself is needed for its error struct, so the adapter gets a name of
  # its own here.
  alias Icecast.Adapter.Req, as: ReqAdapter
  alias Icecast.Meta

  @moduletag :network

  @stream "http://ice1.somafm.com/lush-128-mp3"
  # 301 to https://somafm.com/, which is an HTML page rather than a stream.
  @redirect "http://somafm.com/"

  describe "adapter options" do
    test "are merged into the Req options" do
      assert {:error, %Req.TransportError{reason: :timeout}} =
               ReqAdapter.read_meta(@stream, receive_timeout: 1)
    end

    test "do not disturb the read when they only restate the defaults" do
      assert {:ok, %Meta{}} = ReqAdapter.read_meta(@stream, retry: false, max_redirects: 5)
    end
  end

  describe "finch instance" do
    setup do
      name = Module.concat(__MODULE__, "Finch#{System.unique_integer([:positive])}")
      start_supervised!({Finch, name: name})

      %{finch: name}
    end

    test "can be given by name at call time, without deprecation warning", %{finch: finch} do
      warnings =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          assert {:ok, %Meta{}} = ReqAdapter.read_meta(@stream, finch: finch)
        end)

      refute warnings =~ "deprecated"
    end

    test "can be given with its options at call time", %{finch: finch} do
      assert {:ok, %Meta{}} =
               ReqAdapter.read_meta(@stream, finch: [name: finch, pool_timeout: 10_000])
    end

    test "returns an error when the instance does not exist" do
      assert {:error, _} = ReqAdapter.read_meta(@stream, finch: Icecast.NoSuchFinch)
    end
  end

  describe "redirects" do
    test "are followed by default" do
      # the redirect target is not a stream, so we get past the redirect and
      # then fail on the missing icy-metaint header
      assert {:error, nil} = ReqAdapter.read_meta(@redirect)
    end

    test ":redirect false stops on the redirect" do
      # unlike the hackney adapter, which answers {:error, :redirect}, Req hands
      # back the 3xx response itself: it carries no icy-metaint either, so the
      # two cases are not told apart here
      assert {:error, nil} = ReqAdapter.read_meta(@redirect, redirect: false)
    end

    test ":max_redirects caps the number of hops" do
      assert {:error, %Req.TooManyRedirectsError{max_redirects: 0}} =
               ReqAdapter.read_meta(@redirect, max_redirects: 0)
    end
  end
end
