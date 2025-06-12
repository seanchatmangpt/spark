defmodule AgiFactory.Workflows.DslGeneration do
  @moduledoc """
  Main DSL generation workflow using Ash.Reactor.
  
  This workflow orchestrates the complete DSL generation process:
  1. Load and validate the DSL project
  2. Parse requirements into structured specification
  3. Analyze existing patterns in parallel
  4. Generate multiple implementation strategies
  5. Evaluate and score each strategy
  6. Select the optimal implementation
  7. Generate final production-ready code
  8. Update the project with results
  
  The workflow includes comprehensive error handling and compensation
  strategies for failures at any stage.
  """
  
  use Ash.Reactor

  input :dsl_project_id do
    description "ID of the DSL project to generate"
  end
  
  input :options do
    description "Generation options and configuration"
    default %{}
  end

  # Step 1: Load the DSL project
  step :load_project do
    description "Load the DSL project from the database"
    argument :id, input(:dsl_project_id)
    
    run fn arguments, _context ->
      case AgiFactory.get!(AgiFactory.Resources.DslProject, arguments.id) do
        {:ok, project} -> {:ok, project}
        {:error, reason} -> {:error, {:project_not_found, reason}}
      end
    end
  end

  # Step 2: Parse requirements (using RequirementsParser domain)
  step :parse_requirements do
    description "Parse natural language requirements into structured specification"
    argument :project, result(:load_project)
    
    run fn arguments, _context ->
      # Call RequirementsParser to parse the requirements
      case RequirementsParser.create!(RequirementsParser.Resources.Specification, %{
        original_text: arguments.project.requirements
      }) do
        {:ok, specification} -> {:ok, specification}
        {:error, reason} -> {:error, {:requirements_parsing_failed, reason}}
      end
    end
    
    async? true
  end

  # Step 3: Analyze existing patterns (using UsageAnalyzer domain)
  step :analyze_patterns do
    description "Analyze existing DSL patterns for context"
    argument :specification, result(:parse_requirements)
    
    run fn arguments, _context ->
      # Call UsageAnalyzer to find relevant patterns
      case UsageAnalyzer.create!(UsageAnalyzer.Resources.AnalysisReport, %{
        target_dsl: "global_patterns",
        analysis_type: :patterns,
        time_window: "30d",
        data_sources: [:local, :github]
      }) do
        {:ok, analysis} -> {:ok, analysis}
        {:error, reason} -> {:error, {:pattern_analysis_failed, reason}}
      end
    end
    
    async? true
  end

  # Step 4: Generate multiple strategies (using DslSynthesizer domain)
  step :generate_strategies do
    description "Generate multiple DSL implementation strategies"
    argument :specification, result(:parse_requirements)
    argument :patterns, result(:analyze_patterns)
    argument :strategy_count, path(input(:options), :strategy_count) || 5
    
    run fn arguments, context ->
      strategies = [:template, :pattern_based, :example_driven, :hybrid, :ai_assisted]
      selected_strategies = Enum.take(strategies, arguments.strategy_count)
      
      # Generate each strategy in parallel
      generation_tasks = Enum.map(selected_strategies, fn strategy ->
        Task.async(fn ->
          DslSynthesizer.create!(DslSynthesizer.Resources.GenerationStrategy, %{
            name: :"#{strategy}_generation_#{System.unique_integer()}",
            strategy_type: strategy,
            configuration: %{
              specification: arguments.specification,
              patterns: arguments.patterns
            }
          })
        end)
      end)
      
      # Wait for all strategies to complete
      case Task.await_many(generation_tasks, 300_000) do # 5 minute timeout
        results when is_list(results) ->
          successful_results = Enum.filter(results, &match?({:ok, _}, &1))
          if length(successful_results) > 0 do
            {:ok, Enum.map(successful_results, fn {:ok, result} -> result end)}
          else
            {:error, :no_successful_strategies}
          end
        error ->
          {:error, {:strategy_generation_failed, error}}
      end
    end
    
    max_retries 3
  end

  # Step 5: Evaluate strategies
  step :evaluate_strategies do
    description "Evaluate the quality of each generated strategy"
    argument :strategies, result(:generate_strategies)
    argument :criteria, path(input(:options), :quality_criteria) || %{}
    
    run fn arguments, _context ->
      evaluation_tasks = Enum.map(arguments.strategies, fn strategy ->
        Task.async(fn ->
          # Perform quality assessment for each strategy
          AgiFactory.create!(AgiFactory.Resources.QualityAssessment, %{
            assessment_type: :automatic,
            dsl_project_id: input(:dsl_project_id),
            assessment_options: arguments.criteria
          })
        end)
      end)
      
      case Task.await_many(evaluation_tasks, 180_000) do # 3 minute timeout
        evaluations when is_list(evaluations) ->
          successful_evals = Enum.filter(evaluations, &match?({:ok, _}, &1))
          if length(successful_evals) > 0 do
            {:ok, Enum.map(successful_evals, fn {:ok, eval} -> eval end)}
          else
            {:error, :no_successful_evaluations}
          end
        error ->
          {:error, {:evaluation_failed, error}}
      end
    end
  end

  # Step 6: Select optimal strategy
  step :select_optimal do
    description "Select the best strategy based on evaluations"
    argument :strategies, result(:generate_strategies)
    argument :evaluations, result(:evaluate_strategies)
    argument :threshold, path(input(:options), :quality_threshold) || 75.0
    
    run fn arguments, _context ->
      # Pair strategies with their evaluations
      strategy_scores = Enum.zip(arguments.strategies, arguments.evaluations)
      |> Enum.map(fn {strategy, evaluation} ->
        {strategy, evaluation.overall_score}
      end)
      |> Enum.sort_by(fn {_strategy, score} -> score end, :desc)
      
      case strategy_scores do
        [{best_strategy, score} | _] when score >= arguments.threshold ->
          {:ok, %{strategy: best_strategy, score: score}}
          
        [{best_strategy, score} | _] ->
          {:error, {:below_threshold, best_strategy, score, arguments.threshold}}
          
        [] ->
          {:error, :no_strategies_available}
      end
    end
  end

  # Step 7: Generate final code
  step :generate_final_code do
    description "Generate final production-ready code"
    argument :selected, result(:select_optimal)
    argument :mode, path(input(:options), :mode) || :development
    
    run fn arguments, _context ->
      # Use DslSynthesizer to generate final code
      case DslSynthesizer.update!(arguments.selected.strategy, :generate_final_code, %{
        mode: arguments.mode,
        optimization_level: :production
      }) do
        {:ok, final_result} -> {:ok, final_result}
        {:error, reason} -> {:error, {:final_generation_failed, reason}}
      end
    end
  end

  # Step 8: Update project with results
  step :update_project do
    description "Update the DSL project with generation results"
    argument :project, result(:load_project)
    argument :generated_code, result(:generate_final_code)
    argument :quality_score, path(result(:select_optimal), :score)
    
    run fn arguments, _context ->
      AgiFactory.update!(arguments.project, :complete_generation, %{
        generated_code: arguments.generated_code.code,
        quality_score: arguments.quality_score,
        test_results: arguments.generated_code.test_results || %{}
      })
    end
  end

  # Step 9: Create generation request record
  step :record_generation_request do
    description "Record the successful generation request"
    argument :project, result(:load_project)
    argument :selected_strategy, path(result(:select_optimal), :strategy)
    argument :execution_time, calculate_execution_time()
    
    run fn arguments, _context ->
      AgiFactory.create!(AgiFactory.Resources.GenerationRequest, %{
        dsl_project_id: arguments.project.id,
        strategy: arguments.selected_strategy.strategy_type,
        status: :completed,
        parameters: arguments.selected_strategy.configuration,
        generated_code: result(:generate_final_code).code,
        quality_metrics: %{
          overall_score: path(result(:select_optimal), :score)
        },
        execution_time_ms: arguments.execution_time,
        started_at: DateTime.utc_now(),
        completed_at: DateTime.utc_now()
      })
    end
    
    async? true
  end

  # Compensation strategies for failures

  compensate :mark_project_failed do
    description "Mark the project as failed if workflow fails"
    
    run fn _arguments, context ->
      project_id = context.inputs.dsl_project_id
      error_details = %{
        workflow_error: context.error,
        failed_at: DateTime.utc_now(),
        stage: context.current_step
      }
      
      case AgiFactory.get!(AgiFactory.Resources.DslProject, project_id) do
        {:ok, project} ->
          AgiFactory.update!(project, :mark_failed, %{
            error_details: error_details
          })
        _ ->
          {:ok, :project_not_found}
      end
    end
  end

  compensate :cleanup_partial_artifacts do
    description "Clean up any partial artifacts created during generation"
    
    run fn _arguments, context ->
      # Clean up any temporary files, database records, etc.
      project_id = context.inputs.dsl_project_id
      
      # Remove any incomplete generation requests
      incomplete_requests = AgiFactory.read!(
        AgiFactory.Resources.GenerationRequest,
        :by_project,
        %{dsl_project_id: project_id}
      )
      |> Enum.filter(&(&1.status in [:pending, :running]))
      
      Enum.each(incomplete_requests, fn request ->
        AgiFactory.update!(request, :mark_failed, %{
          error_details: %{reason: "workflow_failure", cleanup: true}
        })
      end)
      
      {:ok, :cleanup_complete}
    end
  end

  compensate :notify_failure do
    description "Notify relevant parties of generation failure"
    
    run fn _arguments, context ->
      # Send notifications about the failure
      Phoenix.PubSub.broadcast(
        AgiFactory.PubSub,
        "dsl_project:#{context.inputs.dsl_project_id}",
        {:generation_failed, %{
          project_id: context.inputs.dsl_project_id,
          error: context.error,
          timestamp: DateTime.utc_now()
        }}
      )
      
      {:ok, :notification_sent}
    end
  end

  # Helper functions

  defp calculate_execution_time do
    # This would be implemented to track actual execution time
    # For now, return a placeholder
    fn -> :timer.seconds(60) end
  end

  def description do
    """
    Complete DSL generation workflow that transforms natural language
    requirements into production-ready DSL implementations using
    multiple strategies, quality evaluation, and optimal selection.
    """
  end
end