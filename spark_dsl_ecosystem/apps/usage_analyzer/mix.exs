defmodule UsageAnalyzer.MixProject do
  use Mix.Project

  def project do
    [
      app: :usage_analyzer,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {UsageAnalyzer.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Ash framework
      {:ash, "~> 3.5"},
      {:ash_postgres, "~> 2.6"},
      {:ash_json_api, "~> 1.4"},
      
      # Database
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.19"},
      
      # JSON handling
      {:jason, "~> 1.4"}
    ]
  end
end
