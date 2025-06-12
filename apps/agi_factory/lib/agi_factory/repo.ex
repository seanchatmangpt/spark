defmodule AgiFactory.Repo do
  use AshPostgres.Repo, otp_app: :agi_factory

  def installed_extensions do
    ["uuid-ossp", "citext"]
  end
end