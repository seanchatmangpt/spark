defmodule AgiFactory do
  use Ash.Domain

  resources do
    resource AgiFactory.Resources.DslProject
    resource AgiFactory.Resources.GenerationRequest
    resource AgiFactory.Resources.QualityAssessment
    resource AgiFactory.Resources.EvolutionCycle
  end

  authorization do
    authorize :by_default
    require_actor? false
  end
end