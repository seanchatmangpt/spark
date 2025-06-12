defmodule EvolutionEngine do
  @moduledoc """
  EvolutionEngine - Continuous DSL Improvement Domain
  
  This Ash domain implements evolutionary algorithms and machine learning
  techniques for continuously improving DSLs based on usage patterns,
  performance metrics, and developer feedback.
  
  ## Architecture
  
  The domain manages:
  - EvolutionRuns (complete evolution cycles with populations)
  - Individuals (specific DSL variants being evolved)
  - FitnessScores (evaluation results for individuals)
  - ImprovementTracking (tracking applied improvements)
  
  ## Usage
  
      # Start evolution for a DSL
      {:ok, run} = EvolutionEngine.create!(EvolutionEngine.Resources.EvolutionRun, %{
        target_dsl: "MyApp.ApiDsl",
        evolution_strategy: :genetic,
        population_size: 100
      })
      
      # Monitor evolution progress
      EvolutionEngine.get_evolution_status(run.id)
  """
  
  use Ash.Domain

  resources do
    resource EvolutionEngine.Resources.EvolutionRun
    resource EvolutionEngine.Resources.Individual
    resource EvolutionEngine.Resources.FitnessScore
    resource EvolutionEngine.Resources.ImprovementTracking
  end

  authorization do
    authorize :by_default
    require_actor? false
  end

  @doc """
  Starts evolution for a target DSL.
  """
  def start_evolution(target_dsl, opts \\ %{}) do
    evolution_strategy = Map.get(opts, :strategy, :genetic)
    population_size = Map.get(opts, :population_size, 50)
    max_generations = Map.get(opts, :max_generations, 100)
    fitness_threshold = Map.get(opts, :fitness_threshold, 0.95)
    
    create!(EvolutionEngine.Resources.EvolutionRun, %{
      target_dsl: target_dsl,
      evolution_strategy: evolution_strategy,
      population_size: population_size,
      max_generations: max_generations,
      fitness_threshold: fitness_threshold,
      configuration: opts
    })
  end

  @doc """
  Starts continuous evolution monitoring for a DSL.
  """
  def start_continuous_evolution(target_dsl, opts \\ %{}) do
    interval_hours = Map.get(opts, :interval_hours, 24)
    autonomy_level = Map.get(opts, :autonomy_level, :supervised)
    quality_threshold = Map.get(opts, :quality_threshold, 0.8)
    
    # Start a long-running evolution process
    Task.Supervisor.start_child(EvolutionEngine.TaskSupervisor, fn ->
      continuous_evolution_loop(target_dsl, %{
        interval_hours: interval_hours,
        autonomy_level: autonomy_level,
        quality_threshold: quality_threshold
      })
    end)
  end

  @doc """
  Gets the current status of an evolution run.
  """
  def get_evolution_status(evolution_run_id) do
    run = get!(EvolutionEngine.Resources.EvolutionRun, evolution_run_id)
    individuals = read!(EvolutionEngine.Resources.Individual, 
      :by_evolution_run, %{evolution_run_id: evolution_run_id})
    
    best_individual = Enum.max_by(individuals, &(&1.fitness_score || 0), fn -> nil end)
    
    %{
      run: run,
      status: run.status,
      generation: run.current_generation,
      population_size: length(individuals),
      best_fitness: best_individual && best_individual.fitness_score,
      progress_percentage: calculate_progress_percentage(run),
      estimated_completion: estimate_completion_time(run)
    }
  end

  @doc """
  Forces evolution to the next generation.
  """
  def advance_generation(evolution_run_id) do
    run = get!(EvolutionEngine.Resources.EvolutionRun, evolution_run_id)
    
    update!(run, :advance_generation, %{})
  end

  @doc """
  Applies successful improvements from evolution.
  """
  def apply_improvements(evolution_run_id, improvement_threshold \\ 0.1) do
    run = get!(EvolutionEngine.Resources.EvolutionRun, evolution_run_id)
    individuals = read!(EvolutionEngine.Resources.Individual, 
      :successful, %{evolution_run_id: evolution_run_id, threshold: improvement_threshold})
    
    improvements_applied = Enum.map(individuals, fn individual ->
      create!(EvolutionEngine.Resources.ImprovementTracking, %{
        evolution_run_id: evolution_run_id,
        individual_id: individual.id,
        improvement_type: :performance_optimization,
        improvement_data: individual.genome_data,
        fitness_improvement: individual.fitness_score - run.baseline_fitness
      })
    end)
    
    {:ok, %{
      improvements_applied: length(improvements_applied),
      total_fitness_improvement: calculate_total_improvement(improvements_applied),
      applied_improvements: improvements_applied
    }}
  end

  @doc """
  Analyzes evolution history and performance.
  """
  def analyze_evolution_history(target_dsl, opts \\ %{}) do
    timeframe = Map.get(opts, :timeframe, "90d")
    
    runs = read!(EvolutionEngine.Resources.EvolutionRun, 
      :by_target_dsl, %{target_dsl: target_dsl, timeframe: timeframe})
    
    %{
      total_runs: length(runs),
      successful_runs: count_successful_runs(runs),
      average_improvement: calculate_average_improvement(runs),
      best_strategies: identify_best_strategies(runs),
      evolution_trends: analyze_evolution_trends(runs),
      recommendations: generate_evolution_recommendations(runs)
    }
  end

  @doc """
  Gets comprehensive evolution metrics.
  """
  def get_evolution_metrics(opts \\ %{}) do
    timeframe = Map.get(opts, :timeframe, "30d")
    
    runs = read!(EvolutionEngine.Resources.EvolutionRun, 
      :recent, %{timeframe: timeframe})
    individuals = read!(EvolutionEngine.Resources.Individual, 
      :recent, %{timeframe: timeframe})
    improvements = read!(EvolutionEngine.Resources.ImprovementTracking, 
      :recent, %{timeframe: timeframe})
    
    %{
      total_evolution_runs: length(runs),
      total_individuals_evaluated: length(individuals),
      total_improvements_applied: length(improvements),
      success_rate: calculate_evolution_success_rate(runs),
      average_fitness_improvement: calculate_average_fitness_improvement(individuals),
      popular_strategies: analyze_popular_strategies(runs),
      performance_trends: analyze_performance_trends(runs)
    }
  end

  @doc """
  Performs A/B testing for evolution improvements.
  """
  def start_ab_test(target_dsl, improvement_a, improvement_b, opts \\ %{}) do
    test_duration_hours = Map.get(opts, :duration_hours, 72)
    sample_size = Map.get(opts, :sample_size, 1000)
    
    # Create A/B test tracking
    test_run = create!(EvolutionEngine.Resources.EvolutionRun, %{
      target_dsl: target_dsl,
      evolution_strategy: :ab_testing,
      test_type: :improvement_comparison,
      test_configuration: %{
        improvement_a: improvement_a,
        improvement_b: improvement_b,
        duration_hours: test_duration_hours,
        sample_size: sample_size
      },
      status: :testing
    })
    
    # Schedule test completion
    Process.send_after(self(), {:complete_ab_test, test_run.id}, 
      test_duration_hours * 60 * 60 * 1000)
    
    {:ok, test_run}
  end

  # Private helper functions

  defp continuous_evolution_loop(target_dsl, opts) do
    interval_ms = opts.interval_hours * 60 * 60 * 1000
    
    # Analyze current DSL performance
    current_performance = analyze_current_performance(target_dsl)
    
    # Determine if evolution is needed
    if evolution_needed?(current_performance, opts.quality_threshold) do
      {:ok, evolution_run} = start_evolution(target_dsl, %{
        population_size: 25, # Smaller for continuous evolution
        max_generations: 10,
        fitness_threshold: opts.quality_threshold
      })
      
      # Wait for evolution to complete
      wait_for_evolution_completion(evolution_run.id)
      
      # Apply improvements if autonomy allows
      if opts.autonomy_level in [:full_auto, :supervised] do
        apply_improvements(evolution_run.id)
      end
    end
    
    # Wait for next cycle
    Process.sleep(interval_ms)
    continuous_evolution_loop(target_dsl, opts)
  end

  defp calculate_progress_percentage(run) do
    if run.max_generations > 0 do
      (run.current_generation / run.max_generations) * 100
    else
      0.0
    end
  end

  defp estimate_completion_time(run) do
    if run.status == :completed do
      nil
    else
      avg_generation_time = calculate_average_generation_time(run)
      remaining_generations = run.max_generations - run.current_generation
      DateTime.add(DateTime.utc_now(), remaining_generations * avg_generation_time, :second)
    end
  end

  defp calculate_total_improvement(improvements) do
    improvements
    |> Enum.map(& &1.fitness_improvement || 0)
    |> Enum.sum()
  end

  defp count_successful_runs(runs) do
    Enum.count(runs, &(&1.status == :completed && &1.best_fitness_achieved > &1.baseline_fitness))
  end

  defp calculate_average_improvement(runs) do
    successful_runs = Enum.filter(runs, &(&1.status == :completed))
    
    if length(successful_runs) > 0 do
      improvements = Enum.map(successful_runs, fn run ->
        (run.best_fitness_achieved || 0) - (run.baseline_fitness || 0)
      end)
      Enum.sum(improvements) / length(improvements)
    else
      0.0
    end
  end

  defp identify_best_strategies(runs) do
    runs
    |> Enum.filter(&(&1.status == :completed))
    |> Enum.group_by(& &1.evolution_strategy)
    |> Enum.map(fn {strategy, strategy_runs} ->
      avg_improvement = calculate_average_improvement(strategy_runs)
      success_rate = length(strategy_runs) / length(runs)
      
      {strategy, %{
        average_improvement: avg_improvement,
        success_rate: success_rate,
        total_runs: length(strategy_runs)
      }}
    end)
    |> Enum.sort_by(fn {_strategy, metrics} -> metrics.average_improvement end, :desc)
  end

  defp analyze_evolution_trends(runs) do
    if length(runs) < 3 do
      %{trend: :insufficient_data}
    else
      sorted_runs = Enum.sort_by(runs, & &1.inserted_at, DateTime)
      
      recent_performance = sorted_runs |> Enum.take(-5) |> calculate_average_improvement()
      older_performance = sorted_runs |> Enum.take(5) |> calculate_average_improvement()
      
      trend = cond do
        recent_performance > older_performance + 0.05 -> :improving
        recent_performance < older_performance - 0.05 -> :declining
        true -> :stable
      end
      
      %{
        trend: trend,
        recent_performance: recent_performance,
        performance_change: recent_performance - older_performance
      }
    end
  end

  defp generate_evolution_recommendations(runs) do
    recommendations = []
    trends = analyze_evolution_trends(runs)
    best_strategies = identify_best_strategies(runs)
    
    # Strategy recommendations
    if length(best_strategies) > 0 do
      {best_strategy, _metrics} = List.first(best_strategies)
      recommendations = ["Consider using #{best_strategy} strategy for better results" | recommendations]
    end
    
    # Trend-based recommendations
    case trends.trend do
      :declining ->
        recommendations = ["Evolution performance is declining, consider reviewing fitness functions" | recommendations]
      :improving ->
        recommendations = ["Evolution is improving, continue current approach" | recommendations]
      _ ->
        recommendations
    end
    
    recommendations
  end

  defp calculate_evolution_success_rate(runs) do
    if length(runs) == 0 do
      0.0
    else
      successful = count_successful_runs(runs)
      successful / length(runs)
    end
  end

  defp calculate_average_fitness_improvement(individuals) do
    improvements = individuals
                  |> Enum.map(& &1.fitness_score || 0)
                  |> Enum.filter(&(&1 > 0))
    
    if length(improvements) > 0 do
      Enum.sum(improvements) / length(improvements)
    else
      0.0
    end
  end

  defp analyze_popular_strategies(runs) do
    runs
    |> Enum.map(& &1.evolution_strategy)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_strategy, count} -> count end, :desc)
    |> Enum.take(5)
  end

  defp analyze_performance_trends(runs) do
    if length(runs) < 2 do
      %{trend: :insufficient_data}
    else
      sorted_runs = Enum.sort_by(runs, & &1.inserted_at, DateTime)
      fitness_scores = Enum.map(sorted_runs, & &1.best_fitness_achieved || 0)
      
      recent_avg = fitness_scores |> Enum.take(-5) |> calculate_average()
      older_avg = fitness_scores |> Enum.take(5) |> calculate_average()
      
      trend = cond do
        recent_avg > older_avg + 0.05 -> :improving
        recent_avg < older_avg - 0.05 -> :declining
        true -> :stable
      end
      
      %{
        trend: trend,
        recent_average: recent_avg,
        change: recent_avg - older_avg
      }
    end
  end

  # Placeholder implementations for helper functions
  defp analyze_current_performance(_target_dsl), do: %{score: 0.75, issues: []}
  defp evolution_needed?(performance, threshold), do: performance.score < threshold
  defp wait_for_evolution_completion(_run_id), do: :ok
  defp calculate_average_generation_time(_run), do: 300 # 5 minutes
  defp calculate_average(list) when length(list) > 0, do: Enum.sum(list) / length(list)
  defp calculate_average(_), do: 0.0
end