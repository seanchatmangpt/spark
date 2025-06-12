defmodule RequirementsParser do
  use Ash.Domain

  resources do
    resource RequirementsParser.Resources.Specification
    resource RequirementsParser.Resources.ParsedEntity
    resource RequirementsParser.Resources.FeatureExtraction
    resource RequirementsParser.Resources.NlpAnalysis
  end

  authorization do
    authorize :by_default
    require_actor? false
  end
end