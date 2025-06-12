defmodule UsageAnalyzer do
  @moduledoc """
  UsageAnalyzer - Real-World DSL Usage Intelligence Domain
  
  This Ash domain provides comprehensive analysis of how DSLs are used
  in practice, identifying patterns, pain points, and optimization
  opportunities through static analysis, runtime telemetry, and user feedback.
  
  ## Architecture
  
  The domain manages:
  - AnalysisReports (comprehensive usage analysis results)
  - PatternDetections (identified usage patterns)
  - PerformanceMetrics (runtime and compile-time performance data)
  - PainPointAnalyses (identified friction and issues)
  
  ## Usage
  
      # Analyze DSL usage patterns
      {:ok, report} = UsageAnalyzer.create!(UsageAnalyzer.Resources.AnalysisReport, %{
        target_dsl: "MyApp.ApiDsl",
        analysis_type: :patterns,
        data_sources: [:local, :github]
      })
      
      # Get pattern detections
      patterns = UsageAnalyzer.read!(UsageAnalyzer.Resources.PatternDetection,
        :by_report, %{report_id: report.id})
  """
  
  use Ash.Domain

  resources do
    resource UsageAnalyzer.Resources.AnalysisReport
    resource UsageAnalyzer.Resources.PatternDetection
    resource UsageAnalyzer.Resources.PerformanceMetric
    resource UsageAnalyzer.Resources.PainPointAnalysis
  end

  authorization do
    authorize :by_default
    require_actor? false
  end

  @doc """
  Analyzes DSL usage across codebases and repositories.
  """
  def analyze_dsl_usage(target_dsl, opts \\ %{}) do
    analysis_type = Map.get(opts, :analysis_type, :comprehensive)
    data_sources = Map.get(opts, :data_sources, [:local])
    time_window = Map.get(opts, :time_window, "30d")
    
    Ash.create!(UsageAnalyzer.Resources.AnalysisReport, %{
      target_dsl: target_dsl,
      analysis_type: analysis_type,
      data_sources: data_sources,
      time_window: time_window,
      analysis_options: opts
    })
  end

  @doc """
  Collects real-time telemetry data for a DSL.
  """
  def start_telemetry_collection(dsl_module, duration_ms \\ 300_000) do
    Ash.create!(UsageAnalyzer.Resources.PerformanceMetric, %{
      target_dsl: inspect(dsl_module),
      metric_type: :telemetry_collection,
      collection_duration_ms: duration_ms,
      status: :collecting
    })
  end

  @doc """
  Identifies pain points in DSL usage.
  """
  def identify_pain_points(target_dsl, opts \\ %{}) do
    analysis_scope = Map.get(opts, :scope, :comprehensive)
    data_sources = Map.get(opts, :data_sources, [:local, :telemetry])
    
    Ash.create!(UsageAnalyzer.Resources.PainPointAnalysis, %{
      target_dsl: target_dsl,
      analysis_scope: analysis_scope,
      data_sources: data_sources,
      analysis_options: opts
    })
  end

  @doc """
  Analyzes performance characteristics of a DSL.
  """
  def analyze_performance(target_dsl, workload_type \\ :standard) do
    Ash.create!(UsageAnalyzer.Resources.PerformanceMetric, %{
      target_dsl: target_dsl,
      metric_type: :performance_analysis,
      workload_type: workload_type,
      status: :analyzing
    })
  end

  @doc """
  Generates comprehensive usage report.
  """
  def generate_usage_report(target_dsl, opts \\ %{}) do
    include_patterns = Map.get(opts, :include_patterns, true)
    include_performance = Map.get(opts, :include_performance, true)
    include_pain_points = Map.get(opts, :include_pain_points, true)
    time_window = Map.get(opts, :time_window, "30d")
    
    # Create main analysis report
    {:ok, report} = create!(UsageAnalyzer.Resources.AnalysisReport, %{
      target_dsl: target_dsl,
      analysis_type: :comprehensive,
      time_window: time_window,
      include_patterns: include_patterns,
      include_performance: include_performance,
      include_pain_points: include_pain_points
    })
    
    # Collect additional data if requested
    additional_analyses = []
    
    if include_patterns do
      {:ok, pattern_analysis} = Ash.create!(UsageAnalyzer.Resources.PatternDetection, %{
        analysis_report_id: report.id,
        target_dsl: target_dsl,
        detection_scope: :comprehensive
      })
      additional_analyses = [pattern_analysis | additional_analyses]
    end
    
    if include_performance do
      {:ok, perf_analysis} = Ash.create!(UsageAnalyzer.Resources.PerformanceMetric, %{
        analysis_report_id: report.id,
        target_dsl: target_dsl,
        metric_type: :comprehensive_analysis
      })
      additional_analyses = [perf_analysis | additional_analyses]
    end
    
    if include_pain_points do
      {:ok, pain_analysis} = Ash.create!(UsageAnalyzer.Resources.PainPointAnalysis, %{
        analysis_report_id: report.id,
        target_dsl: target_dsl,
        analysis_scope: :comprehensive
      })
      additional_analyses = [pain_analysis | additional_analyses]
    end
    
    {:ok, %{
      main_report: report,
      additional_analyses: additional_analyses,
      summary: generate_report_summary(report, additional_analyses)
    }}
  end

  @doc """
  Compares usage patterns between different DSLs.
  """
  def compare_dsls(dsl_list, comparison_criteria \\ []) do
    reports = Enum.map(dsl_list, fn dsl ->
      {:ok, report} = analyze_dsl_usage(dsl, %{analysis_type: :comparison})
      report
    end)
    
    comparison_results = %{
      dsls_compared: dsl_list,
      individual_reports: reports,
      comparative_analysis: perform_comparative_analysis(reports, comparison_criteria),
      recommendations: generate_comparison_recommendations(reports)
    }
    
    {:ok, comparison_results}
  end

  @doc """
  Analyzes trends in DSL usage over time.
  """
  def analyze_usage_trends(target_dsl, time_periods \\ ["7d", "30d", "90d"]) do
    trend_data = Enum.map(time_periods, fn period ->
      {:ok, report} = analyze_dsl_usage(target_dsl, %{
        analysis_type: :trends,
        time_window: period
      })
      {period, report}
    end)
    
    %{
      target_dsl: target_dsl,
      time_periods: time_periods,
      trend_data: trend_data,
      trend_analysis: analyze_trend_patterns(trend_data),
      predictions: generate_trend_predictions(trend_data)
    }
  end

  @doc """
  Gets usage analytics for monitoring dashboards.
  """
  def get_usage_analytics(opts \\ %{}) do
    timeframe = Map.get(opts, :timeframe, "7d")
    
    reports = Ash.read!(UsageAnalyzer.Resources.AnalysisReport, 
      :recent, %{timeframe: timeframe})
    patterns = Ash.read!(UsageAnalyzer.Resources.PatternDetection, 
      :recent, %{timeframe: timeframe})
    performance_metrics = Ash.read!(UsageAnalyzer.Resources.PerformanceMetric, 
      :recent, %{timeframe: timeframe})
    pain_points = Ash.read!(UsageAnalyzer.Resources.PainPointAnalysis, 
      :recent, %{timeframe: timeframe})
    
    %{
      total_analyses: length(reports),
      active_dsls: count_active_dsls(reports),
      pattern_insights: summarize_patterns(patterns),
      performance_summary: summarize_performance(performance_metrics),
      pain_point_summary: summarize_pain_points(pain_points),
      trend_indicators: calculate_trend_indicators(reports)
    }
  end

  # Private helper functions

  defp generate_report_summary(main_report, additional_analyses) do
    %{
      target_dsl: main_report.target_dsl,
      analysis_completed_at: main_report.updated_at,
      overall_health_score: calculate_overall_health_score(main_report, additional_analyses),
      key_findings: extract_key_findings(main_report, additional_analyses),
      recommendations: extract_recommendations(additional_analyses),
      next_steps: suggest_next_steps(main_report, additional_analyses)
    }
  end

  defp perform_comparative_analysis(reports, criteria) do
    %{
      performance_comparison: compare_performance_metrics(reports),
      pattern_similarities: identify_pattern_similarities(reports),
      complexity_comparison: compare_complexity_levels(reports),
      adoption_comparison: compare_adoption_rates(reports),
      quality_comparison: compare_quality_scores(reports)
    }
  end

  defp generate_comparison_recommendations(reports) do
    recommendations = []
    
    # Identify best practices from high-performing DSLs
    best_performers = Enum.filter(reports, &(&1.overall_score && &1.overall_score > 80))
    if length(best_performers) > 0 do
      recommendations = ["Learn from high-performing DSLs: #{Enum.map(best_performers, & &1.target_dsl) |> Enum.join(", ")}" | recommendations]
    end
    
    # Identify common pain points
    common_pain_points = identify_common_pain_points(reports)
    if length(common_pain_points) > 0 do
      recommendations = ["Address common pain points: #{Enum.join(common_pain_points, ", ")}" | recommendations]
    end
    
    recommendations
  end

  defp analyze_trend_patterns(trend_data) do
    # Extract metrics from each time period
    metrics_by_period = Enum.map(trend_data, fn {period, report} ->
      {period, extract_trend_metrics(report)}
    end)
    
    %{
      usage_trend: calculate_usage_trend(metrics_by_period),
      quality_trend: calculate_quality_trend(metrics_by_period),
      complexity_trend: calculate_complexity_trend(metrics_by_period),
      performance_trend: calculate_performance_trend(metrics_by_period)
    }
  end

  defp generate_trend_predictions(trend_data) do
    # Simple linear prediction based on recent trends
    # In a real implementation, this would use more sophisticated forecasting
    %{
      predicted_usage_change: predict_usage_change(trend_data),
      predicted_quality_change: predict_quality_change(trend_data),
      confidence_interval: calculate_prediction_confidence(trend_data)
    }
  end

  defp count_active_dsls(reports) do
    reports
    |> Enum.map(& &1.target_dsl)
    |> Enum.uniq()
    |> length()
  end

  defp summarize_patterns(patterns) do
    pattern_types = Enum.map(patterns, & &1.pattern_type)
    common_patterns = Enum.frequencies(pattern_types)
    
    %{
      total_patterns: length(patterns),
      unique_patterns: length(Enum.uniq(pattern_types)),
      common_patterns: common_patterns,
      emerging_patterns: identify_emerging_patterns(patterns)
    }
  end

  defp summarize_performance(metrics) do
    if length(metrics) == 0 do
      %{average_score: 0, trend: :no_data}
    else
      scores = Enum.map(metrics, & &1.performance_score)
      valid_scores = Enum.filter(scores, & &1)
      
      if length(valid_scores) > 0 do
        %{
          average_score: Enum.sum(valid_scores) / length(valid_scores),
          best_score: Enum.max(valid_scores),
          worst_score: Enum.min(valid_scores),
          trend: calculate_performance_trend(metrics)
        }
      else
        %{average_score: 0, trend: :insufficient_data}
      end
    end
  end

  defp summarize_pain_points(pain_points) do
    if length(pain_points) == 0 do
      %{total_issues: 0, severity_distribution: %{}}
    else
      severities = Enum.map(pain_points, & &1.severity_level)
      severity_distribution = Enum.frequencies(severities)
      
      %{
        total_issues: length(pain_points),
        severity_distribution: severity_distribution,
        most_common_issues: extract_common_issues(pain_points),
        resolution_rate: calculate_resolution_rate(pain_points)
      }
    end
  end

  defp calculate_trend_indicators(reports) do
    if length(reports) < 2 do
      %{trend: :insufficient_data}
    else
      sorted_reports = Enum.sort_by(reports, & &1.inserted_at, DateTime)
      recent_reports = Enum.take(sorted_reports, -5)
      older_reports = Enum.take(sorted_reports, 5)
      
      recent_avg_score = calculate_average_score(recent_reports)
      older_avg_score = calculate_average_score(older_reports)
      
      trend = cond do
        recent_avg_score > older_avg_score + 5 -> :improving
        recent_avg_score < older_avg_score - 5 -> :declining
        true -> :stable
      end
      
      %{
        trend: trend,
        recent_average: recent_avg_score,
        change: recent_avg_score - older_avg_score
      }
    end
  end

  # Additional helper functions with placeholder implementations
  defp calculate_overall_health_score(_main_report, _additional_analyses), do: 75.0
  defp extract_key_findings(_main_report, _additional_analyses), do: []
  defp extract_recommendations(_additional_analyses), do: []
  defp suggest_next_steps(_main_report, _additional_analyses), do: []
  defp compare_performance_metrics(_reports), do: %{}
  defp identify_pattern_similarities(_reports), do: %{}
  defp compare_complexity_levels(_reports), do: %{}
  defp compare_adoption_rates(_reports), do: %{}
  defp compare_quality_scores(_reports), do: %{}
  defp identify_common_pain_points(_reports), do: []
  defp extract_trend_metrics(_report), do: %{}
  defp calculate_usage_trend(_metrics), do: :stable
  defp calculate_quality_trend(_metrics), do: :stable
  defp calculate_complexity_trend(_metrics), do: :stable
  defp calculate_performance_trend(_metrics), do: :stable
  defp predict_usage_change(_trend_data), do: 0.0
  defp predict_quality_change(_trend_data), do: 0.0
  defp calculate_prediction_confidence(_trend_data), do: 0.7
  defp identify_emerging_patterns(_patterns), do: []
  defp extract_common_issues(_pain_points), do: []
  defp calculate_resolution_rate(_pain_points), do: 0.0
  defp calculate_average_score(reports) do
    scores = Enum.map(reports, & &1.overall_score || 0)
    if length(scores) > 0, do: Enum.sum(scores) / length(scores), else: 0.0
  end
end