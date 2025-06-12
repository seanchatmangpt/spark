defmodule DslSynthesizer.Resources.GenerationStrategy do
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "generation_strategies"
    repo DslSynthesizer.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :atom, allow_nil?: false
    attribute :description, :string
    attribute :strategy_type, :atom, constraints: [one_of: [:template, :pattern_based, :example_driven, :hybrid, :ai_assisted]]
    attribute :configuration, :map, default: %{}
    attribute :success_rate, :decimal, default: 0.0, constraints: [min: 0.0, max: 1.0]
    attribute :performance_metrics, :map, default: %{}
    attribute :priority, :integer, default: 1
    attribute :active, :boolean, default: true
    attribute :version, :string, default: "1.0.0"
    timestamps()
  end

  relationships do
    has_many :code_candidates, DslSynthesizer.Resources.CodeCandidate
    has_many :quality_metrics, DslSynthesizer.Resources.QualityMetrics
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :generate_code do
      accept [:name, :strategy_type, :configuration, :priority]
      argument :specification, :map, allow_nil?: false
      argument :patterns, {:array, :map}, default: []
      argument :context, :map, default: %{}
      
      change DslSynthesizer.Changes.ValidateSpecification
      change DslSynthesizer.Changes.ApplyStrategy
      change DslSynthesizer.Changes.OptimizeGenerated
      change DslSynthesizer.Changes.ValidateOutput
      
      after_action DslSynthesizer.AfterActions.CreateCodeCandidate
      after_action DslSynthesizer.AfterActions.UpdateMetrics
    end
    
    update :optimize_strategy do
      accept [:configuration, :performance_metrics]
      
      change DslSynthesizer.Changes.OptimizeConfiguration
      change DslSynthesizer.Changes.UpdateSuccessRate
    end
    
    update :activate do
      change set_attribute(:active, true)
    end
    
    update :deactivate do
      change set_attribute(:active, false)
    end
  end

  validations do
    validate {DslSynthesizer.Validations.ValidConfiguration, []}
    validate {DslSynthesizer.Validations.SuccessRateRange, []}
  end

  calculations do
    calculate :efficiency_score, :decimal do
      calculation DslSynthesizer.Calculations.EfficiencyScore
    end
    
    calculate :recent_performance, :decimal do
      calculation DslSynthesizer.Calculations.RecentPerformance
    end
    
    calculate :complexity_handling, :atom do
      calculation DslSynthesizer.Calculations.ComplexityHandling
    end
  end
end