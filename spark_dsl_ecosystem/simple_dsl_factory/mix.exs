defmodule SimpleDslFactory.MixProject do
  use Mix.Project

  def project do
    [
      app: :simple_dsl_factory,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {SimpleDslFactory.Application, []}
    ]
  end

  defp deps do
    [
      # Core framework - latest stable
      {:ash, "~> 3.5"},
      {:ash_postgres, "~> 2.6"},
      
      # Database
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.19"},
      
      # Utilities
      {:jason, "~> 1.4"},
      
      # Development
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      
      # Testing
      {:stream_data, "~> 1.1"},
      {:ex_unit_properties, "~> 0.1", only: :test}
    ]
  end
end