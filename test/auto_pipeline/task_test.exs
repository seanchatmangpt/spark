defmodule AutoPipeline.TaskTest do
  use ExUnit.Case, async: true
  
  alias AutoPipeline.Task

  describe "new/1" do
    test "creates a task with given attributes" do
      attrs = %{
        name: :test_task,
        description: "A test task",
        command: "echo hello",
        timeout: 5000,
        retry_count: 2,
        depends_on: [:setup],
        environment: %{"VAR" => "value"},
        parallel: true
      }

      task = Task.new(attrs)

      assert task.name == :test_task
      assert task.description == "A test task"
      assert task.command == "echo hello"
      assert task.timeout == 5000
      assert task.retry_count == 2
      assert task.depends_on == [:setup]
      assert task.environment == %{"VAR" => "value"}
      assert task.parallel == true
    end
  end

  describe "validate/1" do
    test "validates a properly configured task" do
      task = %Task{
        name: :valid_task,
        command: "echo test",
        timeout: 5000,
        retry_count: 1,
        depends_on: [:other_task],
        environment: %{"ENV" => "test"}
      }

      assert {:ok, ^task} = Task.validate(task)
    end

    test "rejects task with missing name" do
      task = %Task{name: nil, command: "echo test"}
      assert {:error, "Task name is required"} = Task.validate(task)
    end

    test "rejects task with invalid name" do
      task = %Task{name: "string_name", command: "echo test"}
      assert {:error, "Task name must be an atom"} = Task.validate(task)
    end

    test "rejects task with missing command" do
      task = %Task{name: :test, command: nil}
      assert {:error, "Task command is required"} = Task.validate(task)
    end

    test "rejects task with empty command" do
      task = %Task{name: :test, command: ""}
      assert {:error, "Task command must be a non-empty string"} = Task.validate(task)
    end

    test "rejects task with invalid timeout" do
      task = %Task{
        name: :test, 
        command: "echo test", 
        timeout: -1,
        retry_count: 0,
        depends_on: [],
        environment: %{}
      }
      assert {:error, "Task timeout must be a positive integer"} = Task.validate(task)
    end

    test "rejects task with invalid retry count" do
      task = %Task{
        name: :test, 
        command: "echo test", 
        timeout: 5000,
        retry_count: -1,
        depends_on: [],
        environment: %{}
      }
      assert {:error, "Retry count must be a non-negative integer"} = Task.validate(task)
    end

    test "rejects task with invalid dependencies" do
      task = %Task{
        name: :test, 
        command: "echo test", 
        timeout: 5000,
        retry_count: 0,
        depends_on: ["string_dep"],
        environment: %{}
      }
      assert {:error, "All dependencies must be atoms"} = Task.validate(task)
    end

    test "rejects task with invalid environment" do
      task = %Task{
        name: :test, 
        command: "echo test", 
        timeout: 5000,
        retry_count: 0,
        depends_on: [],
        environment: "not_a_map"
      }
      assert {:error, "Environment must be a map"} = Task.validate(task)
    end
  end
end