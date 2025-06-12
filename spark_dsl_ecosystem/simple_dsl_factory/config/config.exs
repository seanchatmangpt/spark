import Config

config :simple_dsl_factory, SimpleDslFactory.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "simple_dsl_factory_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :simple_dsl_factory,
  ash_domains: [SimpleDslFactory]

config :ash, :validate_domain_resource_inclusion?, false
config :ash, :validate_domain_config_inclusion?, false

import_config "#{config_env()}.exs"