defmodule DslAssistant.Changes do
  @moduledoc """
  Ash change modules for DSL Assistant domain.
  
  These changes implement the business logic for analyzing DSLs
  and generating improvement recommendations.
  """
end

defmodule DslAssistant.Changes.EstimateEffort do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :improvement_type) do
      :simplification -> 
        changeset
        |> Ash.Changeset.change_attribute(:effort_score, 3.0)
        |> Ash.Changeset.change_attribute(:effort_estimate, "2-3 days")
      
      :validation ->
        changeset
        |> Ash.Changeset.change_attribute(:effort_score, 2.0)
        |> Ash.Changeset.change_attribute(:effort_estimate, "1-2 days")
      
      :consistency ->
        changeset
        |> Ash.Changeset.change_attribute(:effort_score, 4.0)
        |> Ash.Changeset.change_attribute(:effort_estimate, "3-5 days")
      
      _ ->
        changeset
        |> Ash.Changeset.change_attribute(:effort_score, 3.5)
        |> Ash.Changeset.change_attribute(:effort_estimate, "3-4 days")
    end
  end
end

defmodule DslAssistant.Changes.EstimateImpact do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    improvement_type = Ash.Changeset.get_attribute(changeset, :improvement_type)
    problem_length = String.length(Ash.Changeset.get_attribute(changeset, :problem_description) || "")
    
    impact_score = case improvement_type do
      :error_prevention -> 0.9  # High impact
      :simplification -> 0.7    # Medium-high impact
      :consistency -> 0.6       # Medium impact
      :discoverability -> 0.5   # Medium impact
      :performance -> 0.8       # High impact
      _ -> 0.5
    end
    
    # Adjust based on problem complexity
    adjusted_impact = if problem_length > 200, do: impact_score + 0.1, else: impact_score
    final_impact = min(1.0, adjusted_impact)
    
    impact_description = case improvement_type do
      :error_prevention -> "Reduces common errors and improves developer experience"
      :simplification -> "Reduces cognitive load and improves usability"
      :consistency -> "Improves consistency across the DSL interface"
      :discoverability -> "Makes DSL features more discoverable"
      :performance -> "Improves DSL compilation and runtime performance"
      _ -> "General improvement to DSL quality"
    end
    
    changeset
    |> Ash.Changeset.change_attribute(:impact_score, final_impact)
    |> Ash.Changeset.change_attribute(:impact_estimate, impact_description)
  end
end

defmodule DslAssistant.Changes.GenerateImplementationSteps do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    improvement_type = Ash.Changeset.get_attribute(changeset, :improvement_type)
    
    steps = case improvement_type do
      :simplification ->
        [
          "Analyze current usage patterns for the target construct",
          "Design simplified interface that maintains functionality",
          "Implement backward-compatible changes",
          "Update documentation and examples",
          "Test with real usage scenarios",
          "Gather user feedback on improved interface"
        ]
      
      :validation ->
        [
          "Identify common error patterns in usage data",
          "Design compile-time validation rules",
          "Implement validation logic in appropriate verifier",
          "Create clear, actionable error messages",
          "Add comprehensive test coverage",
          "Update documentation with validation examples"
        ]
      
      :consistency ->
        [
          "Audit existing DSL constructs for naming patterns",
          "Define consistent naming and interface conventions",
          "Plan migration strategy for existing usage",
          "Implement consistency improvements incrementally",
          "Update all documentation and examples",
          "Validate consistency across entire DSL surface"
        ]
      
      _ ->
        [
          "Analyze the specific improvement requirements",
          "Design implementation approach",
          "Implement changes with backward compatibility",
          "Test thoroughly with existing usage patterns",
          "Update documentation and examples",
          "Deploy and monitor for impact"
        ]
    end
    
    Ash.Changeset.change_attribute(changeset, :implementation_steps, steps)
  end
end

defmodule DslAssistant.Changes.IdentifyAffectedConstructs do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    # Extract affected constructs from the problem description
    problem_description = Ash.Changeset.get_attribute(changeset, :problem_description) || ""
    
    # Simple pattern matching to identify DSL constructs
    constructs = []
    constructs = if String.contains?(problem_description, ["attribute", "field"]), do: ["attributes" | constructs], else: constructs
    constructs = if String.contains?(problem_description, ["relationship", "belongs_to", "has_many"]), do: ["relationships" | constructs], else: constructs
    constructs = if String.contains?(problem_description, ["action", "create", "read", "update", "destroy"]), do: ["actions" | constructs], else: constructs
    constructs = if String.contains?(problem_description, ["validation", "validate"]), do: ["validations" | constructs], else: constructs
    constructs = if String.contains?(problem_description, ["calculation", "calculate"]), do: ["calculations" | constructs], else: constructs
    
    Ash.Changeset.change_attribute(changeset, :affected_constructs, constructs)
  end
end

defmodule DslAssistant.Changes.AssessBreakingChanges do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    improvement_type = Ash.Changeset.get_attribute(changeset, :improvement_type)
    affected_constructs = Ash.Changeset.get_attribute(changeset, :affected_constructs) || []
    
    # Assess if changes would be breaking
    breaking = case improvement_type do
      :consistency -> length(affected_constructs) > 2  # Wide changes more likely breaking
      :simplification -> false  # Usually additive
      :validation -> false      # Usually additive
      :performance -> false     # Usually internal
      _ -> false
    end
    
    migration_strategy = if breaking do
      "Implement with deprecation warnings, provide migration guide, maintain backward compatibility for 2+ versions"
    else
      "Changes are backward compatible, no migration needed"
    end
    
    changeset
    |> Ash.Changeset.change_attribute(:breaking_changes, breaking)
    |> Ash.Changeset.change_attribute(:migration_strategy, migration_strategy)
  end
end

defmodule DslAssistant.Changes.GenerateExamples do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    improvement_type = Ash.Changeset.get_attribute(changeset, :improvement_type)
    target_dsl = Ash.Changeset.get_attribute(changeset, :target_dsl_module) || "ExampleDsl"
    
    {before_example, after_example} = case improvement_type do
      :simplification ->
        {
          """
          # Current verbose syntax
          attribute :name, :string do
            allow_nil? false
            constraints [min_length: 1, max_length: 100]
            description "User name field"
          end
          """,
          """
          # Simplified syntax
          attribute :name, :string, required: true, max_length: 100, description: "User name field"
          """
        }
      
      :validation ->
        {
          """
          # Current: errors at runtime
          attribute :email, :string
          """,
          """
          # Improved: validation at compile time
          attribute :email, :string, format: :email
          """
        }
      
      _ ->
        {
          "# Before: Current usage pattern",
          "# After: Improved usage pattern"
        }
    end
    
    changeset
    |> Ash.Changeset.change_attribute(:example_before, before_example)
    |> Ash.Changeset.change_attribute(:example_after, after_example)
  end
end

defmodule DslAssistant.Changes.DefineSuccessCriteria do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    improvement_type = Ash.Changeset.get_attribute(changeset, :improvement_type)
    
    criteria = case improvement_type do
      :simplification ->
        [
          "Lines of code reduced by 20% for common use cases",
          "Cognitive complexity score decreased",
          "User onboarding time reduced",
          "Positive feedback from developer community",
          "No regression in functionality"
        ]
      
      :validation ->
        [
          "Error detection rate increased by 80%",
          "Compile-time errors replace runtime errors",
          "Clear, actionable error messages provided",
          "No false positives in validation",
          "Backward compatibility maintained"
        ]
      
      :consistency ->
        [
          "Naming patterns consistent across DSL",
          "Interface patterns follow same conventions",
          "Documentation updated with consistent examples",
          "Migration path provided for existing code",
          "Developer confusion reduced"
        ]
      
      _ ->
        [
          "Improvement delivers measurable benefit",
          "No negative impact on existing functionality",
          "Documentation updated appropriately",
          "User feedback is positive",
          "Change is sustainable long-term"
        ]
    end
    
    Ash.Changeset.change_attribute(changeset, :success_criteria, criteria)
  end
end

defmodule DslAssistant.Changes.IdentifyRisks do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    improvement_type = Ash.Changeset.get_attribute(changeset, :improvement_type)
    breaking_changes = Ash.Changeset.get_attribute(changeset, :breaking_changes) || false
    
    base_risks = [
      "User resistance to interface changes",
      "Potential for introducing new bugs",
      "Documentation update requirements"
    ]
    
    type_specific_risks = case improvement_type do
      :simplification ->
        ["Loss of advanced functionality", "Over-simplification reduces flexibility"]
      
      :validation ->
        ["False positive validations", "Performance impact from additional checks"]
      
      :consistency ->
        ["Large-scale changes increase risk", "Migration complexity"]
      
      _ ->
        ["Unintended side effects"]
    end
    
    breaking_risks = if breaking_changes do
      ["Breaking changes require user migration", "Potential ecosystem fragmentation"]
    else
      []
    end
    
    all_risks = base_risks ++ type_specific_risks ++ breaking_risks
    
    Ash.Changeset.change_attribute(changeset, :risks, all_risks)
  end
end

defmodule DslAssistant.Changes.CalculatePriority do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    impact_score = Ash.Changeset.get_attribute(changeset, :impact_score) || 0.5
    effort_score = Ash.Changeset.get_attribute(changeset, :effort_score) || 5.0
    breaking_changes = Ash.Changeset.get_attribute(changeset, :breaking_changes) || false
    
    # Priority = Impact / Effort, adjusted for breaking changes
    base_priority = impact_score / max(1.0, effort_score / 5.0)  # Normalize effort to 0-2 scale
    
    # Reduce priority for breaking changes
    priority_score = if breaking_changes do
      base_priority * 0.7
    else
      base_priority
    end
    
    # Ensure priority is between 0 and 1
    final_priority = min(1.0, max(0.0, priority_score))
    
    Ash.Changeset.change_attribute(changeset, :priority_score, final_priority)
  end
end

defmodule DslAssistant.Changes.DevelopValidationApproach do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    improvement_type = Ash.Changeset.get_attribute(changeset, :improvement_type)
    
    approach = case improvement_type do
      :validation ->
        "Implement unit tests for validation logic, integration tests with real DSL usage, property-based testing for edge cases"
      
      :simplification ->
        "A/B testing with current vs simplified interface, user experience surveys, performance benchmarking"
      
      :consistency ->
        "Automated consistency checking, comprehensive review of all DSL constructs, user feedback on clarity"
      
      _ ->
        "Comprehensive testing with existing usage patterns, user acceptance testing, impact measurement"
    end
    
    rollback_plan = "Maintain previous implementation as fallback, implement feature flags for gradual rollout, monitor key metrics post-deployment"
    
    changeset
    |> Ash.Changeset.change_attribute(:validation_approach, approach)
    |> Ash.Changeset.change_attribute(:rollback_plan, rollback_plan)
  end
end

defmodule DslAssistant.Changes.RecalculatePriority do
  use Ash.Resource.Change
  alias DslAssistant.Changes.CalculatePriority
  
  def change(changeset, opts, context) do
    CalculatePriority.change(changeset, opts, context)
  end
end

defmodule DslAssistant.Changes.UpdateValidationApproach do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    # Update validation approach based on refined understanding
    current_approach = Ash.Changeset.get_attribute(changeset, :validation_approach) || ""
    
    refined_approach = "#{current_approach}\n\nRefined based on implementation feedback and updated risk assessment."
    
    Ash.Changeset.change_attribute(changeset, :validation_approach, refined_approach)
  end
end

# Analysis-specific changes

defmodule DslAssistant.Changes.CalculateComplexityMetrics do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    structure_analysis = Ash.Changeset.get_attribute(changeset, :structure_analysis) || %{}
    
    # Calculate complexity metrics from structure
    sections_count = length(Map.get(structure_analysis, :sections, []))
    entities_count = length(Map.get(structure_analysis, :entities, []))
    api_surface = Map.get(structure_analysis, :api_surface, %{})
    
    complexity_metrics = %{
      "sections_count" => sections_count,
      "entities_count" => entities_count,
      "overall_complexity" => calculate_overall_complexity(sections_count, entities_count),
      "api_surface_size" => Map.get(api_surface, :size, 0),
      "nesting_depth" => calculate_max_nesting_depth(structure_analysis)
    }
    
    Ash.Changeset.change_attribute(changeset, :complexity_metrics, complexity_metrics)
  end
  
  defp calculate_overall_complexity(sections, entities) do
    # Simple complexity calculation
    base_complexity = (sections * 0.2) + (entities * 0.1)
    min(1.0, base_complexity / 5.0)
  end
  
  defp calculate_max_nesting_depth(structure) do
    Map.get(structure, :sections, [])
    |> Enum.map(&Map.get(&1, :nesting_depth, 1))
    |> Enum.max(fn -> 1 end)
  end
end

defmodule DslAssistant.Changes.AnalyzeApiSurface do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    structure_analysis = Ash.Changeset.get_attribute(changeset, :structure_analysis) || %{}
    
    api_surface_analysis = %{
      "public_entities" => count_public_entities(structure_analysis),
      "configuration_options" => count_configuration_options(structure_analysis),
      "extension_points" => count_extension_points(structure_analysis),
      "complexity_score" => calculate_api_complexity(structure_analysis)
    }
    
    Ash.Changeset.change_attribute(changeset, :api_surface_analysis, api_surface_analysis)
  end
  
  defp count_public_entities(structure) do
    length(Map.get(structure, :entities, []))
  end
  
  defp count_configuration_options(structure) do
    # Estimate configuration options
    entities = Map.get(structure, :entities, [])
    entities_count = length(entities)
    entities_count * 3  # Rough estimate of options per entity
  end
  
  defp count_extension_points(structure) do
    length(Map.get(structure, :extension_points, []))
  end
  
  defp calculate_api_complexity(structure) do
    entities = length(Map.get(structure, :entities, []))
    sections = length(Map.get(structure, :sections, []))
    
    # Simple complexity score
    (entities + sections) / 20.0
  end
end

defmodule DslAssistant.Changes.ExtractErrorPatterns do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    usage_patterns = Ash.Changeset.get_attribute(changeset, :usage_patterns) || %{}
    
    error_analysis = %{
      "common_errors" => extract_common_errors(usage_patterns),
      "error_rate" => calculate_error_rate(usage_patterns),
      "error_categories" => categorize_errors(usage_patterns),
      "resolution_patterns" => identify_resolution_patterns(usage_patterns)
    }
    
    Ash.Changeset.change_attribute(changeset, :error_analysis, error_analysis)
  end
  
  defp extract_common_errors(patterns) do
    Map.get(patterns, :errors, [])
    |> Enum.take(5)  # Top 5 errors
  end
  
  defp calculate_error_rate(patterns) do
    errors = Map.get(patterns, :errors, [])
    total_usage = Map.get(patterns, :total_usage, 100)
    
    if total_usage > 0 do
      length(errors) / total_usage
    else
      0.0
    end
  end
  
  defp categorize_errors(patterns) do
    Map.get(patterns, :errors, [])
    |> Enum.group_by(fn error ->
      cond do
        String.contains?(error[:pattern] || "", "syntax") -> "syntax"
        String.contains?(error[:pattern] || "", "validation") -> "validation"
        String.contains?(error[:pattern] || "", "configuration") -> "configuration"
        true -> "other"
      end
    end)
    |> Map.new(fn {category, errors} -> {category, length(errors)} end)
  end
  
  defp identify_resolution_patterns(patterns) do
    # Identify common ways users resolve errors
    Map.get(patterns, :resolutions, [])
    |> Enum.take(3)
  end
end

defmodule DslAssistant.Changes.AnalyzeUserJourneys do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    usage_patterns = Ash.Changeset.get_attribute(changeset, :usage_patterns) || %{}
    
    user_journey_analysis = %{
      "common_paths" => identify_common_user_paths(usage_patterns),
      "friction_points" => find_journey_friction_points(usage_patterns),
      "success_patterns" => identify_success_patterns(usage_patterns),
      "drop_off_points" => find_drop_off_points(usage_patterns)
    }
    
    Ash.Changeset.change_attribute(changeset, :user_journey_analysis, user_journey_analysis)
  end
  
  defp identify_common_user_paths(patterns) do
    Map.get(patterns, :user_paths, [])
    |> Enum.take(3)
  end
  
  defp find_journey_friction_points(patterns) do
    Map.get(patterns, :friction_points, [])
  end
  
  defp identify_success_patterns(patterns) do
    Map.get(patterns, :success_patterns, [])
  end
  
  defp find_drop_off_points(patterns) do
    Map.get(patterns, :drop_off_points, [])
  end
end

defmodule DslAssistant.Changes.BenchmarkAgainstEcosystem do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    dsl_module = Ash.Changeset.get_attribute(changeset, :dsl_module) || ""
    complexity_metrics = Ash.Changeset.get_attribute(changeset, :complexity_metrics) || %{}
    
    benchmark_comparison = %{
      "ecosystem_average_complexity" => 0.6,  # Placeholder
      "relative_complexity" => calculate_relative_complexity(complexity_metrics),
      "similar_dsls" => find_similar_dsls(dsl_module),
      "best_practices_compliance" => assess_best_practices_compliance(complexity_metrics)
    }
    
    Ash.Changeset.change_attribute(changeset, :benchmark_comparison, benchmark_comparison)
  end
  
  defp calculate_relative_complexity(metrics) do
    our_complexity = Map.get(metrics, "overall_complexity", 0.5)
    ecosystem_average = 0.6
    
    our_complexity / ecosystem_average
  end
  
  defp find_similar_dsls(dsl_module) do
    # Placeholder for finding similar DSLs
    cond do
      String.contains?(dsl_module, "Ash") -> ["AshGraphql", "AshJsonApi", "AshAdmin"]
      String.contains?(dsl_module, "Phoenix") -> ["Phoenix.Router", "Phoenix.LiveView"]
      true -> ["GenericDsl1", "GenericDsl2"]
    end
  end
  
  defp assess_best_practices_compliance(metrics) do
    # Simple compliance assessment
    complexity = Map.get(metrics, "overall_complexity", 0.5)
    api_surface = Map.get(metrics, "api_surface_size", 10)
    
    cond do
      complexity < 0.4 && api_surface < 20 -> "high"
      complexity < 0.7 && api_surface < 40 -> "medium"
      true -> "low"
    end
  end
end

defmodule DslAssistant.Changes.CalculateAnalysisConfidence do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    data_sample_size = Ash.Changeset.get_attribute(changeset, :data_sample_size) || 0
    usage_patterns = Ash.Changeset.get_attribute(changeset, :usage_patterns) || %{}
    
    # Calculate confidence based on data quality and quantity
    base_confidence = case data_sample_size do
      n when n >= 100 -> 0.9
      n when n >= 50 -> 0.8
      n when n >= 20 -> 0.7
      n when n >= 10 -> 0.6
      _ -> 0.4
    end
    
    # Adjust for data completeness
    pattern_completeness = calculate_pattern_completeness(usage_patterns)
    final_confidence = base_confidence * pattern_completeness
    
    Ash.Changeset.change_attribute(changeset, :analysis_confidence, final_confidence)
  end
  
  defp calculate_pattern_completeness(patterns) do
    # Check if we have different types of usage data
    has_errors = Map.has_key?(patterns, :errors)
    has_success = Map.has_key?(patterns, :success_patterns)
    has_friction = Map.has_key?(patterns, :friction_points)
    has_journeys = Map.has_key?(patterns, :user_paths)
    
    completeness_factors = [has_errors, has_success, has_friction, has_journeys]
    Enum.count(completeness_factors, & &1) / length(completeness_factors)
  end
end

# Additional changes for UsagePattern

defmodule DslAssistant.Changes.AnalyzePatternContext do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    pattern_type = Ash.Changeset.get_attribute(changeset, :pattern_type)
    outcome = Ash.Changeset.get_attribute(changeset, :outcome)
    
    # Generate context based on pattern type and outcome
    context = case {pattern_type, outcome} do
      {:error, _} ->
        %{
          "context_type" => "error_context",
          "severity" => "high",
          "requires_attention" => true
        }
      
      {:success, :success} ->
        %{
          "context_type" => "success_context",
          "reinforcement_value" => "high",
          "pattern_strength" => "strong"
        }
      
      {:workaround, _} ->
        %{
          "context_type" => "friction_context",
          "improvement_opportunity" => "medium",
          "user_frustration" => "likely"
        }
      
      _ ->
        %{
          "context_type" => "general_context"
        }
    end
    
    changeset
    |> Ash.Changeset.change_attribute(:user_context, Map.merge(Ash.Changeset.get_attribute(changeset, :user_context) || %{}, context))
  end
end

defmodule DslAssistant.Changes.CalculatePatternConfidence do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    frequency = Ash.Changeset.get_attribute(changeset, :frequency) || 1
    pattern_type = Ash.Changeset.get_attribute(changeset, :pattern_type)
    
    # Base confidence from frequency
    frequency_confidence = min(1.0, :math.log(frequency + 1) / :math.log(50))
    
    # Adjust for pattern type reliability
    type_reliability = case pattern_type do
      :success -> 0.9   # Success patterns are highly reliable
      :error -> 0.95    # Error patterns are very reliable
      :common -> 0.8    # Common patterns are reliable
      :workaround -> 0.7  # Workarounds indicate real issues
      :rare -> 0.6      # Rare patterns less reliable
      _ -> 0.7
    end
    
    final_confidence = frequency_confidence * type_reliability
    
    Ash.Changeset.change_attribute(changeset, :confidence_score, final_confidence)
  end
end

defmodule DslAssistant.Changes.DetermineValidationNeeds do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    pattern_type = Ash.Changeset.get_attribute(changeset, :pattern_type)
    confidence = Ash.Changeset.get_attribute(changeset, :confidence_score) || 0.7
    
    validation_status = case {pattern_type, confidence} do
      {:error, c} when c > 0.8 -> :validated  # High-confidence errors are likely valid
      {:success, c} when c > 0.9 -> :validated  # High-confidence successes are likely valid
      {_, c} when c > 0.85 -> :partially_validated
      _ -> :pending_validation
    end
    
    Ash.Changeset.change_attribute(changeset, :validation_status, validation_status)
  end
end

defmodule DslAssistant.Changes.UpdatePatternConfidence do
  use Ash.Resource.Change
  alias DslAssistant.Changes.CalculatePatternConfidence
  
  def change(changeset, opts, context) do
    CalculatePatternConfidence.change(changeset, opts, context)
  end
end

# Additional changes for ImprovementResult

defmodule DslAssistant.Changes.AnalyzeImpact do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    before_metrics = Ash.Changeset.get_attribute(changeset, :before_metrics) || %{}
    after_metrics = Ash.Changeset.get_attribute(changeset, :after_metrics) || %{}
    
    impact_analysis = calculate_impact_analysis(before_metrics, after_metrics)
    
    Ash.Changeset.change_attribute(changeset, :impact_analysis, impact_analysis)
  end
  
  defp calculate_impact_analysis(before_metrics, after_metrics) do
    %{
      "metrics_changed" => find_changed_metrics(before_metrics, after_metrics),
      "positive_changes" => find_positive_changes(before_metrics, after_metrics),
      "negative_changes" => find_negative_changes(before_metrics, after_metrics),
      "overall_direction" => determine_overall_direction(before_metrics, after_metrics)
    }
  end
  
  defp find_changed_metrics(before_metrics, after_metrics) do
    common_keys = MapSet.intersection(MapSet.new(Map.keys(before_metrics)), MapSet.new(Map.keys(after_metrics)))
    
    Enum.filter(common_keys, fn key ->
      before_val = Map.get(before_metrics, key)
      after_val = Map.get(after_metrics, key)
      
      is_number(before_val) && is_number(after_val) && before_val != after_val
    end)
    |> Enum.into([])
  end
  
  defp find_positive_changes(before_metrics, after_metrics) do
    # Simplified - in real implementation would be more sophisticated
    Map.keys(after_metrics)
    |> Enum.filter(fn key ->
      before_val = Map.get(before_metrics, key, 0)
      after_val = Map.get(after_metrics, key, 0)
      
      is_number(before_val) && is_number(after_val) && after_val > before_val
    end)
  end
  
  defp find_negative_changes(before_metrics, after_metrics) do
    Map.keys(after_metrics)
    |> Enum.filter(fn key ->
      before_val = Map.get(before_metrics, key, 0)
      after_val = Map.get(after_metrics, key, 0)
      
      is_number(before_val) && is_number(after_val) && after_val < before_val
    end)
  end
  
  defp determine_overall_direction(before_metrics, after_metrics) do
    positive = length(find_positive_changes(before_metrics, after_metrics))
    negative = length(find_negative_changes(before_metrics, after_metrics))
    
    cond do
      positive > negative -> "positive"
      negative > positive -> "negative"
      true -> "neutral"
    end
  end
end

defmodule DslAssistant.Changes.CalculateActualImpact do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    impact_analysis = Ash.Changeset.get_attribute(changeset, :impact_analysis) || %{}
    
    # Calculate a numerical impact score based on the analysis
    impact_score = case Map.get(impact_analysis, "overall_direction") do
      "positive" -> 0.6  # Base positive impact
      "negative" -> -0.4  # Base negative impact
      _ -> 0.0
    end
    
    # Adjust based on magnitude of changes
    positive_count = length(Map.get(impact_analysis, "positive_changes", []))
    negative_count = length(Map.get(impact_analysis, "negative_changes", []))
    
    adjusted_impact = impact_score + (positive_count * 0.1) - (negative_count * 0.1)
    final_impact = max(-1.0, min(1.0, adjusted_impact))
    
    Ash.Changeset.change_attribute(changeset, :actual_impact_score, final_impact)
  end
end

defmodule DslAssistant.Changes.ValidateSuccessCriteria do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    # This would validate against the success criteria from the related improvement
    # For now, simulate some success criteria validation
    
    impact_score = Ash.Changeset.get_attribute(changeset, :actual_impact_score) || 0.0
    implementation_success = Ash.Changeset.get_attribute(changeset, :implementation_success) || false
    
    success_criteria_met = []
    success_criteria_failed = []
    
    # Example criteria validation
    if impact_score > 0.2 do
      success_criteria_met = ["Positive impact achieved" | success_criteria_met]
    else
      success_criteria_failed = ["Positive impact not achieved" | success_criteria_failed]
    end
    
    if implementation_success do
      success_criteria_met = ["Implementation completed successfully" | success_criteria_met]
    else
      success_criteria_failed = ["Implementation failed" | success_criteria_failed]
    end
    
    total_criteria = length(success_criteria_met) + length(success_criteria_failed)
    
    changeset
    |> Ash.Changeset.change_attribute(:success_criteria_met, success_criteria_met)
    |> Ash.Changeset.change_attribute(:success_criteria_failed, success_criteria_failed)
    |> Ash.Changeset.change_attribute(:total_success_criteria, total_criteria)
  end
end

defmodule DslAssistant.Changes.ExtractLearningInsights do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    impact_score = Ash.Changeset.get_attribute(changeset, :actual_impact_score) || 0.0
    implementation_success = Ash.Changeset.get_attribute(changeset, :implementation_success) || false
    
    insights = []
    
    # Generate insights based on results
    insights = if impact_score > 0.5 do
      ["High impact improvement validated - consider similar approaches" | insights]
    else
      insights
    end
    
    insights = if impact_score < 0 do
      ["Negative impact detected - review approach and consider rollback" | insights]
    else
      insights
    end
    
    insights = if !implementation_success do
      ["Implementation failure - review technical approach and resource allocation" | insights]
    else
      insights
    end
    
    Ash.Changeset.change_attribute(changeset, :learning_insights, insights)
  end
end

defmodule DslAssistant.Changes.AnalyzeUserFeedback do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    user_feedback = Ash.Changeset.get_attribute(changeset, :user_feedback) || %{}
    
    # Analyze sentiment and themes in user feedback
    # This is simplified - real implementation would use NLP
    
    feedback_analysis = %{
      "sentiment" => analyze_sentiment(user_feedback),
      "themes" => extract_themes(user_feedback),
      "actionable_items" => find_actionable_items(user_feedback)
    }
    
    # Update the impact analysis with user feedback insights
    current_impact = Ash.Changeset.get_attribute(changeset, :impact_analysis) || %{}
    updated_impact = Map.merge(current_impact, %{"user_feedback_analysis" => feedback_analysis})
    
    Ash.Changeset.change_attribute(changeset, :impact_analysis, updated_impact)
  end
  
  defp analyze_sentiment(feedback) do
    # Simplified sentiment analysis
    feedback_text = inspect(feedback)
    
    cond do
      String.contains?(feedback_text, ["good", "great", "better", "love"]) -> "positive"
      String.contains?(feedback_text, ["bad", "worse", "hate", "terrible"]) -> "negative"
      true -> "neutral"
    end
  end
  
  defp extract_themes(feedback) do
    # Extract common themes from feedback
    feedback_text = inspect(feedback)
    
    themes = []
    themes = if String.contains?(feedback_text, ["usability", "easy", "difficult"]), do: ["usability" | themes], else: themes
    themes = if String.contains?(feedback_text, ["performance", "speed", "slow"]), do: ["performance" | themes], else: themes
    themes = if String.contains?(feedback_text, ["documentation", "docs", "help"]), do: ["documentation" | themes], else: themes
    
    themes
  end
  
  defp find_actionable_items(feedback) do
    # Find specific actionable items from feedback
    # This is highly simplified
    feedback_text = inspect(feedback)
    
    items = []
    items = if String.contains?(feedback_text, "documentation"), do: ["Improve documentation" | items], else: items
    items = if String.contains?(feedback_text, "example"), do: ["Add more examples" | items], else: items
    
    items
  end
end

defmodule DslAssistant.Changes.UpdateLearningInsights do
  use Ash.Resource.Change
  alias DslAssistant.Changes.ExtractLearningInsights
  
  def change(changeset, opts, context) do
    ExtractLearningInsights.change(changeset, opts, context)
  end
end

defmodule DslAssistant.Changes.IncrementFrequency do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    current_frequency = Ash.Changeset.get_attribute(changeset, :frequency) || 0
    Ash.Changeset.change_attribute(changeset, :frequency, current_frequency + 1)
  end
end

defmodule DslAssistant.Changes.MarkAsRolledBack do
  use Ash.Resource.Change
  
  def change(changeset, _opts, _context) do
    changeset
    |> Ash.Changeset.change_attribute(:rollback_required, true)
    |> Ash.Changeset.change_attribute(:implementation_success, false)
    |> Ash.Changeset.change_attribute(:actual_impact_score, -0.5)
  end
end