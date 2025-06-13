defmodule AsyncApiDsl.MixProject do
  use Mix.Project

  @version "1.0.0"
  @source_url "https://github.com/ash-project/spark"

  def project do
    [
      app: :async_api_dsl,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      
      # Hex package info
      package: package(),
      description: description(),
      
      # Documentation
      docs: docs(),
      
      # Source code info
      source_url: @source_url,
      homepage_url: @source_url,
      
      # Test configuration
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      
      # Code quality
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix]
      ]
    ]
  end

  def application do
    [
      mod: {AsyncApi.Application, []},
      extra_applications: [:logger, :crypto, :inets, :ssl, :gun]
    ]
  end

  defp deps do
    [
      # Core dependency - use path to reference the parent Spark project
      {:spark, path: "../.."},
      
      # JSON/YAML support
      {:jason, "~> 1.4"},
      {:yaml_elixir, "~> 2.9", optional: true},
      
      # HTTP client for gateway integrations
      {:httpoison, "~> 2.0", optional: true},
      
      # Real WebSocket client
      {:gun, "~> 2.0"},
      
      # Real JSON Schema validation
      {:ex_json_schema, "~> 0.9"},
      
      # Real JWT validation  
      {:joken, "~> 2.5"},
      
      # Dev/test dependencies
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp description do
    """
    A powerful Elixir DSL for defining AsyncAPI 3.0 specifications with full
    support for operations, components, protocol bindings, and real-time validation.
    Built on the Spark DSL framework.
    """
  end

  defp package do
    [
      maintainers: ["Spark Team"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Documentation" => "https://hexdocs.pm/async_api_dsl",
        "Spark Framework" => "https://hexdocs.pm/spark"
      },
      files: ~w(lib .formatter.exs mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md", "guides/getting_started.md"],
      groups_for_modules: [
        "Core": [AsyncApi, AsyncApi.Info, AsyncApi.Export],
        "DSL Components": [AsyncApi.Dsl],
        "Transformers": [
          AsyncApi.Transformers.ValidateComponents,
          AsyncApi.Transformers.ValidateMessages,
          AsyncApi.Transformers.ValidateSchemas,
          AsyncApi.Transformers.ValidateChannels,
          AsyncApi.Transformers.ValidateOperations
        ],
        "Mix Tasks": [Mix.Tasks.AsyncApi.Gen]
      ],
      groups_for_extras: [
        "Guides": ["guides/getting_started.md"],
        "Project Info": ["CHANGELOG.md"]
      ]
    ]
  end
end