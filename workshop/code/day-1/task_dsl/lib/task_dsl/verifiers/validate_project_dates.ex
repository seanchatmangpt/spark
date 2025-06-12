defmodule TaskDsl.Verifiers.ValidateProjectDates do
  @moduledoc """
  Verifies that project dates are logical and consistent.
  
  This verifier checks:
  - End dates are after start dates
  - Task due dates fall within project timeline
  - Projects have reasonable duration
  """
  
  use Spark.Dsl.Verifier
  
  alias TaskDsl.Info
  
  @impl Spark.Dsl.Verifier
  def verify(dsl_state) do
    projects = Info.projects(dsl_state)
    
    with :ok <- validate_project_date_ranges(projects),
         :ok <- validate_task_dates_within_projects(projects),
         :ok <- validate_reasonable_project_duration(projects) do
      :ok
    end
  end
  
  defp validate_project_date_ranges(projects) do
    invalid_projects =
      projects
      |> Enum.filter(fn project ->
        project.start_date && project.end_date &&
          Date.compare(project.start_date, project.end_date) != :lt
      end)
      |> Enum.map(& &1.name)
    
    case invalid_projects do
      [] ->
        :ok
      
      invalid ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Project end dates must be after start dates. Invalid projects: #{inspect(invalid)}",
           path: [:projects]
         )}
    end
  end
  
  defp validate_task_dates_within_projects(projects) do
    invalid_tasks =
      projects
      |> Enum.flat_map(fn project ->
        case {project.start_date, project.end_date} do
          {nil, _} -> []
          {_, nil} -> []
          {start_date, end_date} ->
            project.tasks
            |> Enum.filter(fn task ->
              task.due_date &&
                (Date.compare(task.due_date, start_date) == :lt ||
                 Date.compare(task.due_date, end_date) == :gt)
            end)
            |> Enum.map(&{project.name, &1.name})
        end
      end)
    
    case invalid_tasks do
      [] ->
        :ok
      
      invalid ->
        formatted_tasks = Enum.map(invalid, fn {project, task} -> "#{project}/#{task}" end)
        
        {:error,
         Spark.Error.DslError.exception(
           message: "Task due dates must fall within project timeline. Invalid tasks: #{inspect(formatted_tasks)}",
           path: [:projects]
         )}
    end
  end
  
  defp validate_reasonable_project_duration(projects) do
    # Flag projects longer than 2 years as potentially unrealistic
    max_duration_days = 365 * 2
    
    overly_long_projects =
      projects
      |> Enum.filter(fn project ->
        case {project.start_date, project.end_date} do
          {nil, _} -> false
          {_, nil} -> false
          {start_date, end_date} ->
            Date.diff(end_date, start_date) > max_duration_days
        end
      end)
      |> Enum.map(& &1.name)
    
    case overly_long_projects do
      [] ->
        :ok
      
      long_projects ->
        # This is a warning, not an error - return :ok but could log
        IO.warn("Projects longer than 2 years detected: #{inspect(long_projects)}. Consider breaking into smaller projects.")
        :ok
    end
  end
end