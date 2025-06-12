defmodule DslSynthesizer.Resources.CodeCandidate do
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "code_candidates"
    repo DslSynthesizer.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :generated_code, :string, allow_nil?: false
    attribute :language, :atom, default: :elixir
    attribute :syntax_valid, :boolean
    attribute :compilation_status, :atom, constraints: [one_of: [:pending, :success, :failed]]
    attribute :test_results, :map, default: %{}
    attribute :quality_score, :decimal, constraints: [min: 0.0, max: 1.0]
    attribute :performance_metrics, :map, default: %{}
    attribute :metadata, :map, default: %{}
    timestamps()
  end

  relationships do
    belongs_to :generation_strategy, DslSynthesizer.Resources.GenerationStrategy
    has_many :quality_metrics, DslSynthesizer.Resources.QualityMetrics
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :generate_from_strategy do
      accept [:generated_code, :language, :metadata]
      argument :strategy_id, :uuid, allow_nil?: false
      argument :specification, :map, allow_nil?: false
      
      change manage_relationship(:strategy_id, :generation_strategy, type: :replace)
      change DslSynthesizer.Changes.ValidateSyntax
      change DslSynthesizer.Changes.CompileCode
      change DslSynthesizer.Changes.CalculateQuality
    end
    
    update :run_tests do
      change DslSynthesizer.Changes.ExecuteTests
      change DslSynthesizer.Changes.UpdateTestResults
    end
  end

  calculations do
    calculate :readiness_score, :decimal do
      calculation DslSynthesizer.Calculations.ReadinessScore
    end
  end
end