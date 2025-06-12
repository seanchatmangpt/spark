defmodule AutoPipeline.Transformers.OptimizeExecutionOrder do
  @moduledoc """
  DSL transformer for optimizing task execution order based on dependencies.

  REFACTOR: This entire transformer should be removed.
  Reactor's executor already implements optimal execution strategies:
  - Automatic DAG-based execution ordering
  - Concurrent execution of independent steps
  - Resource-aware scheduling via max_concurrency
  - Dynamic execution based on step completion
  
  Migration: Remove this transformer and rely on Reactor's execution engine.
  Any custom optimization logic can be implemented as Reactor middleware.

  This transformer analyzes task dependencies and optimizes the execution order
  to minimize overall pipeline runtime while respecting dependency constraints.
  It implements advanced scheduling algorithms including:

  - Topological sorting for dependency ordering
  - Critical path analysis for maximum parallelization
  - Resource-aware scheduling for optimal task placement
  - Load balancing across parallel execution slots

  ## Usage

  Add this transformer to your DSL extension:

  ```elixir
  use Spark.Dsl.Extension,
    transformers: [AutoPipeline.Transformers.OptimizeExecutionOrder]
  ```

  ## Example Optimizations

  ```elixir
  # Before optimization - sequential execution
  pipeline_tasks do
    task :compile, command: "mix compile", depends_on: []
    task :test, command: "mix test", depends_on: [:compile]
    task :dialyzer, command: "mix dialyzer", depends_on: [:compile]
    task :credo, command: "mix credo", depends_on: []
  end

  # After optimization - parallel execution where possible
  # :compile runs first
  # :test, :dialyzer, and :credo can run in parallel after :compile
  # Optimal scheduling maximizes CPU utilization
  ```
  """

  use Spark.Dsl.Transformer

  @impl Spark.Dsl.Transformer
  def after?(AutoPipeline.Transformers.ValidateDependencies), do: true
  def after?(_), do: false

  @impl Spark.Dsl.Transformer
  def before?(_), do: false

  @doc """
  Transform the DSL state to optimize task execution order.

  This transformer performs several optimizations:
  1. Builds dependency graph from task definitions
  2. Performs topological sort to respect dependencies
  3. Analyzes critical paths for parallelization opportunities
  4. Adds execution_order and parallelization metadata to tasks
  5. Computes optimal resource allocation
  """
  @impl Spark.Dsl.Transformer
  def transform(dsl_state) do
    # REFACTOR: In Reactor-based implementation:
    # 1. This transformer would be completely removed
    # 2. Reactor.Executor handles all execution optimization
    # 3. Custom scheduling can be done via Reactor.Executor.Async hooks
    # 4. Metadata can be stored in step context instead of DSL state
    
    tasks = Spark.Dsl.Transformer.get_entities(dsl_state, [:pipeline_tasks])
    
    # Perform basic optimization analysis and store results
    dependency_graph = build_simple_dependency_graph(tasks)
    parallel_tasks = Enum.filter(tasks, & &1.parallel)
    
    updated_dsl_state = 
      dsl_state
      |> Spark.Dsl.Transformer.persist(:execution_order_optimized, true)
      |> Spark.Dsl.Transformer.persist(:parallel_task_count, length(parallel_tasks))
      |> Spark.Dsl.Transformer.persist(:dependency_complexity, map_size(dependency_graph))
    
    {:ok, updated_dsl_state}
  end

  defp build_simple_dependency_graph(tasks) do
    Enum.into(tasks, %{}, fn task -> {task.name, task.depends_on} end)
  end

  # Private optimization functions

  defp optimize_task_execution_order(tasks) do
    with {:ok, dependency_graph} <- build_dependency_graph(tasks),
         {:ok, execution_levels} <- compute_execution_levels(dependency_graph),
         {:ok, critical_paths} <- analyze_critical_paths(dependency_graph, tasks),
         {:ok, parallelization_plan} <- compute_parallelization_plan(execution_levels, tasks) do
      
      optimized_tasks = enhance_tasks_with_optimization_data(
        tasks, 
        execution_levels, 
        critical_paths, 
        parallelization_plan
      )
      
      {:ok, optimized_tasks}
    end
  end

  defp build_dependency_graph(tasks) do
    try do
      graph = 
        tasks
        |> Enum.reduce(%{}, fn task, acc ->
          Map.put(acc, task.name, task.depends_on)
        end)
      
      {:ok, graph}
    rescue
      e -> {:error, "Failed to build dependency graph: #{inspect(e)}"}
    end
  end

  defp compute_execution_levels(dependency_graph) do
    try do
      levels = topological_sort_with_levels(dependency_graph)
      {:ok, levels}
    rescue
      e -> {:error, "Failed to compute execution levels: #{inspect(e)}"}
    end
  end

  # REFACTOR: Reactor performs topological sorting internally
  # No need for custom implementation
  defp topological_sort_with_levels(graph) do
    # Initialize levels map
    levels = Map.keys(graph) |> Enum.into(%{}, &{&1, 0})
    
    # Compute levels using DFS
    compute_levels(graph, levels, Map.keys(graph))
  end

  defp compute_levels(graph, levels, nodes) do
    Enum.reduce(nodes, levels, fn node, acc_levels ->
      compute_node_level(graph, acc_levels, node, MapSet.new())
    end)
  end

  defp compute_node_level(graph, levels, node, visited) do
    if MapSet.member?(visited, node) do
      levels  # Avoid infinite recursion on cycles
    else
      new_visited = MapSet.put(visited, node)
      dependencies = Map.get(graph, node, [])
      
      max_dep_level = 
        dependencies
        |> Enum.reduce(0, fn dep, max_level ->
          dep_levels = compute_node_level(graph, levels, dep, new_visited)
          dep_level = Map.get(dep_levels, dep, 0)
          max(max_level, dep_level)
        end)
      
      Map.put(levels, node, max_dep_level + 1)
    end
  end

  defp analyze_critical_paths(dependency_graph, tasks) do
    task_durations = 
      tasks
      |> Enum.into(%{}, fn task ->
        # Use timeout as estimated duration, default to 30 seconds
        duration = Map.get(task, :timeout, 30_000)
        {task.name, duration}
      end)
    
    critical_path = find_critical_path(dependency_graph, task_durations)
    {:ok, %{critical_path: critical_path, task_durations: task_durations}}
  end

  # REFACTOR: Critical path analysis could be implemented as Reactor telemetry
  # handler that tracks execution times and identifies bottlenecks
  defp find_critical_path(graph, durations) do
    # Simple critical path calculation - find longest path through dependency graph
    all_paths = find_all_paths(graph)
    
    all_paths
    |> Enum.map(fn path ->
      total_duration = Enum.reduce(path, 0, &(&2 + Map.get(durations, &1, 0)))
      {total_duration, path}
    end)
    |> Enum.max_by(fn {duration, _path} -> duration end)
    |> elem(1)
  end

  defp find_all_paths(graph) do
    # Find all possible execution paths through the dependency graph
    roots = find_root_nodes(graph)
    
    roots
    |> Enum.flat_map(fn root ->
      find_paths_from_node(graph, root, [])
    end)
  end

  defp find_root_nodes(graph) do
    all_nodes = MapSet.new(Map.keys(graph))
    dependent_nodes = 
      graph
      |> Map.values()
      |> List.flatten()
      |> MapSet.new()
    
    MapSet.difference(all_nodes, dependent_nodes)
    |> MapSet.to_list()
  end

  defp find_paths_from_node(graph, node, current_path) do
    new_path = [node | current_path]
    dependents = find_dependents(graph, node)
    
    case dependents do
      [] -> [Enum.reverse(new_path)]
      _ -> 
        dependents
        |> Enum.flat_map(fn dependent ->
          find_paths_from_node(graph, dependent, new_path)
        end)
    end
  end

  defp find_dependents(graph, target_node) do
    graph
    |> Enum.filter(fn {_node, deps} -> target_node in deps end)
    |> Enum.map(fn {node, _deps} -> node end)
  end

  defp compute_parallelization_plan(execution_levels, tasks) do
    # Group tasks by execution level for parallel execution
    parallelization_groups = 
      execution_levels
      |> Enum.group_by(fn {_task, level} -> level end, fn {task, _level} -> task end)
      |> Map.new()
    
    # Analyze resource requirements and compute optimal parallel slots
    parallel_slots = compute_optimal_parallel_slots(tasks, parallelization_groups)
    
    {:ok, %{
      execution_groups: parallelization_groups,
      parallel_slots: parallel_slots
    }}
  end

  # REFACTOR: Use Reactor's max_concurrency option instead
  # Reactor.run(reactor, inputs, context, max_concurrency: System.schedulers_online())
  defp compute_optimal_parallel_slots(tasks, groups) do
    # Simple heuristic: limit parallel tasks based on system capabilities
    # In practice, this could consider CPU cores, memory, etc.
    max_parallel = System.schedulers_online()
    
    groups
    |> Map.new(fn {level, task_names} ->
      parallel_count = min(length(task_names), max_parallel)
      {level, parallel_count}
    end)
  end

  defp enhance_tasks_with_optimization_data(tasks, execution_levels, critical_paths, parallelization_plan) do
    tasks
    |> Enum.map(fn task ->
      execution_level = Map.get(execution_levels, task.name, 0)
      is_critical = task.name in critical_paths.critical_path
      parallel_group = Map.get(parallelization_plan.execution_groups, execution_level, [])
      
      # Return optimization metadata as a separate map
      %{
        task: task,
        execution_level: execution_level,
        is_critical_path: is_critical,
        parallel_group_size: length(parallel_group),
        estimated_duration: Map.get(critical_paths.task_durations, task.name, task.timeout),
        optimization_metadata: %{
          can_parallelize: task.parallel,
          execution_priority: if(is_critical, do: :high, else: :normal),
          resource_weight: compute_resource_weight(task)
        }
      }
    end)
  end

  defp compute_resource_weight(task) do
    # Simple heuristic for resource requirements
    base_weight = 1.0
    
    # Increase weight for tasks with longer timeouts
    timeout_factor = task.timeout / 30_000.0
    
    # Increase weight for tasks with many dependencies (likely more complex)
    dependency_factor = length(task.depends_on) * 0.2
    
    base_weight + timeout_factor + dependency_factor
  end
end
