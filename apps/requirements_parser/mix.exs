defmodule RequirementsParser.MixProject do
  use Mix.Project

  def project do
    [
      app: :requirements_parser,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {RequirementsParser.Application, []}
    ]
  end

  defp deps do
    [
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_reactor, "~> 0.15"},
      {:reactor, "~> 0.15"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      {:nx, "~> 0.7"},
      {:bumblebee, "~> 0.5"},
      {:tokenizers, "~> 0.4"},
      {:telemetry, "~> 1.2"}
    ]
  end
end