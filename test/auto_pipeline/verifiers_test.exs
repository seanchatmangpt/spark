defmodule AutoPipeline.VerifiersTest do
  use ExUnit.Case, async: true

  alias AutoPipeline.Verifiers.{EnsureTasksExecutable, ValidateResourceRequirements}

  describe "EnsureTasksExecutable" do
    test "validates tasks with proper commands" do
      tasks = [
        %{name: :setup, command: "echo setup", depends_on: []},
        %{name: :build, command: "ls -la", depends_on: [:setup]}
      ]

      dsl_state = %{
        entities: %{pipeline_tasks: tasks}
      }

      assert :ok = EnsureTasksExecutable.verify(dsl_state)
    end

    test "empty commands are validated at verifier level" do
      # Empty commands pass schema validation but should be caught by verifiers
      assert_raise Spark.Error.DslError, ~r/empty or missing command/, fn ->
        defmodule EmptyCommandTest do
          use AutoPipeline

          pipeline_tasks do
            task :broken do
              command ""
            end
          end
        end
      end
    end

    test "would reject tasks with nil commands at schema level" do
      # This test shows that nil commands are caught by schema validation,
      # not by the verifier, since command is required in the DSL schema
      assert_raise Spark.Error.DslError, fn ->
        defmodule NilCommandTest do
          use AutoPipeline

          pipeline_tasks do
            task :broken do
              # command is required by schema, so this will fail
            end
          end
        end
      end
    end

    test "validates timeout values" do
      tasks = [
        %{name: :valid, command: "echo test", timeout: 5000, depends_on: []}
      ]

      dsl_state = %{
        entities: %{pipeline_tasks: tasks}
      }

      assert :ok = EnsureTasksExecutable.verify(dsl_state)
    end

    test "timeout validation happens at schema level" do
      # Negative and zero timeouts are caught by the DSL schema validation,
      # not by the verifier, since timeout has type :pos_integer
      assert_raise Spark.Error.DslError, fn ->
        defmodule NegativeTimeoutTest do
          use AutoPipeline

          pipeline_tasks do
            task :broken do
              command "echo test"
              timeout -1
            end
          end
        end
      end
    end

    test "validates retry count values through DSL" do
      defmodule ValidRetryTest do
        use AutoPipeline

        pipeline_tasks do
          task :valid do
            command "echo test"
            retry_count 3
          end
        end
      end

      task = AutoPipeline.Info.task(ValidRetryTest, :valid)
      assert task.retry_count == 3
    end

    test "retry count validation happens at schema level" do
      # Negative retry counts are caught by the DSL schema validation,
      # not by the verifier, since retry_count has type :non_neg_integer
      assert_raise Spark.Error.DslError, fn ->
        defmodule NegativeRetryTest do
          use AutoPipeline

          pipeline_tasks do
            task :broken do
              command "echo test"
              retry_count -1
            end
          end
        end
      end
    end

    test "validates environment variables" do
      tasks = [
        %{name: :valid, command: "echo test", environment: %{"VAR" => "value"}, depends_on: []}
      ]

      dsl_state = %{
        entities: %{pipeline_tasks: tasks}
      }

      assert :ok = EnsureTasksExecutable.verify(dsl_state)
    end

    test "environment validation happens at schema level" do
      # Invalid environment variable keys are caught by the DSL schema validation,
      # not by the verifier, since environment has type {:map, :string, :string}
      assert_raise Spark.Error.DslError, fn ->
        defmodule InvalidEnvKeysTest do
          use AutoPipeline

          pipeline_tasks do
            task :broken do
              command "echo test"
              environment %{:atom_key => "value"}
            end
          end
        end
      end
    end
  end

  describe "ValidateResourceRequirements via DSL compilation" do
    test "validates basic task compilation without resource fields" do
      defmodule BasicResourceTest do
        use AutoPipeline

        pipeline_tasks do
          task :simple do
            command "echo test"
          end

          task :with_timeout do
            command "compile"
            timeout 60_000
          end
        end
      end

      # Should compile successfully
      tasks = AutoPipeline.Info.tasks(BasicResourceTest)
      assert length(tasks) == 2
    end

    test "validates environment variable formats during compilation" do
      defmodule ValidEnvTest do
        use AutoPipeline

        pipeline_tasks do
          task :with_env do
            command "echo test"
            environment %{"CUSTOM_VAR" => "value", "ANOTHER_VAR" => "another_value"}
          end
        end
      end

      task = AutoPipeline.Info.task(ValidEnvTest, :with_env)
      assert task.environment == %{"CUSTOM_VAR" => "value", "ANOTHER_VAR" => "another_value"}
    end

    test "rejects invalid environment variable keys during compilation" do
      assert_raise Spark.Error.DslError, ~r/expected string/, fn ->
        defmodule InvalidEnvTest do
          use AutoPipeline

          pipeline_tasks do
            task :broken do
              command "echo test"
              environment %{:atom_key => "value"}
            end
          end
        end
      end
    end

    test "validates timeout values during compilation" do
      defmodule TimeoutTest do
        use AutoPipeline

        pipeline_tasks do
          task :valid_timeout do
            command "echo test"
            timeout 5000
          end
        end
      end

      task = AutoPipeline.Info.task(TimeoutTest, :valid_timeout)
      assert task.timeout == 5000
    end

    test "rejects zero or negative timeout values during compilation" do
      assert_raise Spark.Error.DslError, ~r/expected positive integer/, fn ->
        defmodule InvalidTimeoutTest do
          use AutoPipeline

          pipeline_tasks do
            task :broken do
              command "echo test"
              timeout 0
            end
          end
        end
      end
    end

    test "validates retry count values during compilation" do
      defmodule RetryTest do
        use AutoPipeline

        pipeline_tasks do
          task :with_retries do
            command "echo test"
            retry_count 3
          end
        end
      end

      task = AutoPipeline.Info.task(RetryTest, :with_retries)
      assert task.retry_count == 3
    end

    test "rejects negative retry count values during compilation" do
      assert_raise Spark.Error.DslError, ~r/expected non negative integer/, fn ->
        defmodule InvalidRetryTest do
          use AutoPipeline

          pipeline_tasks do
            task :broken do
              command "echo test"
              retry_count -1
            end
          end
        end
      end
    end
  end
end