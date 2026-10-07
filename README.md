# Icecast

Read metadata from Shoutcast & Icecast streams.

This is a fork of https://github.com/ryanwinchester/shoutcast_ex, updated to work with hackney 4.x & other clients.

## Installation

in `mix.exs`

```elixir
def deps do
  [
    {:icecast, "~> 1.0.3"},
  ]
end
```

## Usage

```elixir
iex> Icecast.read_meta("http://ice1.somafm.com/lush-128-mp3")
{:ok, %Meta{}}
```

This is a drop-in replacement for shoutcast_ex, with the addition of `:location`, containing the last url after any redirects. 

## HTTP client adapters

Icecast use the hackney 4.x adapter as default.

You can use the alternative Req adapter.

### Using configuration

```elixir
# config/config.exs

# Make sure to install `mint` package as well, recommended
config :icecast, adapter: Icecast.Adapter.Req
```

A Finch instance can be configured for it, by its name or with the Req `:finch` options:

```elixir
# config/config.exs

# Make sure to install `mint` package as well, recommended
config :icecast, finch: instance_name
# or
config :icecast, finch: [name: instance_name, pool_timeout: 10_000]
```

The connection options (timeout, protocols, transport options) are then the ones of the pools of this instance.

### At call time

```elixir
    iex> Icecast.read_meta("http://ice1.somafm.com/lush-128-mp3", [], Icecast.Adapter.Req)
```

The Finch instance can also be given at call time, it takes precedence over the configuration:

```elixir
    iex> Icecast.read_meta("http://ice1.somafm.com/lush-128-mp3", [finch: instance_name], Icecast.Adapter.Req)
```

## Documentation

[https://hexdocs.pm/icecast](https://hexdocs.pm/icecast)
