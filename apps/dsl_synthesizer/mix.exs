defmodule DslSynthesizer.MixProject do
  use Mix.Project

  def project do
    [
      app: :dsl_synthesizer,
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
      mod: {DslSynthesizer.Application, []}
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      {:sourceror, "~> 1.0"},
      {:telemetry, "~> 1.2"},
      {:decimal, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:mox, "~> 1.0", only: :test},
      {:requirements_parser, in_umbrella: true}
    ]
  end
end