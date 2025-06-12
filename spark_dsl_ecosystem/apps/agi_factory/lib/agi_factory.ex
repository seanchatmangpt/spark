defmodule AgiFactory do
  @moduledoc """
  AgiFactory - Near-AGI DSL Generation Domain
  
  This is the main Ash domain for the SparkDslEcosystem AGI factory.
  It orchestrates autonomous DSL generation, quality assurance, and evolution
  using Ash resources and Ash.Reactor workflows.
  
  ## Architecture
  
  The domain manages:
  - DSL Projects (requirements → generated DSLs)
  - Generation Requests (tracking generation workflows)
  - Quality Assessments (automated quality evaluation)
  - Evolution Cycles (continuous improvement)
  
  ## Usage
  
      # Create DSL from natural language
      {:ok, project} = AgiFactory.create!(AgiFactory.Resources.DslProject, %{
        name: "My API DSL",
        requirements: "I need an API DSL with authentication and validation"
      })
      
      # Start generation workflow
      {:ok, _} = AgiFactory.Workflows.DslGeneration.start(%{
        dsl_project_id: project.id,
        options: %{strategy_count: 5, quality_threshold: 90}
      })
  """
  
  use Ash.Domain

  resources do
    resource AgiFactory.Resources.DslProject
    resource AgiFactory.Resources.GenerationRequest
    resource AgiFactory.Resources.QualityAssessment
    resource AgiFactory.Resources.EvolutionCycle
  end

  authorization do
    authorize :by_default
    require_actor? false
  end

  @doc """
  Creates a DSL project and starts generation workflow.
  """
  def generate_dsl(name, requirements, opts \\ []) do
    case create!(AgiFactory.Resources.DslProject, %{
      name: name,
      requirements: requirements
    }) do
      {:ok, project} ->
        # Start generation workflow
        workflow_opts = %{
          dsl_project_id: project.id,
          options: Map.new(opts)
        }
        
        case AgiFactory.Workflows.DslGeneration.start(workflow_opts) do
          {:ok, _workflow} -> {:ok, project}
          {:error, reason} -> {:error, {:workflow_failed, reason}}
        end
        
      {:error, reason} ->
        {:error, {:project_creation_failed, reason}}
    end
  end

  @doc """
  Starts continuous evolution for a DSL project.
  """
  def start_evolution(project_id, opts \\ []) do
    evolution_opts = %{
      dsl_project_id: project_id,
      mode: Keyword.get(opts, :mode, :continuous),
      autonomy_level: Keyword.get(opts, :autonomy_level, :full_auto),
      interval: Keyword.get(opts, :interval, :timer.hours(1))
    }
    
    AgiFactory.Workflows.ContinuousEvolution.start(evolution_opts)
  end

  @doc """
  Gets comprehensive metrics for the AGI factory.
  """
  def get_metrics do
    %{
      total_projects: count_projects(),
      active_generations: count_active_generations(),
      average_quality_score: calculate_average_quality(),
      success_rate: calculate_success_rate(),
      evolution_cycles: count_evolution_cycles(),
      system_health: assess_system_health()
    }
  end

  @doc """
  Analyzes system performance and suggests optimizations.
  """
  def analyze_performance do
    projects = read!(AgiFactory.Resources.DslProject)
    assessments = read!(AgiFactory.Resources.QualityAssessment)
    
    %{
      generation_speed: analyze_generation_speed(projects),
      quality_trends: analyze_quality_trends(assessments),
      bottlenecks: identify_bottlenecks(projects),
      optimization_suggestions: generate_optimization_suggestions(projects, assessments)
    }
  end

  # Private helper functions

  defp count_projects do
    AgiFactory.Resources.DslProject
    |> Ash.Query.for_read(:read)
    |> count!()
  end

  defp count_active_generations do
    AgiFactory.Resources.GenerationRequest
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(status in [:running, :pending])
    |> count!()
  end

  defp calculate_average_quality do
    AgiFactory.Resources.DslProject
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(not is_nil(quality_score))
    |> read!()
    |> Enum.map(& &1.quality_score)
    |> case do
      [] -> 0.0
      scores -> Enum.sum(scores) / length(scores)
    end
  end

  defp calculate_success_rate do
    total = count_projects()
    
    successful = AgiFactory.Resources.DslProject
                |> Ash.Query.for_read(:read)
                |> Ash.Query.filter(status == :deployed)
                |> count!()
    
    if total > 0, do: successful / total, else: 0.0
  end

  defp count_evolution_cycles do
    AgiFactory.Resources.EvolutionCycle
    |> Ash.Query.for_read(:read)
    |> count!()
  end

  defp assess_system_health do
    metrics = get_metrics()
    
    cond do
      metrics.success_rate > 0.9 and metrics.average_quality_score > 85 -> :excellent
      metrics.success_rate > 0.7 and metrics.average_quality_score > 75 -> :good
      metrics.success_rate > 0.5 and metrics.average_quality_score > 65 -> :fair
      true -> :poor
    end
  end

  defp analyze_generation_speed(projects) do
    completed_projects = Enum.filter(projects, &(&1.status in [:deployed, :testing]))
    
    if length(completed_projects) > 0 do
      times = Enum.map(completed_projects, fn project ->
        if project.completed_at && project.inserted_at do
          DateTime.diff(project.completed_at, project.inserted_at, :second)
        else
          nil
        end
      end)
      |> Enum.filter(& &1)
      
      if length(times) > 0 do
        %{
          average_seconds: Enum.sum(times) / length(times),
          fastest: Enum.min(times),
          slowest: Enum.max(times)
        }
      else
        %{average_seconds: 0, fastest: 0, slowest: 0}
      end
    else
      %{average_seconds: 0, fastest: 0, slowest: 0}
    end
  end

  defp analyze_quality_trends(assessments) do
    recent_assessments = assessments
                        |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
                        |> Enum.take(20)
    
    if length(recent_assessments) >= 2 do
      scores = Enum.map(recent_assessments, & &1.overall_score)
      recent_avg = scores |> Enum.take(5) |> Enum.sum() / 5
      older_avg = scores |> Enum.drop(5) |> Enum.take(5) |> Enum.sum() / 5
      
      trend = cond do
        recent_avg > older_avg + 2 -> :improving
        recent_avg < older_avg - 2 -> :declining
        true -> :stable
      end
      
      %{trend: trend, recent_average: recent_avg, change: recent_avg - older_avg}
    else
      %{trend: :insufficient_data, recent_average: 0, change: 0}
    end
  end

  defp identify_bottlenecks(projects) do
    bottlenecks = []
    
    # Check for slow generation times
    avg_speed = analyze_generation_speed(projects)
    if avg_speed.average_seconds > 300 do # 5 minutes
      bottlenecks = [:slow_generation | bottlenecks]
    end
    
    # Check for high failure rate
    if calculate_success_rate() < 0.7 do
      bottlenecks = [:high_failure_rate | bottlenecks]
    end
    
    # Check for low quality scores
    if calculate_average_quality() < 75 do
      bottlenecks = [:low_quality_output | bottlenecks]
    end
    
    bottlenecks
  end

  defp generate_optimization_suggestions(projects, assessments) do
    suggestions = []
    bottlenecks = identify_bottlenecks(projects)
    
    suggestions = if :slow_generation in bottlenecks do
      ["Optimize generation algorithms", "Increase parallel processing" | suggestions]
    else
      suggestions
    end
    
    suggestions = if :high_failure_rate in bottlenecks do
      ["Improve requirements validation", "Enhance error handling" | suggestions]
    else
      suggestions
    end
    
    suggestions = if :low_quality_output in bottlenecks do
      ["Tune quality assessment criteria", "Improve generation strategies" | suggestions]
    else
      suggestions
    end
    
    # Quality trend based suggestions
    quality_trends = analyze_quality_trends(assessments)
    suggestions = if quality_trends.trend == :declining do
      ["Investigate quality regression", "Update generation models" | suggestions]
    else
      suggestions
    end
    
    Enum.uniq(suggestions)
  end
end