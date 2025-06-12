defmodule UsageAnalyzer.Resources.AnalysisReport do
  @moduledoc """
  AnalysisReport resource representing comprehensive DSL usage analysis.
  
  An AnalysisReport captures comprehensive analysis of how DSLs are used
  in practice, including patterns, performance, and pain points.
  """
  
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "analysis_reports"
    repo UsageAnalyzer.Repo
    
    references do
      reference :pattern_detections, on_delete: :delete
      reference :performance_metrics, on_delete: :delete
      reference :pain_point_analyses, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :target_dsl, :string do
      description "DSL being analyzed"
      allow_nil? false
      constraints [min_length: 1, max_length: 200]
    end
    
    attribute :analysis_type, :atom do
      description "Type of analysis performed"
      constraints [one_of: [:comprehensive, :patterns, :performance, :pain_points, :trends, :comparison]]
      default :comprehensive
    end
    
    attribute :data_sources, {:array, :atom} do
      description "Sources of data for analysis"
      constraints [items: [one_of: [:local, :github, :telemetry, :user_feedback, :static_analysis]]]
      default [:local]
    end
    
    attribute :time_window, :string do
      description "Time window for analysis (e.g., '30d', '90d')"
      constraints [max_length: 20]
      default "30d"
    end
    
    attribute :analysis_options, :map do
      description "Options and parameters for analysis"
      default %{}
    end
    
    attribute :status, :atom do
      description "Status of the analysis"
      constraints [one_of: [:pending, :running, :completed, :failed]]
      default :pending
    end
    
    attribute :processing_time_ms, :integer do
      description "Time taken to complete analysis"
      constraints [min: 0]
    end
    
    attribute :overall_score, :decimal do
      description "Overall health/quality score (0-100)"
      constraints [min: 0, max: 100]
    end
    
    attribute :summary_findings, {:array, :string} do
      description "Key findings from the analysis"
      default []
    end
    
    attribute :recommendations, {:array, :string} do
      description "Recommendations based on analysis"
      default []
    end
    
    attribute :analysis_metadata, :map do
      description "Metadata about the analysis process"
      default %{}
    end
    
    attribute :data_quality_score, :decimal do
      description "Quality of input data (0-1)"
      constraints [min: 0, max: 1]
    end
    
    attribute :confidence_level, :decimal do
      description "Confidence in analysis results (0-1)"
      constraints [min: 0, max: 1]
    end
    
    attribute :sample_size, :integer do
      description "Number of data points analyzed"
      constraints [min: 0]
    end
    
    attribute :coverage_percentage, :decimal do
      description "Percentage of target DSL usage covered"
      constraints [min: 0, max: 100]
    end
    
    attribute :include_patterns, :boolean do
      description "Whether pattern analysis was included"
      default true
    end
    
    attribute :include_performance, :boolean do
      description "Whether performance analysis was included"
      default true
    end
    
    attribute :include_pain_points, :boolean do
      description "Whether pain point analysis was included"
      default true
    end
    
    timestamps()
  end

  relationships do
    has_many :pattern_detections, UsageAnalyzer.Resources.PatternDetection do
      description "Pattern detections from this analysis"
    end
    
    has_many :performance_metrics, UsageAnalyzer.Resources.PerformanceMetric do
      description "Performance metrics from this analysis"
    end
    
    has_many :pain_point_analyses, UsageAnalyzer.Resources.PainPointAnalysis do
      description "Pain point analyses from this analysis"
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :start_analysis do
      description "Start a new DSL usage analysis"
      accept [:target_dsl, :analysis_type, :data_sources, :time_window, :analysis_options]
      
      change set_attribute(:status, :running)
      change UsageAnalyzer.Changes.ValidateAnalysisOptions
      change UsageAnalyzer.Changes.InitializeAnalysis
      
      after_action UsageAnalyzer.AfterActions.BeginDataCollection
    end
    
    update :complete_analysis do
      description "Mark analysis as completed"
      accept [:overall_score, :summary_findings, :recommendations, :processing_time_ms]
      
      change set_attribute(:status, :completed)
      change UsageAnalyzer.Changes.FinalizeAnalysis
      
      after_action UsageAnalyzer.AfterActions.GenerateReport
    end
    
    update :fail_analysis do
      description "Mark analysis as failed"
      accept [:analysis_metadata]
      
      change set_attribute(:status, :failed)
    end
    
    read :by_target_dsl do
      description "Read analyses by target DSL"
      
      argument :target_dsl, :string do
        description "Target DSL to filter by"
        allow_nil? false
      end
      
      filter expr(target_dsl == ^arg(:target_dsl))
      prepare build(sort: [inserted_at: :desc])
    end
    
    read :by_analysis_type do
      description "Read analyses by type"
      
      argument :analysis_type, :atom do
        description "Analysis type to filter by"
        allow_nil? false
      end
      
      filter expr(analysis_type == ^arg(:analysis_type))
    end
    
    read :completed do
      description "Read completed analyses"
      
      filter expr(status == :completed)
      prepare build(sort: [overall_score: :desc])
    end
    
    read :recent do
      description "Read recent analyses"
      
      argument :timeframe, :string do
        description "Timeframe to look back"
        default "7d"
      end
      
      prepare UsageAnalyzer.Preparations.FilterByTimeframe
      prepare build(sort: [inserted_at: :desc])
    end
    
    read :high_quality do
      description "Read analyses with high overall scores"
      
      argument :minimum_score, :decimal do
        description "Minimum overall score"
        default 80.0
      end
      
      filter expr(overall_score >= ^arg(:minimum_score))
    end
  end
  
  validations do
    validate {UsageAnalyzer.Validations.AnalysisOptionsValid, []}
    validate {UsageAnalyzer.Validations.TimeWindowValid, []}
  end
  
  calculations do
    calculate :analysis_duration, :integer do
      description "Duration of analysis in milliseconds"
      calculation UsageAnalyzer.Calculations.AnalysisDuration
    end
    
    calculate :findings_count, :integer do
      description "Number of key findings"
      calculation UsageAnalyzer.Calculations.FindingsCount
    end
    
    calculate :actionable_recommendations, :integer do
      description "Number of actionable recommendations"
      calculation UsageAnalyzer.Calculations.ActionableRecommendations
    end
  end

  aggregates do
    count :total_patterns, :pattern_detections do
      description "Total number of detected patterns"
    end
    
    count :total_metrics, :performance_metrics do
      description "Total number of performance metrics"
    end
    
    count :total_pain_points, :pain_point_analyses do
      description "Total number of identified pain points"
    end
    
    avg :average_pattern_confidence, :pattern_detections, :confidence_score do
      description "Average confidence of pattern detections"
    end
  end

  def description do
    """
    AnalysisReport captures comprehensive analysis of DSL usage
    patterns, performance, and pain points for optimization insights.
    """
  end
end