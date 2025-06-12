defmodule DslSynthesizer.Resources.OptimizationResult do
  @moduledoc """
  OptimizationResult resource representing applied optimizations.
  
  OptimizationResult tracks optimizations applied to generated code
  and their impact on quality and performance metrics.
  """
  
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "optimization_results"
    repo DslSynthesizer.Repo
  end

  attributes do
    uuid_primary_key :id
    
    attribute :optimization_type, :atom do
      description "Type of optimization applied"
      allow_nil? false
      constraints [one_of: [:performance, :readability, :maintainability, :size, :complexity, :security, :custom]]
    end
    
    attribute :optimization_name, :string do
      description "Specific name of the optimization"
      allow_nil? false
      constraints [min_length: 1, max_length: 100]
    end
    
    attribute :description, :string do
      description "Description of what was optimized"
      constraints [max_length: 500]
    end
    
    attribute :target_code_candidate_id, :uuid do
      description "ID of the code candidate that was optimized"
      allow_nil? false
    end
    
    attribute :before_metrics, :map do
      description "Metrics before optimization"
      default %{}
    end
    
    attribute :after_metrics, :map do
      description "Metrics after optimization"
      default %{}
    end
    
    attribute :improvement_percentage, :decimal do
      description "Percentage improvement achieved"
      constraints [min: -100, max: 1000] # Allow for degradation and huge improvements
    end
    
    attribute :optimization_strategy, :string do
      description "Strategy used for optimization"
      constraints [max_length: 100]
    end
    
    attribute :applied_techniques, {:array, :string} do
      description "Specific techniques applied"
      default []
    end
    
    attribute :processing_time_ms, :integer do
      description "Time taken to apply optimization"
      constraints [min: 0]
    end
    
    attribute :success_status, :atom do
      description "Success status of optimization"
      constraints [one_of: [:successful, :partially_successful, :failed, :reverted]]
      default :successful
    end
    
    attribute :side_effects, {:array, :string} do
      description "Any side effects or trade-offs"
      default []
    end
    
    attribute :optimization_parameters, :map do
      description "Parameters used for optimization"
      default %{}
    end
    
    attribute :validation_results, :map do
      description "Results of post-optimization validation"
      default %{}
    end
    
    attribute :reviewer_approval, :boolean do
      description "Whether optimization was approved by reviewer"
      default false
    end
    
    attribute :rollback_available, :boolean do
      description "Whether this optimization can be rolled back"
      default true
    end
    
    attribute :optimization_metadata, :map do
      description "Additional metadata about the optimization"
      default %{}
    end
    
    timestamps()
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :apply_optimization do
      description "Apply an optimization to code"
      accept [:optimization_type, :optimization_name, :target_code_candidate_id, :optimization_parameters]
      
      change DslSynthesizer.Changes.CaptureBeforeMetrics
      change DslSynthesizer.Changes.ApplyOptimizationTechniques
      change DslSynthesizer.Changes.CaptureAfterMetrics
      change DslSynthesizer.Changes.CalculateImprovement
      
      after_action DslSynthesizer.AfterActions.ValidateOptimization
    end
    
    update :approve_optimization do
      description "Approve the applied optimization"
      accept [:reviewer_approval]
      
      change DslSynthesizer.Changes.ProcessApproval
    end
    
    update :rollback_optimization do
      description "Rollback the optimization"
      accept []
      
      change set_attribute(:success_status, :reverted)
      change DslSynthesizer.Changes.RevertOptimization
    end
    
    read :by_candidate do
      description "Read optimizations by code candidate"
      
      argument :candidate_id, :uuid do
        description "Code candidate ID to filter by"
        allow_nil? false
      end
      
      filter expr(target_code_candidate_id == ^arg(:candidate_id))
      prepare build(sort: [inserted_at: :desc])
    end
    
    read :by_optimization_type do
      description "Read optimizations by type"
      
      argument :optimization_type, :atom do
        description "Optimization type to filter by"
        allow_nil? false
      end
      
      filter expr(optimization_type == ^arg(:optimization_type))
    end
    
    read :successful do
      description "Read successful optimizations"
      
      filter expr(success_status == :successful)
      prepare build(sort: [improvement_percentage: :desc])
    end
    
    read :high_impact do
      description "Read optimizations with high impact"
      
      argument :minimum_improvement, :decimal do
        description "Minimum improvement percentage"
        default 10.0
      end
      
      filter expr(improvement_percentage >= ^arg(:minimum_improvement))
    end
    
    read :pending_approval do
      description "Read optimizations pending approval"
      
      filter expr(reviewer_approval == false and success_status == :successful)
    end
  end
  
  validations do
    validate {DslSynthesizer.Validations.OptimizationValid, []}
    validate {DslSynthesizer.Validations.MetricsConsistent, []}
  end
  
  calculations do
    calculate :net_benefit, :decimal do
      description "Net benefit considering side effects"
      calculation DslSynthesizer.Calculations.NetBenefit
    end
    
    calculate :risk_score, :decimal do
      description "Risk score for this optimization"
      calculation DslSynthesizer.Calculations.OptimizationRisk
    end
    
    calculate :efficiency_gain, :decimal do
      description "Efficiency gain per unit of processing time"
      calculation DslSynthesizer.Calculations.EfficiencyGain
    end
  end

  def description do
    """
    OptimizationResult tracks applied optimizations and their
    impact on code quality and performance metrics.
    """
  end
end