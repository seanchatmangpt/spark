defmodule UsageAnalyzer.Resources.PainPointAnalysis do
  @moduledoc """
  PainPointAnalysis resource representing identified friction and issues.
  
  A PainPointAnalysis captures specific pain points in DSL usage,
  including their impact, frequency, and potential solutions.
  """
  
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "pain_point_analyses"
    repo UsageAnalyzer.Repo
    
    references do
      reference :analysis_report, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :target_dsl, :string do
      description "DSL where pain point was identified"
      allow_nil? false
      constraints [min_length: 1, max_length: 200]
    end
    
    attribute :pain_point_name, :string do
      description "Name of the identified pain point"
      allow_nil? false
      constraints [min_length: 1, max_length: 100]
    end
    
    attribute :pain_point_type, :atom do
      description "Category of the pain point"
      constraints [one_of: [:usability, :performance, :documentation, :error_handling, :debugging, :complexity, :learning_curve, :tooling]]
    end
    
    attribute :analysis_scope, :atom do
      description "Scope of pain point analysis"
      constraints [one_of: [:comprehensive, :focused, :exploratory, :validation]]
      default :comprehensive
    end
    
    attribute :data_sources, {:array, :atom} do
      description "Sources used to identify this pain point"
      constraints [items: [one_of: [:local, :telemetry, :user_feedback, :error_logs, :static_analysis]]]
      default [:local]
    end
    
    attribute :description, :string do
      description "Detailed description of the pain point"
      constraints [max_length: 1000]
    end
    
    attribute :severity_level, :atom do
      description "Severity of the pain point"
      constraints [one_of: [:low, :medium, :high, :critical]]
      default :medium
    end
    
    attribute :frequency_of_occurrence, :integer do
      description "How often this pain point occurs"
      constraints [min: 0]
    end
    
    attribute :user_impact_score, :decimal do
      description "Impact on user experience (0-100)"
      constraints [min: 0, max: 100]
    end
    
    attribute :productivity_impact, :decimal do
      description "Impact on developer productivity (0-100)"
      constraints [min: 0, max: 100]
    end
    
    attribute :affected_user_percentage, :decimal do
      description "Percentage of users affected"
      constraints [min: 0, max: 100]
    end
    
    attribute :symptoms, {:array, :string} do
      description "Observable symptoms of this pain point"
      default []
    end
    
    attribute :root_causes, {:array, :string} do
      description "Identified root causes"
      default []
    end
    
    attribute :user_feedback, {:array, :map} do
      description "User feedback related to this pain point"
      default []
    end
    
    attribute :error_patterns, {:array, :string} do
      description "Common error patterns associated with this pain point"
      default []
    end
    
    attribute :workarounds, {:array, :string} do
      description "Known workarounds for this pain point"
      default []
    end
    
    attribute :proposed_solutions, {:array, :map} do
      description "Proposed solutions with effort estimates"
      default []
    end
    
    attribute :resolution_priority, :atom do
      description "Priority for resolving this pain point"
      constraints [one_of: [:low, :medium, :high, :critical]]
      default :medium
    end
    
    attribute :resolution_effort_estimate, :atom do
      description "Estimated effort to resolve"
      constraints [one_of: [:trivial, :low, :medium, :high, :very_high]]
    end
    
    attribute :resolution_status, :atom do
      description "Current resolution status"
      constraints [one_of: [:identified, :investigating, :planning, :in_progress, :resolved, :wont_fix]]
      default :identified
    end
    
    attribute :business_impact, :string do
      description "Impact on business objectives"
      constraints [max_length: 500]
    end
    
    attribute :analysis_options, :map do
      description "Options used for analysis"
      default %{}
    end
    
    attribute :evidence_data, :map do
      description "Supporting evidence for this pain point"
      default %{}
    end
    
    attribute :trend_analysis, :map do
      description "Trend in pain point severity/frequency"
      default %{}
    end
    
    timestamps()
  end

  relationships do
    belongs_to :analysis_report, UsageAnalyzer.Resources.AnalysisReport do
      description "The analysis report this pain point belongs to"
      attribute_writable? true
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :identify_pain_point do
      description "Identify a new pain point"
      accept [:target_dsl, :pain_point_name, :pain_point_type, :analysis_scope, :data_sources, :analysis_report_id]
      
      change UsageAnalyzer.Changes.AnalyzePainPointImpact
      change UsageAnalyzer.Changes.IdentifyRootCauses
      change UsageAnalyzer.Changes.GatherEvidence
      change UsageAnalyzer.Changes.EstimateResolutionEffort
      change UsageAnalyzer.Changes.ProposeSolutions
      change UsageAnalyzer.Changes.CalculateResolutionPriority
    end
    
    update :resolve_pain_point do
      description "Mark pain point as resolved"
      accept [:resolution_status, :proposed_solutions]
      
      change set_attribute(:resolution_status, :resolved)
      change UsageAnalyzer.Changes.ValidateResolution
    end
    
    update :update_priority do
      description "Update resolution priority"
      accept [:resolution_priority, :resolution_effort_estimate]
      
      change UsageAnalyzer.Changes.RecalculatePriority
    end
    
    read :by_report do
      description "Read pain points by analysis report"
      
      argument :report_id, :uuid do
        description "Analysis report ID to filter by"
        allow_nil? false
      end
      
      filter expr(analysis_report_id == ^arg(:report_id))
      prepare build(sort: [severity_level: :desc, user_impact_score: :desc])
    end
    
    read :by_target_dsl do
      description "Read pain points by target DSL"
      
      argument :target_dsl, :string do
        description "Target DSL to filter by"
        allow_nil? false
      end
      
      filter expr(target_dsl == ^arg(:target_dsl))
    end
    
    read :by_severity do
      description "Read pain points by severity level"
      
      argument :severity_level, :atom do
        description "Severity level to filter by"
        allow_nil? false
      end
      
      filter expr(severity_level == ^arg(:severity_level))
    end
    
    read :by_pain_point_type do
      description "Read pain points by type"
      
      argument :pain_point_type, :atom do
        description "Pain point type to filter by"
        allow_nil? false
      end
      
      filter expr(pain_point_type == ^arg(:pain_point_type))
    end
    
    read :high_priority do
      description "Read high-priority pain points"
      
      filter expr(resolution_priority in [:high, :critical])
      prepare build(sort: [resolution_priority: :desc, user_impact_score: :desc])
    end
    
    read :unresolved do
      description "Read unresolved pain points"
      
      filter expr(resolution_status in [:identified, :investigating, :planning, :in_progress])
    end
    
    read :recent do
      description "Read recently identified pain points"
      
      argument :timeframe, :string do
        description "Timeframe to look back"
        default "7d"
      end
      
      prepare UsageAnalyzer.Preparations.FilterByTimeframe
      prepare build(sort: [inserted_at: :desc])
    end
  end
  
  validations do
    validate {UsageAnalyzer.Validations.PainPointNameUnique, within_analysis: true}
    validate {UsageAnalyzer.Validations.ImpactScoresValid, []}
  end
  
  calculations do
    calculate :overall_impact_score, :decimal do
      description "Combined impact score considering all factors"
      calculation UsageAnalyzer.Calculations.OverallImpactScore
    end
    
    calculate :resolution_roi, :decimal do
      description "Return on investment for resolving this pain point"
      calculation UsageAnalyzer.Calculations.ResolutionROI
    end
    
    calculate :urgency_score, :decimal do
      description "Urgency score based on impact and trend"
      calculation UsageAnalyzer.Calculations.UrgencyScore
    end
  end

  def description do
    """
    PainPointAnalysis represents identified friction and issues
    in DSL usage, with impact assessment and resolution planning.
    """
  end
end