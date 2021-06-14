defmodule Stats.MixProject do
  use Mix.Project

  def project do
    [
      app: :stats,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Stats.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 1.8"},
      {:poison, "~> 3.0"},
      {:plug, "~> 1.6"},
      {:plug_cowboy, "~> 2.0"},
      {:timex, "~> 3.0"}
    ]
  end
end
