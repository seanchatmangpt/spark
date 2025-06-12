defmodule RequirementsParser.Resources.Specification do
  @moduledoc """
  Specification resource representing parsed requirements.
  
  A Specification captures the transformation from natural language
  or code examples into structured, analyzable format for DSL generation.
  """
  
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "specifications"
    repo RequirementsParser.Repo
    
    references do
      reference :parsed_entities, on_delete: :delete
      reference :feature_extractions, on_delete: :delete
      reference :domain_mappings, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :original_text, :string do
      description "The original natural language or code input"
      allow_nil? false
      constraints [min_length: 5, max_length: 50000]
    end
    
    attribute :input_type, :atom do
      description "Type of input provided"
      constraints [one_of: [:natural_language, :code_example, :specification_file, :mixed]]
      default :natural_language
    end
    
    attribute :language, :atom do
      description "Programming language (for code examples)"
      constraints [one_of: [:elixir, :erlang, :python, :javascript, :other]]
    end
    
    attribute :domain, :atom do
      description "Identified domain of the requirements"
      constraints [one_of: [:api, :validation, :workflow, :ui, :data, :auth, :general]]
    end
    
    attribute :features, {:array, :atom} do
      description "List of identified features"
      default []
    end
    
    attribute :entities, {:array, :map} do
      description "Parsed entities with their properties"
      default []
    end
    
    attribute :constraints, {:array, :atom} do
      description "Identified constraints and requirements"
      default []
    end
    
    attribute :complexity, :atom do
      description "Assessed complexity level"
      constraints [one_of: [:simple, :standard, :advanced, :enterprise]]
    end
    
    attribute :confidence_score, :decimal do
      description "Confidence in the parsing accuracy (0-1)"
      constraints [min: 0, max: 1]
    end
    
    attribute :parsing_metadata, :map do
      description "Metadata about the parsing process"
      default %{}
    end
    
    attribute :processing_time_ms, :integer do
      description "Time taken to process this specification"
      constraints [min: 0]
    end
    
    attribute :alternative_interpretations, {:array, :map} do
      description "Alternative ways to interpret the requirements"
      default []
    end
    
    attribute :validation_results, :map do
      description "Results of specification validation"
      default %{}
    end
    
    attribute :parsing_options, :map do
      description "Options used during parsing"
      default %{}
    end
    
    timestamps()
  end

  relationships do
    has_many :parsed_entities, RequirementsParser.Resources.ParsedEntity do
      description "Entities extracted from this specification"
    end
    
    has_many :feature_extractions, RequirementsParser.Resources.FeatureExtraction do
      description "Features identified in this specification"
    end
    
    has_many :domain_mappings, RequirementsParser.Resources.DomainMapping do
      description "Domain mappings for this specification"
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :parse_natural_language do
      description "Parse natural language requirements"
      accept [:original_text, :parsing_options]
      
      change RequirementsParser.Changes.TokenizeText
      change RequirementsParser.Changes.ExtractIntent
      change RequirementsParser.Changes.IdentifyFeatures
      change RequirementsParser.Changes.InferEntities
      change RequirementsParser.Changes.DetermineDomain
      change RequirementsParser.Changes.AssessComplexity
      change RequirementsParser.Changes.CalculateConfidence
      change set_attribute(:input_type, :natural_language)
      
      after_action RequirementsParser.AfterActions.CreateRelatedRecords
      after_action RequirementsParser.AfterActions.ValidateSpecification
    end
    
    create :parse_code_example do
      description "Parse code example to extract DSL patterns"
      accept [:original_text, :language, :parsing_options]
      
      change RequirementsParser.Changes.ParseAST
      change RequirementsParser.Changes.ExtractPatterns
      change RequirementsParser.Changes.IdentifyStructures
      change RequirementsParser.Changes.InferDSLConcepts
      change RequirementsParser.Changes.AssessCodeComplexity
      change set_attribute(:input_type, :code_example)
      
      after_action RequirementsParser.AfterActions.CreateCodeEntities
    end
    
    update :refine_with_context do
      description "Refine specification with additional context"
      accept [:features, :entities, :constraints, :domain]
      
      argument :refinements, :map do
        description "Additional context and refinements"
        allow_nil? false
      end
      
      change RequirementsParser.Changes.ApplyRefinements
      change RequirementsParser.Changes.RecalculateConfidence
      change RequirementsParser.Changes.UpdateComplexity
      
      after_action RequirementsParser.AfterActions.UpdateRelatedRecords
    end
    
    update :add_alternative_interpretation do
      description "Add an alternative interpretation of the requirements"
      accept []
      
      argument :interpretation, :map do
        description "Alternative interpretation data"
        allow_nil? false
      end
      
      change RequirementsParser.Changes.AddAlternativeInterpretation
    end
    
    read :by_domain do
      description "Read specifications by domain"
      
      argument :domain, :atom do
        description "Domain to filter by"
        allow_nil? false
        constraints [one_of: [:api, :validation, :workflow, :ui, :data, :auth, :general]]
      end
      
      filter expr(domain == ^arg(:domain))
      prepare build(sort: [inserted_at: :desc])
    end
    
    read :by_complexity do
      description "Read specifications by complexity level"
      
      argument :complexity, :atom do
        description "Complexity level to filter by"
        allow_nil? false
        constraints [one_of: [:simple, :standard, :advanced, :enterprise]]
      end
      
      filter expr(complexity == ^arg(:complexity))
    end
    
    read :high_confidence do
      description "Read specifications with high confidence scores"
      
      argument :minimum_confidence, :decimal do
        description "Minimum confidence threshold"
        default 0.8
      end
      
      filter expr(confidence_score >= ^arg(:minimum_confidence))
    end
    
    read :recent do
      description "Read recently created specifications"
      
      argument :timeframe, :string do
        description "Timeframe to look back (e.g., '7d', '30d')"
        default "7d"
      end
      
      prepare RequirementsParser.Preparations.FilterByTimeframe
      prepare build(sort: [inserted_at: :desc])
    end
    
    read :with_features do
      description "Read specifications containing specific features"
      
      argument :required_features, {:array, :atom} do
        description "Features that must be present"
        allow_nil? false
      end
      
      filter RequirementsParser.Predicates.HasAllFeatures
    end
    
    read :similar_to do
      description "Find specifications similar to a given one"
      
      argument :reference_specification_id, :uuid do
        description "ID of the reference specification"
        allow_nil? false
      end
      
      argument :similarity_threshold, :decimal do
        description "Minimum similarity score"
        default 0.7
      end
      
      prepare RequirementsParser.Preparations.CalculateSimilarity
    end
  end
  
  validations do
    validate {RequirementsParser.Validations.TextQuality, minimum_words: 3}
    validate {RequirementsParser.Validations.LanguageConsistency, []}
    validate {RequirementsParser.Validations.FeatureCoherence, []}
  end
  
  calculations do
    calculate :readiness_score, :decimal do
      description "Overall readiness for DSL generation"
      calculation RequirementsParser.Calculations.ReadinessScore
    end
    
    calculate :feature_count, :integer do
      description "Number of identified features"
      calculation RequirementsParser.Calculations.FeatureCount
    end
    
    calculate :entity_count, :integer do
      description "Number of parsed entities"
      calculation RequirementsParser.Calculations.EntityCount
    end
    
    calculate :processing_efficiency, :decimal do
      description "Efficiency of the parsing process"
      calculation RequirementsParser.Calculations.ProcessingEfficiency
    end
    
    calculate :completeness_score, :decimal do
      description "How complete the specification is"
      calculation RequirementsParser.Calculations.CompletenessScore
    end
  end

  aggregates do
    count :total_entities, :parsed_entities do
      description "Total number of parsed entities"
    end
    
    count :total_features, :feature_extractions do
      description "Total number of feature extractions"
    end
    
    avg :average_feature_confidence, :feature_extractions, :confidence_score do
      description "Average confidence of feature extractions"
    end
  end

  def description do
    """
    Specification represents the parsed and structured version of
    natural language requirements or code examples, ready for
    DSL generation processing.
    """
  end
end