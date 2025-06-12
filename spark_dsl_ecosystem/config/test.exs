import Config

# Configure database for testing
config :agi_factory, AgiFactory.Repo,
  database: "spark_dsl_ecosystem_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  log: false

# We don't run a server during test
config :phoenix, :serve_endpoints, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Disable Phoenix PubSub logging in test
config :phoenix_pubsub, log_level: :error

# AGI Factory test configuration
config :agi_factory,
  # Disable background processes during tests
  enable_background_processes: false,
  
  # Use mock external services
  mock_external_services: true,
  
  # Faster timeouts for tests
  generation_timeout: 5_000, # 5 seconds
  workflow_timeout: 10_000, # 10 seconds
  
  # Disable telemetry in tests unless specifically testing it
  enable_telemetry: false,
  
  # Use in-memory cache for tests
  cache_adapter: :memory,
  
  # Disable real-time features in tests
  enable_real_time: false

# Requirements Parser test settings
config :requirements_parser,
  # Always use mocks in tests
  use_mock_nlp: true,
  
  # Disable external API calls
  disable_external_apis: true,
  
  # Use deterministic parsing for consistent tests
  deterministic_parsing: true

# DSL Synthesizer test settings
config :dsl_synthesizer,
  # Use minimal strategies for faster tests
  test_strategy_count: 2,
  
  # Use simplified generation for tests
  simplified_generation: true,
  
  # Disable code execution in tests
  disable_code_execution: true,
  
  # Use mock quality assessments
  mock_quality_assessment: true

# Usage Analyzer test settings
config :usage_analyzer,
  # Use test fixtures instead of real analysis
  use_test_fixtures: true,
  
  # Disable file system scanning in tests
  disable_fs_scanning: true,
  
  # Use mock pattern detection
  mock_pattern_detection: true

# Evolution Engine test settings
config :evolution_engine,
  # Minimal population for tests
  test_population_size: 5,
  
  # Very short cycles for tests
  test_cycle_duration: 100, # 100ms
  
  # Disable actual evolution in tests unless specifically testing
  disable_evolution: true,
  
  # Use deterministic random seed
  deterministic_evolution: true

# Spark Core test settings
config :spark_core,
  # Disable performance monitoring in tests
  disable_performance_monitoring: true,
  
  # Use simplified introspection for tests
  simplified_introspection: true,
  
  # Disable AGI hooks in tests unless specifically testing
  disable_agi_hooks: true

# Reactor test configuration
config :reactor,
  # Shorter timeouts for tests
  default_timeout: 5_000,
  default_max_retries: 1,
  
  # Disable async execution in tests for deterministic behavior
  force_synchronous: true