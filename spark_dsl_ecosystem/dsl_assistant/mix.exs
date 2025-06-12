defmodule DslAssistant.MixProject do
  use Mix.Project

  def project do
    [
      app: :dsl_assistant,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {DslAssistant.Application, []}
    ]
  end

  defp deps do
    [
      {:ash, "~> 3.5.18"},
      {:ash_postgres, "~> 2.6.6"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:spark, "~> 2.2.65"},
      {:decimal, "~> 2.0"},
      {:libgraph, "~> 0.7"}
    ]
  end
end