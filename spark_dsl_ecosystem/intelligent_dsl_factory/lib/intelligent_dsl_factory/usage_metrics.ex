defmodule IntelligentDslFactory.UsageMetrics do
  @moduledoc """
  Real-world usage metrics for generated DSL extensions.
  
  This captures actual usage data, not synthetic metrics, enabling
  genuine learning and improvement of DSL generation.
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: IntelligentDslFactory

  postgres do
    table "usage_metrics"
    repo IntelligentDslFactory.Repo
    
    references do
      reference :generated_extension, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :session_id, :uuid do
      description "Unique identifier for this usage session"
      allow_nil? false
    end
    
    attribute :user_id, :string do
      description "Anonymized user identifier"
      constraints [max_length: 100]
    end
    
    attribute :usage_context, :map do
      description "Context in which the DSL was used"
      default %{}
    end
    
    attribute :constructs_used, {:array, :string} do
      description "List of DSL constructs actually used"
      default []
    end
    
    attribute :error_patterns, {:array, :map} do
      description "Errors encountered during DSL usage"
      default []
    end
    
    attribute :completion_time_ms, :integer do
      description "Time to complete the task using the DSL"
      constraints [min: 0]
    end
    
    attribute :satisfaction_score, :decimal do
      description "User satisfaction rating (0-1)"
      constraints [min: 0, max: 1]
    end
    
    attribute :cognitive_load_indicators, :map do
      description "Measured indicators of cognitive load"
      default %{}
    end
    
    attribute :productivity_metrics, :map do
      description "Productivity measurements compared to manual implementation"
      default %{}
    end
    
    attribute :performance_score, :decimal do
      description "Performance score for generated code (0-1)"
      constraints [min: 0, max: 1]
      default 0.0
    end
    
    attribute :code_quality_metrics, :map do
      description "Quality metrics for code generated using this DSL"
      default %{}
    end
    
    attribute :adaptation_patterns, :map do
      description "How users adapted or worked around DSL limitations"
      default %{}
    end
    
    attribute :success_indicators, :map do
      description "Indicators of whether the task was completed successfully"
      default %{}
    end
    
    attribute :learning_curve_data, :map do
      description "Data about user learning curve with this DSL"
      default %{}
    end
    
    attribute :extension_usage_pattern, :string do
      description "Pattern of how the extension was used"
      constraints [one_of: ["exploratory", "productive", "maintenance", "learning", "debugging"]]
    end
    
    attribute :session_duration_ms, :integer do
      description "Total duration of the usage session"
      constraints [min: 0]
    end
    
    attribute :iterations_count, :integer do
      description "Number of iterations/revisions made"
      constraints [min: 0]
      default 1
    end
    
    attribute :help_seeking_behavior, :map do
      description "Patterns of help-seeking during DSL usage"
      default %{}
    end
    
    attribute :outcome_quality, :decimal do
      description "Quality of the final outcome (0-1)"
      constraints [min: 0, max: 1]
    end
    
    timestamps()
  end

  relationships do
    belongs_to :generated_extension, IntelligentDslFactory.GeneratedExtension do
      description "The DSL extension this usage data relates to"
      allow_nil? false
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :record_usage_session do
      description "Record a complete usage session"
      accept [:session_id, :user_id, :generated_extension_id, :usage_context, :constructs_used]
      
      change IntelligentDslFactory.Changes.AnalyzeUsageContext
      change IntelligentDslFactory.Changes.CalculateCompletionMetrics
      change IntelligentDslFactory.Changes.AssessCognitiveLoad
      change IntelligentDslFactory.Changes.MeasureProductivity
      change IntelligentDslFactory.Changes.EvaluateCodeQuality
      change IntelligentDslFactory.Changes.DetectAdaptationPatterns
      
      after_action IntelligentDslFactory.AfterActions.TriggerUsageLearning
    end
    
    update :complete_session do
      description "Mark session as complete with final metrics"
      accept [:satisfaction_score, :performance_score, :outcome_quality, :session_duration_ms]
      
      change IntelligentDslFactory.Changes.FinalizeSessionMetrics
      change IntelligentDslFactory.Changes.CalculateSuccessIndicators
      
      after_action IntelligentDslFactory.AfterActions.UpdateExtensionMetrics
    end
    
    read :by_extension do
      argument :extension_id, :uuid, allow_nil?: false
      filter expr(generated_extension_id == ^arg(:extension_id))
      prepare build(sort: [inserted_at: :desc])
    end
    
    read :successful_sessions do
      argument :min_satisfaction, :decimal, default: 0.7
      filter expr(satisfaction_score >= ^arg(:min_satisfaction) and outcome_quality >= 0.7)
    end
    
    read :problematic_sessions do
      filter expr(satisfaction_score < 0.5 or outcome_quality < 0.5)
      prepare build(sort: [satisfaction_score: :asc])
    end
    
    read :by_usage_pattern do
      argument :pattern, :string, allow_nil?: false
      filter expr(extension_usage_pattern == ^arg(:pattern))
    end
    
    read :high_productivity do
      prepare IntelligentDslFactory.Preparations.FilterHighProductivity
      prepare build(sort: [performance_score: :desc])
    end
    
    read :learning_curve_analysis do
      argument :user_id, :string, allow_nil?: false
      filter expr(user_id == ^arg(:user_id))
      prepare build(sort: [inserted_at: :asc])
    end
  end

  validations do
    validate {IntelligentDslFactory.Validations.ValidUsageContext, []}
    validate {IntelligentDslFactory.Validations.ConsistentMetrics, []}
  end

  calculations do
    calculate :efficiency_score, :decimal do
      description "Overall efficiency score combining time and quality"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          # Normalize completion time (assuming 1 hour = baseline)
          time_factor = max(0.1, min(1.0, 3600000 / max(1, record.completion_time_ms)))
          quality_factor = Decimal.to_float(record.outcome_quality)
          satisfaction_factor = Decimal.to_float(record.satisfaction_score)
          
          # Weighted efficiency score
          efficiency = (time_factor * 0.4) + (quality_factor * 0.35) + (satisfaction_factor * 0.25)
          Decimal.new(Float.to_string(efficiency))
        end)
      end
    end
    
    calculate :learning_effectiveness, :decimal do
      description "How effective the DSL is for learning"
      calculation IntelligentDslFactory.Calculations.LearningEffectiveness
    end
    
    calculate :adaptation_necessity, :decimal do
      description "How much users needed to adapt around DSL limitations"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          adaptations = map_size(record.adaptation_patterns)
          help_seeking = map_size(record.help_seeking_behavior)
          iterations = record.iterations_count
          
          # Higher values indicate more adaptation was necessary
          necessity = min(1.0, (adaptations * 0.4 + help_seeking * 0.3 + iterations * 0.3) / 10.0)
          Decimal.new(Float.to_string(necessity))
        end)
      end
    end
    
    calculate :cognitive_efficiency, :decimal do
      description "Ratio of outcome quality to cognitive load"
      calculation IntelligentDslFactory.Calculations.CognitiveEfficiency
    end
  end

  aggregates do
    avg :average_satisfaction, :satisfaction_score
    avg :average_performance, :performance_score  
    avg :average_completion_time, :completion_time_ms
    count :total_sessions
    
    # Advanced aggregates for learning insights
    first :first_session_satisfaction, :satisfaction_score, sort: [inserted_at: :asc]
    last :latest_session_satisfaction, :satisfaction_score, sort: [inserted_at: :desc]
  end

  def description do
    """
    UsageMetrics captures comprehensive real-world usage data for DSL extensions,
    enabling evidence-based learning and improvement of DSL generation algorithms.
    """
  end
end