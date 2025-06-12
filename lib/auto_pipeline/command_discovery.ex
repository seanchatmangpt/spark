defmodule AutoPipeline.CommandDiscovery do
  @moduledoc """
  Discovers and analyzes available commands in the .claude/commands directory.
  Creates execution plans with dependency management and resource optimization.
  
  REFACTOR: This module would transform discovered commands into Reactor steps.
  Instead of custom execution plans, it would build a Reactor struct with
  all discovered commands as steps with proper dependencies.
  
  Migration: Update to return a Reactor struct instead of custom plan.
  """

  alias AutoPipeline.{Command, ExecutionSchedule}

  @commands_dir ".claude/commands"

  def discover_available_commands do
    # REFACTOR: Return a Reactor struct instead:
    # reactor = Reactor.new()
    # commands |> Enum.reduce(reactor, &add_command_as_step/2)
    
    command_files = Path.wildcard("#{@commands_dir}/*.md")
    
    commands = Enum.map(command_files, &parse_command_file/1)
    
    categorized_commands = %{
      generation: filter_commands(commands, :generation),
      analysis: filter_commands(commands, :analysis),
      documentation: filter_commands(commands, :documentation),
      testing: filter_commands(commands, :testing),
      optimization: filter_commands(commands, :optimization),
      utility: filter_commands(commands, :utility)
    }
    
    # REFACTOR: No need for custom dependency graph - Reactor handles this
    dependency_graph = build_dependency_graph(commands)
    
    %{
      all_commands: commands,
      categorized: categorized_commands,
      dependency_graph: dependency_graph,
      execution_plan: create_optimal_execution_plan(commands, dependency_graph)
    }
  end

  defp parse_command_file(file_path) do
    # REFACTOR: Parse commands to create Reactor step definitions
    content = File.read!(file_path)
    name = extract_command_name(file_path)
    
    %Command{
      name: name,
      file_path: file_path,
      description: extract_description(content),
      arguments: extract_arguments(content),
      dependencies: extract_dependencies(content),
      estimated_duration: estimate_duration(content),
      resource_requirements: assess_resource_requirements(content),
      output_artifacts: identify_output_artifacts(content),
      quality_impact: assess_quality_impact(content),
      category: categorize_command(name, content)
    }
  end

  defp extract_command_name(file_path) do
    file_path
    |> Path.basename()
    |> Path.rootname()
    |> String.replace("-", "_")
    |> String.to_atom()
  end

  defp extract_description(content) do
    case Regex.run(~r/^# (.+)$/m, content) do
      [_, description] -> String.trim(description)
      _ -> "No description available"
    end
  end

  defp extract_arguments(content) do
    case Regex.run(~r/## Usage\s*```\s*([^`]+)```/s, content) do
      [_, usage] -> parse_usage_arguments(usage)
      _ -> []
    end
  end

  defp parse_usage_arguments(usage) do
    # Extract arguments from usage patterns like /command [arg1] [arg2]
    case Regex.scan(~r/\[([^\]]+)\]/, usage) do
      matches -> Enum.map(matches, fn [_, arg] -> String.to_atom(arg) end)
      _ -> []
    end
  end

  defp extract_dependencies(content) do
    # Look for dependency patterns in the content
    dependencies = []
    
    # Check if command mentions other commands it depends on
    dependencies = if String.contains?(content, "dsl-create"), do: [:dsl_create | dependencies], else: dependencies
    dependencies = if String.contains?(content, "test"), do: [:test_dsl | dependencies], else: dependencies
    dependencies = if String.contains?(content, "analyze"), do: [:spark_analyze | dependencies], else: dependencies
    
    dependencies
  end

  defp estimate_duration(content) do
    # Estimate based on command complexity and content length
    cond do
      String.contains?(content, "infinite") -> 300_000  # 5 minutes
      String.contains?(content, "generate") -> 120_000  # 2 minutes
      String.contains?(content, "analyze") -> 60_000    # 1 minute
      String.contains?(content, "test") -> 90_000       # 1.5 minutes
      String.contains?(content, "docs") -> 45_000       # 45 seconds
      true -> 30_000  # 30 seconds default
    end
  end

  defp assess_resource_requirements(content) do
    %{
      cpu_intensive: String.contains?(content, "analysis") || String.contains?(content, "generate"),
      memory_intensive: String.contains?(content, "infinite") || String.contains?(content, "mcp"),
      io_intensive: String.contains?(content, "docs") || String.contains?(content, "test"),
      network_required: String.contains?(content, "mcp") || String.contains?(content, "fetch")
    }
  end

  defp identify_output_artifacts(content) do
    artifacts = []
    
    artifacts = if String.contains?(content, "DSL"), do: [:dsl_extension | artifacts], else: artifacts
    artifacts = if String.contains?(content, "transformer"), do: [:transformer | artifacts], else: artifacts
    artifacts = if String.contains?(content, "verifier"), do: [:verifier | artifacts], else: artifacts
    artifacts = if String.contains?(content, "docs"), do: [:documentation | artifacts], else: artifacts
    artifacts = if String.contains?(content, "test"), do: [:test | artifacts], else: artifacts
    
    artifacts
  end

  defp assess_quality_impact(content) do
    # Higher scores for commands that significantly impact code quality
    cond do
      String.contains?(content, "test") -> 90
      String.contains?(content, "analyze") -> 85
      String.contains?(content, "verify") -> 80
      String.contains?(content, "generate") -> 75
      String.contains?(content, "docs") -> 70
      true -> 60
    end
  end

  defp categorize_command(name, content) do
    cond do
      String.contains?(to_string(name), "generate") || String.contains?(content, "create") -> :generation
      String.contains?(to_string(name), "analyze") || String.contains?(content, "analysis") -> :analysis
      String.contains?(to_string(name), "docs") || String.contains?(content, "documentation") -> :documentation
      String.contains?(to_string(name), "test") || String.contains?(content, "testing") -> :testing
      String.contains?(to_string(name), "infinite") || String.contains?(content, "optimize") -> :optimization
      true -> :utility
    end
  end

  defp filter_commands(commands, category) do
    Enum.filter(commands, fn command -> command.category == category end)
  end

  defp build_dependency_graph(commands) do
    # Build a simple dependency map
    Enum.reduce(commands, %{}, fn command, graph ->
      Map.put(graph, command.name, command.dependencies)
    end)
  end

  defp create_optimal_execution_plan(commands, dependency_graph) do
    # Simple execution plan - just return commands in dependency order
    sorted_commands = commands
    
    %ExecutionSchedule{
      commands: sorted_commands,
      total_estimated_time: Enum.sum(Enum.map(commands, & &1.estimated_duration)),
      waves: group_into_waves(sorted_commands, dependency_graph),
      critical_path: identify_critical_path(sorted_commands)
    }
  end

  defp topological_sort(commands, dependency_graph) do
    # Simple topological sort implementation
    {sorted, _} = do_topological_sort(commands, dependency_graph, [], MapSet.new())
    Enum.reverse(sorted)
  end

  defp do_topological_sort([], _graph, sorted, _visited), do: {sorted, MapSet.new()}
  
  defp do_topological_sort([command | rest], graph, sorted, visited) do
    if MapSet.member?(visited, command.name) do
      do_topological_sort(rest, graph, sorted, visited)
    else
      {sorted_deps, visited_deps} = resolve_dependencies(command, graph, sorted, visited)
      new_sorted = [command | sorted_deps]
      new_visited = MapSet.put(visited_deps, command.name)
      do_topological_sort(rest, graph, new_sorted, new_visited)
    end
  end

  defp resolve_dependencies(command, graph, sorted, visited) do
    dependencies = Map.get(graph, command.name, [])
    
    Enum.reduce(dependencies, {sorted, visited}, fn dep, {acc_sorted, acc_visited} ->
      if MapSet.member?(acc_visited, dep) do
        {acc_sorted, acc_visited}
      else
        # Find the dependency command and process it
        dep_command = Enum.find(graph, fn {name, _} -> name == dep end)
        if dep_command do
          {[dep_command | acc_sorted], MapSet.put(acc_visited, dep)}
        else
          {acc_sorted, acc_visited}
        end
      end
    end)
  end

  defp group_into_waves(commands, dependency_graph) do
    # Group commands into execution waves based on dependencies
    waves = []
    remaining = commands
    
    group_waves(remaining, dependency_graph, waves, [])
  end

  defp group_waves([], _graph, waves, _completed), do: Enum.reverse(waves)
  
  defp group_waves(remaining, graph, waves, completed) do
    # Find commands with no unfulfilled dependencies
    ready_commands = Enum.filter(remaining, fn command ->
      dependencies = Map.get(graph, command.name, [])
      Enum.all?(dependencies, fn dep -> dep in completed end)
    end)
    
    if ready_commands == [] do
      # If no commands are ready, add remaining commands to avoid infinite loop
      Enum.reverse([remaining | waves])
    else
      new_completed = completed ++ Enum.map(ready_commands, & &1.name)
      new_remaining = remaining -- ready_commands
      new_waves = [ready_commands | waves]
      
      group_waves(new_remaining, graph, new_waves, new_completed)
    end
  end

  defp identify_critical_path(commands) do
    # Simple critical path identification - commands with highest cumulative duration
    Enum.sort_by(commands, & &1.estimated_duration, :desc)
    |> Enum.take(3)
    |> Enum.map(& &1.name)
  end
end