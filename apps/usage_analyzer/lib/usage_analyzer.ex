defmodule UsageAnalyzer do
  use Ash.Domain

  resources do
    resource UsageAnalyzer.Resources.AnalysisReport
    resource UsageAnalyzer.Resources.PatternDetection
    resource UsageAnalyzer.Resources.PerformanceMetric
    resource UsageAnalyzer.Resources.UsageInsight
  end

  authorization do
    authorize :by_default
    require_actor? false
  end
end