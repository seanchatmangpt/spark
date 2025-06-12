defmodule SparkDslEcosystem.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "SparkDslEcosystem - Near-AGI DSL Factory for Autonomous DSL Generation",
      package: package(),
      docs: docs(),
      elixir: "~> 1.14",
      source_url: "https://github.com/ash-project/spark_dsl_ecosystem",
      homepage_url: "https://hexdocs.pm/spark_dsl_ecosystem",
      aliases: aliases(),
      preferred_cli_env: [
        "spark.formatter": :dev,
        "spark.cheat_sheets": :dev,
        docs: :dev
      ]
    ]
  end

  # Dependencies listed here are available only for this
  # project and cannot be accessed from applications inside
  # the apps folder.
  #
  # Run "mix help deps" for examples and options.
  defp deps do
    [
      # Documentation
      {:ex_doc, "~> 0.30", only: [:dev], runtime: false},
      
      # Development tools
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      
      # Testing
      {:stream_data, "~> 1.1"}
    ]
  end

  defp package do
    [
      name: :spark_dsl_ecosystem,
      files: ["apps", "config", "mix.exs", "README*", "LICENSE*", "CHANGELOG*"],
      maintainers: ["SparkDslEcosystem Team"],
      licenses: ["MIT"],
      links: %{
        GitHub: "https://github.com/ash-project/spark_dsl_ecosystem",
        Discord: "https://discord.gg/HTHRaaVPUc"
      }
    ]
  end

  defp docs do
    [
      main: "SparkDslEcosystem",
      source_ref: "v#{Application.spec(:spark_dsl_ecosystem, :vsn)}",
      source_url: "https://github.com/ash-project/spark_dsl_ecosystem",
      extras: [
        "README.md": [title: "Home"],
        "CLAUDE.md": [title: "Development Guide"]
      ],
      groups_for_extras: [
        "Getting Started": [
          "README.md"
        ],
        "Development": [
          "CLAUDE.md"
        ]
      ],
      groups_for_modules: [
        "Core Framework": [
          SparkCore,
          SparkCore.Dsl,
          SparkCore.Extension,
          SparkCore.Entity,
          SparkCore.Section,
          SparkCore.Transformer,
          SparkCore.Verifier
        ],
        "AGI Factory": [
          AgiFactory,
          AgiFactory.Orchestrator,
          AgiFactory.Pipeline,
          AgiFactory.QualityAssurance
        ],
        "Requirements Processing": [
          RequirementsParser,
          RequirementsParser.NLP,
          RequirementsParser.CodeAnalysis,
          RequirementsParser.Specification
        ],
        "DSL Generation": [
          DslSynthesizer,
          DslSynthesizer.StrategyEngine,
          DslSynthesizer.Generator,
          DslSynthesizer.Evaluator
        ],
        "Usage Intelligence": [
          UsageAnalyzer,
          UsageAnalyzer.PatternRecognition,
          UsageAnalyzer.PerformanceMetrics,
          UsageAnalyzer.PainPointDetection
        ],
        "Evolution Engine": [
          EvolutionEngine,
          EvolutionEngine.ContinuousImprovement,
          EvolutionEngine.ABTesting,
          EvolutionEngine.Migration
        ],
        "Knowledge Management": [
          KnowledgeEngine,
          KnowledgeEngine.Compression,
          KnowledgeEngine.Decompression,
          KnowledgeEngine.SPR
        ]
      ]
    ]
  end

  defp aliases do
    [
      # Run tests for all apps
      test: ["cmd mix test"],
      
      # Format all apps
      format: ["cmd mix format"],
      
      # Check all apps
      check: ["cmd mix compile --warnings-as-errors", "cmd mix format --check-formatted", "cmd mix credo --strict"],
      
      # Setup development environment
      setup: ["deps.get", "cmd mix deps.get", "cmd mix compile"],
      
      # SparkDslEcosystem specific commands
      "ecosystem.analyze": ["cmd --app usage_analyzer mix analyze"],
      "ecosystem.evolve": ["cmd --app evolution_engine mix evolve"],
      "ecosystem.generate": ["cmd --app dsl_synthesizer mix generate"]
    ]
  end
end
