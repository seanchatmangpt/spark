ExUnit.start()

# Define Mox mocks for external dependencies
Mox.defmock(UsageAnalyzerChangesMock, for: UsageAnalyzer.Changes)
Mox.defmock(UsageAnalyzerSynthesisMock, for: UsageAnalyzer.Synthesis)
Mox.defmock(UsageAnalyzerRecommendationsMock, for: UsageAnalyzer.Recommendations)
Mox.defmock(UsageAnalyzerReportingMock, for: UsageAnalyzer.Reporting)
Mox.defmock(UsageAnalyzerMock, for: UsageAnalyzer)
Mox.defmock(TelemetryMock, for: :telemetry)
Mox.defmock(JsonMock, for: Jason)

# Configure test environment
Application.put_env(:usage_analyzer, :synthesis_service, UsageAnalyzerSynthesisMock)
Application.put_env(:usage_analyzer, :recommendations_service, UsageAnalyzerRecommendationsMock)
Application.put_env(:usage_analyzer, :reporting_service, UsageAnalyzerReportingMock)
Application.put_env(:usage_analyzer, :telemetry, TelemetryMock)
Application.put_env(:usage_analyzer, :json, JsonMock)

# Set up test database
Ecto.Adapters.SQL.Sandbox.mode(UsageAnalyzer.Repo, :manual)

defmodule UsageAnalyzer.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias UsageAnalyzer.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import UsageAnalyzer.DataCase

      # Import Ash conveniences
      import Ash.Test
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(UsageAnalyzer.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(UsageAnalyzer.Repo, :shared)
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