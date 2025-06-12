defmodule AutoPipeline.IntegrationTest do
  use ExUnit.Case, async: true

  describe "AutoPipeline Integration" do
    test "complete pipeline lifecycle with transformers and verifiers" do
      defmodule CompletePipeline do
        use AutoPipeline

        pipeline_tasks do
          task :setup do
            description "Setup environment"
            command "echo 'setting up environment'"
            timeout 10_000
            retry_count 2
            environment %{"STAGE" => "test"}
          end

          task :dependencies do
            description "Install dependencies"
            command "echo 'installing dependencies'"
            depends_on [:setup]
            timeout 30_000
          end

          task :compile do
            description "Compile application"
            command "echo 'compiling application'"
            depends_on [:dependencies]
            timeout 60_000
            retry_count 1
          end

          task :unit_tests do
            description "Run unit tests"
            command "echo 'running unit tests'"
            depends_on [:compile]
            parallel true
            timeout 120_000
            environment %{"UNIT_TEST_ENV" => "unit"}
          end

          task :integration_tests do
            description "Run integration tests"
            command "echo 'running integration tests'"
            depends_on [:compile]
            parallel true
            timeout 180_000
            environment %{"INTEGRATION_TEST_ENV" => "integration"}
          end

          task :security_scan do
            description "Run security scan"
            command "echo 'running security scan'"
            depends_on [:compile]
            parallel true
            timeout 300_000
          end

          task :deploy_staging do
            description "Deploy to staging"
            command "echo 'deploying to staging'"
            depends_on [:unit_tests, :integration_tests, :security_scan]
            timeout 600_000
            environment %{
              "STAGING_DEPLOY_ENV" => "staging",
              "STAGING_DEPLOY_KEY" => "staging_key"
            }
          end

          task :smoke_tests do
            description "Run smoke tests"
            command "echo 'running smoke tests'"
            depends_on [:deploy_staging]
            timeout 120_000
            environment %{"SMOKE_ENV" => "staging"}
          end

          task :deploy_production do
            description "Deploy to production"
            command "echo 'deploying to production'"
            depends_on [:smoke_tests]
            timeout 900_000
            environment %{
              "PRODUCTION_DEPLOY_ENV" => "production",
              "PRODUCTION_DEPLOY_KEY" => "production_key"
            }
          end
        end
      end

      # Test that tasks are properly defined
      tasks = AutoPipeline.Info.tasks(CompletePipeline)
      assert length(tasks) == 9

      task_names = Enum.map(tasks, & &1.name)
      expected_names = [:setup, :dependencies, :compile, :unit_tests, :integration_tests, 
                       :security_scan, :deploy_staging, :smoke_tests, :deploy_production]
      
      Enum.each(expected_names, fn name ->
        assert name in task_names, "Task #{name} should be defined"
      end)

      # Test dependency resolution
      setup_task = AutoPipeline.Info.task(CompletePipeline, :setup)
      assert setup_task.depends_on == []

      dependencies_task = AutoPipeline.Info.task(CompletePipeline, :dependencies)
      assert :setup in dependencies_task.depends_on

      compile_task = AutoPipeline.Info.task(CompletePipeline, :compile)
      assert :dependencies in compile_task.depends_on

      deploy_staging_task = AutoPipeline.Info.task(CompletePipeline, :deploy_staging)
      assert :unit_tests in deploy_staging_task.depends_on
      assert :integration_tests in deploy_staging_task.depends_on
      assert :security_scan in deploy_staging_task.depends_on

      # Test parallel task identification
      parallel_tasks = AutoPipeline.Info.parallel_tasks(CompletePipeline)
      parallel_names = Enum.map(parallel_tasks, & &1.name)
      assert :unit_tests in parallel_names
      assert :integration_tests in parallel_names
      assert :security_scan in parallel_names

      # Test root task identification
      root_tasks = AutoPipeline.Info.root_tasks(CompletePipeline)
      assert length(root_tasks) == 1
      assert hd(root_tasks).name == :setup

      # Test task attributes are preserved
      unit_tests_task = AutoPipeline.Info.task(CompletePipeline, :unit_tests)
      assert unit_tests_task.parallel == true
      assert unit_tests_task.environment == %{"UNIT_TEST_ENV" => "unit"}
      assert unit_tests_task.timeout == 120_000

      compile_task = AutoPipeline.Info.task(CompletePipeline, :compile)
      assert compile_task.retry_count == 1

      # Test pipeline validation
      assert AutoPipeline.Info.validate_pipeline(CompletePipeline) == :ok
    end

    test "complex dependency graph with multiple paths" do
      defmodule ComplexPipeline do
        use AutoPipeline

        pipeline_tasks do
          task :init do
            command "echo init"
          end

          task :config_a do
            command "echo config_a"
            depends_on [:init]
          end

          task :config_b do
            command "echo config_b"
            depends_on [:init]
          end

          task :process_a do
            command "echo process_a"
            depends_on [:config_a]
            parallel true
          end

          task :process_b do
            command "echo process_b"
            depends_on [:config_b]
            parallel true
          end

          task :combine do
            command "echo combine"
            depends_on [:process_a, :process_b]
          end

          task :finalize do
            command "echo finalize"
            depends_on [:combine]
          end
        end
      end

      tasks = AutoPipeline.Info.tasks(ComplexPipeline)
      assert length(tasks) == 7

      # Verify dependency relationships
      init_task = AutoPipeline.Info.task(ComplexPipeline, :init)
      assert init_task.depends_on == []

      config_a_task = AutoPipeline.Info.task(ComplexPipeline, :config_a)
      assert :init in config_a_task.depends_on

      config_b_task = AutoPipeline.Info.task(ComplexPipeline, :config_b)
      assert :init in config_b_task.depends_on

      combine_task = AutoPipeline.Info.task(ComplexPipeline, :combine)
      assert :process_a in combine_task.depends_on
      assert :process_b in combine_task.depends_on

      # Test parallel execution identification
      parallel_tasks = AutoPipeline.Info.parallel_tasks(ComplexPipeline)
      parallel_names = Enum.map(parallel_tasks, & &1.name)
      assert :process_a in parallel_names
      assert :process_b in parallel_names

      # Test that dependent tasks are correctly identified
      process_a_dependents = AutoPipeline.Info.dependent_tasks(ComplexPipeline, :process_a)
      assert length(process_a_dependents) == 1
      assert hd(process_a_dependents).name == :combine

      combine_dependents = AutoPipeline.Info.dependent_tasks(ComplexPipeline, :combine)
      assert length(combine_dependents) == 1
      assert hd(combine_dependents).name == :finalize

      # Validate pipeline
      assert AutoPipeline.Info.validate_pipeline(ComplexPipeline) == :ok
    end

    test "error conditions are properly handled" do
      # Test circular dependency detection
      assert_raise Spark.Error.DslError, ~r/Circular dependency detected/, fn ->
        defmodule CircularPipeline do
          use AutoPipeline

          pipeline_tasks do
            task :a do
              command "echo a"
              depends_on [:c]
            end

            task :b do
              command "echo b"
              depends_on [:a]
            end

            task :c do
              command "echo c"
              depends_on [:b]
            end
          end
        end
      end

      # Test missing dependency detection
      assert_raise Spark.Error.DslError, ~r/non-existent dependencies/, fn ->
        defmodule MissingDepPipeline do
          use AutoPipeline

          pipeline_tasks do
            task :existing do
              command "echo existing"
              depends_on [:missing_task]
            end
          end
        end
      end

      # Test invalid timeout values
      assert_raise Spark.Error.DslError, ~r/expected positive integer/, fn ->
        defmodule InvalidTimeoutPipeline do
          use AutoPipeline

          pipeline_tasks do
            task :invalid_timeout do
              command "echo test"
              timeout 0
            end
          end
        end
      end
    end

    test "metadata generation and optimization work correctly" do
      defmodule MetadataPipeline do
        use AutoPipeline

        pipeline_tasks do
          task :first do
            command "echo first"
            timeout 1000
          end

          task :second do
            command "echo second"
            depends_on [:first]
            timeout 2000
          end

          task :third do
            command "echo third"
            depends_on [:second]
            timeout 3000
          end
        end
      end

      tasks = AutoPipeline.Info.tasks(MetadataPipeline)
      
      # Check that basic task properties are preserved and valid
      Enum.each(tasks, fn task ->
        # Original attributes should be preserved
        assert is_atom(task.name)
        assert is_binary(task.command)
        assert is_list(task.depends_on)
        assert is_integer(task.timeout)
        assert is_integer(task.retry_count)
      end)

      # Verify dependencies are maintained correctly
      first_task = AutoPipeline.Info.task(MetadataPipeline, :first)
      second_task = AutoPipeline.Info.task(MetadataPipeline, :second)
      third_task = AutoPipeline.Info.task(MetadataPipeline, :third)

      assert first_task.depends_on == []
      assert :first in second_task.depends_on
      assert :second in third_task.depends_on
    end
  end
end