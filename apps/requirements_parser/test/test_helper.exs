ExUnit.start()

# Define Mox mocks for external dependencies
Mox.defmock(RequirementsParserNLPMock, for: RequirementsParser.NLP)
Mox.defmock(RequirementsParserFeaturesMock, for: RequirementsParser.Features)
Mox.defmock(RequirementsParserConfidenceMock, for: RequirementsParser.Confidence)
Mox.defmock(RequirementsParserChangesMock, for: RequirementsParser.Changes)
Mox.defmock(BumblebeeMock, for: Bumblebee)
Mox.defmock(NxMock, for: Nx)
Mox.defmock(TokenizersMock, for: Tokenizers)

# Configure test environment
Application.put_env(:requirements_parser, :nlp_service, RequirementsParserNLPMock)
Application.put_env(:requirements_parser, :features_service, RequirementsParserFeaturesMock)
Application.put_env(:requirements_parser, :confidence_service, RequirementsParserConfidenceMock)
Application.put_env(:requirements_parser, :bumblebee, BumblebeeMock)

# Set up test database
Ecto.Adapters.SQL.Sandbox.mode(RequirementsParser.Repo, :manual)

defmodule RequirementsParser.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias RequirementsParser.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import RequirementsParser.DataCase

      # Import Ash conveniences
      import Ash.Test
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(RequirementsParser.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(RequirementsParser.Repo, :shared)
    end

    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.
  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end