import Config

# Configure your database
# config :chat_demo, ChatDemo.Repo,
#   username: "postgres",
#   password: "postgres",
#   hostname: "localhost",
#   database: "chat_demo_dev",
#   stacktrace: true,
#   show_sensitive_data_on_connection_error: true,
#   pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with esbuild to bundle .js and .css sources.
config :chat_demo, ChatDemoWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "chat_demo_secret_key_base_12345678901234567890123456789012",
  watchers: []

# Enable dev routes for dashboard and mailbox
config :chat_demo, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

# Configure JSON library
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# import_config "#{config_env()}.exs"