defmodule DslSynthesizer do
  @moduledoc """
  DslSynthesizer - Multi-Strategy DSL Generation Domain
  
  This Ash domain handles the synthesis of DSL implementations using
  multiple generation strategies, evaluation, and optimization.
  
  ## Architecture
  
  The domain manages:
  - GenerationStrategies (different approaches to DSL generation)
  - CodeCandidates (generated DSL implementations)
  - QualityMetrics (evaluation results for generated code)
  - OptimizationResults (improvements applied to generated code)
  
  ## Usage
  
      # Generate DSL using multiple strategies
      {:ok, strategies} = DslSynthesizer.generate_multiple_strategies(specification, %{
        strategy_count: 5,
        quality_threshold: 85
      })
      
      # Get the best candidate
      best = DslSynthesizer.select_best_candidate(strategies)
  """
  
  use Ash.Domain

  resources do
    resource DslSynthesizer.Resources.GenerationStrategy
    resource DslSynthesizer.Resources.CodeCandidate
    resource DslSynthesizer.Resources.QualityMetrics
    resource DslSynthesizer.Resources.OptimizationResult
  end

  authorization do
    authorize :by_default
    require_actor? false
  end

  @doc """
  Generates multiple DSL implementation strategies.
  """
  def generate_multiple_strategies(specification, opts \\ %{}) do
    strategy_count = Map.get(opts, :strategy_count, 5)
    parallel = Map.get(opts, :parallel, true)
    
    strategies = select_strategies(specification, strategy_count)
    
    if parallel do
      generate_strategies_parallel(specification, strategies, opts)
    else
      generate_strategies_sequential(specification, strategies, opts)
    end
  end

  @doc """
  Generates a single strategy implementation.
  """
  def generate_single_strategy(specification, strategy_type, opts \\ %{}) do
    create!(DslSynthesizer.Resources.GenerationStrategy, %{
      strategy_type: strategy_type,
      specification_data: specification,
      generation_options: opts
    })
  end

  @doc """
  Evaluates and selects the best code candidate from multiple strategies.
  """
  def select_best_candidate(strategies, criteria \\ %{}) do
    quality_threshold = Map.get(criteria, :quality_threshold, 75.0)
    
    # Get all code candidates from strategies
    candidates = Enum.flat_map(strategies, fn strategy ->
      read!(DslSynthesizer.Resources.CodeCandidate, 
        :by_strategy, %{strategy_id: strategy.id})
    end)
    
    # Find the best candidate
    best_candidate = candidates
                    |> Enum.filter(&(&1.overall_quality_score >= quality_threshold))
                    |> Enum.max_by(&(&1.overall_quality_score), fn -> nil end)
    
    case best_candidate do
      nil -> {:error, :no_candidates_meet_threshold}
      candidate -> {:ok, candidate}
    end
  end

  @doc """
  Optimizes a generated code candidate.
  """
  def optimize_candidate(candidate_id, optimization_options \\ %{}) do
    candidate = get!(DslSynthesizer.Resources.CodeCandidate, candidate_id)
    
    update!(candidate, :optimize, %{
      optimization_options: optimization_options
    })
  end

  @doc """
  Generates final production-ready code from a candidate.
  """
  def generate_final_code(candidate_id, mode \\ :development) do
    candidate = get!(DslSynthesizer.Resources.CodeCandidate, candidate_id)
    
    update!(candidate, :generate_final, %{
      generation_mode: mode,
      include_tests: true,
      include_documentation: true,
      include_examples: true
    })
  end

  @doc """
  Analyzes synthesis performance and patterns.
  """
  def analyze_synthesis_performance(opts \\ []) do
    timeframe = Keyword.get(opts, :timeframe, "30d")
    
    strategies = read!(DslSynthesizer.Resources.GenerationStrategy, 
      :recent, %{timeframe: timeframe})
    candidates = read!(DslSynthesizer.Resources.CodeCandidate, 
      :recent, %{timeframe: timeframe})
    
    %{
      total_strategies: length(strategies),
      total_candidates: length(candidates),
      strategy_success_rates: analyze_strategy_success_rates(strategies),
      quality_trends: analyze_quality_trends(candidates),
      generation_speed: analyze_generation_speed(strategies),
      optimization_impact: analyze_optimization_impact(candidates)
    }
  end

  @doc """
  Gets synthesis statistics for monitoring.
  """
  def get_synthesis_statistics do
    strategies = read!(DslSynthesizer.Resources.GenerationStrategy)
    candidates = read!(DslSynthesizer.Resources.CodeCandidate)
    
    %{
      total_strategies: length(strategies),
      total_candidates: length(candidates),
      average_quality: calculate_average_quality(candidates),
      success_rate: calculate_success_rate(strategies),
      popular_strategies: analyze_popular_strategies(strategies),
      quality_distribution: analyze_quality_distribution(candidates)
    }
  end

  @doc """
  Recommends optimal strategies for a given specification.
  """
  def recommend_strategies(specification) do
    # Analyze specification characteristics
    characteristics = analyze_specification_characteristics(specification)
    
    # Get historical performance data
    historical_data = get_historical_strategy_performance()
    
    # Generate recommendations
    recommendations = generate_strategy_recommendations(characteristics, historical_data)
    
    %{
      recommended_strategies: recommendations,
      reasoning: explain_recommendations(characteristics, recommendations),
      confidence: calculate_recommendation_confidence(characteristics, historical_data)
    }
  end

  # Private helper functions

  defp select_strategies(specification, count) do
    all_strategies = [:template, :pattern_based, :example_driven, :hybrid, :ai_assisted, 
                     :genetic, :rule_based, :machine_learning]
    
    # Get recommendations and select top strategies
    recommendations = recommend_strategies(specification)
    recommended = recommendations.recommended_strategies
    
    # Ensure we have enough strategies
    selected = if length(recommended) >= count do
      Enum.take(recommended, count)
    else
      remaining_needed = count - length(recommended)
      remaining_strategies = all_strategies -- recommended
      recommended ++ Enum.take(remaining_strategies, remaining_needed)
    end
    
    Enum.take(selected, count)
  end

  defp generate_strategies_parallel(specification, strategies, opts) do
    tasks = Enum.map(strategies, fn strategy_type ->
      Task.async(fn ->
        generate_single_strategy(specification, strategy_type, opts)
      end)
    end)
    
    case Task.await_many(tasks, 300_000) do # 5 minute timeout
      results when is_list(results) ->
        successful_results = Enum.filter(results, &match?({:ok, _}, &1))
        if length(successful_results) > 0 do
          {:ok, Enum.map(successful_results, fn {:ok, result} -> result end)}
        else
          {:error, :no_successful_strategies}
        end
      error ->
        {:error, {:parallel_generation_failed, error}}
    end
  end

  defp generate_strategies_sequential(specification, strategies, opts) do
    results = Enum.reduce_while(strategies, [], fn strategy_type, acc ->
      case generate_single_strategy(specification, strategy_type, opts) do
        {:ok, strategy} -> {:cont, [strategy | acc]}
        {:error, _reason} -> {:cont, acc} # Continue with other strategies
      end
    end)
    
    if length(results) > 0 do
      {:ok, Enum.reverse(results)}
    else
      {:error, :no_successful_strategies}
    end
  end

  defp analyze_strategy_success_rates(strategies) do
    strategies
    |> Enum.group_by(& &1.strategy_type)
    |> Enum.map(fn {strategy_type, strategy_list} ->
      successful = Enum.count(strategy_list, &(&1.status == :completed))
      total = length(strategy_list)
      success_rate = if total > 0, do: successful / total, else: 0.0
      
      {strategy_type, %{
        success_rate: success_rate,
        total_attempts: total,
        successful_attempts: successful
      }}
    end)
    |> Map.new()
  end

  defp analyze_quality_trends(candidates) do
    if length(candidates) < 2 do
      %{trend: :insufficient_data}
    else
      sorted_candidates = Enum.sort_by(candidates, & &1.inserted_at, DateTime)
      scores = Enum.map(sorted_candidates, & &1.overall_quality_score)
      
      recent_scores = Enum.take(scores, -10)
      older_scores = Enum.take(scores, 10)
      
      recent_avg = if length(recent_scores) > 0, do: Enum.sum(recent_scores) / length(recent_scores), else: 0
      older_avg = if length(older_scores) > 0, do: Enum.sum(older_scores) / length(older_scores), else: 0
      
      trend = cond do
        recent_avg > older_avg + 5 -> :improving
        recent_avg < older_avg - 5 -> :declining
        true -> :stable
      end
      
      %{
        trend: trend,
        recent_average: recent_avg,
        older_average: older_avg,
        change: recent_avg - older_avg
      }
    end
  end

  defp analyze_generation_speed(strategies) do
    processing_times = strategies
                      |> Enum.map(& &1.processing_time_ms)
                      |> Enum.filter(& &1)
    
    if length(processing_times) > 0 do
      %{
        average_ms: Enum.sum(processing_times) / length(processing_times),
        fastest_ms: Enum.min(processing_times),
        slowest_ms: Enum.max(processing_times)
      }
    else
      %{average_ms: 0, fastest_ms: 0, slowest_ms: 0}
    end
  end

  defp analyze_optimization_impact(candidates) do
    optimized_candidates = Enum.filter(candidates, &(&1.optimization_applied))
    
    if length(optimized_candidates) > 0 do
      improvements = Enum.map(optimized_candidates, fn candidate ->
        candidate.quality_score_after_optimization - candidate.overall_quality_score
      end)
      
      %{
        average_improvement: Enum.sum(improvements) / length(improvements),
        best_improvement: Enum.max(improvements),
        optimization_rate: length(optimized_candidates) / length(candidates)
      }
    else
      %{average_improvement: 0, best_improvement: 0, optimization_rate: 0}
    end
  end

  defp calculate_average_quality(candidates) do
    if length(candidates) == 0 do
      0.0
    else
      scores = Enum.map(candidates, & &1.overall_quality_score)
      Enum.sum(scores) / length(scores)
    end
  end

  defp calculate_success_rate(strategies) do
    if length(strategies) == 0 do
      0.0
    else
      successful = Enum.count(strategies, &(&1.status == :completed))
      successful / length(strategies)
    end
  end

  defp analyze_popular_strategies(strategies) do
    strategies
    |> Enum.map(& &1.strategy_type)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_strategy, count} -> count end, :desc)
    |> Enum.take(5)
  end

  defp analyze_quality_distribution(candidates) do
    scores = Enum.map(candidates, & &1.overall_quality_score)
    
    %{
      excellent: Enum.count(scores, &(&1 >= 90)),
      good: Enum.count(scores, &(&1 >= 80 and &1 < 90)),
      fair: Enum.count(scores, &(&1 >= 70 and &1 < 80)),
      poor: Enum.count(scores, &(&1 < 70))
    }
  end

  defp analyze_specification_characteristics(specification) do
    %{
      domain: specification.domain || :general,
      complexity: specification.complexity || :standard,
      feature_count: length(specification.features || []),
      entity_count: length(specification.entities || []),
      has_auth: :authentication in (specification.features || []),
      has_validation: :validation in (specification.features || []),
      has_api: specification.domain == :api
    }
  end

  defp get_historical_strategy_performance do
    # This would analyze historical data from the database
    # For now, return mock data
    %{
      template: %{success_rate: 0.85, avg_quality: 75, avg_time_ms: 5000},
      pattern_based: %{success_rate: 0.78, avg_quality: 82, avg_time_ms: 8000},
      example_driven: %{success_rate: 0.72, avg_quality: 88, avg_time_ms: 12000},
      hybrid: %{success_rate: 0.89, avg_quality: 85, avg_time_ms: 15000},
      ai_assisted: %{success_rate: 0.91, avg_quality: 92, avg_time_ms: 25000}
    }
  end

  defp generate_strategy_recommendations(characteristics, historical_data) do
    recommendations = []
    
    # Always include hybrid for good balance
    recommendations = [:hybrid | recommendations]
    
    # AI-assisted for complex requirements
    if characteristics.complexity in [:advanced, :enterprise] do
      recommendations = [:ai_assisted | recommendations]
    end
    
    # Template for simple, standard patterns
    if characteristics.complexity in [:simple, :standard] and characteristics.domain != :general do
      recommendations = [:template | recommendations]
    end
    
    # Pattern-based for API domains
    if characteristics.has_api do
      recommendations = [:pattern_based | recommendations]
    end
    
    # Example-driven for complex feature combinations
    if characteristics.feature_count > 3 do
      recommendations = [:example_driven | recommendations]
    end
    
    Enum.uniq(recommendations)
  end

  defp explain_recommendations(characteristics, recommendations) do
    explanations = []
    
    if :hybrid in recommendations do
      explanations = ["Hybrid strategy provides good balance of quality and reliability" | explanations]
    end
    
    if :ai_assisted in recommendations and characteristics.complexity in [:advanced, :enterprise] do
      explanations = ["AI-assisted recommended for complex requirements" | explanations]
    end
    
    if :template in recommendations and characteristics.complexity in [:simple, :standard] do
      explanations = ["Template strategy efficient for standard patterns" | explanations]
    end
    
    if :pattern_based in recommendations and characteristics.has_api do
      explanations = ["Pattern-based strategy works well for API domains" | explanations]
    end
    
    explanations
  end

  defp calculate_recommendation_confidence(characteristics, historical_data) do
    # Calculate confidence based on how well characteristics match historical patterns
    # This is a simplified calculation
    base_confidence = 0.7
    
    # Increase confidence for well-known domains
    domain_bonus = if characteristics.domain in [:api, :validation, :workflow], do: 0.1, else: 0.0
    
    # Increase confidence for standard complexity
    complexity_bonus = if characteristics.complexity == :standard, do: 0.1, else: 0.0
    
    # Decrease confidence for very complex scenarios
    complexity_penalty = if characteristics.complexity == :enterprise, do: -0.1, else: 0.0
    
    confidence = base_confidence + domain_bonus + complexity_bonus + complexity_penalty
    max(0.0, min(1.0, confidence))
  end
end