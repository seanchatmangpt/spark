defmodule Spark.Test.GeneratorTestCase do
  @moduledoc """
  Base test case for Spark generator tests.
  
  Provides common setup and utilities for testing Mix task generators.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use ExUnit.Case
      import Spark.Test.GeneratorTestHelpers
      import ExUnit.CaptureIO
      
      # Import common test patterns
      alias Spark.Test.GeneratorTestHelpers

      # Common test setup
      setup do
        # Reset any global state if needed
        :ok
      end

      # Helper to assert task completion
      defp assert_task_success(result) do
        case result do
          {:ok, _} -> result
          %{} -> result  # Igniter result
          _ -> flunk("Expected successful task result, got: #{inspect(result)}")
        end
      end

      # Helper to assert task failure
      defp assert_task_failure(result, expected_reason \\ nil) do
        case result do
          {:error, reason} -> 
            if expected_reason do
              assert reason == expected_reason
            end
            result
          _ -> flunk("Expected task failure, got: #{inspect(result)}")
        end
      end

      # Helper to test generator with multiple option combinations
      defp test_option_combinations(generator_module, base_args, option_combinations) do
        for {test_name, options} <- option_combinations do
          test_args = Map.merge(base_args, %{options: options})
          result = simulate_task_run(generator_module, test_args)
          
          {test_name, result}
        end
      end
    end
  end

  # Module setup for the test case
  setup_all do
    # Any global setup needed for generator tests
    :ok
  end
end