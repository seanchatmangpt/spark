defmodule AgiFactory.Repo do
  @moduledoc """
  Ecto repository for AgiFactory domain.
  
  Handles all database operations for DSL projects, generation requests,
  quality assessments, and evolution cycles.
  """
  
  use AshPostgres.Repo, otp_app: :agi_factory

  def installed_extensions do
    ["ash-functions", "uuid-ossp", "citext"]
  end
end