defmodule DslAssistant.Calculations do
  @moduledoc """
  Ash calculation modules for DSL Assistant domain.
  
  These calculations provide computed values and analytics
  for DSL analysis and improvement tracking.
  """
end

defmodule DslAssistant.Calculations.ImprovementPotential do
  use Ash.Resource.Calculation
  
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      friction_points_count = length(record.friction_points)
      complexity_score = get_complexity_score(record.complexity_metrics)
      error_rate = get_error_rate(record.error_analysis)
      
      # Calculate improvement potential (0-1 scale)
      base_potential = (friction_points_count * 0.1) + (complexity_score * 0.3) + (error_rate * 0.6)
      
      # Adjust for analysis confidence
      confidence_adjusted = base_potential * record.analysis_confidence
      
      # Ensure result is between 0 and 1
      potential = min(1.0, max(0.0, confidence_adjusted))
      
      Decimal.new(Float.to_string(potential))
    end)
  end
  
  defp get_complexity_score(complexity_metrics) do
    case complexity_metrics do
      %{"overall_complexity" => score} when is_number(score) -> score
      _ -> 0.5  # Default moderate complexity
    end
  end
  
  defp get_error_rate(error_analysis) do
    case error_analysis do
      %{"error_rate" => rate} when is_number(rate) -> rate
      _ -> 0.1  # Default low error rate
    end
  end
end

defmodule DslAssistant.Calculations.PatternConfidence do
  use Ash.Resource.Calculation
  
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      frequency = record.frequency || 0
      context_score = calculate_context_score(record)
      validation_score = calculate_validation_score(record)
      
      # Base confidence from frequency (logarithmic scale)
      frequency_confidence = if frequency > 0 do
        :math.log(frequency + 1) / :math.log(100)  # Normalize to 0-1
      else
        0.0
      end
      
      # Combined confidence score
      combined_confidence = (frequency_confidence * 0.5) + (context_score * 0.3) + (validation_score * 0.2)
      
      # Ensure between 0 and 1
      final_confidence = min(1.0, max(0.0, combined_confidence))
      
      Decimal.new(Float.to_string(final_confidence))
    end)
  end
  
  defp calculate_context_score(record) do
    # Score based on how much context we have about the pattern
    context_indicators = [
      record.error_context != nil,
      record.user_context != nil,
      record.performance_context != nil,
      record.business_context != nil
    ]
    
    Enum.count(context_indicators, & &1) / length(context_indicators)
  end
  
  defp calculate_validation_score(record) do
    # Score based on validation status
    case record.validation_status do
      :validated -> 1.0
      :partially_validated -> 0.7
      :pending_validation -> 0.4
      _ -> 0.2
    end
  end
end

defmodule DslAssistant.Calculations.ImprovementROI do
  use Ash.Resource.Calculation
  
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      if record.actual_impact_score && record.implementation_effort && record.implementation_effort > 0 do
        # ROI = (Impact - Cost) / Cost
        # Simplified: Impact / Effort ratio
        roi = record.actual_impact_score / record.implementation_effort
        Decimal.new(Float.to_string(roi))
      else
        # Use estimated values if actual not available
        estimated_impact = get_estimated_impact(record)
        estimated_effort = get_estimated_effort(record)
        
        if estimated_effort > 0 do
          roi = estimated_impact / estimated_effort
          Decimal.new(Float.to_string(roi))
        else
          Decimal.new("0.0")
        end
      end
    end)
  end
  
  defp get_estimated_impact(record) do
    # Get impact from related improvement if available
    case record do
      %{improvement: %{impact_score: score}} when is_number(score) -> score
      _ -> 0.5  # Default moderate impact
    end
  end
  
  defp get_estimated_effort(record) do
    # Get effort from related improvement if available
    case record do
      %{improvement: %{effort_score: score}} when is_number(score) -> score
      _ -> 5.0  # Default moderate effort
    end
  end
end

defmodule DslAssistant.Calculations.SuccessRate do
  use Ash.Resource.Calculation
  
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      success_criteria = record.success_criteria_met || []
      total_criteria = record.total_success_criteria || length(success_criteria)
      
      if total_criteria > 0 do
        success_rate = length(success_criteria) / total_criteria
        Decimal.new(Float.to_string(success_rate))
      else
        Decimal.new("0.0")
      end
    end)
  end
end

defmodule DslAssistant.Calculations.TrendAnalysis do
  use Ash.Resource.Calculation
  
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      # Analyze trend in improvement results over time
      # This would typically look at historical data
      
      # Simplified trend calculation based on recent vs older metrics
      recent_performance = get_recent_performance(record)
      historical_performance = get_historical_performance(record)
      
      if historical_performance > 0 do
        trend = (recent_performance - historical_performance) / historical_performance
        
        # Classify trend
        trend_classification = cond do
          trend > 0.1 -> "improving"
          trend < -0.1 -> "declining"
          true -> "stable"
        end
        
        trend_classification
      else
        "insufficient_data"
      end
    end)
  end
  
  defp get_recent_performance(record) do
    # Get recent performance metrics
    case record do
      %{actual_impact_score: score} when is_number(score) -> score
      _ -> 0.5
    end
  end
  
  defp get_historical_performance(_record) do
    # In a real implementation, this would query historical data
    0.4  # Placeholder baseline
  end
end

defmodule DslAssistant.Calculations.QualityScore do
  use Ash.Resource.Calculation
  
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      # Calculate overall quality score for a DSL analysis
      
      # Factor in multiple quality dimensions
      completeness_score = calculate_completeness_score(record)
      accuracy_score = calculate_accuracy_score(record)
      actionability_score = calculate_actionability_score(record)
      
      # Weighted average
      quality_score = (completeness_score * 0.3) + (accuracy_score * 0.4) + (actionability_score * 0.3)
      
      Decimal.new(Float.to_string(quality_score))
    end)
  end
  
  defp calculate_completeness_score(record) do
    # Score based on how complete the analysis is
    completeness_factors = [
      record.structure_analysis != %{},
      record.usage_patterns != %{},
      length(record.friction_points) > 0,
      length(record.recommended_improvements) > 0,
      record.complexity_metrics != %{},
      record.error_analysis != %{}
    ]
    
    Enum.count(completeness_factors, & &1) / length(completeness_factors)
  end
  
  defp calculate_accuracy_score(record) do
    # Score based on confidence and validation
    record.analysis_confidence || 0.5
  end
  
  defp calculate_actionability_score(record) do
    # Score based on how actionable the recommendations are
    improvements = record.recommended_improvements || []
    
    if length(improvements) > 0 do
      actionable_improvements = Enum.count(improvements, fn improvement ->
        has_implementation_steps = Map.has_key?(improvement, "implementation_steps")
        has_examples = Map.has_key?(improvement, "example_before") && Map.has_key?(improvement, "example_after")
        has_effort_estimate = Map.has_key?(improvement, "effort_estimate")
        
        has_implementation_steps && has_examples && has_effort_estimate
      end)
      
      actionable_improvements / length(improvements)
    else
      0.0
    end
  end
end