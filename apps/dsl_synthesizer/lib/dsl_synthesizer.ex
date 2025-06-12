defmodule DslSynthesizer do
  use Ash.Domain

  resources do
    resource DslSynthesizer.Resources.GenerationStrategy
    resource DslSynthesizer.Resources.CodeCandidate
    resource DslSynthesizer.Resources.QualityMetrics
    resource DslSynthesizer.Resources.TemplateEngine
  end

  authorization do
    authorize :by_default
    require_actor? false
  end
end