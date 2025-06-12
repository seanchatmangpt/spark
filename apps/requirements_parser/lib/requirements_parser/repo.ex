defmodule RequirementsParser.Repo do
  use AshPostgres.Repo, otp_app: :requirements_parser

  def installed_extensions do
    ["uuid-ossp", "citext"]
  end
end