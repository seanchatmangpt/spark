defmodule UsageAnalyzer.Workflows.ComprehensiveAnalysis do
  use Ash.Reactor

  input :target_dsl
  input :analysis_depth, default: :moderate
  input :time_window, default: "30d"

  step :structural_analysis do
    argument :dsl, input(:target_dsl)
    run {UsageAnalyzer, :create!, [UsageAnalyzer.Resources.AnalysisReport, %{
      target_dsl: input(:target_dsl),
      analysis_type: :patterns,
      analysis_depth: input(:analysis_depth),
      time_window: input(:time_window)
    }]}
    async? true
  end

  step :performance_analysis do
    argument :dsl, input(:target_dsl)
    run {UsageAnalyzer, :create!, [UsageAnalyzer.Resources.AnalysisReport, %{
      target_dsl: input(:target_dsl),
      analysis_type: :performance,
      analysis_depth: input(:analysis_depth),
      time_window: input(:time_window)
    }]}
    async? true
  end

  step :pain_point_analysis do
    argument :dsl, input(:target_dsl)
    run {UsageAnalyzer, :create!, [UsageAnalyzer.Resources.AnalysisReport, %{
      target_dsl: input(:target_dsl),
      analysis_type: :pain_points,
      analysis_depth: input(:analysis_depth),
      time_window: input(:time_window)
    }]}
    async? true
  end

  step :introspection_analysis do
    argument :dsl, input(:target_dsl)
    run {UsageAnalyzer, :create!, [UsageAnalyzer.Resources.AnalysisReport, %{
      target_dsl: input(:target_dsl),
      analysis_type: :introspection,
      analysis_depth: input(:analysis_depth)
    }]}
    async? true
  end

  step :synthesize_insights do
    argument :reports, [
      result(:structural_analysis),
      result(:performance_analysis),
      result(:pain_point_analysis),
      result(:introspection_analysis)
    ]
    run {UsageAnalyzer.Synthesis, :combine_analyses}
  end

  step :generate_recommendations do
    argument :insights, result(:synthesize_insights)
    argument :target_dsl, input(:target_dsl)
    run {UsageAnalyzer.Recommendations, :generate_actionable}
  end

  step :create_master_report do
    argument :insights, result(:synthesize_insights)
    argument :recommendations, result(:generate_recommendations)
    run {UsageAnalyzer.Reporting, :create_comprehensive_report}
  end
end