defmodule UsageAnalyzer.Resources.PatternDetection do
  @moduledoc """
  PatternDetection resource representing identified usage patterns.
  
  A PatternDetection captures specific patterns in DSL usage,
  including frequency, context, and effectiveness metrics.
  """
  
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "pattern_detections"
    repo UsageAnalyzer.Repo
    
    references do
      reference :analysis_report, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :pattern_name, :string do
      description "Name of the detected pattern"
      allow_nil? false
      constraints [min_length: 1, max_length: 100]
    end
    
    attribute :pattern_type, :atom do
      description "Type/category of the pattern"
      constraints [one_of: [:structural, :behavioral, :performance, :error, :optimization, :anti_pattern]]
    end
    
    attribute :target_dsl, :string do
      description "DSL where pattern was detected"
      allow_nil? false
      constraints [min_length: 1, max_length: 200]
    end
    
    attribute :detection_scope, :atom do
      description "Scope of pattern detection"
      constraints [one_of: [:local, :project, :repository, :organization, :global]]
      default :project
    end
    
    attribute :frequency, :integer do
      description "Number of times pattern was observed"
      constraints [min: 1]
    end
    
    attribute :prevalence_percentage, :decimal do
      description "Percentage of usage showing this pattern"
      constraints [min: 0, max: 100]
    end
    
    attribute :confidence_score, :decimal do
      description "Confidence in pattern detection (0-1)"
      constraints [min: 0, max: 1]
    end
    
    attribute :pattern_description, :string do
      description "Detailed description of the pattern"
      constraints [max_length: 1000]
    end
    
    attribute :pattern_examples, {:array, :map} do
      description "Examples of this pattern in use"
      default []
    end
    
    attribute :context_data, :map do
      description "Context in which pattern appears"
      default %{}
    end
    
    attribute :effectiveness_score, :decimal do
      description "How effective this pattern is (0-100)"
      constraints [min: 0, max: 100]
    end
    
    attribute :impact_areas, {:array, :atom} do
      description "Areas impacted by this pattern"
      constraints [items: [one_of: [:performance, :maintainability, :usability, :security, :reliability]]]
      default []
    end
    
    attribute :positive_impacts, {:array, :string} do
      description "Positive impacts of this pattern"
      default []
    end
    
    attribute :negative_impacts, {:array, :string} do
      description "Negative impacts or concerns"
      default []
    end
    
    attribute :improvement_suggestions, {:array, :string} do
      description "Suggestions for pattern improvement"
      default []
    end
    
    attribute :detection_method, :atom do
      description "Method used to detect this pattern"
      constraints [one_of: [:static_analysis, :runtime_analysis, :ml_detection, :rule_based, :manual]]
    end
    
    attribute :detection_confidence, :decimal do
      description "Confidence in detection method (0-1)"
      constraints [min: 0, max: 1]
    end
    
    attribute :trend_direction, :atom do
      description "Trend in pattern usage"
      constraints [one_of: [:increasing, :decreasing, :stable, :emerging, :declining]]
    end
    
    attribute :related_patterns, {:array, :string} do
      description "Related or similar patterns"
      default []
    end
    
    timestamps()
  end

  relationships do
    belongs_to :analysis_report, UsageAnalyzer.Resources.AnalysisReport do
      description "The analysis report this pattern belongs to"
      attribute_writable? true
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :detect_pattern do
      description "Detect a new usage pattern"
      accept [:pattern_name, :pattern_type, :target_dsl, :frequency, :analysis_report_id]
      
      change UsageAnalyzer.Changes.CalculatePrevalence
      change UsageAnalyzer.Changes.AnalyzePatternImpact
      change UsageAnalyzer.Changes.GenerateExamples
      change UsageAnalyzer.Changes.CalculatePatternConfidence
      change UsageAnalyzer.Changes.IdentifyRelatedPatterns
    end
    
    read :by_report do
      description "Read patterns by analysis report"
      
      argument :report_id, :uuid do
        description "Analysis report ID to filter by"
        allow_nil? false
      end
      
      filter expr(analysis_report_id == ^arg(:report_id))
      prepare build(sort: [prevalence_percentage: :desc])
    end
    
    read :by_pattern_type do
      description "Read patterns by type"
      
      argument :pattern_type, :atom do
        description "Pattern type to filter by"
        allow_nil? false
      end
      
      filter expr(pattern_type == ^arg(:pattern_type))
    end
    
    read :by_target_dsl do
      description "Read patterns by target DSL"
      
      argument :target_dsl, :string do
        description "Target DSL to filter by"
        allow_nil? false
      end
      
      filter expr(target_dsl == ^arg(:target_dsl))
    end
    
    read :high_frequency do
      description "Read patterns with high frequency"
      
      argument :minimum_frequency, :integer do
        description "Minimum frequency threshold"
        default 10
      end
      
      filter expr(frequency >= ^arg(:minimum_frequency))
    end
    
    read :anti_patterns do
      description "Read identified anti-patterns"
      
      filter expr(pattern_type == :anti_pattern)
      prepare build(sort: [frequency: :desc])
    end
    
    read :emerging_patterns do
      description "Read emerging patterns"
      
      filter expr(trend_direction == :emerging)
    end
    
    read :recent do
      description "Read recently detected patterns"
      
      argument :timeframe, :string do
        description "Timeframe to look back"
        default "7d"
      end
      
      prepare UsageAnalyzer.Preparations.FilterByTimeframe
      prepare build(sort: [inserted_at: :desc])
    end
  end
  
  validations do
    validate {UsageAnalyzer.Validations.PatternNameUnique, within_analysis: true}
    validate {UsageAnalyzer.Validations.FrequencyConsistent, []}
  end
  
  calculations do
    calculate :impact_score, :decimal do
      description "Overall impact score based on frequency and effectiveness"
      calculation UsageAnalyzer.Calculations.PatternImpactScore
    end
    
    calculate :improvement_priority, :decimal do
      description "Priority for pattern improvement (0-100)"
      calculation UsageAnalyzer.Calculations.ImprovementPriority
    end
    
    calculate :adoption_rate, :decimal do
      description "Rate of pattern adoption"
      calculation UsageAnalyzer.Calculations.AdoptionRate
    end
  end

  def description do
    """
    PatternDetection represents specific usage patterns identified
    in DSL usage analysis, with frequency and impact metrics.
    """
  end
end