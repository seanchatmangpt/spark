defmodule AutoPipeline.Verifiers.ValidateResourceRequirements do
  @moduledoc """
  DSL verifier for validating pipeline resource requirements and conflicts.

  REFACTOR: This entire verifier should become Reactor middleware.
  Reactor provides better runtime resource management:
  
  1. Replace with AutoPipeline.Reactor.Middleware.ResourceManager
  2. Use Reactor.Executor.ConcurrencyTracker for resource pooling
  3. max_concurrency handles CPU limits automatically
  4. Runtime checks are more accurate than compile-time estimates
  5. Reactor context can track actual resource usage
  
  Migration: Create middleware that checks resources before step execution.

  This verifier ensures that task resource requirements are feasible and that
  concurrent tasks don't conflict over shared resources. It validates:

  - Resource conflicts between parallel tasks
  - Memory constraints for the entire pipeline
  - CPU limits and scheduling conflicts
  - Disk I/O and network resource constraints
  - Environment variable conflicts
  - Working directory conflicts

  ## Usage

  Add this verifier to your DSL extension:

  ```elixir
  use Spark.Dsl.Extension,
    verifiers: [AutoPipeline.Verifiers.ValidateResourceRequirements]
  ```

  ## Example Validations

  ```elixir
  # This would pass validation
  pipeline_tasks do
    task :compile do
      command "mix compile"
      working_directory "/app"
      environment %{"MIX_ENV" => "dev"}
    end
    
    task :test do
      command "mix test"
      depends_on [:compile]
      working_directory "/app"
      environment %{"MIX_ENV" => "test"}  # Different env, no conflict
    end
  end

  # This would fail validation - working directory conflict
  pipeline_tasks do
    task :compile do
      command "mix compile"
      working_directory "/app"
      parallel true
    end
    
    task :format do
      command "mix format"
      working_directory "/app"  # Conflict: same directory, both parallel
      parallel true
    end
  end
  ```
  """

  use Spark.Dsl.Verifier

  alias Spark.Error.DslError

  # REFACTOR: These limits should be configurable via Reactor context
  # or middleware options instead of hardcoded module attributes
  # Resource limits and constraints
  @max_memory_per_task 2_048  # MB
  @max_total_memory 8_192     # MB  
  @max_parallel_io_tasks 3
  @reserved_env_vars ["PATH", "HOME", "USER", "PWD"]

  @doc """
  Verify the DSL state for resource requirements and conflicts.

  Performs comprehensive resource validation including:
  - Checking for resource conflicts between parallel tasks
  - Validating memory constraints don't exceed system limits
  - Ensuring CPU limits are reasonable for the pipeline
  - Detecting working directory conflicts
  - Validating environment variable usage
  """
  @impl Spark.Dsl.Verifier
  def verify(dsl_state) do
    # REFACTOR: In Reactor implementation:
    # 1. Resource conflicts checked by middleware before step execution
    # 2. Memory tracking done at runtime, not compile time
    # 3. CPU limits enforced via max_concurrency
    # 4. Working directory locks managed by middleware
    # 5. Environment managed per-step in Reactor context
    
    tasks = get_entities(dsl_state, [:pipeline_tasks])
    
    with :ok <- validate_resource_conflicts(tasks),
         :ok <- validate_memory_constraints(tasks),
         :ok <- validate_cpu_limits(tasks),
         :ok <- validate_working_directory_conflicts(tasks),
         :ok <- validate_environment_conflicts(tasks) do
      :ok
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, "Resource validation failed: #{inspect(error)}"}
    end
  end

  # Resource conflict validation

  defp validate_resource_conflicts(tasks) do
    parallel_groups = group_parallel_tasks(tasks)
    
    parallel_groups
    |> Enum.find_value(:ok, fn {_level, parallel_tasks} ->
      case check_resource_conflicts_in_group(parallel_tasks) do
        [] -> nil
        conflicts -> {:error, format_resource_conflicts(conflicts)}
      end
    end)
  end

  # REFACTOR: Reactor automatically manages parallel execution
  # based on DAG dependencies - no need to manually group
  defp group_parallel_tasks(tasks) do
    # Group tasks that can run in parallel (same execution level)
    tasks
    |> Enum.filter(& &1.parallel)
    |> Enum.group_by(fn task -> 
      Map.get(task, :execution_level, 0)
    end)
  end

  defp check_resource_conflicts_in_group(parallel_tasks) do
    conflicts = []
    
    # Check for working directory conflicts
    conflicts = conflicts ++ check_working_directory_conflicts(parallel_tasks)
    
    # Check for I/O intensive task conflicts
    conflicts = conflicts ++ check_io_conflicts(parallel_tasks)
    
    # Check for environment variable conflicts
    conflicts = conflicts ++ check_env_var_conflicts(parallel_tasks)
    
    conflicts
  end

  defp check_working_directory_conflicts(tasks) do
    tasks
    |> Enum.filter(fn task -> task.working_directory != nil end)
    |> Enum.group_by(& &1.working_directory)
    |> Enum.filter(fn {_dir, tasks_in_dir} -> length(tasks_in_dir) > 1 end)
    |> Enum.map(fn {dir, conflicting_tasks} ->
      {:working_directory_conflict, dir, Enum.map(conflicting_tasks, & &1.name)}
    end)
  end

  defp check_io_conflicts(tasks) do
    io_intensive_tasks = 
      tasks
      |> Enum.filter(&is_io_intensive_task/1)
    
    if length(io_intensive_tasks) > @max_parallel_io_tasks do
      [{:io_conflict, io_intensive_tasks |> Enum.map(& &1.name)}]
    else
      []
    end
  end

  defp is_io_intensive_task(task) do
    # Detect I/O intensive tasks based on command patterns
    io_patterns = [
      ~r/mix\s+compile/,
      ~r/mix\s+deps/,
      ~r/npm\s+install/,
      ~r/docker\s+build/,
      ~r/git\s+clone/,
      ~r/cp\s+/,
      ~r/rsync\s+/
    ]
    
    Enum.any?(io_patterns, &Regex.match?(&1, task.command))
  end

  defp check_env_var_conflicts(tasks) do
    # Check for conflicting environment variable assignments
    env_conflicts = 
      tasks
      |> Enum.flat_map(fn task ->
        Enum.map(task.environment, fn {key, value} ->
          {task.name, key, value}
        end)
      end)
      |> Enum.group_by(fn {_task, key, _value} -> key end)
      |> Enum.filter(fn {_key, assignments} -> 
        # Check if same env var has different values across tasks
        assignments
        |> Enum.map(fn {_task, _key, value} -> value end)
        |> Enum.uniq()
        |> length() > 1
      end)
      |> Enum.map(fn {env_key, conflicting_assignments} ->
        {:env_var_conflict, env_key, conflicting_assignments}
      end)
    
    env_conflicts
  end

  # Memory constraint validation

  defp validate_memory_constraints(tasks) do
    with :ok <- validate_individual_task_memory(tasks),
         :ok <- validate_total_memory_usage(tasks) do
      :ok
    end
  end

  defp validate_individual_task_memory(tasks) do
    memory_violations = 
      tasks
      |> Enum.filter(fn task ->
        estimated_memory = estimate_task_memory_usage(task)
        estimated_memory > @max_memory_per_task
      end)
    
    case memory_violations do
      [] -> :ok
      violations ->
        task_names = Enum.map(violations, & &1.name)
        validation_error("Tasks exceed individual memory limit (#{@max_memory_per_task}MB): #{inspect(task_names)}")
    end
  end

  defp validate_total_memory_usage(tasks) do
    parallel_groups = group_parallel_tasks(tasks)
    
    max_concurrent_memory = 
      parallel_groups
      |> Map.values()
      |> Enum.map(fn group ->
        Enum.reduce(group, 0, fn task, acc ->
          acc + estimate_task_memory_usage(task)
        end)
      end)
      |> Enum.max(fn -> 0 end)
    
    if max_concurrent_memory > @max_total_memory do
      validation_error("Total concurrent memory usage (#{max_concurrent_memory}MB) exceeds system limit (#{@max_total_memory}MB)")
    else
      :ok
    end
  end

  defp estimate_task_memory_usage(task) do
    # Simple heuristic for memory estimation
    base_memory = 128  # Base memory for any task
    
    # Increase memory based on command type
    command_memory = cond do
      String.contains?(task.command, "compile") -> 512
      String.contains?(task.command, "test") -> 256
      String.contains?(task.command, "dialyzer") -> 1024
      String.contains?(task.command, "docs") -> 256
      true -> 128
    end
    
    # Increase memory for longer timeout tasks (assumption: more complex)
    timeout_factor = min(task.timeout / 30_000, 2.0)
    timeout_memory = command_memory * timeout_factor
    
    round(base_memory + timeout_memory)
  end

  # CPU limit validation

  # REFACTOR: Use Reactor's max_concurrency option instead:
  # Reactor.run(reactor, inputs, context, max_concurrency: System.schedulers_online())
  defp validate_cpu_limits(tasks) do
    max_parallel_tasks = 
      tasks
      |> group_parallel_tasks()
      |> Map.values()
      |> Enum.map(&length/1)
      |> Enum.max(fn -> 0 end)
    
    system_cores = System.schedulers_online()
    
    if max_parallel_tasks > system_cores * 2 do
      validation_error("Maximum parallel tasks (#{max_parallel_tasks}) exceeds reasonable CPU limit (#{system_cores * 2})")
    else
      :ok
    end
  end

  # Working directory conflict validation

  defp validate_working_directory_conflicts(tasks) do
    conflicts = check_working_directory_conflicts(tasks)
    
    case conflicts do
      [] -> :ok
      _ -> validation_error(format_working_directory_conflicts(conflicts))
    end
  end

  # Environment variable conflict validation

  defp validate_environment_conflicts(tasks) do
    with :ok <- validate_reserved_env_vars(tasks),
         :ok <- validate_env_var_consistency(tasks) do
      :ok
    end
  end

  defp validate_reserved_env_vars(tasks) do
    reserved_violations = 
      tasks
      |> Enum.flat_map(fn task ->
        reserved_used = 
          task.environment
          |> Map.keys()
          |> Enum.filter(&(&1 in @reserved_env_vars))
        
        Enum.map(reserved_used, &{task.name, &1})
      end)
    
    case reserved_violations do
      [] -> :ok
      violations ->
        violation_summary = 
          violations
          |> Enum.map(fn {task, var} -> "#{task}:#{var}" end)
          |> Enum.join(", ")
        
        validation_error("Tasks attempt to override reserved environment variables: #{violation_summary}")
    end
  end

  defp validate_env_var_consistency(tasks) do
    env_conflicts = check_env_var_conflicts(tasks)
    
    case env_conflicts do
      [] -> :ok
      _ -> validation_error(format_env_var_conflicts(env_conflicts))
    end
  end

  # Helper functions

  defp get_entities(dsl_state, section_path) do
    Spark.Dsl.Transformer.get_entities(dsl_state, section_path) || []
  end

  defp validation_error(message) do
    {:error, DslError.exception(message: message)}
  end

  # Error formatting functions

  defp format_resource_conflicts(conflicts) do
    conflict_messages = 
      conflicts
      |> Enum.map(&format_single_conflict/1)
      |> Enum.join("; ")
    
    "Resource conflicts detected: #{conflict_messages}"
  end

  defp format_single_conflict({:working_directory_conflict, dir, tasks}) do
    "Working directory '#{dir}' used by parallel tasks: #{Enum.join(tasks, ", ")}"
  end

  defp format_single_conflict({:io_conflict, tasks}) do
    "Too many I/O intensive tasks running in parallel: #{Enum.join(tasks, ", ")}"
  end

  defp format_single_conflict({:env_var_conflict, key, assignments}) do
    task_values = 
      assignments
      |> Enum.map(fn {task, _key, value} -> "#{task}=#{value}" end)
      |> Enum.join(", ")
    
    "Environment variable '#{key}' has conflicting values: #{task_values}"
  end

  defp format_working_directory_conflicts(conflicts) do
    conflicts
    |> Enum.map(&format_single_conflict/1)
    |> Enum.join("; ")
  end

  defp format_env_var_conflicts(conflicts) do
    conflicts
    |> Enum.map(&format_single_conflict/1)
    |> Enum.join("; ")
  end
end
