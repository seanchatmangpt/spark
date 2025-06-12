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
      {:ash, "~> 3.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_reactor, "~> 0.15"},
      {:reactor, "~> 0.15"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.17"},
      {:spark, "~> 2.2"},
      {:sourceror, "~> 1.0"},
      {:telemetry, "~> 1.2"},
      {:requirements_parser, in_umbrella: true}
    ]
  end
end