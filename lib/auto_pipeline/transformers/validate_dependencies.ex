defmodule AutoPipeline.Transformers.ValidateDependencies do
  @moduledoc """
  Transformer that validates task dependencies at compile time.

  REFACTOR: This entire transformer should be removed.
  Reactor automatically validates dependencies when building the DAG.
  Reactor will raise errors for:
  - Non-existent step references
  - Circular dependencies
  - Invalid dependency graphs
  
  Migration: Simply let Reactor handle all dependency validation.

  This ensures that:
  1. All task dependencies reference existing tasks
  2. There are no circular dependencies
  3. The dependency graph is valid
  """

  use Spark.Dsl.Transformer

  @impl Spark.Dsl.Transformer
  def before?(Spark.Dsl.Transformer.SetAttribute), do: true
  def before?(_), do: false

  @impl Spark.Dsl.Transformer
  def after?(Spark.Dsl.Transformer.SetAttribute), do: false
  def after?(_), do: true

  @impl Spark.Dsl.Transformer  
  def transform(dsl_state) do
    # REFACTOR: In Reactor-based implementation, this transformer would be removed entirely.
    # The ConvertToReactor transformer would build the Reactor struct, and Reactor
    # would handle all validation automatically during add_step operations.
    
    tasks = Spark.Dsl.Transformer.get_entities(dsl_state, [:pipeline_tasks])
    
    with :ok <- validate_dependencies_exist(tasks),
         :ok <- validate_no_circular_dependencies(tasks) do
      {:ok, dsl_state}
    else
      {:error, error} ->
        {:error, 
         Spark.Error.DslError.exception(
           module: Spark.Dsl.Transformer.get_persisted(dsl_state, :module),
           message: error,
           path: [:pipeline_tasks]
         )}
    end
  end

  defp validate_dependencies_exist(tasks) do
    task_names = MapSet.new(tasks, & &1.name)
    
    invalid_deps = 
      tasks
      |> Enum.flat_map(fn task ->
        Enum.reject(task.depends_on, &MapSet.member?(task_names, &1))
        |> Enum.map(&{task.name, &1})
      end)
    
    case invalid_deps do
      [] -> 
        :ok
      deps -> 
        {:error, "Task dependency validation failed. The following tasks reference non-existent dependencies: #{format_invalid_deps(deps)}"}
    end
  end

  defp validate_no_circular_dependencies(tasks) do
    task_map = Map.new(tasks, &{&1.name, &1.depends_on})
    
    case find_circular_dependency(task_map) do
      nil -> 
        :ok
      cycle -> 
        {:error, "Circular dependency detected in task pipeline: #{Enum.join(cycle, " -> ")}"}
    end
  end

  defp format_invalid_deps(deps) do
    deps
    |> Enum.map(fn {task, dep} -> "#{task} depends on #{dep}" end)
    |> Enum.join(", ")
  end

  # REFACTOR: Reactor's graph building automatically detects cycles
  # This entire function and its helpers can be removed
  defp find_circular_dependency(task_map) do
    task_map
    |> Map.keys()
    |> Enum.find_value(fn task ->
      case detect_cycle(task, task_map, MapSet.new(), []) do
        {:cycle, path} -> path
        :no_cycle -> nil
      end
    end)
  end

  defp detect_cycle(task, task_map, visited, path) do
    cond do
      task in visited ->
        cycle_start = Enum.find_index(path, &(&1 == task))
        cycle = Enum.drop(path, cycle_start) |> Enum.reverse()
        {:cycle, [task | cycle]}
      
      Map.has_key?(task_map, task) ->
        new_visited = MapSet.put(visited, task)
        new_path = [task | path]
        
        task_map[task]
        |> Enum.find_value(:no_cycle, fn dep ->
          case detect_cycle(dep, task_map, new_visited, new_path) do
            {:cycle, cycle_path} -> {:cycle, cycle_path}
            :no_cycle -> nil
          end
        end) || :no_cycle
      
      true ->
        :no_cycle
    end
  end
end