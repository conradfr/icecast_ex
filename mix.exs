defmodule IcecastEx.MixProject do
  use Mix.Project

  @source_url "https://github.com/conradfr/icecast_ex"
  @version "1.0.2"

  def project do
    [
      app: :icecast,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: """
      Shoutcast & Icecast metadata reader
      """,
      package: package(),
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:hackney, "~> 4.7.0", optional: true},
      {:req, "~> 0.7.0", optional: true},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp package do
    [
      maintainers: ["conradfr"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        LICENSE: [title: "License"]
      ],
      groups_for_modules: [
        Behaviours: [
          Icecast.Adapter
        ],
        Adapters: [~r/Icecast.Adapter./]
      ],
      nest_modules_by_prefix: [
        Tesla.Adapter
      ]
    ]
  end
end
