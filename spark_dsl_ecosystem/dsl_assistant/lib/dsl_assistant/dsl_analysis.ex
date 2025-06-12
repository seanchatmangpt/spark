defmodule DslAssistant.DslAnalysis do
  @moduledoc """
  Analysis results for a specific DSL, capturing real structural data
  and usage patterns to enable concrete improvements.
  
  This is evidence-based analysis, not theoretical modeling.
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: DslAssistant

  postgres do
    table "dsl_analyses"
    repo DslAssistant.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :dsl_module, :string do
      description "Module name of the analyzed DSL"
      allow_nil? false
      constraints [min_length: 1, max_length: 200]
    end
    
    attribute :structure_analysis, :map do
      description "Structural analysis of the DSL (sections, entities, etc.)"
      allow_nil? false
      default %{}
    end
    
    attribute :usage_patterns, :map do
      description "Patterns extracted from real usage data"
      allow_nil? false
      default %{}
    end
    
    attribute :friction_points, {:array, :map} do
      description "Identified sources of friction for users"
      default []
    end
    
    attribute :recommended_improvements, {:array, :map} do
      description "Concrete improvement recommendations with effort estimates"
      default []
    end
    
    attribute :complexity_metrics, :map do
      description "Measured complexity across different dimensions"
      default %{}
    end
    
    attribute :api_surface_analysis, :map do
      description "Analysis of the DSL's public API surface"
      default %{}
    end
    
    attribute :error_analysis, :map do
      description "Analysis of common errors and their patterns"
      default %{}
    end
    
    attribute :user_journey_analysis, :map do
      description "Analysis of typical user journeys through the DSL"
      default %{}
    end
    
    attribute :benchmark_comparison, :map do
      description "Comparison with similar DSLs in the ecosystem"
      default %{}
    end
    
    attribute :analysis_confidence, :decimal do
      description "Confidence in analysis results based on data quality (0-1)"
      constraints [min: 0, max: 1]
      default 0.5
    end
    
    attribute :data_sample_size, :integer do
      description "Number of usage samples analyzed"
      constraints [min: 0]
      default 0
    end
    
    attribute :analysis_timestamp, :utc_datetime_usec do
      description "When this analysis was performed"
      allow_nil? false
      default &DateTime.utc_now/0
    end
    
    timestamps()
  end

  relationships do
    has_many :usage_patterns_detailed, DslAssistant.UsagePattern do
      description "Detailed usage patterns found in this analysis"
    end
    
    has_many :improvements, DslAssistant.Improvement do
      description "Improvements recommended based on this analysis"
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :analyze_dsl do
      description "Create analysis from DSL structure and usage data"
      accept [:dsl_module, :structure_analysis, :usage_patterns, :friction_points, :recommended_improvements]
      
      change DslAssistant.Changes.CalculateComplexityMetrics
      change DslAssistant.Changes.AnalyzeApiSurface
      change DslAssistant.Changes.ExtractErrorPatterns
      change DslAssistant.Changes.AnalyzeUserJourneys
      change DslAssistant.Changes.BenchmarkAgainstEcosystem
      change DslAssistant.Changes.CalculateAnalysisConfidence
      
      after_action DslAssistant.AfterActions.CreateDetailedPatterns
      after_action DslAssistant.AfterActions.GenerateImprovements
    end
    
    read :by_dsl_module do
      argument :dsl_module, :string, allow_nil?: false
      filter expr(dsl_module == ^arg(:dsl_module))
      prepare build(sort: [analysis_timestamp: :desc])
    end
    
    read :recent_analyses do
      argument :days_back, :integer, default: 30
      prepare DslAssistant.Preparations.FilterRecentAnalyses
      prepare build(sort: [analysis_timestamp: :desc])
    end
    
    read :high_confidence do
      argument :min_confidence, :decimal, default: 0.8
      filter expr(analysis_confidence >= ^arg(:min_confidence))
    end
    
    read :with_friction_points do
      filter expr(fragment("jsonb_array_length(friction_points) > 0"))
      prepare build(sort: [analysis_timestamp: :desc])
    end
  end

  validations do
    validate {DslAssistant.Validations.ValidDslModule, []}
    validate {DslAssistant.Validations.AnalysisDataConsistency, []}
  end

  calculations do
    calculate :total_friction_points, :integer do
      description "Total number of identified friction points"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          length(record.friction_points)
        end)
      end
    end
    
    calculate :high_impact_improvements, :integer do
      description "Number of high-impact improvement recommendations"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          record.recommended_improvements
          |> Enum.count(&(Map.get(&1, "impact_estimate", 0) > 0.5))
        end)
      end
    end
    
    calculate :overall_health_score, :decimal do
      description "Overall health score of the DSL (0-1)"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          friction_penalty = min(0.5, length(record.friction_points) * 0.05)
          complexity_penalty = calculate_complexity_penalty(record.complexity_metrics)
          error_penalty = calculate_error_penalty(record.error_analysis)
          
          base_score = 1.0
          final_score = base_score - friction_penalty - complexity_penalty - error_penalty
          
          Decimal.new(Float.to_string(max(0.0, final_score)))
        end)
      end
    end
    
    calculate :improvement_potential, :decimal do
      description "Potential improvement score based on identified issues"
      calculation DslAssistant.Calculations.ImprovementPotential
    end
  end

  aggregates do
    count :total_improvements, :improvements
    avg :average_improvement_effort, :improvements, :effort_score
  end

  # Helper functions for calculations
  defp calculate_complexity_penalty(complexity_metrics) do
    case complexity_metrics do
      %{"overall_complexity" => complexity} when complexity > 0.7 -> 0.2
      %{"overall_complexity" => complexity} when complexity > 0.5 -> 0.1
      _ -> 0.0
    end
  end

  defp calculate_error_penalty(error_analysis) do
    case error_analysis do
      %{"error_rate" => rate} when rate > 0.1 -> 0.3
      %{"error_rate" => rate} when rate > 0.05 -> 0.15
      _ -> 0.0
    end
  end

  def description do
    """
    DslAnalysis captures comprehensive analysis of an existing DSL,
    providing evidence-based insights for concrete improvements.
    """
  end
end