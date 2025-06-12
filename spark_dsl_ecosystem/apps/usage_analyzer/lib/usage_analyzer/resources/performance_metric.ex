defmodule UsageAnalyzer.Resources.PerformanceMetric do
  @moduledoc """
  PerformanceMetric resource representing DSL performance measurements.
  
  A PerformanceMetric captures runtime and compile-time performance
  data for DSL usage analysis and optimization opportunities.
  """
  
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "performance_metrics"
    repo UsageAnalyzer.Repo
    
    references do
      reference :analysis_report, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :target_dsl, :string do
      description "DSL being measured"
      allow_nil? false
      constraints [min_length: 1, max_length: 200]
    end
    
    attribute :metric_type, :atom do
      description "Type of performance metric"
      constraints [one_of: [:telemetry_collection, :performance_analysis, :comprehensive_analysis, :compile_time, :runtime, :memory_usage, :throughput]]
    end
    
    attribute :metric_name, :string do
      description "Specific name of the metric"
      allow_nil? false
      constraints [min_length: 1, max_length: 100]
    end
    
    attribute :measurement_value, :decimal do
      description "Measured value"
      allow_nil? false
    end
    
    attribute :measurement_unit, :string do
      description "Unit of measurement"
      constraints [max_length: 20]
    end
    
    attribute :performance_score, :decimal do
      description "Normalized performance score (0-100)"
      constraints [min: 0, max: 100]
    end
    
    attribute :baseline_value, :decimal do
      description "Baseline value for comparison"
    end
    
    attribute :benchmark_percentile, :decimal do
      description "Percentile rank against benchmarks"
      constraints [min: 0, max: 100]
    end
    
    attribute :workload_type, :atom do
      description "Type of workload measured"
      constraints [one_of: [:standard, :light, :heavy, :stress, :custom]]
      default :standard
    end
    
    attribute :measurement_context, :map do
      description "Context of the measurement"
      default %{}
    end
    
    attribute :collection_duration_ms, :integer do
      description "Duration of metric collection"
      constraints [min: 0]
    end
    
    attribute :sample_size, :integer do
      description "Number of samples in measurement"
      constraints [min: 1]
      default 1
    end
    
    attribute :variance, :decimal do
      description "Variance in measurements"
      constraints [min: 0]
    end
    
    attribute :standard_deviation, :decimal do
      description "Standard deviation of measurements"
      constraints [min: 0]
    end
    
    attribute :status, :atom do
      description "Status of metric collection"
      constraints [one_of: [:collecting, :analyzing, :completed, :failed]]
      default :collecting
    end
    
    attribute :performance_issues, {:array, :string} do
      description "Identified performance issues"
      default []
    end
    
    attribute :optimization_opportunities, {:array, :string} do
      description "Potential optimization opportunities"
      default []
    end
    
    attribute :trend_data, {:array, :map} do
      description "Historical trend data"
      default []
    end
    
    attribute :environment_info, :map do
      description "Environment information during measurement"
      default %{}
    end
    
    attribute :confidence_interval, :map do
      description "Statistical confidence interval"
      default %{}
    end
    
    attribute :outliers_detected, :integer do
      description "Number of outliers detected"
      constraints [min: 0]
      default 0
    end
    
    timestamps()
  end

  relationships do
    belongs_to :analysis_report, UsageAnalyzer.Resources.AnalysisReport do
      description "The analysis report this metric belongs to"
      attribute_writable? true
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :collect_metric do
      description "Collect a new performance metric"
      accept [:target_dsl, :metric_type, :metric_name, :measurement_value, :measurement_unit]
      
      change UsageAnalyzer.Changes.NormalizeMetricValue
      change UsageAnalyzer.Changes.CalculatePerformanceScore
      change UsageAnalyzer.Changes.CompareToBenchmarks
      change UsageAnalyzer.Changes.AnalyzePerformanceIssues
      change UsageAnalyzer.Changes.IdentifyOptimizationOpportunities
    end
    
    update :complete_collection do
      description "Mark metric collection as completed"
      accept [:performance_score, :performance_issues, :optimization_opportunities]
      
      change set_attribute(:status, :completed)
      change UsageAnalyzer.Changes.FinalizeMetric
    end
    
    read :by_report do
      description "Read metrics by analysis report"
      
      argument :report_id, :uuid do
        description "Analysis report ID to filter by"
        allow_nil? false
      end
      
      filter expr(analysis_report_id == ^arg(:report_id))
      prepare build(sort: [metric_type: :asc, metric_name: :asc])
    end
    
    read :by_target_dsl do
      description "Read metrics by target DSL"
      
      argument :target_dsl, :string do
        description "Target DSL to filter by"
        allow_nil? false
      end
      
      filter expr(target_dsl == ^arg(:target_dsl))
    end
    
    read :by_metric_type do
      description "Read metrics by type"
      
      argument :metric_type, :atom do
        description "Metric type to filter by"
        allow_nil? false
      end
      
      filter expr(metric_type == ^arg(:metric_type))
    end
    
    read :poor_performance do
      description "Read metrics indicating poor performance"
      
      argument :threshold_score, :decimal do
        description "Performance score threshold"
        default 50.0
      end
      
      filter expr(performance_score <= ^arg(:threshold_score))
      prepare build(sort: [performance_score: :asc])
    end
    
    read :with_issues do
      description "Read metrics with identified performance issues"
      
      filter expr(fragment("jsonb_array_length(?) > 0", performance_issues))
    end
    
    read :recent do
      description "Read recent performance metrics"
      
      argument :timeframe, :string do
        description "Timeframe to look back"
        default "7d"
      end
      
      prepare UsageAnalyzer.Preparations.FilterByTimeframe
      prepare build(sort: [inserted_at: :desc])
    end
  end
  
  validations do
    validate {UsageAnalyzer.Validations.MetricValueValid, []}
    validate {UsageAnalyzer.Validations.PerformanceScoreConsistent, []}
  end
  
  calculations do
    calculate :performance_grade, :string do
      description "Letter grade for performance (A-F)"
      calculation UsageAnalyzer.Calculations.PerformanceGrade
    end
    
    calculate :improvement_potential, :decimal do
      description "Potential for performance improvement"
      calculation UsageAnalyzer.Calculations.PerformanceImprovementPotential
    end
    
    calculate :reliability_score, :decimal do
      description "Reliability based on variance"
      calculation UsageAnalyzer.Calculations.ReliabilityScore
    end
  end

  def description do
    """
    PerformanceMetric captures runtime and compile-time performance
    measurements for DSL usage analysis and optimization.
    """
  end
end