defmodule DslAssistant.UsagePattern do
  @moduledoc """
  A specific usage pattern identified from real DSL usage data.
  
  Usage patterns capture how developers actually use DSL constructs,
  including common sequences, error patterns, and success patterns.
  """
  
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    domain: DslAssistant

  postgres do
    table "usage_patterns"
    repo DslAssistant.Repo
    
    references do
      reference :dsl_analysis, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :pattern_type, :atom do
      description "Type of usage pattern"
      constraints [one_of: [:common, :rare, :error, :success, :workaround, :antipattern]]
      allow_nil? false
    end
    
    attribute :construct_name, :string do
      description "DSL construct this pattern relates to"
      allow_nil? false
      constraints [min_length: 1, max_length: 100]
    end
    
    attribute :pattern_description, :string do
      description "Description of the usage pattern"
      allow_nil? false
      constraints [min_length: 10, max_length: 1000]
    end
    
    attribute :frequency, :integer do
      description "How often this pattern occurs"
      constraints [min: 0]
      default 1
    end
    
    attribute :example_code, :string do
      description "Example code demonstrating this pattern"
      constraints [max_length: 2000]
    end
    
    attribute :context_description, :string do
      description "Context in which this pattern typically occurs"
      constraints [max_length: 500]
    end
    
    attribute :user_intent, :string do
      description "What the user was trying to accomplish"
      constraints [max_length: 200]
    end
    
    attribute :outcome, :atom do
      description "Outcome of this pattern usage"
      constraints [one_of: [:success, :error, :workaround, :abandonment]]
    end
    
    attribute :error_context, :map do
      description "Error details if this pattern led to errors"
      default %{}
    end
    
    attribute :performance_context, :map do
      description "Performance characteristics of this pattern"
      default %{}
    end
    
    attribute :user_context, :map do
      description "User experience context (skill level, domain, etc.)"
      default %{}
    end
    
    attribute :business_context, :map do
      description "Business context where this pattern was used"
      default %{}
    end
    
    attribute :resolution_pattern, :string do
      description "How users typically resolve issues with this pattern"
      constraints [max_length: 500]
    end
    
    attribute :alternative_approaches, {:array, :string} do
      description "Alternative approaches users tried"
      default []
    end
    
    attribute :confidence_score, :decimal do
      description "Confidence in this pattern identification (0-1)"
      constraints [min: 0, max: 1]
      default 0.7
    end
    
    attribute :validation_status, :atom do
      description "Status of pattern validation"
      constraints [one_of: [:pending_validation, :partially_validated, :validated, :invalidated]]
      default :pending_validation
    end
    
    attribute :first_observed, :utc_datetime_usec do
      description "When this pattern was first observed"
      allow_nil? false
      default &DateTime.utc_now/0
    end
    
    attribute :last_observed, :utc_datetime_usec do
      description "When this pattern was last observed"
      allow_nil? false
      default &DateTime.utc_now/0
    end
    
    timestamps()
  end

  relationships do
    belongs_to :dsl_analysis, DslAssistant.DslAnalysis do
      description "The analysis that identified this pattern"
      allow_nil? false
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :identify_pattern do
      description "Identify a new usage pattern from data"
      accept [:pattern_type, :construct_name, :pattern_description, :frequency, 
              :example_code, :user_intent, :outcome, :dsl_analysis_id]
      
      change DslAssistant.Changes.AnalyzePatternContext
      change DslAssistant.Changes.CalculatePatternConfidence
      change DslAssistant.Changes.DetermineValidationNeeds
      
      after_action DslAssistant.AfterActions.IndexPattern
    end
    
    update :validate_pattern do
      description "Update pattern with validation results"
      accept [:validation_status, :confidence_score, :resolution_pattern]
      
      change DslAssistant.Changes.UpdatePatternConfidence
    end
    
    update :observe_pattern do
      description "Record a new observation of this pattern"
      accept [:last_observed]
      
      change {DslAssistant.Changes.IncrementFrequency, []}
    end
    
    read :by_construct do
      argument :construct_name, :string, allow_nil?: false
      filter expr(construct_name == ^arg(:construct_name))
      prepare build(sort: [frequency: :desc])
    end
    
    read :by_type do
      argument :pattern_type, :atom, allow_nil?: false
      filter expr(pattern_type == ^arg(:pattern_type))
      prepare build(sort: [frequency: :desc])
    end
    
    read :frequent_patterns do
      argument :min_frequency, :integer, default: 10
      filter expr(frequency >= ^arg(:min_frequency))
      prepare build(sort: [frequency: :desc])
    end
    
    read :error_patterns do
      filter expr(pattern_type == :error or outcome == :error)
      prepare build(sort: [frequency: :desc])
    end
    
    read :success_patterns do
      filter expr(pattern_type == :success or outcome == :success)
      prepare build(sort: [frequency: :desc])
    end
    
    read :antipatterns do
      filter expr(pattern_type == :antipattern)
      prepare build(sort: [frequency: :desc])
    end
    
    read :high_confidence do
      argument :min_confidence, :decimal, default: 0.8
      filter expr(confidence_score >= ^arg(:min_confidence))
    end
    
    read :validated_patterns do
      filter expr(validation_status == :validated)
      prepare build(sort: [confidence_score: :desc])
    end
    
    read :recent_patterns do
      argument :days_back, :integer, default: 30
      prepare DslAssistant.Preparations.FilterRecentPatterns
    end
  end

  validations do
    validate {DslAssistant.Validations.ValidUsagePattern, []}
  end

  calculations do
    calculate :pattern_confidence, :decimal, DslAssistant.Calculations.PatternConfidence
    
    calculate :impact_potential, :decimal do
      description "Potential impact of addressing this pattern"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          base_impact = case record.pattern_type do
            :error -> 0.9        # High impact to fix errors
            :antipattern -> 0.8  # High impact to fix antipatterns
            :workaround -> 0.6   # Medium impact to eliminate workarounds
            :success -> 0.3      # Lower impact but good to reinforce
            _ -> 0.5
          end
          
          # Adjust for frequency
          frequency_multiplier = min(2.0, :math.log(record.frequency + 1) / :math.log(10))
          final_impact = base_impact * frequency_multiplier / 2.0
          
          Decimal.new(Float.to_string(min(1.0, final_impact)))
        end)
      end
    end
    
    calculate :pattern_age_days, :integer do
      description "How many days since pattern was first observed"
      calculation fn records, _context ->
        now = DateTime.utc_now()
        
        Enum.map(records, fn record ->
          DateTime.diff(now, record.first_observed, :day)
        end)
      end
    end
    
    calculate :observation_frequency, :decimal do
      description "How often this pattern is observed (observations per day)"
      calculation fn records, _context ->
        Enum.map(records, fn record ->
          age_days = max(1, DateTime.diff(DateTime.utc_now(), record.first_observed, :day))
          frequency_per_day = record.frequency / age_days
          Decimal.new(Float.to_string(frequency_per_day))
        end)
      end
    end
  end

  aggregates do
    # No aggregates needed for this resource currently
  end

  def description do
    """
    UsagePattern captures real-world usage patterns of DSL constructs,
    enabling evidence-based improvements and better developer experience.
    """
  end
end