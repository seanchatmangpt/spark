defmodule AutoPipeline.DslValidationTest do
  use ExUnit.Case, async: true

  test "circular dependency detection" do
    assert_raise Spark.Error.DslError, ~r/Circular dependency detected/, fn ->
      defmodule CircularPipeline do
        use AutoPipeline

        pipeline_tasks do
          task :a do
            command "echo a"
            depends_on [:b]
          end

          task :b do
            command "echo b"
            depends_on [:c]
          end

          task :c do
            command "echo c"
            depends_on [:a]
          end
        end
      end
    end
  end

  test "invalid dependency detection" do
    assert_raise Spark.Error.DslError, ~r/non-existent dependencies/, fn ->
      defmodule InvalidDepPipeline do
        use AutoPipeline

        pipeline_tasks do
          task :valid do
            command "echo valid"
            depends_on [:nonexistent]
          end
        end
      end
    end
  end

  test "empty command validation" do
    assert_raise Spark.Error.DslError, ~r/empty or missing command/, fn ->
      defmodule EmptyCommandPipeline do
        use AutoPipeline

        pipeline_tasks do
          task :broken do
            command ""
          end
        end
      end
    end
  end

  test "invalid timeout validation" do
    assert_raise Spark.Error.DslError, ~r/expected positive integer/, fn ->
      defmodule InvalidTimeoutPipeline do
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

  test "invalid retry count validation" do
    assert_raise Spark.Error.DslError, ~r/expected non negative integer/, fn ->
      defmodule InvalidRetryPipeline do
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

  test "invalid environment validation" do
    assert_raise Spark.Error.DslError, ~r/expected string/, fn ->
      defmodule InvalidEnvPipeline do
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