defmodule RequirementsParser.Resources.FeatureExtraction do
  @moduledoc """
  FeatureExtraction resource representing identified features and capabilities.
  
  A FeatureExtraction captures a specific feature or capability that was
  identified in the requirements, along with metadata about its extraction.
  """
  
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "feature_extractions"
    repo RequirementsParser.Repo
    
    references do
      reference :specification, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :feature_name, :string do
      description "Name of the extracted feature"
      allow_nil? false
      constraints [min_length: 1, max_length: 100]
    end
    
    attribute :feature_type, :atom do
      description "Type/category of the feature"
      constraints [one_of: [:authentication, :validation, :api, :ui, :data, :workflow, :integration, :security, :performance, :custom]]
    end
    
    attribute :description, :string do
      description "Detailed description of the feature"
      constraints [max_length: 1000]
    end
    
    attribute :requirements, {:array, :string} do
      description "Specific requirements for this feature"
      default []
    end
    
    attribute :dependencies, {:array, :string} do
      description "Other features this depends on"
      default []
    end
    
    attribute :priority, :atom do
      description "Priority level of this feature"
      constraints [one_of: [:low, :medium, :high, :critical]]
      default :medium
    end
    
    attribute :complexity, :atom do
      description "Implementation complexity estimate"
      constraints [one_of: [:trivial, :simple, :moderate, :complex, :very_complex]]
      default :moderate
    end
    
    attribute :confidence_score, :decimal do
      description "Confidence in feature identification (0-1)"
      constraints [min: 0, max: 1]
    end
    
    attribute :extraction_method, :atom do
      description "Method used to extract this feature"
      constraints [one_of: [:keyword_matching, :semantic_analysis, :pattern_recognition, :context_inference, :manual]]
    end
    
    attribute :source_indicators, {:array, :string} do
      description "Text/patterns that indicated this feature"
      default []
    end
    
    attribute :implementation_hints, :map do
      description "Hints for implementing this feature"
      default %{}
    end
    
    attribute :validation_criteria, {:array, :string} do
      description "Criteria to validate feature implementation"
      default []
    end
    
    attribute :alternative_interpretations, {:array, :map} do
      description "Alternative ways to interpret this feature"
      default []
    end
    
    timestamps()
  end

  relationships do
    belongs_to :specification, RequirementsParser.Resources.Specification do
      description "The specification this feature belongs to"
      attribute_writable? true
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :extract_feature do
      description "Extract a feature from requirements"
      accept [:feature_name, :feature_type, :description, :specification_id]
      
      change RequirementsParser.Changes.AnalyzeFeatureDependencies
      change RequirementsParser.Changes.EstimateComplexity
      change RequirementsParser.Changes.CalculateFeatureConfidence
      change RequirementsParser.Changes.GenerateImplementationHints
    end
    
    read :by_specification do
      description "Read features by specification"
      
      argument :specification_id, :uuid do
        description "Specification ID to filter by"
        allow_nil? false
      end
      
      filter expr(specification_id == ^arg(:specification_id))
      prepare build(sort: [priority: :desc, confidence_score: :desc])
    end
    
    read :by_feature_type do
      description "Read features by type"
      
      argument :feature_type, :atom do
        description "Feature type to filter by"
        allow_nil? false
      end
      
      filter expr(feature_type == ^arg(:feature_type))
    end
    
    read :by_priority do
      description "Read features by priority"
      
      argument :priority, :atom do
        description "Priority level to filter by"
        allow_nil? false
      end
      
      filter expr(priority == ^arg(:priority))
    end
    
    read :high_confidence do
      description "Read features with high confidence scores"
      
      argument :minimum_confidence, :decimal do
        description "Minimum confidence threshold"
        default 0.8
      end
      
      filter expr(confidence_score >= ^arg(:minimum_confidence))
    end
    
    read :complex_features do
      description "Read features with high complexity"
      
      filter expr(complexity in [:complex, :very_complex])
      prepare build(sort: [priority: :desc])
    end
  end
  
  validations do
    validate {RequirementsParser.Validations.FeatureNameUnique, within_specification: true}
    validate {RequirementsParser.Validations.DependenciesValid, []}
  end
  
  calculations do
    calculate :implementation_effort, :decimal do
      description "Estimated implementation effort (0-10 scale)"
      calculation RequirementsParser.Calculations.ImplementationEffort
    end
    
    calculate :dependency_count, :integer do
      description "Number of dependencies this feature has"
      calculation RequirementsParser.Calculations.DependencyCount
    end
    
    calculate :risk_score, :decimal do
      description "Risk score based on complexity and dependencies"
      calculation RequirementsParser.Calculations.FeatureRisk
    end
  end

  def description do
    """
    FeatureExtraction represents a specific feature or capability
    identified in requirements, with metadata for implementation planning.
    """
  end
end