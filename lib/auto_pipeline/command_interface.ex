defmodule AutoPipeline.CommandInterface do
  @moduledoc """
  Main command interface for the automated pipeline system.
  Integrates with Reactor for reliable execution and provides CLI interface.
  
  REFACTOR: This interface should directly use Reactor.
  The execute_with_reactor_or_fallback function should actually
  build and run a Reactor instead of using custom execution engine.
  
  Migration: Replace ExecutionEngine with Reactor.run/4.
  """

  def run(args \\ []) do
    # Parse command line arguments
    {project_scope, mode, quality_threshold, max_concurrency} = parse_args(args)
    
    IO.puts("🚀 Initializing Automated Spark DSL Development Pipeline")
    IO.puts("📋 Configuration:")
    IO.puts("   Scope: #{project_scope}")
    IO.puts("   Mode: #{mode}")
    IO.puts("   Quality Threshold: #{quality_threshold}%")
    IO.puts("   Max Concurrency: #{max_concurrency}")
    IO.puts("")
    
    # Execute the pipeline using Reactor if available, otherwise fallback
    case execute_with_reactor_or_fallback(%{
      project_scope: project_scope,
      mode: mode,
      quality_threshold: quality_threshold,
      max_concurrency: max_concurrency
    }) do
      {:ok, result} ->
        IO.puts("✅ Pipeline completed successfully!")
        display_final_results(result)
        {:ok, result}
        
      {:error, reason} ->
        IO.puts("❌ Pipeline failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp execute_with_reactor_or_fallback(inputs) do
    # REFACTOR: Should be:
    # reactor = AutoPipeline.build_reactor(inputs)
    # Reactor.run(reactor, %{}, build_context(inputs), max_concurrency: inputs.max_concurrency)
    AutoPipeline.ExecutionEngine.run(inputs)
  end

  defp parse_args(args) do
    # Default values
    project_scope = Enum.at(args, 0, "full")
    mode = Enum.at(args, 1, "development")
    quality_threshold = String.to_integer(Enum.at(args, 2, "75"))
    max_concurrency = String.to_integer(Enum.at(args, 3, "8"))
    
    # Validate inputs
    project_scope = validate_project_scope(project_scope)
    mode = validate_mode(mode)
    quality_threshold = max(0, min(100, quality_threshold))
    max_concurrency = max(1, min(16, max_concurrency))
    
    {project_scope, mode, quality_threshold, max_concurrency}
  end

  defp validate_project_scope(scope) do
    valid_scopes = ["full", "dsl-only", "analysis-only", "docs-only"]
    if scope in valid_scopes, do: scope, else: "full"
  end

  defp validate_mode(mode) do
    valid_modes = ["development", "production", "research", "maintenance"]
    if mode in valid_modes, do: mode, else: "development"
  end

  defp display_final_results(result) do
    summary = result.summary
    
    IO.puts("""
    
    📊 Final Pipeline Report:
    ========================
    
    🎯 Overall Success Rate: #{calculate_success_percentage(summary)}%
    📈 Quality Score: #{summary.average_quality}%
    ⏱️  Total Execution Time: #{format_duration(summary.total_execution_time)}
    📦 Artifacts Generated: #{length(summary.artifacts_generated)}
    
    📁 Detailed Report: #{result.report_path}
    """)
    
    # Display artifact breakdown
    if length(summary.artifacts_generated) > 0 do
      artifact_counts = Enum.frequencies(summary.artifacts_generated)
      IO.puts("🔧 Generated Artifacts:")
      Enum.each(artifact_counts, fn {artifact, count} ->
        IO.puts("   • #{humanize_artifact(artifact)}: #{count}")
      end)
    end
    
    # Display any recommendations
    if result.execution_results.status == :completed do
      IO.puts("\n✨ Pipeline completed successfully with all quality checks passed!")
    else
      IO.puts("\n⚠️  Pipeline completed with some quality issues. Check the detailed report for recommendations.")
    end
  end

  defp calculate_success_percentage(summary) do
    if summary.total_commands > 0 do
      round(summary.successful_commands / summary.total_commands * 100)
    else
      0
    end
  end

  defp format_duration(milliseconds) do
    seconds = div(milliseconds, 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    
    cond do
      minutes > 0 -> "#{minutes}m #{remaining_seconds}s"
      seconds > 0 -> "#{seconds}s"
      true -> "#{milliseconds}ms"
    end
  end

  defp humanize_artifact(artifact) do
    case artifact do
      :dsl_extension -> "DSL Extensions"
      :transformer -> "Transformers"
      :verifier -> "Verifiers"
      :documentation -> "Documentation"
      :test -> "Tests"
      :test_results -> "Test Results"
      :analysis_report -> "Analysis Reports"
      _ -> to_string(artifact) |> String.replace("_", " ") |> String.capitalize()
    end
  end

  # Convenience functions for different execution modes
  
  def run_full_pipeline(quality_threshold \\ 75) do
    run(["full", "development", to_string(quality_threshold), "8"])
  end

  def run_dsl_development(quality_threshold \\ 80) do
    run(["dsl-only", "development", to_string(quality_threshold), "6"])
  end

  def run_quality_analysis(quality_threshold \\ 85) do
    run(["analysis-only", "research", to_string(quality_threshold), "4"])
  end

  def run_documentation_pipeline(quality_threshold \\ 70) do
    run(["docs-only", "development", to_string(quality_threshold), "8"])
  end

  def run_production_pipeline(quality_threshold \\ 90) do
    run(["full", "production", to_string(quality_threshold), "4"])
  end

  # Debug and monitoring functions
  
  def dry_run(args \\ []) do
    {_project_scope, _mode, _quality_threshold, _max_concurrency} = parse_args(args)
    
    IO.puts("🔍 Dry Run - Automated Pipeline Configuration")
    IO.puts("============================================")
    
    # Discover commands without executing
    command_discovery = AutoPipeline.CommandDiscovery.discover_available_commands()
    
    IO.puts("📋 Available Commands: #{length(command_discovery.all_commands)}")
    
    # Show categorized commands
    Enum.each(command_discovery.categorized, fn {category, commands} ->
      IO.puts("  #{String.capitalize(to_string(category))}: #{length(commands)} commands")
      Enum.each(commands, fn cmd ->
        IO.puts("    • #{cmd.name} - #{cmd.description}")
      end)
    end)
    
    # Show execution plan
    execution_plan = command_discovery.execution_plan
    IO.puts("\n⏱️  Estimated Total Time: #{format_duration(execution_plan.total_estimated_time)}")
    IO.puts("🌊 Execution Waves: #{length(execution_plan.waves)}")
    
    Enum.with_index(execution_plan.waves)
    |> Enum.each(fn {wave, index} ->
      IO.puts("  Wave #{index + 1}: #{length(wave)} commands (concurrent)")
      Enum.each(wave, fn cmd ->
        IO.puts("    • #{cmd.name} (~#{div(cmd.estimated_duration, 1000)}s)")
      end)
    end)
    
    IO.puts("\n🎯 Critical Path: #{Enum.join(execution_plan.critical_path, " → ")}")
    
    {:ok, command_discovery}
  end

  def list_available_commands do
    command_discovery = AutoPipeline.CommandDiscovery.discover_available_commands()
    
    IO.puts("📋 Available Pipeline Commands")
    IO.puts("=============================")
    
    Enum.each(command_discovery.all_commands, fn cmd ->
      IO.puts("#{cmd.name}")
      IO.puts("  Description: #{cmd.description}")
      IO.puts("  Category: #{cmd.category}")
      IO.puts("  Dependencies: #{inspect(cmd.dependencies)}")
      IO.puts("  Estimated Duration: #{div(cmd.estimated_duration, 1000)}s")
      IO.puts("  Quality Impact: #{cmd.quality_impact}%")
      IO.puts("")
    end)
    
    command_discovery.all_commands
  end

  def show_help do
    IO.puts("""
    🚀 Auto Pipeline - Automated Spark DSL Development
    ===================================================
    
    USAGE:
      AutoPipeline.CommandInterface.run([project_scope, mode, quality_threshold, max_concurrency])
    
    ARGUMENTS:
      project_scope     - Scope of execution (default: "full")
                         Options: "full", "dsl-only", "analysis-only", "docs-only"
      
      mode             - Execution mode (default: "development")
                         Options: "development", "production", "research", "maintenance"
      
      quality_threshold - Minimum quality score 0-100 (default: 75)
      
      max_concurrency  - Maximum concurrent tasks 1-16 (default: 8)
    
    CONVENIENCE FUNCTIONS:
      run_full_pipeline(quality)     - Full development pipeline
      run_dsl_development(quality)   - DSL-focused development
      run_quality_analysis(quality)  - Comprehensive analysis
      run_documentation_pipeline(quality) - Documentation generation
      run_production_pipeline(quality)    - Production-ready pipeline
    
    UTILITIES:
      dry_run(args)              - Show execution plan without running
      list_available_commands()  - List all discovered commands
      show_help()               - Show this help message
    
    EXAMPLES:
      # Full pipeline with high quality standards
      AutoPipeline.CommandInterface.run(["full", "production", "90", "4"])
      
      # Quick DSL development
      AutoPipeline.CommandInterface.run_dsl_development(80)
      
      # Research mode with comprehensive analysis
      AutoPipeline.CommandInterface.run(["analysis-only", "research", "85", "6"])
      
      # Preview execution plan
      AutoPipeline.CommandInterface.dry_run(["full", "development", "75", "8"])
    """)
  end
end