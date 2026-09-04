# Icecast

Read metadata from Shoutcast & Icecast streams.

This is a fork of https://github.com/ryanwinchester/shoutcast_ex, updated to work with hackney 4.x & other clients.

## Installation

in `mix.exs`

```elixir
def deps do
  [
    {:icecast, git: "https://github.com/conradfr/icecast_ex.git", branch: "~> 1.0.0"},
  ]
end
```

## Usage

```elixir
iex> Icecast.read_meta("http://ice1.somafm.com/lush-128-mp3")
{:ok, %Meta{}}
```

## HTTP client adapters

Icecast use the hackney 4.x adapter as default.

You can use the alternative Req adapter.

### Using configuration

```elixir
# config/config.exs

# Make sure to install `mint` package as well, recommended
config :icecast, adapter: Icecast.Adapter.Req
```

A Finch instance can be configured for it:

```elixir
# config/config.exs

# Make sure to install `mint` package as well, recommended
config :icecast, finch: instance_name
```

### At call time

```elixir
    iex> Shoutcast.read_meta("http://ice1.somafm.com/lush-128-mp3", [], Icecast.Adapter.Req)
```

## Documentation

[https://hexdocs.pm/icecast](https://hexdocs.pm/icecast)
