defmodule EvolutionEngine.Resources.EvolutionRun do
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "evolution_runs"
    repo EvolutionEngine.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :target_dsl, :string, allow_nil?: false
    attribute :generation, :integer, default: 0
    attribute :population_size, :integer, default: 100, constraints: [min: 10, max: 1000]
    attribute :status, :atom, constraints: [one_of: [:initializing, :evolving, :converged, :terminated, :failed]], default: :initializing
    attribute :best_fitness, :decimal
    attribute :average_fitness, :decimal
    attribute :diversity_score, :decimal
    attribute :configuration, :map, default: %{}
    attribute :termination_criteria, :map, default: %{}
    attribute :mutation_rate, :decimal, default: 0.1, constraints: [min: 0.0, max: 1.0]
    attribute :crossover_rate, :decimal, default: 0.8, constraints: [min: 0.0, max: 1.0]
    attribute :elite_size, :integer, default: 10
    attribute :max_generations, :integer, default: 100
    timestamps()
  end

  relationships do
    has_many :individuals, EvolutionEngine.Resources.Individual
    has_many :fitness_scores, EvolutionEngine.Resources.FitnessScore
    has_many :genetic_operators, EvolutionEngine.Resources.GeneticOperator
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :start_evolution do
      accept [:target_dsl, :population_size, :configuration, :mutation_rate, :crossover_rate, :max_generations]
      
      change EvolutionEngine.Changes.ValidateConfiguration
      change EvolutionEngine.Changes.InitializePopulation
      change set_attribute(:status, :evolving)
      
      after_action EvolutionEngine.AfterActions.StartEvolutionLoop
      after_action EvolutionEngine.AfterActions.NotifyEvolutionStart
    end
    
    update :evolve_generation do
      change EvolutionEngine.Changes.EvaluateFitness
      change EvolutionEngine.Changes.SelectParents
      change EvolutionEngine.Changes.CreateOffspring
      change EvolutionEngine.Changes.ApplyMutations
      change EvolutionEngine.Changes.UpdateGeneration
      change EvolutionEngine.Changes.CheckTermination
      
      after_action EvolutionEngine.AfterActions.UpdateStatistics
    end
    
    update :terminate_evolution do
      accept [:best_fitness, :average_fitness, :diversity_score]
      argument :termination_reason, :atom
      
      change set_attribute(:status, :terminated)
      change EvolutionEngine.Changes.RecordTerminationReason
      
      after_action EvolutionEngine.AfterActions.GenerateFinalReport
    end
    
    update :mark_converged do
      accept [:best_fitness, :average_fitness]
      
      change set_attribute(:status, :converged)
      
      after_action EvolutionEngine.AfterActions.ExtractBestSolution
    end
  end

  validations do
    validate {EvolutionEngine.Validations.ValidPopulationSize, []}
    validate {EvolutionEngine.Validations.ValidRates, []}
    validate {EvolutionEngine.Validations.EliteSizeConstraint, []}
  end

  calculations do
    calculate :convergence_rate, :decimal do
      calculation EvolutionEngine.Calculations.ConvergenceRate
    end
    
    calculate :diversity_trend, :atom do
      calculation EvolutionEngine.Calculations.DiversityTrend
    end
    
    calculate :improvement_rate, :decimal do
      calculation EvolutionEngine.Calculations.ImprovementRate
    end
    
    calculate :estimated_completion, :utc_datetime do
      calculation EvolutionEngine.Calculations.EstimatedCompletion
    end
  end
end