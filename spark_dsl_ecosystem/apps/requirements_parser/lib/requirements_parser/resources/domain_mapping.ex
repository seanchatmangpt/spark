defmodule RequirementsParser.Resources.DomainMapping do
  @moduledoc """
  DomainMapping resource representing mapping to known domain patterns.
  
  A DomainMapping captures how requirements map to known domain patterns
  and existing DSL templates, enabling better generation strategy selection.
  """
  
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "domain_mappings"
    repo RequirementsParser.Repo
    
    references do
      reference :specification, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :domain_name, :atom do
      description "Name of the identified domain"
      allow_nil? false
      constraints [one_of: [:api, :validation, :workflow, :ui, :data, :auth, :general, :ecommerce, :cms, :analytics]]
    end
    
    attribute :subdomain, :string do
      description "More specific subdomain identification"
      constraints [max_length: 100]
    end
    
    attribute :mapping_confidence, :decimal do
      description "Confidence in domain mapping (0-1)"
      constraints [min: 0, max: 1]
    end
    
    attribute :domain_patterns, {:array, :string} do
      description "Specific patterns that match this domain"
      default []
    end
    
    attribute :template_recommendations, {:array, :map} do
      description "Recommended templates for this domain"
      default []
    end
    
    attribute :existing_dsl_matches, {:array, :map} do
      description "Existing DSLs that match requirements"
      default []
    end
    
    attribute :domain_constraints, {:array, :string} do
      description "Domain-specific constraints"
      default []
    end
    
    attribute :common_entities, {:array, :string} do
      description "Common entities in this domain"
      default []
    end
    
    attribute :typical_workflows, {:array, :map} do
      description "Typical workflows in this domain"
      default []
    end
    
    attribute :integration_points, {:array, :string} do
      description "Common integration points"
      default []
    end
    
    attribute :domain_expertise_level, :atom do
      description "Required expertise level for this domain"
      constraints [one_of: [:beginner, :intermediate, :advanced, :expert]]
      default :intermediate
    end
    
    attribute :mapping_evidence, :map do
      description "Evidence supporting this domain mapping"
      default %{}
    end
    
    attribute :alternative_domains, {:array, :atom} do
      description "Alternative domain interpretations"
      default []
    end
    
    timestamps()
  end

  relationships do
    belongs_to :specification, RequirementsParser.Resources.Specification do
      description "The specification this mapping belongs to"
      attribute_writable? true
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :map_to_domain do
      description "Map requirements to a domain"
      accept [:domain_name, :subdomain, :specification_id]
      
      change RequirementsParser.Changes.AnalyzeDomainPatterns
      change RequirementsParser.Changes.FindTemplateMatches
      change RequirementsParser.Changes.IdentifyCommonEntities
      change RequirementsParser.Changes.CalculateMappingConfidence
      change RequirementsParser.Changes.SuggestIntegrations
    end
    
    read :by_specification do
      description "Read mappings by specification"
      
      argument :specification_id, :uuid do
        description "Specification ID to filter by"
        allow_nil? false
      end
      
      filter expr(specification_id == ^arg(:specification_id))
      prepare build(sort: [mapping_confidence: :desc])
    end
    
    read :by_domain do
      description "Read mappings by domain"
      
      argument :domain_name, :atom do
        description "Domain to filter by"
        allow_nil? false
      end
      
      filter expr(domain_name == ^arg(:domain_name))
    end
    
    read :high_confidence do
      description "Read mappings with high confidence"
      
      argument :minimum_confidence, :decimal do
        description "Minimum confidence threshold"
        default 0.8
      end
      
      filter expr(mapping_confidence >= ^arg(:minimum_confidence))
    end
    
    read :with_templates do
      description "Read mappings that have template recommendations"
      
      filter expr(fragment("jsonb_array_length(?) > 0", template_recommendations))
    end
  end
  
  validations do
    validate {RequirementsParser.Validations.DomainMappingValid, []}
    validate {RequirementsParser.Validations.TemplateRecommendationsConsistent, []}
  end
  
  calculations do
    calculate :template_count, :integer do
      description "Number of template recommendations"
      calculation RequirementsParser.Calculations.TemplateCount
    end
    
    calculate :integration_complexity, :decimal do
      description "Complexity score for integrations"
      calculation RequirementsParser.Calculations.IntegrationComplexity
    end
    
    calculate :domain_fit_score, :decimal do
      description "How well requirements fit this domain"
      calculation RequirementsParser.Calculations.DomainFitScore
    end
  end

  def description do
    """
    DomainMapping represents the mapping of requirements to known
    domain patterns, enabling template selection and strategy optimization.
    """
  end
end