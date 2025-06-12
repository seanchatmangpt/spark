defmodule AutoPipeline.QualityAssurance do
  @moduledoc """
  Quality assurance module for monitoring and improving pipeline execution quality.
  
  REFACTOR: This should become Reactor middleware.
  Quality checks can be implemented as:
  1. Reactor.Middleware.QualityMonitor - tracks step quality
  2. Telemetry handlers for quality metrics
  3. Step compensate/undo functions for quality recovery
  
  Migration: Convert to middleware that monitors step execution.
  """

  def perform_quality_checkpoint(wave_results, quality_threshold) do
    # REFACTOR: In Reactor, quality monitoring would happen via:
    # - Telemetry events from step execution
    # - Middleware that tracks quality in context
    # - Custom step return values with quality metadata
    
    # Analyze quality across the wave
    quality_metrics = %{
      average_quality: calculate_average_quality(wave_results),
      success_rate: calculate_success_rate(wave_results),
      critical_failures: identify_critical_failures(wave_results),
      quality_distribution: analyze_quality_distribution(wave_results)
    }
    
    # REFACTOR: Reactor can halt execution based on step results
    # Middleware can decide whether to continue based on quality
    # Decision logic for pipeline continuation
    decision = case quality_metrics do
      %{average_quality: avg, success_rate: success} when avg >= quality_threshold and success >= 0.8 ->
        :continue
        
      %{critical_failures: []} when quality_metrics.average_quality >= quality_threshold * 0.9 ->
        :continue
        
      %{critical_failures: [_ | _] = failures} ->
        :abort
        
      _ ->
        :retry_with_improvements
    end
    
    improvements = case decision do
      :retry_with_improvements ->
        generate_quality_improvements(wave_results, quality_threshold)
      _ ->
        []
    end
    
    %{
      status: decision,
      metrics: quality_metrics,
      improvements: improvements,
      recommendations: generate_quality_recommendations(quality_metrics)
    }
  end

  defp calculate_average_quality(wave_results) do
    if length(wave_results) > 0 do
      total_quality = Enum.sum(Enum.map(wave_results, & &1.quality_score))
      div(total_quality, length(wave_results))
    else
      0
    end
  end

  defp calculate_success_rate(wave_results) do
    if length(wave_results) > 0 do
      successful_count = Enum.count(wave_results, fn result -> result.status == :success end)
      successful_count / length(wave_results)
    else
      0.0
    end
  end

  defp identify_critical_failures(wave_results) do
    Enum.filter(wave_results, fn result ->
      result.status == :failed or (result.status == :quality_failed and result.quality_score < 50)
    end)
  end

  defp analyze_quality_distribution(wave_results) do
    quality_scores = Enum.map(wave_results, & &1.quality_score)
    
    %{
      min: if(length(quality_scores) > 0, do: Enum.min(quality_scores), else: 0),
      max: if(length(quality_scores) > 0, do: Enum.max(quality_scores), else: 0),
      median: calculate_median(quality_scores),
      standard_deviation: calculate_std_dev(quality_scores)
    }
  end

  defp calculate_median([]), do: 0
  defp calculate_median(scores) do
    sorted = Enum.sort(scores)
    length = length(sorted)
    
    if rem(length, 2) == 0 do
      mid1 = Enum.at(sorted, div(length, 2) - 1)
      mid2 = Enum.at(sorted, div(length, 2))
      div(mid1 + mid2, 2)
    else
      Enum.at(sorted, div(length, 2))
    end
  end

  defp calculate_std_dev([]), do: 0
  defp calculate_std_dev(scores) do
    mean = Enum.sum(scores) / length(scores)
    variance = Enum.sum(Enum.map(scores, fn x -> :math.pow(x - mean, 2) end)) / length(scores)
    :math.sqrt(variance) |> Float.round(2)
  end

  defp generate_quality_improvements(wave_results, quality_threshold) do
    low_quality_results = Enum.filter(wave_results, fn result ->
      result.quality_score < quality_threshold
    end)
    
    Enum.map(low_quality_results, fn result ->
      %{
        command: result.command,
        issue: identify_quality_issue(result),
        improvement_strategy: determine_improvement_strategy(result),
        modified_args: suggest_argument_modifications(result),
        additional_context: suggest_additional_context(result)
      }
    end)
  end

  defp identify_quality_issue(result) do
    cond do
      result.status == :failed -> "Command execution failed"
      result.quality_score < 60 -> "Low quality output"
      length(result.errors) > 0 -> "Execution errors present"
      length(result.warnings) > 3 -> "Multiple warnings"
      true -> "Unknown quality issue"
    end
  end

  defp determine_improvement_strategy(result) do
    cond do
      result.status == :failed -> "Increase timeout and retry with additional validation"
      result.quality_score < 60 -> "Enhance input parameters and add quality checks"
      length(result.errors) > 0 -> "Fix error conditions and improve error handling"
      true -> "General quality improvement"
    end
  end

  defp suggest_argument_modifications(_result) do
    # Placeholder for argument modification suggestions
    %{timeout: "increase", validation: "enhanced", error_handling: "improved"}
  end

  defp suggest_additional_context(_result) do
    # Placeholder for additional context suggestions
    %{logging: "verbose", monitoring: "enabled", checkpoints: "added"}
  end

  defp generate_quality_recommendations(quality_metrics) do
    recommendations = []
    
    recommendations = if quality_metrics.average_quality < 70 do
      ["Consider increasing quality thresholds for individual commands" | recommendations]
    else
      recommendations
    end
    
    recommendations = if quality_metrics.success_rate < 0.8 do
      ["Review command dependencies and execution order" | recommendations]  
    else
      recommendations
    end
    
    recommendations = if length(quality_metrics.critical_failures) > 0 do
      ["Address critical failures before proceeding" | recommendations]
    else
      recommendations
    end
    
    if recommendations == [] do
      ["Pipeline execution quality is acceptable"]
    else
      recommendations
    end
  end
end