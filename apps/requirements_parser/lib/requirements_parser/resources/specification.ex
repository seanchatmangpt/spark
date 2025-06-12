defmodule RequirementsParser.Resources.Specification do
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "specifications"
    repo RequirementsParser.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :original_text, :string, allow_nil?: false
    attribute :domain, :atom, constraints: [one_of: [:web, :api, :mobile, :data, :ai, :embedded]]
    attribute :features, {:array, :atom}, default: []
    attribute :entities, {:array, :map}, default: []
    attribute :constraints, {:array, :atom}, default: []
    attribute :complexity, :atom, constraints: [one_of: [:simple, :moderate, :complex, :expert]]
    attribute :confidence_score, :decimal, constraints: [min: 0.0, max: 1.0]
    attribute :language, :atom, default: :english
    attribute :metadata, :map, default: %{}
    timestamps()
  end

  relationships do
    has_many :parsed_entities, RequirementsParser.Resources.ParsedEntity
    has_many :feature_extractions, RequirementsParser.Resources.FeatureExtraction
    has_many :nlp_analyses, RequirementsParser.Resources.NlpAnalysis
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :parse_natural_language do
      accept [:original_text, :language]
      
      change RequirementsParser.Changes.TokenizeText
      change RequirementsParser.Changes.ExtractIntent
      change RequirementsParser.Changes.IdentifyFeatures
      change RequirementsParser.Changes.InferEntities
      change RequirementsParser.Changes.CalculateComplexity
      change RequirementsParser.Changes.CalculateConfidence
      
      after_action RequirementsParser.AfterActions.CreateRelatedEntities
    end
    
    update :refine_specification do
      accept [:features, :entities, :constraints, :domain]
      
      change RequirementsParser.Changes.ValidateRefinements
      change RequirementsParser.Changes.RecalculateComplexity
      change RequirementsParser.Changes.UpdateConfidence
    end
    
    update :enhance_with_context do
      accept [:metadata]
      argument :context_data, :map
      
      change RequirementsParser.Changes.EnhanceWithContext
    end
  end

  validations do
    validate {RequirementsParser.Validations.MinimumTextLength, minimum: 10}
    validate {RequirementsParser.Validations.ValidDomain, []}
  end

  calculations do
    calculate :readiness_score, :decimal do
      calculation RequirementsParser.Calculations.ReadinessScore
    end
    
    calculate :extraction_completeness, :decimal do
      calculation RequirementsParser.Calculations.ExtractionCompleteness
    end
    
    calculate :ambiguity_level, :atom do
      calculation RequirementsParser.Calculations.AmbiguityLevel
    end
  end
end