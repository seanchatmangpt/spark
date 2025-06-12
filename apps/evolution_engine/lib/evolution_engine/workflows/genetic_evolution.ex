defmodule EvolutionEngine.Workflows.GeneticEvolution do
  use Ash.Reactor

  input :target_dsl
  input :population_size, default: 100
  input :max_generations, default: 50
  input :fitness_threshold, default: 0.95

  step :initialize_run do
    argument :target, input(:target_dsl)
    argument :pop_size, input(:population_size)
    argument :max_gen, input(:max_generations)
    
    run {EvolutionEngine, :create!, [EvolutionEngine.Resources.EvolutionRun, %{
      target_dsl: input(:target_dsl),
      population_size: input(:population_size),
      max_generations: input(:max_generations)
    }]}
  end

  step :create_initial_population do
    argument :run, result(:initialize_run)
    argument :size, input(:population_size)
    run {EvolutionEngine.Population, :initialize_random}
    async? true
  end

  step :evaluate_initial_fitness do
    argument :population, result(:create_initial_population)
    run {EvolutionEngine.Fitness, :evaluate_population}
  end

  step :evolution_loop do
    argument :run, result(:initialize_run)
    argument :population, result(:create_initial_population)
    argument :threshold, input(:fitness_threshold)
    run {EvolutionEngine.Loop, :evolve_until_convergence}
    max_retries 0
    timeout :timer.minutes(30)
  end

  step :extract_best_solution do
    argument :final_population, result(:evolution_loop)
    run {EvolutionEngine.Selection, :extract_elite}
  end

  step :generate_report do
    argument :run, result(:initialize_run)
    argument :best_solution, result(:extract_best_solution)
    run {EvolutionEngine.Reporting, :create_evolution_report}
  end

  compensate :cleanup_failed_run do
    argument :run, result(:initialize_run)
    run {EvolutionEngine, :update!, [result(:initialize_run), %{status: :failed}]}
  end
end