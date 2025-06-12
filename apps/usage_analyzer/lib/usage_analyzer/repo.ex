defmodule UsageAnalyzer.Repo do
  use AshPostgres.Repo, otp_app: :usage_analyzer

  def installed_extensions do
    ["uuid-ossp", "citext"]
  end
end