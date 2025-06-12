defmodule AutoPipelineTest do
  use ExUnit.Case, async: true
  
  doctest AutoPipeline

  defmodule TestPipeline do
    use AutoPipeline

    pipeline_tasks do
      task :setup do
        description "Setup the environment"
        command "echo 'setting up'"
        timeout 5000
      end

      task :build do
        description "Build the application"
        command "echo 'building'"
        depends_on [:setup]
        timeout 10_000
      end

      task :test do
        description "Run tests"
        command "echo 'testing'"
        depends_on [:build]
        parallel true
      end

      task :deploy do
        description "Deploy application"
        command "echo 'deploying'"
        depends_on [:test]
        environment %{"ENV" => "production"}
      end
    end
  end

  test "pipeline tasks are properly defined" do
    tasks = AutoPipeline.Info.tasks(TestPipeline)
    
    assert length(tasks) == 4
    
    task_names = Enum.map(tasks, & &1.name)
    assert :setup in task_names
    assert :build in task_names
    assert :test in task_names
    assert :deploy in task_names
  end

  test "task dependencies are correctly resolved" do
    root_tasks = AutoPipeline.Info.root_tasks(TestPipeline)
    assert length(root_tasks) == 1
    assert hd(root_tasks).name == :setup

    build_dependents = AutoPipeline.Info.dependent_tasks(TestPipeline, :build)
    assert length(build_dependents) == 1
    assert hd(build_dependents).name == :test
  end

  test "task attributes are properly set" do
    setup_task = AutoPipeline.Info.task(TestPipeline, :setup)
    assert setup_task.name == :setup
    assert setup_task.description == "Setup the environment"
    assert setup_task.command == "echo 'setting up'"
    assert setup_task.timeout == 5000
    assert setup_task.depends_on == []

    test_task = AutoPipeline.Info.task(TestPipeline, :test)
    assert test_task.parallel == true
    assert test_task.depends_on == [:build]

    deploy_task = AutoPipeline.Info.task(TestPipeline, :deploy)
    assert deploy_task.environment == %{"ENV" => "production"}
  end

  test "pipeline validation succeeds for valid configuration" do
    assert AutoPipeline.Info.validate_pipeline(TestPipeline) == :ok
  end

  test "parallel tasks are identified correctly" do
    parallel_tasks = AutoPipeline.Info.parallel_tasks(TestPipeline)
    assert length(parallel_tasks) == 1
    assert hd(parallel_tasks).name == :test
  end
end