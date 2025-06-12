import Config

# Configure the umbrella apps
config :agi_factory,
  ecto_repos: [AgiFactory.Repo],
  ash_domains: [AgiFactory]

config :requirements_parser,
  ash_domains: [RequirementsParser]

config :dsl_synthesizer,
  ash_domains: [DslSynthesizer]

config :usage_analyzer,
  ash_domains: [UsageAnalyzer]

config :evolution_engine,
  ash_domains: [EvolutionEngine]

config :spark_core,
  ash_domains: [SparkCore]

# Database configuration for AgiFactory
config :agi_factory, AgiFactory.Repo,
  username: System.get_env("DATABASE_USER", "postgres"),
  password: System.get_env("DATABASE_PASS", "postgres"),
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  port: String.to_integer(System.get_env("DATABASE_PORT", "5432")),
  database: System.get_env("DATABASE_NAME", "spark_dsl_ecosystem_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: String.to_integer(System.get_env("DATABASE_POOL_SIZE", "10")),
  queue_target: 5000,
  queue_interval: 30_000

# Ash configuration
config :ash, :include_embedded_source_by_default?, false
config :ash, :policies, show_policy_breakdowns?: true
config :ash, :known_types, [AgiFactory.Types.QualityScore]

# Phoenix PubSub configuration
config :phoenix, :json_library, Jason

# Telemetry configuration
config :telemetry_poller, :default, period: 5_000

# Logger configuration
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :domain, :resource, :action]

# Reactor configuration
config :reactor,
  default_timeout: 300_000,
  default_max_retries: 3

# Import environment specific config
import_config "#{config_env()}.exs"