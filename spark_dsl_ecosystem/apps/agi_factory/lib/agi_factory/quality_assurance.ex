defmodule AgiFactory.QualityAssurance do
  @moduledoc """
  Quality assurance for generated DSLs.
  
  This module evaluates the quality of generated DSL implementations
  across multiple dimensions including correctness, performance,
  usability, and maintainability.
  """
  
  @doc """
  Evaluates all DSL candidates for quality.
  """
  def evaluate_all(candidates) do
    Enum.map(candidates, &evaluate_candidate/1)
  end
  
  @doc """
  Evaluates a single DSL candidate.
  """
  def evaluate_candidate(candidate) do
    %{
      compilation_success: test_compilation(candidate),
      test_coverage: assess_test_coverage(candidate),
      documentation_quality: assess_documentation(candidate),
      performance_score: benchmark_performance(candidate),
      design_quality: assess_design_quality(candidate),
      spark_compliance: check_spark_compliance(candidate),
      usability_score: assess_usability(candidate),
      maintainability_index: calculate_maintainability(candidate)
    }
  end
  
  @doc """
  Performs a quality checkpoint on results.
  """
  def perform_quality_checkpoint(results, threshold) do
    quality_metrics = calculate_quality_metrics(results)
    
    decision = 
      cond do
        quality_metrics.average_quality >= threshold and 
        quality_metrics.success_rate >= 0.8 ->
          :continue
          
        quality_metrics.critical_failures == [] and
        quality_metrics.average_quality >= threshold * 0.9 ->
          :continue
          
        quality_metrics.critical_failures != [] ->
          :abort
          
        true ->
          :retry_with_improvements
      end
    
    %{
      status: decision,
      metrics: quality_metrics,
      improvements: generate_improvements(results, threshold),
      recommendations: generate_recommendations(quality_metrics)
    }
  end
  
  # Private functions
  
  defp test_compilation(candidate) do
    # Test if the generated code compiles
    case compile_candidate(candidate) do
      {:ok, _} -> 100
      {:error, _} -> 0
    end
  end
  
  defp compile_candidate(candidate) do
    # In real implementation, would use Code.compile_string
    if String.contains?(candidate.code, "syntax error") do
      {:error, :syntax_error}
    else
      {:ok, []}
    end
  end
  
  defp assess_test_coverage(candidate) do
    # Calculate test coverage percentage
    # Simplified - would analyze actual test generation
    case candidate do
      %{tests: tests} when is_list(tests) ->
        length(tests) * 10 |> min(100)
      _ ->
        0
    end
  end
  
  defp assess_documentation(candidate) do
    score = 0
    code = Map.get(candidate, :code, "")
    
    # Check for moduledoc
    score = if String.contains?(code, "@moduledoc"), do: score + 30, else: score
    
    # Check for function docs
    doc_count = length(Regex.scan(~r/@doc/, code))
    score = score + min(doc_count * 10, 40)
    
    # Check for examples
    score = if String.contains?(code, "## Example"), do: score + 20, else: score
    
    # Check for spec definitions
    score = if String.contains?(code, "@spec"), do: score + 10, else: score
    
    score
  end
  
  defp benchmark_performance(candidate) do
    # Simplified performance scoring
    # In reality would run actual benchmarks
    
    # Check for obvious performance issues
    code = Map.get(candidate, :code, "")
    score = 100
    
    # Penalize nested loops
    if String.contains?(code, "Enum.map") and String.contains?(code, "Enum.filter") do
      score = score - 10
    end
    
    # Reward compile-time operations
    if String.contains?(code, "Transformer") do
      score = min(score + 10, 100)
    end
    
    score
  end
  
  defp assess_design_quality(candidate) do
    score = 0
    code = Map.get(candidate, :code, "")
    
    # Single Responsibility
    module_count = length(Regex.scan(~r/defmodule/, code))
    if module_count <= 3, do: score = score + 25
    
    # Clear structure
    if String.contains?(code, "@section") and String.contains?(code, "@entity") do
      score = score + 25
    end
    
    # Extensibility
    if String.contains?(code, "use Spark.Dsl.Extension") do
      score = score + 25
    end
    
    # Error handling
    if String.contains?(code, "Spark.Error.DslError") do
      score = score + 25
    end
    
    score
  end
  
  defp check_spark_compliance(candidate) do
    required_patterns = [
      "use Spark.Dsl",
      "Spark.Dsl.Entity",
      "Spark.Dsl.Section"
    ]
    
    code = Map.get(candidate, :code, "")
    
    compliance = Enum.reduce(required_patterns, 0, fn pattern, acc ->
      if String.contains?(code, pattern), do: acc + 33, else: acc
    end)
    
    min(compliance, 100)
  end
  
  defp assess_usability(candidate) do
    score = 0
    code = Map.get(candidate, :code, "")
    
    # Clear naming
    if has_clear_naming?(code), do: score = score + 30
    
    # Good defaults
    if String.contains?(code, "default:"), do: score = score + 20
    
    # Helpful error messages
    if has_helpful_errors?(code), do: score = score + 25
    
    # Examples provided
    if String.contains?(code, "examples:"), do: score = score + 25
    
    score
  end
  
  defp calculate_maintainability(candidate) do
    # Simplified maintainability index
    doc_score = assess_documentation(candidate)
    design_score = assess_design_quality(candidate)
    test_score = assess_test_coverage(candidate)
    
    (doc_score + design_score + test_score) / 3
  end
  
  defp has_clear_naming?(code) do
    # Check for descriptive names
    String.contains?(code, "name:") and
    not String.contains?(code, "thing1") and
    not String.contains?(code, "data")
  end
  
  defp has_helpful_errors?(code) do
    String.contains?(code, "message:") or
    String.contains?(code, "DslError")
  end
  
  defp calculate_quality_metrics(results) do
    scores = Enum.map(results, &extract_overall_score/1)
    
    %{
      average_quality: calculate_average(scores),
      success_rate: calculate_success_rate(results),
      critical_failures: identify_critical_failures(results),
      quality_distribution: analyze_distribution(scores)
    }
  end
  
  defp extract_overall_score(result) do
    # Average all quality dimensions
    dimensions = [
      :compilation_success,
      :test_coverage,
      :documentation_quality,
      :performance_score,
      :design_quality,
      :spark_compliance,
      :usability_score,
      :maintainability_index
    ]
    
    scores = Enum.map(dimensions, fn dim ->
      Map.get(result, dim, 0)
    end)
    
    calculate_average(scores)
  end
  
  defp calculate_average([]), do: 0
  defp calculate_average(scores) do
    Enum.sum(scores) / length(scores)
  end
  
  defp calculate_success_rate(results) do
    successful = Enum.count(results, fn r ->
      Map.get(r, :compilation_success, 0) > 0
    end)
    
    if length(results) > 0 do
      successful / length(results)
    else
      0
    end
  end
  
  defp identify_critical_failures(results) do
    Enum.filter(results, fn r ->
      Map.get(r, :compilation_success, 0) == 0 or
      Map.get(r, :spark_compliance, 0) < 50
    end)
  end
  
  defp analyze_distribution(scores) do
    %{
      min: Enum.min(scores, fn -> 0 end),
      max: Enum.max(scores, fn -> 0 end),
      median: calculate_median(scores),
      std_dev: calculate_std_dev(scores)
    }
  end
  
  defp calculate_median([]), do: 0
  defp calculate_median(scores) do
    sorted = Enum.sort(scores)
    mid = div(length(sorted), 2)
    
    if rem(length(sorted), 2) == 0 do
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    else
      Enum.at(sorted, mid)
    end
  end
  
  defp calculate_std_dev(scores) do
    avg = calculate_average(scores)
    
    variance = 
      scores
      |> Enum.map(fn s -> :math.pow(s - avg, 2) end)
      |> calculate_average()
    
    :math.sqrt(variance)
  end
  
  defp generate_improvements(results, threshold) do
    low_quality = Enum.filter(results, fn r ->
      extract_overall_score(r) < threshold
    end)
    
    Enum.flat_map(low_quality, fn result ->
      improvements_for_result(result)
    end)
    |> Enum.uniq()
  end
  
  defp improvements_for_result(result) do
    improvements = []
    
    if Map.get(result, :documentation_quality, 0) < 50 do
      improvements = ["Add comprehensive documentation" | improvements]
    end
    
    if Map.get(result, :test_coverage, 0) < 60 do
      improvements = ["Increase test coverage" | improvements]
    end
    
    if Map.get(result, :performance_score, 0) < 70 do
      improvements = ["Optimize performance" | improvements]
    end
    
    improvements
  end
  
  defp generate_recommendations(metrics) do
    recommendations = []
    
    if metrics.average_quality < 80 do
      recommendations = ["Focus on quality improvements" | recommendations]
    end
    
    if metrics.success_rate < 0.9 do
      recommendations = ["Improve compilation success rate" | recommendations]
    end
    
    if metrics.quality_distribution.std_dev > 20 do
      recommendations = ["Reduce quality variance between candidates" | recommendations]
    end
    
    recommendations
  end
end