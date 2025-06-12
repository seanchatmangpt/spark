defmodule RequirementsParser.Workflows.NlpProcessing do
  use Ash.Reactor

  input :text
  input :language, default: :english
  input :domain, default: :general

  step :tokenize do
    argument :text, input(:text)
    argument :language, input(:language)
    run {RequirementsParser.NLP, :tokenize}
    async? true
  end

  step :extract_entities do
    argument :tokens, result(:tokenize)
    argument :domain, input(:domain)
    run {RequirementsParser.NLP, :extract_entities}
    async? true
  end

  step :analyze_intent do
    argument :tokens, result(:tokenize)
    run {RequirementsParser.NLP, :analyze_intent}
    async? true
  end

  step :identify_features do
    argument :entities, result(:extract_entities)
    argument :intent, result(:analyze_intent)
    run {RequirementsParser.Features, :identify_from_entities}
  end

  step :calculate_confidence do
    argument :entities, result(:extract_entities)
    argument :features, result(:identify_features)
    argument :intent, result(:analyze_intent)
    run {RequirementsParser.Confidence, :calculate_overall}
  end

  step :create_specification do
    argument :original_text, input(:text)
    argument :entities, result(:extract_entities)
    argument :features, result(:identify_features)
    argument :confidence, result(:calculate_confidence)
    argument :domain, input(:domain)
    
    run {RequirementsParser, :create!, [RequirementsParser.Resources.Specification, %{
      original_text: input(:text),
      entities: result(:extract_entities),
      features: result(:identify_features),
      confidence_score: result(:calculate_confidence),
      domain: input(:domain)
    }]}
  end
end