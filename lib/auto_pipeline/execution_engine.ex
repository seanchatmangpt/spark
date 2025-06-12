defmodule AutoPipeline.ExecutionEngine do
  @moduledoc """
  Simple execution engine for automated pipeline commands.
  Provides reliable execution with failure recovery without external dependencies.
  
  REFACTOR: This entire module should be replaced by Reactor.
  Reactor provides all these features and more:
  - Dependency resolution and DAG execution
  - Concurrent step execution with max_concurrency
  - Built-in error handling and compensation
  - Comprehensive telemetry
  - Dynamic step addition
  
  Migration: Remove this module and use Reactor.run/4 instead.
  """

  alias AutoPipeline.{CommandDiscovery, QualityAssurance, ExecutionResult}

  def run(inputs) do
    # REFACTOR: Replace with Reactor.run/4:
    # reactor = build_reactor_from_discovery()
    # Reactor.run(reactor, inputs, context, max_concurrency: inputs.max_concurrency)
    
    try do
      # Step 1: Discover available commands
      command_discovery = CommandDiscovery.discover_available_commands()
      
      # Step 2: Create execution schedule
      # REFACTOR: Reactor handles scheduling automatically
      schedule = create_execution_schedule(
        command_discovery,
        inputs.project_scope,
        inputs.mode,
        inputs.max_concurrency
      )
      
      # Step 3: Execute command waves
      # REFACTOR: Reactor executes steps based on DAG
      execution_results = execute_command_waves(schedule, inputs.quality_threshold)
      
      # Step 4: Generate report
      # REFACTOR: Use Reactor telemetry events for reporting
      report = generate_pipeline_report(execution_results, schedule)
      
      {:ok, report}
    rescue
      error -> {:error, error}
    end
  end

  defp create_execution_schedule(command_discovery, project_scope, mode, max_concurrency) do
    # REFACTOR: Reactor builds execution plan from DAG automatically
    # No need for manual wave calculation
    relevant_commands = filter_by_scope(command_discovery.categorized, project_scope)
    execution_waves = calculate_optimal_waves(relevant_commands, command_discovery.dependency_graph, max_concurrency)
    prioritized_waves = adjust_for_mode(execution_waves, mode)
    
    %{
      waves: prioritized_waves,
      total_estimated_time: calculate_total_time(prioritized_waves),
      resource_requirements: calculate_resource_requirements(prioritized_waves),
      critical_path: identify_critical_path(prioritized_waves),
      quality_checkpoints: insert_quality_checkpoints(prioritized_waves)
    }
  end

  defp filter_by_scope(categorized_commands, project_scope) do
    case project_scope do
      "full" -> Map.values(categorized_commands) |> List.flatten()
      "dsl-only" -> categorized_commands.generation ++ categorized_commands.testing
      "analysis-only" -> categorized_commands.analysis ++ categorized_commands.optimization
      "docs-only" -> categorized_commands.documentation
      _ -> Map.values(categorized_commands) |> List.flatten()
    end
  end

  defp calculate_optimal_waves(commands, dependency_graph, max_concurrency) do
    # Group commands into waves respecting dependencies and concurrency limits
    sorted_commands = topological_sort_commands(commands, dependency_graph)
    group_into_concurrent_waves(sorted_commands, dependency_graph, max_concurrency)
  end

  defp topological_sort_commands(commands, dependency_graph) do
    # Simple topological sort implementation
    command_map = Map.new(commands, fn cmd -> {cmd.name, cmd} end)
    
    {sorted, _} = do_topological_sort(
      Map.keys(command_map), 
      dependency_graph, 
      [], 
      MapSet.new(), 
      command_map
    )
    
    Enum.reverse(sorted)
  end

  defp do_topological_sort([], _graph, sorted, _visited, _command_map), do: {sorted, MapSet.new()}
  
  defp do_topological_sort([cmd_name | rest], graph, sorted, visited, command_map) do
    if MapSet.member?(visited, cmd_name) do
      do_topological_sort(rest, graph, sorted, visited, command_map)
    else
      dependencies = Map.get(graph, cmd_name, [])
      
      # Process dependencies first
      {dep_sorted, dep_visited} = Enum.reduce(dependencies, {sorted, visited}, fn dep, {acc_sorted, acc_visited} ->
        if MapSet.member?(acc_visited, dep) do
          {acc_sorted, acc_visited}
        else
          command = Map.get(command_map, dep)
          if command do
            {[command | acc_sorted], MapSet.put(acc_visited, dep)}
          else
            {acc_sorted, acc_visited}
          end
        end
      end)
      
      # Add current command
      command = Map.get(command_map, cmd_name)
      new_sorted = if command, do: [command | dep_sorted], else: dep_sorted
      new_visited = MapSet.put(dep_visited, cmd_name)
      
      do_topological_sort(rest, graph, new_sorted, new_visited, command_map)
    end
  end

  defp group_into_concurrent_waves(commands, dependency_graph, max_concurrency) do
    waves = []
    remaining = commands
    completed = []
    
    group_waves_recursive(remaining, dependency_graph, waves, completed, max_concurrency)
  end

  defp group_waves_recursive([], _graph, waves, _completed, _max_concurrency), do: Enum.reverse(waves)
  
  defp group_waves_recursive(remaining, graph, waves, completed, max_concurrency) do
    # Find commands with no unfulfilled dependencies
    ready_commands = Enum.filter(remaining, fn command ->
      dependencies = Map.get(graph, command.name, [])
      Enum.all?(dependencies, fn dep -> dep in completed end)
    end)
    
    case ready_commands do
      [] ->
        # No commands ready - add remaining to avoid infinite loop
        Enum.reverse([remaining | waves])
      _ ->
        # Limit by max concurrency and resource constraints
        wave_commands = Enum.take(ready_commands, max_concurrency)
        new_completed = completed ++ Enum.map(wave_commands, & &1.name)
        new_remaining = remaining -- wave_commands
        new_waves = [wave_commands | waves]
        
        group_waves_recursive(new_remaining, graph, new_waves, new_completed, max_concurrency)
    end
  end

  defp adjust_for_mode(waves, mode) do
    case mode do
      "production" -> prioritize_quality_commands(waves)
      "research" -> prioritize_analysis_commands(waves) 
      "maintenance" -> prioritize_optimization_commands(waves)
      _ -> waves # development mode - no special prioritization
    end
  end

  defp prioritize_quality_commands(waves) do
    # Move testing and verification commands to earlier waves
    Enum.map(waves, fn wave ->
      Enum.sort_by(wave, fn cmd ->
        case cmd.category do
          :testing -> 1
          :analysis -> 2
          :generation -> 3
          _ -> 4
        end
      end)
    end)
  end

  defp prioritize_analysis_commands(waves) do
    # Move analysis commands to earlier waves
    Enum.map(waves, fn wave ->
      Enum.sort_by(wave, fn cmd ->
        case cmd.category do
          :analysis -> 1
          :optimization -> 2
          :generation -> 3
          _ -> 4
        end
      end)
    end)
  end

  defp prioritize_optimization_commands(waves) do
    # Move optimization commands to earlier waves
    Enum.map(waves, fn wave ->
      Enum.sort_by(wave, fn cmd ->
        case cmd.category do
          :optimization -> 1
          :analysis -> 2
          :testing -> 3
          _ -> 4
        end
      end)
    end)
  end

  defp calculate_total_time(waves) do
    # Sum of maximum duration in each wave (since they run concurrently)
    Enum.reduce(waves, 0, fn wave, acc ->
      max_duration = Enum.max_by(wave, & &1.estimated_duration, fn -> %{estimated_duration: 0} end)
      acc + (max_duration.estimated_duration || 0)
    end)
  end

  defp calculate_resource_requirements(waves) do
    # Calculate peak resource requirements across all waves
    Enum.reduce(waves, %{cpu: 0, memory: 0, io: 0, network: 0}, fn wave, acc ->
      wave_resources = Enum.reduce(wave, %{cpu: 0, memory: 0, io: 0, network: 0}, fn cmd, wave_acc ->
        reqs = cmd.resource_requirements
        %{
          cpu: wave_acc.cpu + (if reqs.cpu_intensive, do: 1, else: 0),
          memory: wave_acc.memory + (if reqs.memory_intensive, do: 1, else: 0),
          io: wave_acc.io + (if reqs.io_intensive, do: 1, else: 0),
          network: wave_acc.network + (if reqs.network_required, do: 1, else: 0)
        }
      end)
      
      %{
        cpu: max(acc.cpu, wave_resources.cpu),
        memory: max(acc.memory, wave_resources.memory),
        io: max(acc.io, wave_resources.io),
        network: max(acc.network, wave_resources.network)
      }
    end)
  end

  defp identify_critical_path(waves) do
    # Find the longest path through the waves
    Enum.flat_map(waves, fn wave ->
      Enum.take(Enum.sort_by(wave, & &1.estimated_duration, :desc), 1)
    end)
    |> Enum.map(& &1.name)
  end

  defp insert_quality_checkpoints(waves) do
    # Add quality checkpoints after each wave
    Enum.with_index(waves)
    |> Enum.map(fn {wave, index} ->
      %{
        wave_index: index,
        commands: wave,
        quality_checkpoint: true
      }
    end)
  end

  defp execute_command_waves(schedule, quality_threshold) do
    IO.puts("🚀 Starting Automated Spark DSL Development Pipeline")
    IO.puts("📊 Total Waves: #{length(schedule.waves)} | Quality Threshold: #{quality_threshold}%")
    
    total_waves = length(schedule.waves)
    
    {results, _} = Enum.with_index(schedule.waves)
    |> Enum.reduce({[], %{completed: [], failed: []}}, fn {wave, wave_index}, {all_results, acc_status} ->
      IO.puts("\n🌊 Executing Wave #{wave_index + 1}/#{total_waves}: #{length(wave)} commands")
      
      # Execute wave commands concurrently using Task.async_stream
      wave_results = execute_wave_concurrently(wave, acc_status, quality_threshold)
      
      # Quality checkpoint after each wave
      quality_check = QualityAssurance.perform_quality_checkpoint(wave_results, quality_threshold)
      
      case quality_check.status do
        :continue ->
          new_completed = acc_status.completed ++ Enum.map(wave_results, & &1.command)
          new_status = %{acc_status | completed: new_completed}
          {all_results ++ wave_results, new_status}
          
        :abort ->
          IO.puts("❌ Quality threshold not met. Aborting pipeline.")
          aborted_result = %ExecutionResult{
            status: :aborted,
            wave_index: wave_index + 1,
            results: all_results ++ wave_results,
            quality_check: quality_check
          }
          {[aborted_result], acc_status}
          
        :retry_with_improvements ->
          IO.puts("🔄 Retrying wave with quality improvements...")
          improved_wave = apply_quality_improvements(wave, quality_check.improvements)
          retry_results = execute_wave_concurrently(improved_wave, acc_status, quality_threshold)
          new_completed = acc_status.completed ++ Enum.map(retry_results, & &1.command)
          new_status = %{acc_status | completed: new_completed}
          {all_results ++ retry_results, new_status}
      end
    end)
    
    %ExecutionResult{
      status: :completed,
      results: results,
      total_commands: Enum.sum(Enum.map(schedule.waves, &length/1)),
      successful_commands: Enum.count(results, fn r -> r.status == :success end),
      failed_commands: Enum.count(results, fn r -> r.status == :failed end)
    }
  end

  defp execute_wave_concurrently(wave_commands, context, quality_threshold) do
    # Use Task.async_stream for concurrent execution
    wave_commands
    |> Task.async_stream(
      fn command -> execute_command_with_monitoring(command, context, quality_threshold) end,
      max_concurrency: length(wave_commands),
      timeout: :timer.minutes(10)
    )
    |> Enum.map(fn {:ok, result} -> result end)
  end

  defp execute_command_with_monitoring(command, _context, quality_threshold) do
    IO.puts("  ▶️  Executing: #{command.name}")
    start_time = System.monotonic_time(:millisecond)
    
    # Simulate command execution - in real implementation, this would call the actual command
    result = simulate_command_execution(command)
    
    execution_time = System.monotonic_time(:millisecond) - start_time
    
    # Validate output quality
    quality_score = assess_output_quality(result, command, quality_threshold)
    
    %{
      command: command.name,
      status: determine_status(result, quality_score, quality_threshold),
      output: result,
      quality_score: quality_score,
      execution_time: execution_time,
      artifacts: extract_artifacts(result, command),
      errors: extract_errors(result),
      warnings: extract_warnings(result)
    }
  end

  defp simulate_command_execution(command) do
    # Simulate execution time
    Process.sleep(div(command.estimated_duration, 10))
    
    # Simulate different outcomes based on command type
    case command.category do
      :testing -> %{status: :success, output: "All tests passed", artifacts: [:test_results]}
      :generation -> %{status: :success, output: "DSL generated", artifacts: [:dsl_extension]}
      :analysis -> %{status: :success, output: "Analysis complete", artifacts: [:analysis_report]}
      :documentation -> %{status: :success, output: "Docs generated", artifacts: [:documentation]}
      _ -> %{status: :success, output: "Command completed", artifacts: []}
    end
  end

  defp assess_output_quality(result, command, _quality_threshold) do
    # Simple quality assessment based on command success and type
    base_score = if result.status == :success, do: 80, else: 40
    
    # Adjust based on command's quality impact
    adjustment = div(command.quality_impact, 10)
    
    min(100, base_score + adjustment)
  end

  defp determine_status(result, quality_score, quality_threshold) do
    cond do
      result.status != :success -> :failed
      quality_score < quality_threshold -> :quality_failed
      true -> :success
    end
  end

  defp extract_artifacts(result, _command) do
    Map.get(result, :artifacts, [])
  end

  defp extract_errors(result) do
    Map.get(result, :errors, [])
  end

  defp extract_warnings(result) do
    Map.get(result, :warnings, [])
  end

  defp apply_quality_improvements(wave, improvements) do
    # Apply suggested improvements to commands in the wave
    Enum.map(wave, fn command ->
      improvement = Enum.find(improvements, fn imp -> imp.command == command.name end)
      if improvement do
        # Apply the improvement strategy
        apply_improvement_strategy(command, improvement)
      else
        command
      end
    end)
  end

  defp apply_improvement_strategy(command, _improvement) do
    # Simple improvement: increase timeout for retry
    %{command | estimated_duration: command.estimated_duration * 2}
  end

  defp generate_pipeline_report(execution_results, schedule) do
    summary = %{
      total_commands: execution_results.total_commands,
      successful_commands: execution_results.successful_commands,
      failed_commands: execution_results.failed_commands,
      average_quality: calculate_average_quality(execution_results.results),
      total_execution_time: schedule.total_estimated_time,
      artifacts_generated: collect_all_artifacts(execution_results.results)
    }
    
    # Generate markdown report
    markdown_report = generate_markdown_report(summary, execution_results)
    
    # Save report
    File.write!("auto_pipeline_report.md", markdown_report)
    
    # Print summary
    print_pipeline_summary(summary)
    
    %{
      summary: summary,
      report_path: "auto_pipeline_report.md",
      execution_results: execution_results
    }
  end

  defp calculate_average_quality(results) do
    if length(results) > 0 do
      total_quality = Enum.sum(Enum.map(results, & &1.quality_score))
      div(total_quality, length(results))
    else
      0
    end
  end

  defp collect_all_artifacts(results) do
    Enum.flat_map(results, & &1.artifacts)
  end

  defp generate_markdown_report(summary, execution_results) do
    """
    # Automated Spark DSL Pipeline Report

    ## Execution Summary
    - **Total Commands**: #{summary.total_commands}
    - **Successful**: #{summary.successful_commands}
    - **Failed**: #{summary.failed_commands}
    - **Average Quality**: #{summary.average_quality}%
    - **Total Execution Time**: #{format_duration(summary.total_execution_time)}

    ## Generated Artifacts
    #{format_artifacts(summary.artifacts_generated)}

    ## Command Results
    #{format_command_results(execution_results.results)}

    ---
    *Generated by AutoPipeline.ExecutionEngine at #{DateTime.utc_now()}*
    """
  end

  defp format_duration(milliseconds) do
    seconds = div(milliseconds, 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    
    if minutes > 0 do
      "#{minutes}m #{remaining_seconds}s"
    else
      "#{remaining_seconds}s"
    end
  end

  defp format_artifacts(artifacts) do
    artifact_counts = Enum.frequencies(artifacts)
    
    Enum.map(artifact_counts, fn {artifact, count} ->
      "- #{artifact}: #{count}"
    end)
    |> Enum.join("\n")
  end

  defp format_command_results(results) do
    Enum.map(results, fn result ->
      status_icon = case result.status do
        :success -> "✅"
        :failed -> "❌"
        :quality_failed -> "⚠️"
      end
      
      "#{status_icon} **#{result.command}** (#{result.quality_score}%) - #{result.execution_time}ms"
    end)
    |> Enum.join("\n")
  end

  defp print_pipeline_summary(summary) do
    IO.puts("""

    🎉 Automated Spark DSL Pipeline Complete!
    ==========================================

    📈 Execution Summary:
       Total Commands: #{summary.total_commands}
       ✅ Successful: #{summary.successful_commands}
       ❌ Failed: #{summary.failed_commands}
       📊 Average Quality: #{summary.average_quality}%
       ⏱️  Total Time: #{format_duration(summary.total_execution_time)}

    📦 Generated Artifacts: #{length(summary.artifacts_generated)}

    📋 Report Generated: auto_pipeline_report.md
    """)
  end
end