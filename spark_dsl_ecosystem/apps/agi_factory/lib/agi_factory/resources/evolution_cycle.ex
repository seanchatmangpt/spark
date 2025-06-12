defmodule AgiFactory.Resources.EvolutionCycle do
  @moduledoc """
  Evolution Cycle resource for tracking continuous DSL improvement.
  
  Represents a single cycle of evolution including analysis of current state,
  generation of improvements, testing, and application of successful changes.
  """
  
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "evolution_cycles"
    repo AgiFactory.Repo
    
    references do
      reference :dsl_project, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :cycle_number, :integer do
      description "Sequential cycle number for this project"
      constraints [min: 1]
      allow_nil? false
    end
    
    attribute :evolution_strategy, :atom do
      description "Evolution strategy used in this cycle"
      constraints [one_of: [:genetic, :gradient_descent, :random_search, :bayesian, :hybrid]]
      default :genetic
    end
    
    attribute :status, :atom do
      description "Current cycle status"
      constraints [one_of: [:initializing, :analyzing, :generating, :testing, :applying, :completed, :failed]]
      default :initializing
    end
    
    attribute :trigger_reason, :atom do
      description "What triggered this evolution cycle"
      constraints [one_of: [:scheduled, :performance_degradation, :quality_issues, :user_feedback, :manual]]
    end
    
    attribute :baseline_metrics, :map do
      description "Metrics before evolution started"
      default %{}
    end
    
    attribute :target_metrics, :map do
      description "Target metrics to achieve"
      default %{}
    end
    
    attribute :improvements_generated, :integer do
      description "Number of improvement candidates generated"
      constraints [min: 0]
      default 0
    end
    
    attribute :improvements_tested, :integer do
      description "Number of improvements that were tested"
      constraints [min: 0]
      default 0
    end
    
    attribute :improvements_applied, :integer do
      description "Number of improvements successfully applied"
      constraints [min: 0]
      default 0
    end
    
    attribute :final_metrics, :map do
      description "Metrics after evolution completed"
      default %{}
    end
    
    attribute :performance_improvement, :decimal do
      description "Overall performance improvement percentage"
    end
    
    attribute :quality_improvement, :decimal do
      description "Quality improvement percentage"
    end
    
    attribute :evolution_data, :map do
      description "Detailed evolution process data"
      default %{}
    end
    
    attribute :lessons_learned, {:array, :string} do
      description "Insights gained from this evolution cycle"
      default []
    end
    
    attribute :next_cycle_recommendations, {:array, :string} do
      description "Recommendations for the next evolution cycle"
      default []
    end
    
    attribute :started_at, :utc_datetime do
      description "When the evolution cycle started"
    end
    
    attribute :completed_at, :utc_datetime do
      description "When the evolution cycle completed"
    end
    
    attribute :duration_ms, :integer do
      description "Total duration of the evolution cycle in milliseconds"
      constraints [min: 0]
    end
    
    timestamps()
  end

  relationships do
    belongs_to :dsl_project, AgiFactory.Resources.DslProject do
      description "The DSL project being evolved"
      allow_nil? false
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :start_evolution do
      description "Starts a new evolution cycle"
      accept [:evolution_strategy, :trigger_reason, :target_metrics]
      
      argument :dsl_project_id, :uuid do
        description "ID of the DSL project to evolve"
        allow_nil? false
      end
      
      argument :evolution_options, :map do
        description "Options for the evolution process"
        default %{}
      end
      
      change AgiFactory.Changes.ValidateEvolutionTarget
      change AgiFactory.Changes.CaptureBaselineMetrics
      change AgiFactory.Changes.CalculateCycleNumber
      change set_attribute(:status, :analyzing)
      change set_attribute(:started_at, &DateTime.utc_now/0)
      change relate_actor(:dsl_project, argument(:dsl_project_id))
      
      after_action AgiFactory.AfterActions.StartEvolutionWorkflow
    end
    
    update :advance_to_generating do
      description "Advances cycle to the generating phase"
      accept [:improvements_generated]
      
      change AgiFactory.Changes.ValidateAnalysisComplete
      change set_attribute(:status, :generating)
    end
    
    update :advance_to_testing do
      description "Advances cycle to the testing phase"
      accept [:improvements_tested]
      
      change AgiFactory.Changes.ValidateImprovementsGenerated
      change set_attribute(:status, :testing)
    end
    
    update :advance_to_applying do
      description "Advances cycle to the applying phase"
      accept []
      
      change AgiFactory.Changes.ValidateTestingComplete
      change set_attribute(:status, :applying)
    end
    
    update :complete_successfully do
      description "Marks evolution cycle as successfully completed"
      accept [:improvements_applied, :final_metrics, :performance_improvement, :quality_improvement, :lessons_learned, :next_cycle_recommendations]
      
      change AgiFactory.Changes.ValidateEvolutionResults
      change AgiFactory.Changes.CalculateDuration
      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
      
      after_action AgiFactory.AfterActions.UpdateProjectWithEvolution
      after_action AgiFactory.AfterActions.ScheduleNextCycle
    end
    
    update :mark_failed do
      description "Marks evolution cycle as failed"
      accept []
      
      argument :failure_reason, :string do
        description "Reason for the failure"
        allow_nil? false
      end
      
      change AgiFactory.Changes.RecordEvolutionFailure
      change AgiFactory.Changes.CalculateDuration
      change set_attribute(:status, :failed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
      
      after_action AgiFactory.AfterActions.HandleEvolutionFailure
    end
    
    read :by_project do
      description "Read evolution cycles for a specific project"
      
      argument :dsl_project_id, :uuid do
        description "DSL project ID"
        allow_nil? false
      end
      
      filter expr(dsl_project_id == ^arg(:dsl_project_id))
      prepare build(sort: [cycle_number: :desc])
    end
    
    read :successful do
      description "Read only successfully completed cycles"
      filter expr(status == :completed)
      prepare build(sort: [completed_at: :desc])
    end
    
    read :by_strategy do
      description "Read cycles by evolution strategy"
      
      argument :strategy, :atom do
        description "Evolution strategy to filter by"
        allow_nil? false
        constraints [one_of: [:genetic, :gradient_descent, :random_search, :bayesian, :hybrid]]
      end
      
      filter expr(evolution_strategy == ^arg(:strategy))
    end
    
    read :high_impact do
      description "Read cycles that achieved significant improvements"
      
      argument :minimum_improvement, :decimal do
        description "Minimum improvement percentage"
        default 10.0
      end
      
      filter expr(performance_improvement >= ^arg(:minimum_improvement) or quality_improvement >= ^arg(:minimum_improvement))
    end
    
    read :recent do
      description "Read recent evolution cycles"
      
      argument :days, :integer do
        description "Number of days back to look"
        default 30
      end
      
      filter expr(started_at >= ago(^arg(:days), :day))
      prepare build(sort: [started_at: :desc])
    end
  end
  
  validations do
    validate {AgiFactory.Validations.EvolutionMetrics, []}
    validate {AgiFactory.Validations.ImprovementConsistency, []}
  end
  
  calculations do
    calculate :success_rate, :decimal do
      description "Success rate of improvements in this cycle"
      calculation AgiFactory.Calculations.EvolutionSuccessRate
    end
    
    calculate :efficiency_score, :decimal do
      description "Efficiency of the evolution process"
      calculation AgiFactory.Calculations.EvolutionEfficiency
    end
    
    calculate :impact_score, :decimal do
      description "Overall impact of this evolution cycle"
      calculation AgiFactory.Calculations.EvolutionImpact
    end
    
    calculate :duration_hours, :decimal do
      description "Duration of evolution cycle in hours"
      calculation AgiFactory.Calculations.EvolutionDurationHours
    end
  end

  def description do
    """
    Evolution Cycle tracks a complete cycle of continuous improvement
    for a DSL project, including analysis, generation of improvements,
    testing, and application of successful changes.
    """
  end
end