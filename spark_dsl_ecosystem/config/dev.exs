import Config

# Configure database for development
config :agi_factory, AgiFactory.Repo,
  database: "spark_dsl_ecosystem_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  queue_target: 5000,
  queue_interval: 30_000,
  log: :debug

# Enable dev routes for dashboard and emails if using Phoenix
config :phoenix, :plug_init_mode, :runtime

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# AGI Factory development configuration
config :agi_factory,
  # Enable verbose logging for development
  verbose_logging: true,
  
  # Development-specific workflow settings
  development_mode: true,
  
  # Faster generation timeouts for development
  generation_timeout: 60_000, # 1 minute
  
  # Enable all telemetry in development
  enable_telemetry: true,
  
  # Development database settings
  enable_query_cache: false,
  
  # Mock external services in development
  mock_external_services: true

# Requirements Parser development settings
config :requirements_parser,
  # Use mock NLP services for faster development
  use_mock_nlp: true,
  
  # Enable debug logging for parsing
  debug_parsing: true

# DSL Synthesizer development settings
config :dsl_synthesizer,
  # Reduce strategy count for faster development
  default_strategy_count: 3,
  
  # Use simplified generation for development
  simplified_generation: true,
  
  # Enable code generation debugging
  debug_generation: true

# Usage Analyzer development settings
config :usage_analyzer,
  # Use sample data in development
  use_sample_data: true,
  
  # Reduce analysis scope for faster development
  analysis_scope: :limited

# Evolution Engine development settings
config :evolution_engine,
  # Reduce population size for faster development
  development_population_size: 20,
  
  # Shorter evolution cycles in development
  development_cycle_duration: :timer.minutes(5),
  
  # Enable evolution debugging
  debug_evolution: true

# Spark Core development settings
config :spark_core,
  # Enable enhanced debugging
  debug_transformers: true,
  
  # More verbose introspection
  verbose_introspection: true