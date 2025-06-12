defmodule RequirementsParser.Resources.ParsedEntity do
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "parsed_entities"
    repo RequirementsParser.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :entity_type, :atom, constraints: [one_of: [:model, :action, :field, :relationship, :validation, :constraint]]
    attribute :name, :string, allow_nil?: false
    attribute :description, :string
    attribute :properties, :map, default: %{}
    attribute :dependencies, {:array, :string}, default: []
    attribute :confidence, :decimal, constraints: [min: 0.0, max: 1.0]
    attribute :source_span, :map
    timestamps()
  end

  relationships do
    belongs_to :specification, RequirementsParser.Resources.Specification
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :extract_from_text do
      accept [:entity_type, :name, :description, :properties]
      argument :specification_id, :uuid, allow_nil?: false
      argument :text_span, :map
      
      change manage_relationship(:specification_id, :specification, type: :replace)
      change RequirementsParser.Changes.SetSourceSpan
      change RequirementsParser.Changes.CalculateEntityConfidence
    end
  end
end