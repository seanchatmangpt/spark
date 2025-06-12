defmodule IntelligentDslFactory.GeneratedExtension do
  @moduledoc """
  A generated Spark DSL extension with complete semantic modeling.
  
  This represents the actual output of intelligent DSL generation - 
  not just code, but a complete language extension with reasoning capabilities.
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: IntelligentDslFactory

  postgres do
    table "generated_extensions"
    repo IntelligentDslFactory.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :extension_name, :string do
      description "Name of the generated DSL extension"
      allow_nil? false
      constraints [min_length: 1, max_length: 100]
    end
    
    attribute :extension_code, :string do
      description "Complete Spark DSL extension implementation"
      allow_nil? false
      constraints [min_length: 100]
    end
    
    attribute :entities, {:array, :map} do
      description "Spark DSL entities with complete schemas"
      default []
    end
    
    attribute :sections, {:array, :map} do
      description "Hierarchical DSL sections"
      default []
    end
    
    attribute :transformers, {:array, :string} do
      description "Compile-time transformers for semantic processing"
      default []
    end
    
    attribute :verifiers, {:array, :string} do
      description "Semantic verifiers for constraint checking"
      default []
    end
    
    attribute :semantic_patterns, {:array, :uuid} do
      description "IDs of semantic patterns used in this extension"
      default []
    end
    
    attribute :generation_metadata, :map do
      description "Metadata about the generation process"
      default %{}
    end
    
    attribute :domain_fidelity_score, :decimal do
      description "How well this extension captures the target domain (0-1)"
      constraints [min: 0, max: 1]
      default 0.0
    end
    
    attribute :semantic_correctness_score, :decimal do
      description "Semantic correctness based on formal validation (0-1)"
      constraints [min: 0, max: 1]
      default 0.0
    end
    
    attribute :usability_score, :decimal do
      description "Predicted usability based on cognitive load analysis (0-1)"
      constraints [min: 0, max: 1]
      default 0.0
    end
    
    attribute :performance_characteristics, :map do
      description "Measured and predicted performance characteristics"
      default %{}
    end
    
    attribute :compilation_success, :boolean do
      description "Whether the generated extension compiles successfully"
      default false
    end
    
    attribute :test_results, :map do
      description "Results of automated testing"
      default %{}
    end
    
    attribute :learning_generation, :integer do
      description "Generation number in learning evolution"
      constraints [min: 0]
      default 0
    end
    
    attribute :parent_extension_id, :uuid do
      description "ID of parent extension if this is an evolved version"
    end
    
    attribute :improvement_rationale, :string do
      description "Explanation of improvements made in this generation"
      constraints [max_length: 2000]
    end
    
    attribute :usage_analytics, :map do
      description "Analytics from real-world usage"
      default %{}
    end
    
    attribute :success_metric, :decimal do
      description "Overall success metric (0-1)"
      constraints [min: 0, max: 1]
      default 0.0
    end
    
    timestamps()
  end

  relationships do
    has_many :usage_metrics, IntelligentDslFactory.UsageMetrics do
      description "Usage metrics for this extension"
    end
    
    belongs_to :parent_extension, __MODULE__ do
      description "Parent extension in evolution chain"
    end
    
    has_many :child_extensions, __MODULE__, destination_attribute: :parent_extension_id do
      description "Evolved versions of this extension"
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :generate_from_patterns do
      description "Generate extension from semantic patterns"
      accept [:extension_name, :entities, :sections, :transformers, :verifiers, :semantic_patterns]
      
      change IntelligentDslFactory.Changes.GenerateExtensionCode
      change IntelligentDslFactory.Changes.ValidateSemanticCorrectness
      change IntelligentDslFactory.Changes.CalculateDomainFidelity
      change IntelligentDslFactory.Changes.PredictUsability
      change IntelligentDslFactory.Changes.AnalyzePerformanceCharacteristics
      
      after_action IntelligentDslFactory.AfterActions.CompileAndTest
      after_action IntelligentDslFactory.AfterActions.CalculateSuccessMetric
    end
    
    update :evolve_from_feedback do
      description "Evolve extension based on usage feedback"
      accept [:usage_analytics, :improvement_rationale]
      
      argument :feedback_data, :map, allow_nil?: false
      
      change IntelligentDslFactory.Changes.AnalyzeFeedback
      change IntelligentDslFactory.Changes.IdentifyImprovementOpportunities
      change IntelligentDslFactory.Changes.ApplyEvolutionaryChanges
      change set_attribute(:learning_generation, expr(learning_generation + 1))
      
      after_action IntelligentDslFactory.AfterActions.CreateEvolvedVersion
    end
    
    update :record_usage_data do
      description "Record real-world usage data"
      accept [:usage_analytics]
      
      change IntelligentDslFactory.Changes.ProcessUsageData
      change IntelligentDslFactory.Changes.UpdatePerformanceMetrics
      
      after_action IntelligentDslFactory.AfterActions.TriggerLearning
    end
    
    read :by_domain_fidelity do
      argument :min_fidelity, :decimal, default: 0.8
      filter expr(domain_fidelity_score >= ^arg(:min_fidelity))
      prepare build(sort: [domain_fidelity_score: :desc])
    end
    
    read :high_performance do
      argument :min_success_metric, :decimal, default: 0.8
      filter expr(success_metric >= ^arg(:min_success_metric))
      prepare build(sort: [success_metric: :desc])
    end
    
    read :evolution_chain do
      argument :extension_id, :uuid, allow_nil?: false
      prepare IntelligentDslFactory.Preparations.BuildEvolutionChain
    end
    
    read :latest_generation do
      prepare build(sort: [learning_generation: :desc], limit: 1)
    end
    
    read :successful_extensions do
      filter expr(compilation_success == true and success_metric >= 0.7)
      prepare build(sort: [success_metric: :desc])
    end
  end

  validations do
    validate {IntelligentDslFactory.Validations.ValidSparkExtensionCode, attribute: :extension_code}
    validate {IntelligentDslFactory.Validations.ConsistentEntityDefinitions, []}
    validate {IntelligentDslFactory.Validations.ValidTransformerReferences, []}
  end

  calculations do
    calculate :overall_quality_score, :decimal do
      description "Comprehensive quality score combining all metrics"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          fidelity = Decimal.to_float(record.domain_fidelity_score)
          correctness = Decimal.to_float(record.semantic_correctness_score) 
          usability = Decimal.to_float(record.usability_score)
          success = Decimal.to_float(record.success_metric)
          
          # Weighted combination emphasizing real-world success
          quality = (fidelity * 0.25) + (correctness * 0.25) + (usability * 0.2) + (success * 0.3)
          Decimal.new(Float.to_string(quality))
        end)
      end
    end
    
    calculate :evolution_progress, :decimal do
      description "Progress made through evolutionary learning"
      calculation IntelligentDslFactory.Calculations.EvolutionProgress
    end
    
    calculate :cognitive_complexity, :decimal do
      description "Cognitive complexity for developers using this DSL"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          entity_count = length(record.entities)
          section_depth = calculate_section_depth(record.sections)
          concept_count = count_unique_concepts(record.entities)
          
          # Cognitive load formula based on HCI research
          complexity = (entity_count * 0.1) + (section_depth * 0.15) + (concept_count * 0.2)
          normalized = min(1.0, complexity / 10.0)
          
          Decimal.new(Float.to_string(normalized))
        end)
      end
    end
    
    calculate :abstraction_power, :decimal do
      description "How much abstraction this DSL provides over manual implementation"
      calculation IntelligentDslFactory.Calculations.AbstractionPower
    end
  end

  aggregates do
    count :total_usage_sessions, :usage_metrics
    avg :average_user_satisfaction, :usage_metrics, :satisfaction_score
    max :peak_performance_metric, :usage_metrics, :performance_score
  end

  # Helper functions for complex calculations
  defp calculate_section_depth(sections) do
    sections
    |> Enum.map(&get_section_depth(&1, 0))
    |> Enum.max(fn -> 0 end)
  end

  defp get_section_depth(section, current_depth) do
    subsections = Map.get(section, "subsections", [])
    if length(subsections) == 0 do
      current_depth + 1
    else
      subsections
      |> Enum.map(&get_section_depth(&1, current_depth + 1))
      |> Enum.max()
    end
  end

  defp count_unique_concepts(entities) do
    entities
    |> Enum.flat_map(&extract_concepts_from_entity/1)
    |> Enum.uniq()
    |> length()
  end

  defp extract_concepts_from_entity(entity) do
    # Extract semantic concepts from entity definition
    schema = Map.get(entity, "schema", [])
    args = Map.get(entity, "args", [])
    
    [entity["name"] | schema ++ args]
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.to_atom/1)
  end

  def description do
    """
    GeneratedExtension represents a complete Spark DSL extension with
    semantic modeling, performance characteristics, and evolution tracking.
    """
  end
end