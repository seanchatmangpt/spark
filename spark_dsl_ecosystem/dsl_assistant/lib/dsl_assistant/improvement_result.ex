defmodule DslAssistant.ImprovementResult do
  @moduledoc """
  Results from implementing a specific DSL improvement.
  
  This captures before/after metrics to validate that improvements
  actually make things better and enables learning for future recommendations.
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: DslAssistant

  postgres do
    table "improvement_results"
    repo DslAssistant.Repo
    
    references do
      reference :improvement, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :implementation_approach, :string do
      description "How the improvement was implemented"
      constraints [max_length: 500]
    end
    
    attribute :before_metrics, :map do
      description "Metrics measured before the improvement"
      allow_nil? false
      default %{}
    end
    
    attribute :after_metrics, :map do
      description "Metrics measured after the improvement"
      allow_nil? false
      default %{}
    end
    
    attribute :impact_analysis, :map do
      description "Analysis of the improvement's impact"
      default %{}
    end
    
    attribute :implementation_success, :boolean do
      description "Whether the implementation was successful"
      allow_nil? false
      default true
    end
    
    attribute :implementation_notes, :string do
      description "Notes about the implementation process"
      constraints [max_length: 2000]
    end
    
    attribute :implementation_effort, :decimal do
      description "Actual effort required (in person-days)"
      constraints [min: 0]
    end
    
    attribute :actual_impact_score, :decimal do
      description "Measured impact score (-1 to 1, where 1 is very positive)"
      constraints [min: -1, max: 1]
    end
    
    attribute :user_feedback, :map do
      description "Feedback from users about the improvement"
      default %{}
    end
    
    attribute :unexpected_consequences, {:array, :string} do
      description "Unexpected positive or negative consequences"
      default []
    end
    
    attribute :rollback_required, :boolean do
      description "Whether rollback was required"
      default false
    end
    
    attribute :rollback_reason, :string do
      description "Reason for rollback if it occurred"
      constraints [max_length: 500]
    end
    
    attribute :validation_method, :string do
      description "How the improvement was validated"
      constraints [max_length: 200]
    end
    
    attribute :measurement_period_days, :integer do
      description "How many days were used to measure impact"
      constraints [min: 1]
      default 30
    end
    
    attribute :sample_size, :integer do
      description "Number of usage instances measured"
      constraints [min: 0]
      default 0
    end
    
    attribute :statistical_significance, :decimal do
      description "Statistical significance of the measured impact (p-value)"
      constraints [min: 0, max: 1]
    end
    
    attribute :confidence_interval, :map do
      description "Confidence interval for impact measurements"
      default %{}
    end
    
    attribute :success_criteria_met, {:array, :string} do
      description "Which success criteria were met"
      default []
    end
    
    attribute :success_criteria_failed, {:array, :string} do
      description "Which success criteria were not met"
      default []
    end
    
    attribute :total_success_criteria, :integer do
      description "Total number of success criteria evaluated"
      constraints [min: 0]
      default 0
    end
    
    attribute :measured_at, :utc_datetime_usec do
      description "When these results were measured"
      allow_nil? false
      default &DateTime.utc_now/0
    end
    
    attribute :follow_up_required, :boolean do
      description "Whether follow-up measurement is needed"
      default false
    end
    
    attribute :follow_up_date, :utc_datetime_usec do
      description "When follow-up measurement should occur"
    end
    
    attribute :learning_insights, {:array, :string} do
      description "Key insights learned from this implementation"
      default []
    end
    
    timestamps()
  end

  relationships do
    belongs_to :improvement, DslAssistant.Improvement do
      description "The improvement that was implemented"
      allow_nil? false
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :record_implementation do
      description "Record the results of implementing an improvement"
      accept [:improvement_id, :implementation_approach, :before_metrics, :after_metrics,
              :implementation_success, :implementation_notes, :measurement_period_days]
      
      change DslAssistant.Changes.AnalyzeImpact
      change DslAssistant.Changes.CalculateActualImpact
      change DslAssistant.Changes.ValidateSuccessCriteria
      change DslAssistant.Changes.ExtractLearningInsights
      
      after_action DslAssistant.AfterActions.UpdateImprovementFeedback
      after_action DslAssistant.AfterActions.TriggerLearningUpdate
    end
    
    update :add_user_feedback do
      description "Add user feedback about the improvement"
      accept [:user_feedback, :unexpected_consequences]
      
      change DslAssistant.Changes.AnalyzeUserFeedback
      change DslAssistant.Changes.UpdateLearningInsights
    end
    
    update :record_rollback do
      description "Record that the improvement was rolled back"
      accept [:rollback_required, :rollback_reason]
      
      change {DslAssistant.Changes.MarkAsRolledBack, []}
      
      after_action DslAssistant.AfterActions.UpdateNegativeLearning
    end
    
    update :schedule_follow_up do
      description "Schedule follow-up measurement"
      accept [:follow_up_required, :follow_up_date]
    end
    
    read :successful_implementations do
      filter expr(implementation_success == true and rollback_required == false)
      prepare build(sort: [actual_impact_score: :desc])
    end
    
    read :failed_implementations do
      filter expr(implementation_success == false or rollback_required == true)
      prepare build(sort: [measured_at: :desc])
    end
    
    read :high_impact_results do
      argument :min_impact, :decimal, default: 0.5
      filter expr(actual_impact_score >= ^arg(:min_impact))
      prepare build(sort: [actual_impact_score: :desc])
    end
    
    read :negative_impact_results do
      filter expr(actual_impact_score < 0)
      prepare build(sort: [actual_impact_score: :asc])
    end
    
    read :by_improvement_type do
      argument :improvement_type, :atom, allow_nil?: false
      prepare build(
        load: [:improvement],
        sort: [actual_impact_score: :desc]
      )
      filter expr(improvement.improvement_type == ^arg(:improvement_type))
    end
    
    read :requiring_follow_up do
      filter expr(follow_up_required == true)
      prepare build(sort: [follow_up_date: :asc])
    end
    
    read :statistically_significant do
      argument :max_p_value, :decimal, default: 0.05
      filter expr(statistical_significance <= ^arg(:max_p_value))
    end
    
    read :recent_results do
      argument :days_back, :integer, default: 30
      prepare DslAssistant.Preparations.FilterRecentResults
    end
  end

  validations do
    validate {DslAssistant.Validations.ValidImprovementResult, []}
  end

  calculations do
    calculate :success_rate, :decimal, DslAssistant.Calculations.SuccessRate
    
    calculate :roi, :decimal, DslAssistant.Calculations.ImprovementROI
    
    calculate :impact_magnitude, :decimal do
      description "Absolute magnitude of impact regardless of direction"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          impact = record.actual_impact_score || 0.0
          magnitude = abs(impact)
          Decimal.new(Float.to_string(magnitude))
        end)
      end
    end
    
    calculate :implementation_efficiency, :decimal do
      description "Impact achieved per unit of effort"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          impact = record.actual_impact_score || 0.0
          effort = record.implementation_effort || 1.0
          
          efficiency = if effort > 0, do: impact / effort, else: 0.0
          Decimal.new(Float.to_string(efficiency))
        end)
      end
    end
    
    calculate :confidence_level, :atom do
      description "Confidence level in the results based on statistical significance"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          case record.statistical_significance do
            p when is_number(p) and p <= 0.01 -> :very_high
            p when is_number(p) and p <= 0.05 -> :high
            p when is_number(p) and p <= 0.1 -> :medium
            p when is_number(p) and p <= 0.2 -> :low
            _ -> :very_low
          end
        end)
      end
    end
    
    calculate :trend_indicator, :atom, DslAssistant.Calculations.TrendAnalysis
    
    calculate :learning_value, :decimal do
      description "How valuable this result is for learning (0-1)"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          # Higher learning value for:
          # - Unexpected results (high magnitude)
          # - Statistical significance
          # - Good sample size
          # - Clear insights
          
          magnitude_score = min(1.0, abs(record.actual_impact_score || 0.0))
          
          significance_score = case record.statistical_significance do
            p when is_number(p) and p <= 0.05 -> 1.0
            p when is_number(p) and p <= 0.1 -> 0.8
            p when is_number(p) and p <= 0.2 -> 0.6
            _ -> 0.3
          end
          
          sample_score = min(1.0, (record.sample_size || 0) / 100.0)
          
          insights_score = min(1.0, length(record.learning_insights) / 5.0)
          
          learning_value = (magnitude_score * 0.3) + (significance_score * 0.3) + 
                          (sample_score * 0.2) + (insights_score * 0.2)
          
          Decimal.new(Float.to_string(learning_value))
        end)
      end
    end
  end

  aggregates do
    # No aggregates needed for this resource currently
  end

  def description do
    """
    ImprovementResult captures the actual outcomes of implementing
    DSL improvements, enabling evidence-based learning and better
    future recommendations.
    """
  end
end