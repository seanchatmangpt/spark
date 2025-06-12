import Config

config :dsl_assistant,
  ash_domains: [DslAssistant]

config :dsl_assistant, DslAssistant.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "dsl_assistant_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"