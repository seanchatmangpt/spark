import Config

config :dsl_assistant, DslAssistant.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "dsl_assistant_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10