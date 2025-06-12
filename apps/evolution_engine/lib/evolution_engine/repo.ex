defmodule EvolutionEngine.Repo do
  use AshPostgres.Repo, otp_app: :evolution_engine

  def installed_extensions do
    ["uuid-ossp", "citext"]
  end
end