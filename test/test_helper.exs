# Both HTTP clients are optional dependencies, so they are not started with the
# application: the adapters under test need them running.
{:ok, _} = Application.ensure_all_started(:hackney)
{:ok, _} = Application.ensure_all_started(Req)

# Every test that talks to a real stream is tagged `:network`.
# Run `mix test --exclude network` to skip them.
ExUnit.start()
