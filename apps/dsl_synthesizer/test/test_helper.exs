ExUnit.start()

# Define Mox mocks for external dependencies
Mox.defmock(DslSynthesizerMock, for: DslSynthesizer)
Mox.defmock(DslSynthesizerChangesMock, for: DslSynthesizer.Changes)
Mox.defmock(DslSynthesizerEvaluationMock, for: DslSynthesizer.Evaluation)
Mox.defmock(DslSynthesizerSelectionMock, for: DslSynthesizer.Selection)
Mox.defmock(DslSynthesizerGenerationMock, for: DslSynthesizer.Generation)
Mox.defmock(SourcerorMock, for: Sourceror)
Mox.defmock(SparkMock, for: Spark)

# Configure test environment
Application.put_env(:dsl_synthesizer, :evaluation_service, DslSynthesizerEvaluationMock)
Application.put_env(:dsl_synthesizer, :selection_service, DslSynthesizerSelectionMock)
Application.put_env(:dsl_synthesizer, :generation_service, DslSynthesizerGenerationMock)
Application.put_env(:dsl_synthesizer, :sourceror, SourcerorMock)

# Set up test database
Ecto.Adapters.SQL.Sandbox.mode(DslSynthesizer.Repo, :manual)

defmodule DslSynthesizer.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias DslSynthesizer.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import DslSynthesizer.DataCase

      # Import Ash conveniences
      import Ash.Test
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(DslSynthesizer.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(DslSynthesizer.Repo, :shared)
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