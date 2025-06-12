defmodule SimpleDslFactory.Repo do
  use AshPostgres.Repo, otp_app: :simple_dsl_factory

  def installed_extensions do
    ["uuid-ossp", "citext"]
  end
end