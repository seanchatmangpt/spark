defmodule AutoPipeline.TransformersTest do
  use ExUnit.Case, async: true

  describe "ValidateDependencies via DSL compilation" do
    test "validates dependencies exist in compiled module" do
      defmodule ValidDepsTest do
        use AutoPipeline

        pipeline_tasks do
          task :setup do
            command "echo setup"
          end

          task :build do
            command "echo build"
            depends_on [:setup]
          end

          task :test do
            command "echo test"
            depends_on [:build]
          end
        end
      end

      # If compilation succeeds, dependencies are valid
      tasks = AutoPipeline.Info.tasks(ValidDepsTest)
      assert length(tasks) == 3
      
      build_task = AutoPipeline.Info.task(ValidDepsTest, :build)
      assert :setup in build_task.depends_on
    end

    test "detects circular dependencies during compilation" do
      assert_raise Spark.Error.DslError, ~r/Circular dependency detected/, fn ->
        defmodule CircularDepsTest do
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

    test "detects missing dependencies during compilation" do
      assert_raise Spark.Error.DslError, ~r/non-existent dependencies/, fn ->
        defmodule MissingDepsTest do
          use AutoPipeline

          pipeline_tasks do
            task :setup do
              command "echo setup"
            end

            task :build do
              command "echo build"
              depends_on [:nonexistent]
            end
          end
        end
      end
    end
  end

  describe "GenerateTaskMetadata via compiled tasks" do
    test "metadata is added to compiled tasks" do
      defmodule MetadataTest do
        use AutoPipeline

        pipeline_tasks do
          task :setup do
            command "echo setup"
          end

          task :build do
            command "echo build"
            depends_on [:setup]
          end
        end
      end

      tasks = AutoPipeline.Info.tasks(MetadataTest)
      assert length(tasks) == 2

      # Check that tasks have metadata fields (they should be added by transformers)
      Enum.each(tasks, fn task ->
        # Verify task has basic required properties
        assert is_atom(task.name)
        assert is_binary(task.command)
        assert is_list(task.depends_on)
        assert is_integer(task.timeout)
        assert is_integer(task.retry_count)
      end)
    end

    test "preserves original task properties through transformation" do
      defmodule PropertiesTest do
        use AutoPipeline

        pipeline_tasks do
          task :test_task do
            command "echo test"
            timeout 5000
            retry_count 2
            environment %{"TEST" => "value"}
          end
        end
      end

      test_task = AutoPipeline.Info.task(PropertiesTest, :test_task)
      
      assert test_task.name == :test_task
      assert test_task.command == "echo test"
      assert test_task.timeout == 5000
      assert test_task.retry_count == 2
      assert test_task.environment == %{"TEST" => "value"}
    end
  end

  describe "OptimizeExecutionOrder via compiled pipeline" do
    test "maintains task dependencies after optimization" do
      defmodule OptimizeTest do
        use AutoPipeline

        pipeline_tasks do
          task :setup do
            command "echo setup"
          end

          task :build do
            command "echo build"
            depends_on [:setup]
          end

          task :test do
            command "echo test"
            depends_on [:build]
          end

          task :deploy do
            command "echo deploy"
            depends_on [:test]
          end
        end
      end

      tasks = AutoPipeline.Info.tasks(OptimizeTest)
      
      # Tasks should maintain their dependency relationships after optimization
      setup_task = AutoPipeline.Info.task(OptimizeTest, :setup)
      build_task = AutoPipeline.Info.task(OptimizeTest, :build)
      test_task = AutoPipeline.Info.task(OptimizeTest, :test)
      deploy_task = AutoPipeline.Info.task(OptimizeTest, :deploy)

      assert setup_task.depends_on == []
      assert :setup in build_task.depends_on
      assert :build in test_task.depends_on
      assert :test in deploy_task.depends_on
    end

    test "optimization preserves parallel task flags" do
      defmodule ParallelTest do
        use AutoPipeline

        pipeline_tasks do
          task :setup do
            command "echo setup"
          end

          task :test_a do
            command "echo test_a"
            depends_on [:setup]
            parallel true
          end

          task :test_b do
            command "echo test_b"
            depends_on [:setup]
            parallel true
          end
        end
      end

      test_a = AutoPipeline.Info.task(ParallelTest, :test_a)
      test_b = AutoPipeline.Info.task(ParallelTest, :test_b)

      assert test_a.parallel == true
      assert test_b.parallel == true
    end
  end
end