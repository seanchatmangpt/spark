defmodule UsageAnalyzer.Resources.PatternDetection do
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "pattern_detections"
    repo UsageAnalyzer.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :pattern_type, :atom, constraints: [one_of: [:structural, :behavioral, :temporal, :semantic]]
    attribute :pattern_name, :string, allow_nil?: false
    attribute :description, :string
    attribute :frequency, :integer, default: 1
    attribute :confidence, :decimal, constraints: [min: 0.0, max: 1.0]
    attribute :impact_level, :atom, constraints: [one_of: [:low, :medium, :high, :critical]]
    attribute :pattern_data, :map, default: %{}
    attribute :examples, {:array, :map}, default: []
    timestamps()
  end

  relationships do
    belongs_to :analysis_report, UsageAnalyzer.Resources.AnalysisReport
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :detect_pattern do
      accept [:pattern_type, :pattern_name, :description, :frequency, :confidence, :impact_level, :pattern_data, :examples]
      argument :report_id, :uuid, allow_nil?: false
      
      change manage_relationship(:report_id, :analysis_report, type: :replace)
      change UsageAnalyzer.Changes.ValidatePatternData
      change UsageAnalyzer.Changes.CalculateImpact
    end
  end

  calculations do
    calculate :significance_score, :decimal do
      calculation UsageAnalyzer.Calculations.SignificanceScore
    end
  end
end