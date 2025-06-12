import Config

config :simple_dsl_factory, SimpleDslFactory.Repo,
  database: "simple_dsl_factory_dev",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10