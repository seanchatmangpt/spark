ExUnit.start()

# Define Mox mocks for external dependencies
Mox.defmock(RequirementsParserMock, for: RequirementsParser.Actions)
Mox.defmock(DslSynthesizerMock, for: DslSynthesizer.Actions)
Mox.defmock(UsageAnalyzerMock, for: UsageAnalyzer.Actions)
Mox.defmock(EvolutionEngineMock, for: EvolutionEngine.Actions)
Mox.defmock(AgiFactoryQualityAssuranceMock, for: AgiFactory.QualityAssurance.Actions)
Mox.defmock(AgiFactorySelectionMock, for: AgiFactory.Selection.Actions)
Mox.defmock(AgiFactoryCleanupMock, for: AgiFactory.Cleanup)

# Configure test environment
Application.put_env(:agi_factory, :requirements_parser, RequirementsParserMock)
Application.put_env(:agi_factory, :dsl_synthesizer, DslSynthesizerMock)
Application.put_env(:agi_factory, :usage_analyzer, UsageAnalyzerMock)
Application.put_env(:agi_factory, :evolution_engine, EvolutionEngineMock)

# Set up test database
Ecto.Adapters.SQL.Sandbox.mode(AgiFactory.Repo, :manual)

defmodule AgiFactory.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias AgiFactory.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import AgiFactory.DataCase

      # Import Ash conveniences
      import Ash.Test
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(AgiFactory.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(AgiFactory.Repo, :shared)
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