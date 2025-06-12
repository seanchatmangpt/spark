import Config

# Configure the database for production
# You'll want to use environment variables in real deployment
config :simple_dsl_factory, SimpleDslFactory.Repo,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")