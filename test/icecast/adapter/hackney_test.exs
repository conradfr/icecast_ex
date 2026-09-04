defmodule Icecast.Adapter.HackneyTest do
  use ExUnit.Case, async: true

  alias Icecast.Adapter.Hackney
  alias Icecast.Meta

  @moduletag :network

  @stream "http://ice1.somafm.com/lush-128-mp3"
  # 301 to https://somafm.com/, which is an HTML page rather than a stream.
  @redirect "http://somafm.com/"

  describe "adapter options" do
    test "redirects are followed by default" do
      # the location header is followed, and the target is not a stream, so we
      # get past the redirect and then fail on the missing icy-metaint header
      assert {:error, nil} = Hackney.read_meta(@redirect)
    end

    test ":follow_redirect false stops on the redirect" do
      assert {:error, :redirect} = Hackney.read_meta(@redirect, follow_redirect: false)
    end

    test ":max_redirects caps the number of hops" do
      assert {:error, {:max_redirects, 1}} = Hackney.read_meta(@redirect, max_redirects: 0)
    end
  end

  describe "hackney options" do
    test "keys outside the adapter options are passed on to hackney" do
      assert {:error, :connect_timeout} = Hackney.read_meta(@stream, connect_timeout: 1)
    end

    test "hackney options and adapter options can be given together" do
      assert {:ok, %Meta{}} =
               Hackney.read_meta(@stream,
                 follow_redirect: true,
                 pool: false,
                 recv_timeout: 5_000
               )
    end
  end
end
