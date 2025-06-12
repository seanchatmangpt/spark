defmodule IntelligentDslFactory.DomainAnalysis do
  @moduledoc """
  Comprehensive domain analysis resource that captures the semantic
  structure and constraints of a problem domain.
  
  This is not simple data collection - it's semantic reasoning about
  domain concepts, relationships, and constraints.
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: IntelligentDslFactory

  postgres do
    table "domain_analyses"
    repo IntelligentDslFactory.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :domain_name, :string do
      description "Human-readable name for the analyzed domain"
      allow_nil? false
      constraints [min_length: 1, max_length: 200]
    end
    
    attribute :entity_relationships, :map do
      description "Graph structure of domain entities and their relationships"
      allow_nil? false
      default %{}
    end
    
    attribute :business_rules, :map do
      description "Extracted business rules, constraints, and invariants"
      allow_nil? false
      default %{}
    end
    
    attribute :constraint_patterns, :map do
      description "Identified patterns in domain constraints and validations"
      allow_nil? false
      default %{}
    end
    
    attribute :workflow_patterns, :map do
      description "Process flows and state transitions in the domain"
      allow_nil? false
      default %{}
    end
    
    attribute :semantic_concepts, :map do
      description "Core concepts and their semantic relationships"
      allow_nil? false
      default %{}
    end
    
    attribute :domain_specification, :string do
      description "Original domain specification input"
      allow_nil? false
    end
    
    attribute :analysis_confidence, :decimal do
      description "Confidence score for the analysis (0-1)"
      constraints [min: 0, max: 1]
      default 0.5
    end
    
    attribute :semantic_complexity, :decimal do
      description "Measured semantic complexity of the domain"
      constraints [min: 0]
      default 1.0
    end
    
    attribute :analysis_timestamp, :utc_datetime_usec do
      description "When this analysis was performed"
      allow_nil? false
      default &DateTime.utc_now/0
    end
    
    attribute :analysis_metadata, :map do
      description "Metadata about the analysis process and algorithms used"
      default %{}
    end
    
    timestamps()
  end

  relationships do
    has_many :semantic_patterns, IntelligentDslFactory.SemanticPattern do
      description "Patterns extracted from this domain analysis"
    end
    
    has_many :generated_extensions, IntelligentDslFactory.GeneratedExtension do
      description "DSL extensions generated from this analysis"
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :analyze_domain do
      description "Perform comprehensive domain analysis"
      accept [:domain_name, :domain_specification]
      
      change IntelligentDslFactory.Changes.PerformSemanticAnalysis
      change IntelligentDslFactory.Changes.ExtractEntityRelationships
      change IntelligentDslFactory.Changes.IdentifyBusinessRules
      change IntelligentDslFactory.Changes.AnalyzeConstraintPatterns
      change IntelligentDslFactory.Changes.ExtractWorkflowPatterns
      change IntelligentDslFactory.Changes.CalculateSemanticComplexity
      change IntelligentDslFactory.Changes.AssessAnalysisConfidence
      
      after_action IntelligentDslFactory.AfterActions.TriggerPatternExtraction
    end
    
    read :by_domain_name do
      argument :domain_name, :string, allow_nil?: false
      filter expr(domain_name == ^arg(:domain_name))
      prepare build(sort: [analysis_timestamp: :desc])
    end
    
    read :high_confidence do
      argument :min_confidence, :decimal, default: 0.8
      filter expr(analysis_confidence >= ^arg(:min_confidence))
      prepare build(sort: [analysis_confidence: :desc])
    end
    
    read :by_complexity_range do
      argument :min_complexity, :decimal, default: 0.0
      argument :max_complexity, :decimal, default: 10.0
      filter expr(semantic_complexity >= ^arg(:min_complexity) and 
                 semantic_complexity <= ^arg(:max_complexity))
    end
    
    read :recent_analyses do
      argument :days_back, :integer, default: 30
      prepare IntelligentDslFactory.Preparations.FilterByRecentAnalyses
      prepare build(sort: [analysis_timestamp: :desc])
    end
  end

  validations do
    validate {IntelligentDslFactory.Validations.ValidDomainSpecification, []}
    validate {IntelligentDslFactory.Validations.SemanticDataConsistency, []}
  end

  calculations do
    calculate :entity_count, :integer do
      description "Number of identified domain entities"
      calculation IntelligentDslFactory.Calculations.CountEntities
    end
    
    calculate :relationship_density, :decimal do
      description "Density of relationships between entities"
      calculation IntelligentDslFactory.Calculations.RelationshipDensity
    end
    
    calculate :rule_complexity, :decimal do
      description "Complexity score based on business rules"
      calculation IntelligentDslFactory.Calculations.RuleComplexity
    end
    
    calculate :semantic_coherence, :decimal do
      description "How semantically coherent the domain concepts are"
      calculation IntelligentDslFactory.Calculations.SemanticCoherence
    end
    
    calculate :analysis_quality_score, :decimal do
      description "Overall quality of the domain analysis"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          # Real quality calculation based on multiple factors
          confidence_weight = Decimal.to_float(record.analysis_confidence) * 0.4
          complexity_factor = min(1.0, Decimal.to_float(record.semantic_complexity) / 5.0) * 0.3
          completeness_factor = calculate_completeness(record) * 0.3
          
          Decimal.new(Float.to_string(confidence_weight + complexity_factor + completeness_factor))
        end)
      end
    end
  end

  aggregates do
    count :total_patterns, :semantic_patterns
    avg :average_pattern_confidence, :semantic_patterns, :confidence_score
  end

  # Helper functions for calculations
  defp calculate_completeness(record) do
    # Check how complete the analysis is across different dimensions
    dimensions = [
      map_size(record.entity_relationships),
      map_size(record.business_rules),
      map_size(record.constraint_patterns),
      map_size(record.workflow_patterns),
      map_size(record.semantic_concepts)
    ]
    
    filled_dimensions = Enum.count(dimensions, &(&1 > 0))
    filled_dimensions / length(dimensions)
  end

  def description do
    """
    DomainAnalysis captures comprehensive semantic understanding of a problem domain,
    enabling intelligent generation of domain-specific language constructs.
    """
  end
end