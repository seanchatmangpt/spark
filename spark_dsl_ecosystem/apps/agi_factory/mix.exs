defmodule AgiFactory.MixProject do
  use Mix.Project

  def project do
    [
      app: :agi_factory,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      
      # Documentation
      name: "AgiFactory",
      description: "Near-AGI DSL generation orchestration engine",
      docs: docs(),
      
      # Testing
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AgiFactory.Application, []}
    ]
  end

  defp deps do
    [
      # Ash framework - latest versions
      {:ash, "~> 3.5"},
      {:ash_postgres, "~> 2.6"},
      {:ash_json_api, "~> 1.4"},
      
      # Database - latest versions
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.19"},
      
      # Phoenix integration - latest
      {:phoenix_pubsub, "~> 2.1"},
      
      # Telemetry and monitoring - latest
      {:telemetry, "~> 1.3"},
      {:telemetry_metrics, "~> 1.0"},
      
      # JSON handling - latest
      {:jason, "~> 1.4"},
      
      # Caching - latest
      {:cachex, "~> 3.6"},
      
      # Development and testing - latest
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:stream_data, "~> 1.1"},
      
      # Umbrella dependencies
      {:requirements_parser, in_umbrella: true},
      {:dsl_synthesizer, in_umbrella: true},
      {:usage_analyzer, in_umbrella: true},
      {:evolution_engine, in_umbrella: true},
      {:spark_core, in_umbrella: true}
    ]
  end

  defp docs do
    [
      main: "AgiFactory",
      source_url: "https://github.com/ash-project/spark_dsl_ecosystem",
      extras: [
        "README.md": [title: "Overview"],
        "../../RESEARCH_FINDINGS.md": [title: "Research Findings"],
        "../../IMPLEMENTATION_PLANS.md": [title: "Implementation Plans"]
      ],
      groups_for_extras: [
        "Getting Started": ["README.md"],
        "Architecture": ["../../RESEARCH_FINDINGS.md", "../../IMPLEMENTATION_PLANS.md"]
      ],
      groups_for_modules: [
        "Core Domain": [AgiFactory],
        "Resources": [
          AgiFactory.Resources.DslProject,
          AgiFactory.Resources.GenerationRequest,
          AgiFactory.Resources.QualityAssessment,
          AgiFactory.Resources.EvolutionCycle
        ],
        "Workflows": [
          AgiFactory.Workflows.DslGeneration,
          AgiFactory.Workflows.ContinuousEvolution
        ],
        "Changes": [
          AgiFactory.Changes.ParseRequirements,
          AgiFactory.Changes.CreateSpecification,
          AgiFactory.Changes.ValidateGeneration
        ],
        "Calculations": [
          AgiFactory.Calculations.HealthScore,
          AgiFactory.Calculations.EvolutionPotential,
          AgiFactory.Calculations.GenerationTime
        ],
        "Infrastructure": [
          AgiFactory.Repo,
          AgiFactory.Application
        ]
      ]
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "test.watch": ["test.watch --stale"],
      
      # Custom aliases for AGI Factory
      "agi.metrics": ["run -e 'IO.inspect(AgiFactory.get_metrics())'"],
      "agi.health": ["run -e 'IO.inspect(AgiFactory.analyze_performance())'"],
      "agi.demo": ["run priv/repo/demo.exs"]
    ]
  end
end