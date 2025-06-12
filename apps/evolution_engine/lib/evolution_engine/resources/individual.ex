defmodule EvolutionEngine.Resources.Individual do
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "individuals"
    repo EvolutionEngine.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :genome, :map, allow_nil?: false
    attribute :fitness, :decimal
    attribute :age, :integer, default: 0
    attribute :generation, :integer, default: 0
    attribute :parent_ids, {:array, :string}, default: []
    attribute :mutation_count, :integer, default: 0
    attribute :crossover_count, :integer, default: 0
    attribute :phenotype, :map
    attribute :metadata, :map, default: %{}
    timestamps()
  end

  relationships do
    belongs_to :evolution_run, EvolutionEngine.Resources.EvolutionRun
    has_many :fitness_scores, EvolutionEngine.Resources.FitnessScore
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :initialize_random do
      argument :run_id, :uuid, allow_nil?: false
      argument :genome_template, :map, allow_nil?: false
      
      change manage_relationship(:run_id, :evolution_run, type: :replace)
      change EvolutionEngine.Changes.GenerateRandomGenome
      change EvolutionEngine.Changes.CalculateInitialFitness
    end
    
    create :crossover do
      argument :parent1_id, :uuid, allow_nil?: false
      argument :parent2_id, :uuid, allow_nil?: false
      argument :run_id, :uuid, allow_nil?: false
      
      change manage_relationship(:run_id, :evolution_run, type: :replace)
      change EvolutionEngine.Changes.PerformCrossover
      change EvolutionEngine.Changes.IncrementCrossoverCount
    end
    
    update :mutate do
      argument :mutation_rate, :decimal, allow_nil?: false
      
      change EvolutionEngine.Changes.ApplyMutation
      change EvolutionEngine.Changes.IncrementMutationCount
      change EvolutionEngine.Changes.RecalculateFitness
    end
    
    update :age do
      change EvolutionEngine.Changes.IncrementAge
    end
  end

  calculations do
    calculate :diversity_contribution, :decimal do
      calculation EvolutionEngine.Calculations.DiversityContribution
    end
    
    calculate :survival_probability, :decimal do
      calculation EvolutionEngine.Calculations.SurvivalProbability
    end
  end
end