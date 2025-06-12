defmodule SimpleDslFactory.GeneratedResource do
  @moduledoc """
  A generated Ash resource with actual Elixir code.
  
  This stores the output of our DSL generation process.
  The code is real, compilable Elixir that defines an Ash resource.
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SimpleDslFactory

  postgres do
    table "generated_resources"
    repo SimpleDslFactory.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :code, :string do
      description "Generated Elixir code for the resource"
      allow_nil? false
      constraints [min_length: 50]  # Ensure we have substantial code
    end
    
    attribute :generated_at, :utc_datetime_usec do
      description "When this resource was generated"
      allow_nil? false
      default &DateTime.utc_now/0
    end
    
    timestamps()
  end

  relationships do
    belongs_to :dsl_spec, SimpleDslFactory.DslSpec do
      description "The specification used to generate this resource"
      allow_nil? false
    end
    
    has_many :quality_measurements, SimpleDslFactory.QualityMeasurement do
      description "Quality measurements for this generated resource"
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    read :by_spec do
      argument :dsl_spec_id, :uuid, allow_nil?: false
      filter expr(dsl_spec_id == ^arg(:dsl_spec_id))
      prepare build(sort: [generated_at: :desc])
    end
    
    read :recent do
      prepare build(sort: [generated_at: :desc], limit: 50)
    end
    
    read :with_quality do
      prepare build(load: [:quality_measurements, :dsl_spec])
    end
  end

  validations do
    validate {SimpleDslFactory.Validations.ValidElixirCode, attribute: :code}
  end

  calculations do
    calculate :lines_of_code, :integer do
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          record.code
          |> String.split("\n")
          |> Enum.reject(&(&1 |> String.trim() == ""))
          |> length()
        end)
      end
    end
    
    calculate :latest_quality_score, :decimal do
      calculation fn records, _context ->
        # This would be more sophisticated in practice
        Enum.map(records, fn _record ->
          Decimal.new("0.0")  # Placeholder - would load from quality_measurements
        end)
      end
    end
  end

  def description do
    """
    GeneratedResource contains actual Elixir code generated from a DslSpec.
    This is the concrete output of our generation process.
    """
  end
end