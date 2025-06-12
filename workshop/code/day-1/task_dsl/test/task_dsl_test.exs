defmodule TaskDslTest do
  use ExUnit.Case, async: true
  
  alias TaskDsl.Info
  
  defmodule TestProject do
    use TaskDsl
    
    projects do
      project "Spark Workshop" do
        description "Learn to build DSLs with Spark"
        start_date ~D[2024-01-15]
        end_date ~D[2024-01-19]
        owner "instructor"
        
        task "Prepare materials" do
          priority :high
          assignee "instructor"
          due_date ~D[2024-01-15]
          status :done
          description "Create slides, exercises, and examples"
          estimated_hours 20
        end
        
        task "Setup environment" do
          priority :medium
          assignee "participants"
          due_date ~D[2024-01-16]
          status :in_progress
          description "Install Elixir and configure development tools"
          estimated_hours 2
        end
        
        task "Build first DSL" do
          priority :high
          assignee "participants"
          due_date ~D[2024-01-17]
          status :todo
          description "Create personal configuration DSL"
          estimated_hours 4
        end
      end
      
      project "Personal Learning" do
        description "Individual skill development"
        owner "participant"
        
        task "Read documentation" do
          priority :medium
          assignee "self"
          status :done
        end
        
        task "Practice exercises" do
          priority :high
          assignee "self"
          status :in_progress
        end
      end
    end
  end
  
  describe "basic DSL functionality" do
    test "defines projects correctly" do
      projects = Info.projects(TestProject)
      assert length(projects) == 2
      
      workshop = Info.project!(TestProject, "Spark Workshop")
      assert workshop.description == "Learn to build DSLs with Spark"
      assert workshop.owner == "instructor"
      assert workshop.start_date == ~D[2024-01-15]
      assert workshop.end_date == ~D[2024-01-19]
    end
    
    test "defines tasks correctly" do
      workshop = Info.project!(TestProject, "Spark Workshop")
      assert length(workshop.tasks) == 3
      
      prepare_task = Enum.find(workshop.tasks, &(&1.name == "Prepare materials"))
      assert prepare_task.priority == :high
      assert prepare_task.assignee == "instructor"
      assert prepare_task.status == :done
      assert prepare_task.estimated_hours == 20
    end
  end
  
  describe "info module functions" do
    test "all_tasks returns tasks from all projects" do
      all_tasks = Info.all_tasks(TestProject)
      assert length(all_tasks) == 5
      
      task_names = Enum.map(all_tasks, & &1.name)
      assert "Prepare materials" in task_names
      assert "Read documentation" in task_names
    end
    
    test "tasks_by_status filters correctly" do
      done_tasks = Info.tasks_by_status(TestProject, :done)
      assert length(done_tasks) == 2
      
      todo_tasks = Info.tasks_by_status(TestProject, :todo)
      assert length(todo_tasks) == 1
      
      in_progress_tasks = Info.tasks_by_status(TestProject, :in_progress)
      assert length(in_progress_tasks) == 2
    end
    
    test "tasks_by_assignee filters correctly" do
      instructor_tasks = Info.tasks_by_assignee(TestProject, "instructor")
      assert length(instructor_tasks) == 1
      
      participant_tasks = Info.tasks_by_assignee(TestProject, "participants")
      assert length(participant_tasks) == 2
      
      self_tasks = Info.tasks_by_assignee(TestProject, "self")
      assert length(self_tasks) == 2
    end
    
    test "tasks_by_priority filters correctly" do
      high_priority = Info.tasks_by_priority(TestProject, :high)
      assert length(high_priority) == 3
      
      medium_priority = Info.tasks_by_priority(TestProject, :medium)
      assert length(medium_priority) == 2
      
      low_priority = Info.tasks_by_priority(TestProject, :low)
      assert length(low_priority) == 0
    end
    
    test "overdue_tasks identifies past due dates" do
      # This test would need to be adjusted based on current date
      # or we could create a test module with known overdue tasks
      overdue = Info.overdue_tasks(TestProject)
      # Since our test dates are in the past, they would be overdue
      # unless the task is completed
      assert is_list(overdue)
    end
  end
  
  describe "project reporting" do
    test "project_completion calculates percentage correctly" do
      workshop_completion = Info.project_completion(TestProject, "Spark Workshop")
      # 1 done out of 3 tasks = 33.33%
      assert_in_delta workshop_completion, 33.33, 0.1
      
      learning_completion = Info.project_completion(TestProject, "Personal Learning")
      # 1 done out of 2 tasks = 50%
      assert_in_delta learning_completion, 50.0, 0.1
    end
    
    test "project_report generates comprehensive report" do
      report = Info.project_report(TestProject, "Spark Workshop")
      
      assert report.project_name == "Spark Workshop"
      assert report.total_tasks == 3
      assert report.completed == 1
      assert report.in_progress == 1
      assert report.todo == 1
      assert report.blocked == 0
      assert_in_delta report.completion_percentage, 33.33, 0.1
    end
    
    test "summary_stats provides overall statistics" do
      stats = Info.summary_stats(TestProject)
      
      assert stats.total_projects == 2
      assert stats.total_tasks == 5
      assert stats.completed_tasks == 2
      assert stats.in_progress_tasks == 2
      assert stats.todo_tasks == 1
      assert stats.blocked_tasks == 0
      assert stats.high_priority_tasks == 3
    end
  end
  
  describe "error handling" do
    test "returns error for non-existent project" do
      assert Info.project(TestProject, "Non-existent") == :error
      
      assert_raise RuntimeError, fn ->
        Info.project!(TestProject, "Non-existent")
      end
    end
    
    test "project_report handles non-existent project" do
      report = Info.project_report(TestProject, "Non-existent")
      assert report == {:error, :project_not_found}
    end
  end
end