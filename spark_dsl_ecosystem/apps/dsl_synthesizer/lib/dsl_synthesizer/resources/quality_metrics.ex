defmodule DslSynthesizer.Resources.QualityMetrics do
  @moduledoc """
  QualityMetrics resource representing detailed quality analysis.
  
  QualityMetrics provides comprehensive evaluation of generated code
  across multiple dimensions including performance, maintainability, and usability.
  """
  
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "quality_metrics"
    repo DslSynthesizer.Repo
    
    references do
      reference :code_candidate, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :metric_type, :atom do
      description "Type of quality metric"
      allow_nil? false
      constraints [one_of: [:performance, :maintainability, :usability, :security, :reliability, :portability]]
    end
    
    attribute :metric_name, :string do
      description "Specific name of the metric"
      allow_nil? false
      constraints [min_length: 1, max_length: 100]
    end
    
    attribute :metric_value, :decimal do
      description "Numeric value of the metric"
      allow_nil? false
    end
    
    attribute :metric_unit, :string do
      description "Unit of measurement for the metric"
      constraints [max_length: 20]
    end
    
    attribute :score, :decimal do
      description "Normalized score (0-100)"
      constraints [min: 0, max: 100]
    end
    
    attribute :weight, :decimal do
      description "Weight of this metric in overall quality (0-1)"
      constraints [min: 0, max: 1]
      default 1.0
    end
    
    attribute :threshold_passed, :boolean do
      description "Whether this metric passes quality thresholds"
      default true
    end
    
    attribute :benchmark_comparison, :map do
      description "Comparison with industry benchmarks"
      default %{}
    end
    
    attribute :measurement_details, :map do
      description "Detailed measurement information"
      default %{}
    end
    
    attribute :improvement_suggestions, {:array, :string} do
      description "Suggestions for improving this metric"
      default []
    end
    
    attribute :trend_data, {:array, :map} do
      description "Historical trend data for this metric"
      default []
    end
    
    attribute :confidence_level, :decimal do
      description "Confidence in metric accuracy (0-1)"
      constraints [min: 0, max: 1]
      default 1.0
    end
    
    timestamps()
  end

  relationships do
    belongs_to :code_candidate, DslSynthesizer.Resources.CodeCandidate do
      description "The code candidate this metric belongs to"
      attribute_writable? true
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :measure_quality do
      description "Measure quality for a code candidate"
      accept [:metric_type, :metric_name, :metric_value, :code_candidate_id]
      
      change DslSynthesizer.Changes.NormalizeMetricValue
      change DslSynthesizer.Changes.CalculateScore
      change DslSynthesizer.Changes.CompareToBenchmarks
      change DslSynthesizer.Changes.GenerateImprovementSuggestions
    end
    
    read :by_candidate do
      description "Read metrics by code candidate"
      
      argument :candidate_id, :uuid do
        description "Code candidate ID to filter by"
        allow_nil? false
      end
      
      filter expr(code_candidate_id == ^arg(:candidate_id))
      prepare build(sort: [metric_type: :asc, metric_name: :asc])
    end
    
    read :by_metric_type do
      description "Read metrics by type"
      
      argument :metric_type, :atom do
        description "Metric type to filter by"
        allow_nil? false
      end
      
      filter expr(metric_type == ^arg(:metric_type))
    end
    
    read :failing_thresholds do
      description "Read metrics that fail quality thresholds"
      
      filter expr(threshold_passed == false)
      prepare build(sort: [score: :asc])
    end
    
    read :high_impact do
      description "Read metrics with high weight/impact"
      
      argument :minimum_weight, :decimal do
        description "Minimum weight threshold"
        default 0.7
      end
      
      filter expr(weight >= ^arg(:minimum_weight))
    end
  end
  
  validations do
    validate {DslSynthesizer.Validations.MetricValueValid, []}
    validate {DslSynthesizer.Validations.ScoreConsistent, []}
  end
  
  calculations do
    calculate :weighted_score, :decimal do
      description "Score weighted by importance"
      calculation DslSynthesizer.Calculations.WeightedScore
    end
    
    calculate :percentile_rank, :decimal do
      description "Percentile rank compared to similar metrics"
      calculation DslSynthesizer.Calculations.PercentileRank
    end
    
    calculate :improvement_potential, :decimal do
      description "Potential for improvement (0-100)"
      calculation DslSynthesizer.Calculations.MetricImprovementPotential
    end
  end

  def description do
    """
    QualityMetrics provides detailed quality analysis for generated
    code candidates across multiple evaluation dimensions.
    """
  end
end