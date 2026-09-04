defmodule IcecastTest do
  use ExUnit.Case, async: false

  # `get_adapter/1` reads the application environment, so these cannot run
  # concurrently with anything else that touches it.
  describe "get_adapter/1" do
    setup do
      previous = Application.get_env(:icecast, :adapter)

      on_exit(fn ->
        case previous do
          nil -> Application.delete_env(:icecast, :adapter)
          adapter -> Application.put_env(:icecast, :adapter, adapter)
        end
      end)

      Application.delete_env(:icecast, :adapter)
    end

    test "defaults to the hackney adapter" do
      assert Icecast.get_adapter() == Icecast.Adapter.Hackney
    end

    test "uses the configured adapter" do
      Application.put_env(:icecast, :adapter, Icecast.Adapter.Req)

      assert Icecast.get_adapter() == Icecast.Adapter.Req
    end

    test "an explicit adapter wins over the configured one" do
      Application.put_env(:icecast, :adapter, Icecast.Adapter.Req)

      assert Icecast.get_adapter(Icecast.Adapter.Hackney) == Icecast.Adapter.Hackney
    end
  end

  describe "read_meta/3" do
    @describetag :network

    @stream "http://ice1.somafm.com/lush-128-mp3"

    test "reads through the configured adapter" do
      previous = Application.get_env(:icecast, :adapter)
      Application.put_env(:icecast, :adapter, Icecast.Adapter.Req)

      on_exit(fn ->
        case previous do
          nil -> Application.delete_env(:icecast, :adapter)
          adapter -> Application.put_env(:icecast, :adapter, adapter)
        end
      end)

      assert {:ok, %Icecast.Meta{}} = Icecast.read_meta(@stream)
    end

    test "passes the adapter options along" do
      assert {:error, :connect_timeout} =
               Icecast.read_meta(@stream, [connect_timeout: 1], Icecast.Adapter.Hackney)
    end
  end
end
