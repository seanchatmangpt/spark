defmodule DslSynthesizer.Workflows.MultiStrategyGeneration do
  use Ash.Reactor

  input :specification
  input :strategy_count, default: 5
  input :parallel_limit, default: 3

  step :template_strategy do
    argument :spec, input(:specification)
    run {DslSynthesizer, :create!, [DslSynthesizer.Resources.GenerationStrategy, %{
      name: :template_generation,
      strategy_type: :template,
      specification: input(:specification)
    }]}
    async? true
  end

  step :pattern_strategy do
    argument :spec, input(:specification)
    run {DslSynthesizer, :create!, [DslSynthesizer.Resources.GenerationStrategy, %{
      name: :pattern_generation,
      strategy_type: :pattern_based,
      specification: input(:specification)
    }]}
    async? true
  end

  step :ai_strategy do
    argument :spec, input(:specification)
    run {DslSynthesizer, :create!, [DslSynthesizer.Resources.GenerationStrategy, %{
      name: :ai_generation,
      strategy_type: :ai_assisted,
      specification: input(:specification)
    }]}
    async? true
  end

  step :hybrid_strategy do
    argument :spec, input(:specification)
    run {DslSynthesizer, :create!, [DslSynthesizer.Resources.GenerationStrategy, %{
      name: :hybrid_generation,
      strategy_type: :hybrid,
      specification: input(:specification)
    }]}
    async? true
  end

  step :example_strategy do
    argument :spec, input(:specification)
    run {DslSynthesizer, :create!, [DslSynthesizer.Resources.GenerationStrategy, %{
      name: :example_generation,
      strategy_type: :example_driven,
      specification: input(:specification)
    }]}
    async? true
  end

  step :evaluate_strategies do
    argument :strategies, [
      result(:template_strategy),
      result(:pattern_strategy),
      result(:ai_strategy),
      result(:hybrid_strategy),
      result(:example_strategy)
    ]
    run {DslSynthesizer.Evaluation, :compare_strategies}
  end

  step :select_best do
    argument :evaluations, result(:evaluate_strategies)
    run {DslSynthesizer.Selection, :choose_optimal}
  end

  step :generate_final_candidates do
    argument :best_strategy, result(:select_best)
    argument :candidate_count, input(:strategy_count)
    run {DslSynthesizer.Generation, :create_candidates}
  end
end