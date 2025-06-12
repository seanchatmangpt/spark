defmodule IntelligentDslFactory.SemanticPattern do
  @moduledoc """
  Represents a semantic pattern extracted from domain analysis.
  
  These patterns are not simple templates - they're abstractions that
  capture recurring semantic structures across domains.
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: IntelligentDslFactory

  postgres do
    table "semantic_patterns"
    repo IntelligentDslFactory.Repo
    
    references do
      reference :domain_analysis, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :pattern_name, :string do
      description "Human-readable name for this pattern"
      allow_nil? false
      constraints [min_length: 1, max_length: 100]
    end
    
    attribute :pattern_type, :atom do
      description "Type of semantic pattern"
      constraints [one_of: [:entity, :relationship, :constraint, :workflow, :transformation, :validation, :aggregation]]
      allow_nil? false
    end
    
    attribute :semantic_signature, :map do
      description "Formal semantic signature of the pattern"
      allow_nil? false
      default %{}
    end
    
    attribute :abstraction_level, :atom do
      description "Level of abstraction this pattern operates at"
      constraints [one_of: [:concrete, :abstract, :meta, :universal]]
      default :concrete
    end
    
    attribute :domain_specificity, :decimal do
      description "How domain-specific vs. general this pattern is (0-1)"
      constraints [min: 0, max: 1]
      default 0.5
    end
    
    attribute :reusability_score, :decimal do
      description "How reusable this pattern is across domains (0-1)"
      constraints [min: 0, max: 1]
      default 0.5
    end
    
    attribute :implementation_complexity, :decimal do
      description "Complexity of implementing this pattern (0-10)"
      constraints [min: 0, max: 10]
      default 1.0
    end
    
    attribute :confidence_score, :decimal do
      description "Confidence in this pattern extraction (0-1)"
      constraints [min: 0, max: 1]
      default 0.5
    end
    
    attribute :pattern_data, :map do
      description "Complete pattern data including implementation details"
      allow_nil? false
      default %{}
    end
    
    attribute :usage_frequency, :integer do
      description "How often this pattern appears in successful DSLs"
      constraints [min: 0]
      default 0
    end
    
    attribute :success_correlation, :decimal do
      description "Correlation between this pattern and DSL success (0-1)"
      constraints [min: 0, max: 1]
      default 0.5
    end
    
    attribute :semantic_constraints, {:array, :map} do
      description "Formal constraints that must be satisfied for valid usage"
      default []
    end
    
    attribute :composition_rules, :map do
      description "Rules for how this pattern composes with others"
      default %{}
    end
    
    attribute :performance_characteristics, :map do
      description "Known performance implications of this pattern"
      default %{}
    end
    
    timestamps()
  end

  relationships do
    belongs_to :domain_analysis, IntelligentDslFactory.DomainAnalysis do
      description "The domain analysis this pattern was extracted from"
    end
    
    has_many :generated_extensions, IntelligentDslFactory.GeneratedExtension do
      description "Extensions that use this pattern"
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :extract_pattern do
      description "Extract a semantic pattern from domain analysis"
      accept [:pattern_name, :pattern_type, :semantic_signature, :pattern_data, :domain_analysis_id]
      
      change IntelligentDslFactory.Changes.ValidateSemanticSignature
      change IntelligentDslFactory.Changes.CalculateAbstractionLevel
      change IntelligentDslFactory.Changes.AssessDomainSpecificity
      change IntelligentDslFactory.Changes.EvaluateReusability
      change IntelligentDslFactory.Changes.EstimateImplementationComplexity
      change IntelligentDslFactory.Changes.DeriveSemanticConstraints
      change IntelligentDslFactory.Changes.AnalyzeCompositionRules
      
      after_action IntelligentDslFactory.AfterActions.IndexPattern
    end
    
    update :refine_from_usage do
      description "Refine pattern based on usage data"
      accept [:usage_frequency, :success_correlation, :performance_characteristics]
      
      change IntelligentDslFactory.Changes.UpdateReusabilityScore
      change IntelligentDslFactory.Changes.AdjustConfidenceScore
      
      after_action IntelligentDslFactory.AfterActions.PropagateRefinements
    end
    
    read :by_pattern_type do
      argument :pattern_type, :atom, allow_nil?: false
      filter expr(pattern_type == ^arg(:pattern_type))
      prepare build(sort: [confidence_score: :desc])
    end
    
    read :high_reusability do
      argument :min_reusability, :decimal, default: 0.7
      filter expr(reusability_score >= ^arg(:min_reusability))
      prepare build(sort: [reusability_score: :desc])
    end
    
    read :by_abstraction_level do
      argument :level, :atom, allow_nil?: false
      filter expr(abstraction_level == ^arg(:level))
    end
    
    read :successful_patterns do
      argument :min_success_correlation, :decimal, default: 0.7
      filter expr(success_correlation >= ^arg(:min_success_correlation))
      prepare build(sort: [success_correlation: :desc, usage_frequency: :desc])
    end
    
    read :composable_with do
      argument :target_pattern_id, :uuid, allow_nil?: false
      prepare IntelligentDslFactory.Preparations.FindComposablePatterns
    end
  end

  validations do
    validate {IntelligentDslFactory.Validations.ValidSemanticSignature, []}
    validate {IntelligentDslFactory.Validations.ConsistentPatternData, []}
    validate {IntelligentDslFactory.Validations.ValidCompositionRules, []}
  end

  calculations do
    calculate :pattern_value_score, :decimal do
      description "Overall value score combining reusability, confidence, and success"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          reusability = Decimal.to_float(record.reusability_score)
          confidence = Decimal.to_float(record.confidence_score)
          success = Decimal.to_float(record.success_correlation)
          frequency_factor = min(1.0, record.usage_frequency / 100.0)
          
          # Weighted combination favoring proven, reusable patterns
          value = (reusability * 0.3) + (confidence * 0.25) + (success * 0.35) + (frequency_factor * 0.1)
          Decimal.new(Float.to_string(value))
        end)
      end
    end
    
    calculate :complexity_efficiency, :decimal do
      description "Ratio of value to implementation complexity"
      calculation IntelligentDslFactory.Calculations.ComplexityEfficiency
    end
    
    calculate :semantic_richness, :decimal do
      description "Measure of semantic expressiveness"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          # Analyze semantic signature richness
          signature_complexity = analyze_signature_complexity(record.semantic_signature)
          constraint_richness = length(record.semantic_constraints) / 10.0
          composition_complexity = map_size(record.composition_rules) / 5.0
          
          richness = min(1.0, (signature_complexity + constraint_richness + composition_complexity) / 3.0)
          Decimal.new(Float.to_string(richness))
        end)
      end
    end
  end

  aggregates do
    count :usage_count, :generated_extensions
    avg :average_success_rate, :generated_extensions, :success_metric
  end

  # Helper functions for semantic analysis
  defp analyze_signature_complexity(signature) do
    # Real semantic complexity analysis
    elements = count_semantic_elements(signature)
    relationships = count_semantic_relationships(signature)
    constraints = count_semantic_constraints(signature)
    
    # Normalized complexity score
    min(1.0, (elements + relationships * 1.5 + constraints * 2.0) / 20.0)
  end

  defp count_semantic_elements(signature) do
    # Count entities, attributes, operations, etc.
    Map.get(signature, "elements", []) |> length()
  end

  defp count_semantic_relationships(signature) do
    # Count semantic relationships between elements
    Map.get(signature, "relationships", []) |> length()
  end

  defp count_semantic_constraints(signature) do
    # Count semantic constraints and invariants
    Map.get(signature, "constraints", []) |> length()
  end

  def description do
    """
    SemanticPattern represents a reusable abstraction extracted from domain analysis,
    capable of being composed into DSL extensions that capture domain knowledge.
    """
  end
end