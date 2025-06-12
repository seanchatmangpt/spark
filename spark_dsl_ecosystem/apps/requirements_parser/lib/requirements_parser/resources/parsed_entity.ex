defmodule RequirementsParser.Resources.ParsedEntity do
  @moduledoc """
  ParsedEntity resource representing individual entities extracted from requirements.
  
  A ParsedEntity represents a single conceptual entity (like a User, Product, etc.)
  that was identified in the requirements parsing process.
  """
  
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "parsed_entities"
    repo RequirementsParser.Repo
    
    references do
      reference :specification, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :name, :string do
      description "Name of the parsed entity"
      allow_nil? false
      constraints [min_length: 1, max_length: 100]
    end
    
    attribute :entity_type, :atom do
      description "Type of entity (model, service, controller, etc.)"
      constraints [one_of: [:model, :service, :controller, :repository, :validator, :transformer, :custom]]
      default :model
    end
    
    attribute :properties, {:array, :map} do
      description "Properties/attributes of this entity"
      default []
    end
    
    attribute :relationships, {:array, :map} do
      description "Relationships to other entities"
      default []
    end
    
    attribute :actions, {:array, :map} do
      description "Actions/methods this entity supports"
      default []
    end
    
    attribute :constraints, {:array, :map} do
      description "Validation constraints for this entity"
      default []
    end
    
    attribute :context_data, :map do
      description "Additional context about this entity"
      default %{}
    end
    
    attribute :confidence_score, :decimal do
      description "Confidence in this entity identification (0-1)"
      constraints [min: 0, max: 1]
    end
    
    attribute :source_location, :map do
      description "Location in source where this entity was identified"
      default %{}
    end
    
    attribute :semantic_role, :atom do
      description "Semantic role in the domain"
      constraints [one_of: [:primary, :secondary, :supporting, :utility]]
      default :primary
    end
    
    timestamps()
  end

  relationships do
    belongs_to :specification, RequirementsParser.Resources.Specification do
      description "The specification this entity belongs to"
      attribute_writable? true
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :extract_from_text do
      description "Extract entity from parsed text"
      accept [:name, :entity_type, :properties, :specification_id]
      
      change RequirementsParser.Changes.InferRelationships
      change RequirementsParser.Changes.ExtractActions
      change RequirementsParser.Changes.IdentifyConstraints
      change RequirementsParser.Changes.CalculateEntityConfidence
    end
    
    read :by_specification do
      description "Read entities by specification"
      
      argument :specification_id, :uuid do
        description "Specification ID to filter by"
        allow_nil? false
      end
      
      filter expr(specification_id == ^arg(:specification_id))
      prepare build(sort: [semantic_role: :asc, name: :asc])
    end
    
    read :by_entity_type do
      description "Read entities by type"
      
      argument :entity_type, :atom do
        description "Entity type to filter by"
        allow_nil? false
      end
      
      filter expr(entity_type == ^arg(:entity_type))
    end
    
    read :high_confidence do
      description "Read entities with high confidence scores"
      
      argument :minimum_confidence, :decimal do
        description "Minimum confidence threshold"
        default 0.8
      end
      
      filter expr(confidence_score >= ^arg(:minimum_confidence))
    end
  end
  
  validations do
    validate {RequirementsParser.Validations.EntityNameValid, []}
    validate {RequirementsParser.Validations.PropertiesConsistent, []}
  end
  
  calculations do
    calculate :property_count, :integer do
      description "Number of properties this entity has"
      calculation RequirementsParser.Calculations.PropertyCount
    end
    
    calculate :relationship_count, :integer do
      description "Number of relationships this entity has"
      calculation RequirementsParser.Calculations.RelationshipCount
    end
    
    calculate :complexity_score, :decimal do
      description "Complexity score based on properties and relationships"
      calculation RequirementsParser.Calculations.EntityComplexity
    end
  end

  def description do
    """
    ParsedEntity represents an individual conceptual entity extracted
    from requirements, with its properties, relationships, and actions.
    """
  end
end