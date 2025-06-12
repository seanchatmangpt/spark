defmodule AutoPipeline do
  @moduledoc """
  Automated Spark DSL Development Pipeline

  REFACTOR: This module should become a thin wrapper around Reactor.
  The entire orchestration logic should be delegated to Reactor's execution engine.
  
  Orchestrates concurrent execution of all available Spark development commands, creating a 
  comprehensive, automated development pipeline with intelligent task scheduling, dependency 
  management, and quality assurance.

  ## Usage

      # Run full pipeline with default settings
      AutoPipeline.run()

      # Run with custom configuration
      AutoPipeline.run(["full", "development", "80", "6"])

      # Use convenience functions
      AutoPipeline.run_dsl_development(85)
      AutoPipeline.run_production_pipeline(90)

  ## Available Project Scopes

  - `"full"` - Complete automated development workflow
  - `"dsl-only"` - Focus on DSL development and testing  
  - `"analysis-only"` - Comprehensive analysis pipeline
  - `"docs-only"` - Documentation-focused pipeline

  ## Execution Modes

  - `"development"` - Standard development workflow
  - `"production"` - Production-ready with high quality standards
  - `"research"` - Research-focused with comprehensive analysis  
  - `"maintenance"` - Optimization and maintenance focused

  ## Features

  - **Intelligent Command Discovery**: Automatically discovers and analyzes available commands
  - **Dependency Management**: Respects command dependencies and optimal execution order
    # REFACTOR: Use Reactor's DAG resolution
  - **Concurrent Execution**: Runs commands concurrently within dependency constraints
    # REFACTOR: Use Reactor's async step execution
  - **Quality Assurance**: Real-time quality monitoring with configurable thresholds
    # REFACTOR: Implement as Reactor middleware
  - **Reactor Integration**: Uses Reactor's saga pattern for reliable execution
    # REFACTOR: Currently mentioned but not implemented - make this real
  - **Comprehensive Reporting**: Detailed execution reports and metrics
    # REFACTOR: Use Reactor's telemetry events

  """

  alias AutoPipeline.CommandInterface

  # Main execution functions
  defdelegate run(args \\ []), to: CommandInterface
  defdelegate run_full_pipeline(quality_threshold \\ 75), to: CommandInterface
  defdelegate run_dsl_development(quality_threshold \\ 80), to: CommandInterface
  defdelegate run_quality_analysis(quality_threshold \\ 85), to: CommandInterface
  defdelegate run_documentation_pipeline(quality_threshold \\ 70), to: CommandInterface
  defdelegate run_production_pipeline(quality_threshold \\ 90), to: CommandInterface

  # Utility functions
  defdelegate dry_run(args \\ []), to: CommandInterface
  defdelegate list_available_commands(), to: CommandInterface
  defdelegate show_help(), to: CommandInterface

  # REFACTOR: Replace with Reactor-based implementation:
  # defmacro __using__(opts) do
  #   quote do
  #     use Reactor, unquote(opts)
  #     use AutoPipeline.Dsl  # Thin DSL layer that compiles to Reactor
  #   end
  # end
  
  # Legacy DSL support for backward compatibility
  use Spark.Dsl,
    default_extensions: [extensions: [AutoPipeline.Dsl]]
end
