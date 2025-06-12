defmodule DslSynthesizer.Repo do
  use AshPostgres.Repo, otp_app: :dsl_synthesizer

  def installed_extensions do
    ["uuid-ossp", "citext"]
  end
end