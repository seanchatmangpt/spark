defmodule AgiFactory.Workflows.DslGeneration do
  use Ash.Reactor

  input :dsl_project_id
  input :options, default: %{}

  step :load_project do
    argument :id, input(:dsl_project_id)
    run {AgiFactory, :get!, [AgiFactory.Resources.DslProject, input(:dsl_project_id)]}
  end

  step :parse_requirements do
    argument :project, result(:load_project)
    run {RequirementsParser.Actions, :parse_project_requirements}
    async? true
  end

  step :analyze_patterns do
    argument :specification, result(:parse_requirements)
    run {UsageAnalyzer.Actions, :analyze_for_generation}
    async? true
  end

  step :generate_strategies do
    argument :specification, result(:parse_requirements)
    argument :patterns, result(:analyze_patterns)
    argument :strategy_count, path(input(:options), :strategy_count)
    run {DslSynthesizer.Actions, :generate_multiple_strategies}
    max_retries 3
  end

  step :evaluate_strategies do
    argument :strategies, result(:generate_strategies)
    argument :criteria, path(input(:options), :quality_criteria)
    run {AgiFactory.QualityAssurance.Actions, :evaluate_all}
  end

  step :select_optimal do
    argument :strategies, result(:generate_strategies)
    argument :evaluations, result(:evaluate_strategies)
    run {AgiFactory.Selection.Actions, :choose_best}
  end

  step :generate_code do
    argument :selected_strategy, result(:select_optimal)
    argument :mode, path(input(:options), :mode)
    run {DslSynthesizer.Actions, :generate_final_code}
  end

  step :update_project do
    argument :project, result(:load_project)
    argument :generated_code, result(:generate_code)
    argument :quality_score, path(result(:evaluate_strategies), :best_score)
    run {AgiFactory, :update!, [result(:load_project), %{
      generated_code: result(:generate_code),
      quality_score: path(result(:evaluate_strategies), :best_score),
      status: :testing
    }]}
  end

  compensate :mark_failed do
    run {AgiFactory, :update!, [result(:load_project), %{status: :failed}]}
  end

  compensate :cleanup_artifacts do
    run {AgiFactory.Cleanup, :remove_generation_artifacts}
  end
end