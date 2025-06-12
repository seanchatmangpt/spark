defmodule EvolutionEngine do
  use Ash.Domain

  resources do
    resource EvolutionEngine.Resources.EvolutionRun
    resource EvolutionEngine.Resources.Individual
    resource EvolutionEngine.Resources.FitnessScore
    resource EvolutionEngine.Resources.GeneticOperator
  end

  authorization do
    authorize :by_default
    require_actor? false
  end
end