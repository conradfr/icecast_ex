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

  describe "redirects" do
    test "are followed by default" do
      # the redirect target is not a stream, so we get past the redirect and
      # then fail on the missing icy-metaint header
      assert {:error, nil} = ReqAdapter.read_meta(@redirect)
    end
  end
end
