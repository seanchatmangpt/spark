defmodule TaskDsl.Info do
  @moduledoc """
  Runtime introspection functions for TaskDsl.
  
  This module provides convenient functions for accessing
  task and project data at runtime.
  """
  
  use Spark.InfoGenerator,
    extension: TaskDsl.Extension,
    sections: [:projects]
  
  @doc """
  Get all tasks across all projects.
  """
  def all_tasks(module) do
    module
    |> projects()
    |> Enum.flat_map(& &1.tasks)
  end
  
  @doc """
  Get tasks filtered by status.
  """
  def tasks_by_status(module, status) do
    module
    |> all_tasks()
    |> Enum.filter(&(&1.status == status))
  end
  
  @doc """
  Get tasks assigned to a specific person.
  """
  def tasks_by_assignee(module, assignee) do
    module
    |> all_tasks()
    |> Enum.filter(&(&1.assignee == assignee))
  end
  
  @doc """
  Get tasks with a specific priority.
  """
  def tasks_by_priority(module, priority) do
    module
    |> all_tasks()
    |> Enum.filter(&(&1.priority == priority))
  end
  
  @doc """
  Get overdue tasks (due date has passed).
  """
  def overdue_tasks(module) do
    today = Date.utc_today()
    
    module
    |> all_tasks()
    |> Enum.filter(fn task ->
      task.due_date && Date.compare(task.due_date, today) == :lt && task.status != :done
    end)
  end
  
  @doc """
  Get project completion percentage.
  """
  def project_completion(module, project_name) do
    case project(module, project_name) do
      {:ok, project} ->
        total_tasks = length(project.tasks)
        
        if total_tasks == 0 do
          100.0
        else
          completed_tasks = Enum.count(project.tasks, &(&1.status == :done))
          (completed_tasks / total_tasks) * 100
        end
      
      :error ->
        0.0
    end
  end
  
  @doc """
  Generate a simple project report.
  """
  def project_report(module, project_name) do
    case project(module, project_name) do
      {:ok, project} ->
        total_tasks = length(project.tasks)
        completed = Enum.count(project.tasks, &(&1.status == :done))
        in_progress = Enum.count(project.tasks, &(&1.status == :in_progress))
        todo = Enum.count(project.tasks, &(&1.status == :todo))
        blocked = Enum.count(project.tasks, &(&1.status == :blocked))
        
        %{
          project_name: project.name,
          description: project.description,
          total_tasks: total_tasks,
          completed: completed,
          in_progress: in_progress,
          todo: todo,
          blocked: blocked,
          completion_percentage: project_completion(module, project_name)
        }
      
      :error ->
        {:error, :project_not_found}
    end
  end
  
  @doc """
  Get summary statistics across all projects.
  """
  def summary_stats(module) do
    all_tasks = all_tasks(module)
    total_projects = length(projects(module))
    
    %{
      total_projects: total_projects,
      total_tasks: length(all_tasks),
      completed_tasks: Enum.count(all_tasks, &(&1.status == :done)),
      in_progress_tasks: Enum.count(all_tasks, &(&1.status == :in_progress)),
      todo_tasks: Enum.count(all_tasks, &(&1.status == :todo)),
      blocked_tasks: Enum.count(all_tasks, &(&1.status == :blocked)),
      overdue_tasks: length(overdue_tasks(module)),
      high_priority_tasks: Enum.count(all_tasks, &(&1.priority == :high))
    }
  end
end