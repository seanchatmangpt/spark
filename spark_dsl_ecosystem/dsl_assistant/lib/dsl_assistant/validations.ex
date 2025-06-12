defmodule DslAssistant.Validations do
  @moduledoc """
  Ash validation modules for DSL Assistant domain.
  
  These validations ensure data quality and consistency
  across the DSL analysis and improvement system.
  """
end

defmodule DslAssistant.Validations.ValidImplementationSteps do
  use Ash.Resource.Validation
  
  def validate(changeset, _opts) do
    implementation_steps = Ash.Changeset.get_attribute(changeset, :implementation_steps) || []
    
    cond do
      length(implementation_steps) < 3 ->
        {:error, [implementation_steps: "must have at least 3 implementation steps"]}
      
      Enum.any?(implementation_steps, &(String.length(&1) < 10)) ->
        {:error, [implementation_steps: "each step must be at least 10 characters"]}
      
      true ->
        :ok
    end
  end
end

defmodule DslAssistant.Validations.ConsistentEffortImpact do
  use Ash.Resource.Validation
  
  def validate(changeset, _opts) do
    effort_score = Ash.Changeset.get_attribute(changeset, :effort_score)
    impact_score = Ash.Changeset.get_attribute(changeset, :impact_score)
    breaking_changes = Ash.Changeset.get_attribute(changeset, :breaking_changes) || false
    
    cond do
      # High impact + low effort should not have breaking changes
      impact_score && impact_score > 0.8 && effort_score && effort_score < 2.0 && breaking_changes ->
        {:error, [breaking_changes: "high impact, low effort improvements should not require breaking changes"]}
      
      # Very high effort with very low impact is suspicious
      effort_score && effort_score > 8.0 && impact_score && impact_score < 0.3 ->
        {:error, [effort_score: "very high effort with very low impact may not be worthwhile"]}
      
      true ->
        :ok
    end
  end
end

defmodule DslAssistant.Validations.ValidSuccessCriteria do
  use Ash.Resource.Validation
  
  def validate(changeset, _opts) do
    success_criteria = Ash.Changeset.get_attribute(changeset, :success_criteria) || []
    
    cond do
      length(success_criteria) < 2 ->
        {:error, [success_criteria: "must have at least 2 success criteria"]}
      
      Enum.any?(success_criteria, &(String.length(&1) < 15)) ->
        {:error, [success_criteria: "each criterion must be at least 15 characters and specific"]}
      
      true ->
        :ok
    end
  end
end

defmodule DslAssistant.Validations.ValidDslModule do
  use Ash.Resource.Validation
  
  def validate(changeset, _opts) do
    dsl_module = Ash.Changeset.get_attribute(changeset, :dsl_module)
    
    cond do
      is_nil(dsl_module) || dsl_module == "" ->
        {:error, [dsl_module: "DSL module name is required"]}
      
      !String.contains?(dsl_module, ".") ->
        {:error, [dsl_module: "DSL module should be a qualified module name (e.g., MyApp.DSL)"]}
      
      String.length(dsl_module) > 200 ->
        {:error, [dsl_module: "DSL module name is too long"]}
      
      true ->
        :ok
    end
  end
end

defmodule DslAssistant.Validations.AnalysisDataConsistency do
  use Ash.Resource.Validation
  
  def validate(changeset, _opts) do
    structure_analysis = Ash.Changeset.get_attribute(changeset, :structure_analysis) || %{}
    usage_patterns = Ash.Changeset.get_attribute(changeset, :usage_patterns) || %{}
    friction_points = Ash.Changeset.get_attribute(changeset, :friction_points) || []
    
    cond do
      # If we have usage patterns, we should have some analysis
      map_size(usage_patterns) > 0 && map_size(structure_analysis) == 0 ->
        {:error, [structure_analysis: "structure analysis required when usage patterns are provided"]}
      
      # If we have friction points, they should reference valid constructs
      length(friction_points) > 0 && !has_valid_construct_references?(friction_points, structure_analysis) ->
        {:error, [friction_points: "friction points reference constructs not found in structure analysis"]}
      
      true ->
        :ok
    end
  end
  
  defp has_valid_construct_references?(friction_points, structure_analysis) do
    # Simple validation - in a real implementation, this would be more sophisticated
    available_constructs = Map.keys(structure_analysis)
    
    Enum.all?(friction_points, fn friction_point ->
      construct_name = Map.get(friction_point, "construct_name", "")
      construct_name == "" || Enum.any?(available_constructs, &String.contains?(construct_name, to_string(&1)))
    end)
  end
end

defmodule DslAssistant.Validations.ValidImprovementResult do
  use Ash.Resource.Validation
  
  def validate(changeset, _opts) do
    before_metrics = Ash.Changeset.get_attribute(changeset, :before_metrics) || %{}
    after_metrics = Ash.Changeset.get_attribute(changeset, :after_metrics) || %{}
    actual_impact_score = Ash.Changeset.get_attribute(changeset, :actual_impact_score)
    
    cond do
      # Should have consistent metric keys
      map_size(before_metrics) > 0 && map_size(after_metrics) > 0 && 
      !maps_have_consistent_keys?(before_metrics, after_metrics) ->
        {:error, [after_metrics: "before and after metrics should measure the same things"]}
      
      # Impact score should be reasonable
      actual_impact_score && (actual_impact_score < -1.0 || actual_impact_score > 1.0) ->
        {:error, [actual_impact_score: "impact score should be between -1.0 and 1.0"]}
      
      true ->
        :ok
    end
  end
  
  defp maps_have_consistent_keys?(map1, map2) do
    keys1 = MapSet.new(Map.keys(map1))
    keys2 = MapSet.new(Map.keys(map2))
    
    # At least 50% overlap in keys
    overlap = MapSet.intersection(keys1, keys2)
    overlap_ratio = MapSet.size(overlap) / max(1, MapSet.size(keys1))
    overlap_ratio >= 0.5
  end
end

defmodule DslAssistant.Validations.ValidUsagePattern do
  use Ash.Resource.Validation
  
  def validate(changeset, _opts) do
    pattern_type = Ash.Changeset.get_attribute(changeset, :pattern_type)
    frequency = Ash.Changeset.get_attribute(changeset, :frequency)
    confidence_score = Ash.Changeset.get_attribute(changeset, :confidence_score)
    
    cond do
      # Frequency should be reasonable for pattern type
      pattern_type == :common && frequency && frequency < 5 ->
        {:error, [frequency: "common patterns should have frequency >= 5"]}
      
      pattern_type == :rare && frequency && frequency > 20 ->
        {:error, [frequency: "rare patterns should have frequency <= 20"]}
      
      # Confidence should be reasonable
      confidence_score && confidence_score < 0.1 ->
        {:error, [confidence_score: "patterns with very low confidence may not be reliable"]}
      
      true ->
        :ok
    end
  end
end