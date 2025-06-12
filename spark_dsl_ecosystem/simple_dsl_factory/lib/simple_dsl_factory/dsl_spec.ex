defmodule SimpleDslFactory.DslSpec do
  @moduledoc """
  A specification for generating DSL resources.
  
  This is a simple, concrete resource that stores what we need
  to generate Ash resources. No phantom dependencies, no mock functions.
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SimpleDslFactory

  postgres do
    table "dsl_specs"
    repo SimpleDslFactory.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :name, :string do
      description "Name of the resource to generate (e.g., 'BlogPost')"
      allow_nil? false
      constraints [min_length: 1, max_length: 100]
    end
    
    attribute :attributes, :string do
      description "JSON-encoded list of attributes"
      allow_nil? false
    end
    
    attribute :actions, {:array, :atom} do
      description "List of actions to include"
      default [:create, :read, :update, :destroy]
    end
    
    attribute :raw_spec, :string do
      description "Original specification as JSON"
      allow_nil? false
    end
    
    timestamps()
  end

  relationships do
    has_many :generated_resources, SimpleDslFactory.GeneratedResource do
      description "Resources generated from this spec"
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    read :by_name do
      argument :name, :string, allow_nil?: false
      filter expr(name == ^arg(:name))
    end
    
    read :recent do
      prepare build(sort: [inserted_at: :desc], limit: 20)
    end
  end

  validations do
    validate match(:name, ~r/^[A-Z][a-zA-Z0-9]*$/) do
      message "must be a valid module name (PascalCase)"
    end
    
    validate {SimpleDslFactory.Validations.ValidAttributesJson, attribute: :attributes}
  end

  calculations do
    calculate :attribute_count, :integer do
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          case Jason.decode(record.attributes) do
            {:ok, attrs} when is_list(attrs) -> length(attrs)
            _ -> 0
          end
        end)
      end
    end
  end

  def description do
    """
    DslSpec stores specifications for generating Ash resources.
    Each spec contains the metadata needed to generate working Elixir code.
    """
  end
end