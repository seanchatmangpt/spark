ExUnit.start()

# Setup test database
Ecto.Adapters.SQL.Sandbox.mode(SimpleDslFactory.Repo, :manual)