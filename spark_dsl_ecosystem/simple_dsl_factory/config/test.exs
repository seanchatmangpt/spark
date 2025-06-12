import Config

config :simple_dsl_factory, SimpleDslFactory.Repo,
  database: "simple_dsl_factory_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10