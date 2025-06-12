defmodule SimpleDslFactory.QualityMeasurement do
  @moduledoc """
  Real, measurable quality metrics for generated code.
  
  These are not mock scores - they're actual measurements:
  - Lines of code (counted)
  - Compilation time (measured)
  - Compilation success (tested)
  - Cyclomatic complexity (calculated)
  - Convention adherence (checked)
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: SimpleDslFactory

  postgres do
    table "quality_measurements"
    repo SimpleDslFactory.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :lines_of_code, :integer do
      description "Actual line count of generated code"
      allow_nil? false
      constraints [min: 1]
    end
    
    attribute :cyclomatic_complexity, :integer do
      description "Measured cyclomatic complexity"
      allow_nil? false
      constraints [min: 1]
    end
    
    attribute :compilation_time_ms, :integer do
      description "Actual time to compile the code in milliseconds"
      allow_nil? false
      constraints [min: 0]
    end
    
    attribute :compiles_successfully, :boolean do
      description "Whether the generated code actually compiles"
      allow_nil? false
    end
    
    attribute :follows_conventions, :boolean do
      description "Whether code follows Elixir conventions"
      allow_nil? false
    end
    
    attribute :overall_score, :decimal do
      description "Calculated overall quality score (0-100)"
      allow_nil? false
      constraints [min: 0, max: 100]
    end
    
    timestamps()
  end

  relationships do
    belongs_to :generated_resource, SimpleDslFactory.GeneratedResource do
      description "The generated resource this measurement applies to"
      allow_nil? false
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    read :by_resource do
      argument :generated_resource_id, :uuid, allow_nil?: false
      filter expr(generated_resource_id == ^arg(:generated_resource_id))
      prepare build(sort: [inserted_at: :desc])
    end
    
    read :high_quality do
      argument :min_score, :decimal, default: 80.0
      filter expr(overall_score >= ^arg(:min_score))
      prepare build(sort: [overall_score: :desc])
    end
    
    read :compilation_failures do
      filter expr(compiles_successfully == false)
      prepare build(sort: [inserted_at: :desc])
    end
    
    read :performance_analysis do
      prepare build(sort: [compilation_time_ms: :asc])
    end
  end

  validations do
    validate numericality(:overall_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    validate numericality(:cyclomatic_complexity, greater_than: 0)
  end

  calculations do
    calculate :quality_grade, :string do
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          score = Decimal.to_float(record.overall_score)
          cond do
            score >= 90 -> "A"
            score >= 80 -> "B"
            score >= 70 -> "C"
            score >= 60 -> "D"
            true -> "F"
          end
        end)
      end
    end
    
    calculate :efficiency_ratio, :decimal do
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          # Quality per millisecond of compilation time
          if record.compilation_time_ms > 0 do
            Decimal.div(record.overall_score, Decimal.new(record.compilation_time_ms))
          else
            Decimal.new("0.0")
          end
        end)
      end
    end
  end

  aggregates do
    # These aggregates provide real insights into our generation quality
  end

  def description do
    """
    QualityMeasurement stores real, measurable metrics about generated code.
    Every measurement is based on actual code analysis, not estimates or mocks.
    """
  end
end