ExUnit.start()

# Define Mox mocks for external dependencies
Mox.defmock(EvolutionEngineChangesMock, for: EvolutionEngine.Changes)
Mox.defmock(EvolutionEnginePopulationMock, for: EvolutionEngine.Population)
Mox.defmock(EvolutionEngineFitnessMock, for: EvolutionEngine.Fitness)
Mox.defmock(EvolutionEngineLoopMock, for: EvolutionEngine.Loop)
Mox.defmock(EvolutionEngineSelectionMock, for: EvolutionEngine.Selection)
Mox.defmock(EvolutionEngineReportingMock, for: EvolutionEngine.Reporting)
Mox.defmock(NxMock, for: Nx)
Mox.defmock(EvolutionEngineGeneticOperatorsMock, for: EvolutionEngine.GeneticOperators)

# Configure test environment
Application.put_env(:evolution_engine, :population_service, EvolutionEnginePopulationMock)
Application.put_env(:evolution_engine, :fitness_service, EvolutionEngineFitnessMock)
Application.put_env(:evolution_engine, :loop_service, EvolutionEngineLoopMock)
Application.put_env(:evolution_engine, :selection_service, EvolutionEngineSelectionMock)
Application.put_env(:evolution_engine, :reporting_service, EvolutionEngineReportingMock)
Application.put_env(:evolution_engine, :nx, NxMock)

# Set up test database
Ecto.Adapters.SQL.Sandbox.mode(EvolutionEngine.Repo, :manual)

defmodule EvolutionEngine.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias EvolutionEngine.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import EvolutionEngine.DataCase

      # Import Ash conveniences
      import Ash.Test
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(EvolutionEngine.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(EvolutionEngine.Repo, :shared)
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