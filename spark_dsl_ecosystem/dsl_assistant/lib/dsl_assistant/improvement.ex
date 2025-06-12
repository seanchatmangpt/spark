defmodule DslAssistant.Improvement do
  @moduledoc """
  A concrete, actionable improvement recommendation for a DSL.
  
  Each improvement includes:
  - Specific problem it solves
  - Concrete implementation steps  
  - Effort and impact estimates
  - Success criteria for validation
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: DslAssistant

  postgres do
    table "improvements"
    repo DslAssistant.Repo
    
    references do
      reference :dsl_analysis, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :title, :string do
      description "Concise title describing the improvement"
      allow_nil? false
      constraints [min_length: 5, max_length: 200]
    end
    
    attribute :improvement_type, :atom do
      description "Category of improvement"
      constraints [one_of: [:simplification, :validation, :consistency, :discoverability, :performance, :composition, :error_prevention]]
      allow_nil? false
    end
    
    attribute :problem_description, :string do
      description "Specific problem this improvement addresses"
      allow_nil? false
      constraints [min_length: 10, max_length: 1000]
    end
    
    attribute :proposed_solution, :string do
      description "Detailed description of the proposed solution"
      allow_nil? false
      constraints [min_length: 10, max_length: 2000]
    end
    
    attribute :implementation_steps, {:array, :string} do
      description "Step-by-step implementation guide"
      default []
    end
    
    attribute :effort_estimate, :string do
      description "Estimated implementation effort (e.g., '2 days', '1 week')"
      constraints [max_length: 50]
    end
    
    attribute :effort_score, :decimal do
      description "Numerical effort score (0-10, where 10 is very high effort)"
      constraints [min: 0, max: 10]
      default 5.0
    end
    
    attribute :impact_estimate, :string do
      description "Estimated impact description"
      constraints [max_length: 200]
    end
    
    attribute :impact_score, :decimal do
      description "Numerical impact score (0-1, where 1 is very high impact)"
      constraints [min: 0, max: 1]
      default 0.5
    end
    
    attribute :affected_constructs, {:array, :string} do
      description "DSL constructs that would be modified"
      default []
    end
    
    attribute :breaking_changes, :boolean do
      description "Whether this improvement requires breaking changes"
      default false
    end
    
    attribute :migration_strategy, :string do
      description "Strategy for migrating existing usage"
      constraints [max_length: 1000]
    end
    
    attribute :example_before, :string do
      description "Example of current usage pattern"
      constraints [max_length: 2000]
    end
    
    attribute :example_after, :string do
      description "Example of improved usage pattern"
      constraints [max_length: 2000]
    end
    
    attribute :success_criteria, {:array, :string} do
      description "Measurable criteria for successful implementation"
      default []
    end
    
    attribute :risks, {:array, :string} do
      description "Potential risks and mitigation strategies"
      default []
    end
    
    attribute :dependencies, {:array, :string} do
      description "Other improvements this depends on"
      default []
    end
    
    attribute :priority_score, :decimal do
      description "Priority score based on impact vs effort (0-1)"
      constraints [min: 0, max: 1]
      default 0.5
    end
    
    attribute :target_dsl_module, :string do
      description "DSL module this improvement targets"
      allow_nil? false
      constraints [min_length: 1, max_length: 200]
    end
    
    attribute :validation_approach, :string do
      description "How to validate this improvement works"
      constraints [max_length: 500]
    end
    
    attribute :rollback_plan, :string do
      description "Plan for rolling back if improvement causes issues"
      constraints [max_length: 500]
    end
    
    timestamps()
  end

  relationships do
    belongs_to :dsl_analysis, DslAssistant.DslAnalysis do
      description "The analysis that generated this improvement"
      allow_nil? false
    end
    
    has_many :improvement_results, DslAssistant.ImprovementResult do
      description "Results from implementing this improvement"
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :recommend_improvement do
      description "Create an improvement recommendation"
      accept [:title, :improvement_type, :problem_description, :proposed_solution, 
              :target_dsl_module, :dsl_analysis_id]
      
      change DslAssistant.Changes.EstimateEffort
      change DslAssistant.Changes.EstimateImpact
      change DslAssistant.Changes.GenerateImplementationSteps
      change DslAssistant.Changes.IdentifyAffectedConstructs
      change DslAssistant.Changes.AssessBreakingChanges
      change DslAssistant.Changes.GenerateExamples
      change DslAssistant.Changes.DefineSuccessCriteria
      change DslAssistant.Changes.IdentifyRisks
      change DslAssistant.Changes.CalculatePriority
      change DslAssistant.Changes.DevelopValidationApproach
      
      after_action DslAssistant.AfterActions.IndexImprovement
    end
    
    update :refine_from_feedback do
      description "Refine improvement based on implementation feedback"
      accept [:effort_score, :impact_score, :implementation_steps, :risks]
      
      change DslAssistant.Changes.RecalculatePriority
      change DslAssistant.Changes.UpdateValidationApproach
    end
    
    read :by_dsl_module do
      argument :dsl_module, :string, allow_nil?: false
      filter expr(target_dsl_module == ^arg(:dsl_module))
      prepare build(sort: [priority_score: :desc])
    end
    
    read :by_improvement_type do
      argument :improvement_type, :atom, allow_nil?: false
      filter expr(improvement_type == ^arg(:improvement_type))
    end
    
    read :high_priority do
      argument :min_priority, :decimal, default: 0.7
      filter expr(priority_score >= ^arg(:min_priority))
      prepare build(sort: [priority_score: :desc])
    end
    
    read :low_effort_high_impact do
      filter expr(effort_score <= 3.0 and impact_score >= 0.7)
      prepare build(sort: [priority_score: :desc])
    end
    
    read :non_breaking do
      filter expr(breaking_changes == false)
      prepare build(sort: [impact_score: :desc])
    end
    
    read :implementable do
      # Improvements that are ready to implement (no blocking dependencies)
      filter expr(fragment("jsonb_array_length(dependencies) = 0"))
      prepare build(sort: [priority_score: :desc])
    end
  end

  validations do
    validate {DslAssistant.Validations.ValidImplementationSteps, []}
    validate {DslAssistant.Validations.ConsistentEffortImpact, []}
    validate {DslAssistant.Validations.ValidSuccessCriteria, []}
  end

  calculations do
    calculate :value_ratio, :decimal do
      description "Impact to effort ratio (higher is better)"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          effort = max(0.1, Decimal.to_float(record.effort_score))
          impact = Decimal.to_float(record.impact_score)
          ratio = impact / effort
          Decimal.new(Float.to_string(ratio))
        end)
      end
    end
    
    calculate :implementation_readiness, :decimal do
      description "How ready this improvement is for implementation (0-1)"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          has_clear_steps = length(record.implementation_steps) > 0
          has_examples = record.example_before != nil && record.example_after != nil
          has_success_criteria = length(record.success_criteria) > 0
          has_validation = record.validation_approach != nil
          no_blocking_deps = length(record.dependencies) == 0
          
          readiness_factors = [has_clear_steps, has_examples, has_success_criteria, has_validation, no_blocking_deps]
          readiness_score = Enum.count(readiness_factors, & &1) / length(readiness_factors)
          
          Decimal.new(Float.to_string(readiness_score))
        end)
      end
    end
    
    calculate :risk_level, :atom do
      description "Overall risk level for this improvement"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          risk_count = length(record.risks)
          breaking = record.breaking_changes
          
          cond do
            breaking && risk_count > 2 -> :high
            breaking || risk_count > 1 -> :medium
            true -> :low
          end
        end)
      end
    end
  end

  aggregates do
    count :total_implementation_results, :improvement_results
    avg :average_actual_impact, :improvement_results, :actual_impact_score
  end

  def description do
    """
    Improvement represents a concrete, actionable recommendation for improving
    a DSL, with detailed implementation guidance and success criteria.
    """
  end
end