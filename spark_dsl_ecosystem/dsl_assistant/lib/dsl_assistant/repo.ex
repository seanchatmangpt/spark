defmodule DslAssistant.Repo do
  use AshPostgres.Repo,
    otp_app: :dsl_assistant

  def installed_extensions do
    ["uuid-ossp", "citext"]
  end
end