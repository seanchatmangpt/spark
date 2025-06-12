defmodule EvolutionEngine.Resources.EvolutionRun do
  @moduledoc """
  EvolutionRun resource representing a complete evolution cycle.
  
  An EvolutionRun manages a complete evolutionary algorithm execution
  for improving DSL implementations, tracking populations and generations.
  """
  
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "evolution_runs"
    repo EvolutionEngine.Repo
    
    references do
      reference :individuals, on_delete: :delete
      reference :improvement_trackings, on_delete: :delete
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :target_dsl, :string do
      description "DSL being evolved"
      allow_nil? false
      constraints [min_length: 1, max_length: 200]
    end
    
    attribute :evolution_strategy, :atom do
      description "Evolution strategy being used"
      constraints [one_of: [:genetic, :differential, :particle_swarm, :simulated_annealing, :ab_testing, :hybrid]]
      default :genetic
    end
    
    attribute :population_size, :integer do
      description "Size of the evolution population"
      constraints [min: 1, max: 1000]
      default 50
    end
    
    attribute :max_generations, :integer do
      description "Maximum number of generations"
      constraints [min: 1, max: 10000]
      default 100
    end
    
    attribute :current_generation, :integer do
      description "Current generation number"
      constraints [min: 0]
      default 0
    end
    
    attribute :fitness_threshold, :decimal do
      description "Target fitness threshold"
      constraints [min: 0, max: 1]
      default 0.95
    end
    
    attribute :baseline_fitness, :decimal do
      description "Baseline fitness before evolution"
      constraints [min: 0, max: 1]
    end
    
    attribute :best_fitness_achieved, :decimal do
      description "Best fitness achieved so far"
      constraints [min: 0, max: 1]
    end
    
    attribute :status, :atom do
      description "Current status of evolution run"
      constraints [one_of: [:pending, :running, :completed, :failed, :cancelled, :testing]]
      default :pending
    end
    
    attribute :configuration, :map do
      description "Evolution configuration parameters"
      default %{}
    end
    
    attribute :test_type, :atom do
      description "Type of test for A/B testing runs"
      constraints [one_of: [:improvement_comparison, :strategy_comparison, :parameter_tuning]]
    end
    
    attribute :test_configuration, :map do
      description "Configuration for A/B testing"
      default %{}
    end
    
    attribute :mutation_rate, :decimal do
      description "Mutation rate for genetic algorithms"
      constraints [min: 0, max: 1]
      default 0.1
    end
    
    attribute :crossover_rate, :decimal do
      description "Crossover rate for genetic algorithms"
      constraints [min: 0, max: 1]
      default 0.8
    end
    
    attribute :selection_pressure, :decimal do
      description "Selection pressure parameter"
      constraints [min: 0, max: 10]
      default 2.0
    end
    
    attribute :convergence_threshold, :decimal do
      description "Threshold for determining convergence"
      constraints [min: 0, max: 1]
      default 0.01
    end
    
    attribute :diversity_maintenance, :boolean do
      description "Whether to maintain population diversity"
      default true
    end
    
    attribute :elitism_percentage, :decimal do
      description "Percentage of elite individuals to preserve"
      constraints [min: 0, max: 1]
      default 0.1
    end
    
    attribute :execution_metadata, :map do
      description "Metadata about execution"
      default %{}
    end
    
    attribute :performance_metrics, :map do
      description "Performance metrics for this run"
      default %{}
    end
    
    attribute :resource_usage, :map do
      description "Resource usage during evolution"
      default %{}
    end
    
    timestamps()
  end

  relationships do
    has_many :individuals, EvolutionEngine.Resources.Individual do
      description "Individuals in this evolution run"
    end
    
    has_many :improvement_trackings, EvolutionEngine.Resources.ImprovementTracking do
      description "Improvements tracked for this run"
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :start_evolution do
      description "Start a new evolution run"
      accept [:target_dsl, :evolution_strategy, :population_size, :max_generations, :fitness_threshold, :configuration]
      
      change set_attribute(:status, :running)
      change EvolutionEngine.Changes.InitializePopulation
      change EvolutionEngine.Changes.CalculateBaselineFitness
      
      after_action EvolutionEngine.AfterActions.BeginEvolution
    end
    
    update :advance_generation do
      description "Advance to the next generation"
      accept []
      
      change EvolutionEngine.Changes.EvolvePopulation
      change EvolutionEngine.Changes.UpdateGenerationCounter
      change EvolutionEngine.Changes.CheckConvergence
    end
    
    update :complete_evolution do
      description "Mark evolution as completed"
      accept [:best_fitness_achieved, :performance_metrics]
      
      change set_attribute(:status, :completed)
      change EvolutionEngine.Changes.FinalizeEvolution
    end
    
    read :by_target_dsl do
      description "Read evolution runs by target DSL"
      
      argument :target_dsl, :string do
        description "Target DSL to filter by"
        allow_nil? false
      end
      
      argument :timeframe, :string do
        description "Timeframe to look back"
        default "90d"
      end
      
      filter expr(target_dsl == ^arg(:target_dsl))
      prepare EvolutionEngine.Preparations.FilterByTimeframe
      prepare build(sort: [inserted_at: :desc])
    end
    
    read :by_status do
      description "Read evolution runs by status"
      
      argument :status, :atom do
        description "Status to filter by"
        allow_nil? false
      end
      
      filter expr(status == ^arg(:status))
    end
    
    read :successful do
      description "Read successful evolution runs"
      
      argument :evolution_run_id, :uuid do
        description "Evolution run ID"
        allow_nil? false
      end
      
      argument :threshold, :decimal do
        description "Improvement threshold"
        default 0.1
      end
      
      filter expr(status == :completed and best_fitness_achieved > baseline_fitness + ^arg(:threshold))
      prepare build(sort: [best_fitness_achieved: :desc])
    end
    
    read :recent do
      description "Read recent evolution runs"
      
      argument :timeframe, :string do
        description "Timeframe to look back"
        default "30d"
      end
      
      prepare EvolutionEngine.Preparations.FilterByTimeframe
      prepare build(sort: [inserted_at: :desc])
    end
  end
  
  validations do
    validate {EvolutionEngine.Validations.PopulationSizeValid, []}
    validate {EvolutionEngine.Validations.EvolutionParametersValid, []}
  end
  
  calculations do
    calculate :progress_percentage, :decimal do
      description "Progress as percentage of max generations"
      calculation EvolutionEngine.Calculations.ProgressPercentage
    end
    
    calculate :fitness_improvement, :decimal do
      description "Improvement over baseline fitness"
      calculation EvolutionEngine.Calculations.FitnessImprovement
    end
    
    calculate :convergence_rate, :decimal do
      description "Rate of convergence"
      calculation EvolutionEngine.Calculations.ConvergenceRate
    end
  end

  aggregates do
    count :total_individuals, :individuals do
      description "Total number of individuals"
    end
    
    avg :average_fitness, :individuals, :fitness_score do
      description "Average fitness of population"
    end
    
    max :best_individual_fitness, :individuals, :fitness_score do
      description "Best individual fitness"
    end
  end

  def description do
    """
    EvolutionRun represents a complete evolutionary algorithm execution
    for improving DSL implementations through population-based optimization.
    """
  end
end