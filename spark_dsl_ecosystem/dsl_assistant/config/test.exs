import Config

config :dsl_assistant, DslAssistant.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "dsl_assistant_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10