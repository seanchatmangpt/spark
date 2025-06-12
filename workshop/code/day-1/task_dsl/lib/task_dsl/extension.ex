defmodule TaskDsl.Extension do
  @moduledoc """
  Spark DSL extension for task management.
  
  This module defines the structure and validation rules
  for the task management DSL.
  """
  
  alias TaskDsl.Entities
  
  @task %Spark.Dsl.Entity{
    name: :task,
    target: Entities.Task,
    args: [:name],
    describe: "Define a task within a project",
    examples: [
      """
      task "Setup development environment" do
        priority :high
        assignee "developer"
        due_date ~D[2024-01-30]
        status :todo
        description "Install Elixir, configure editor, clone repository"
        estimated_hours 4
      end
      """
    ],
    schema: [
      name: [
        type: :string,
        required: true,
        doc: "The name of the task"
      ],
      priority: [
        type: {:one_of, [:low, :medium, :high]},
        default: :medium,
        doc: "Task priority level"
      ],
      due_date: [
        type: :date,
        doc: "When the task should be completed"
      ],
      assignee: [
        type: :string,
        doc: "Person responsible for the task"
      ],
      status: [
        type: {:one_of, [:todo, :in_progress, :done, :blocked]},
        default: :todo,
        doc: "Current task status"
      ],
      description: [
        type: :string,
        doc: "Detailed description of the task"
      ],
      estimated_hours: [
        type: :non_neg_integer,
        doc: "Estimated hours to complete the task"
      ]
    ]
  }
  
  @project %Spark.Dsl.Entity{
    name: :project,
    target: Entities.Project,
    args: [:name],
    entities: [task: @task],
    describe: "Define a project containing tasks",
    examples: [
      """
      project "Website Redesign" do
        description "Complete overhaul of company website"
        start_date ~D[2024-02-01]
        end_date ~D[2024-04-30]
        owner "design_team"
        
        task "Create wireframes" do
          priority :high
          assignee "designer"
          estimated_hours 16
        end
        
        task "Implement frontend" do
          priority :medium
          assignee "frontend_dev"
          estimated_hours 40
        end
      end
      """
    ],
    schema: [
      name: [
        type: :string,
        required: true,
        doc: "The name of the project"
      ],
      description: [
        type: :string,
        doc: "Project description and goals"
      ],
      start_date: [
        type: :date,
        doc: "Project start date"
      ],
      end_date: [
        type: :date,
        doc: "Project target completion date"
      ],
      owner: [
        type: :string,
        doc: "Person or team responsible for the project"
      ]
    ]
  }
  
  @projects %Spark.Dsl.Section{
    name: :projects,
    entities: [@project],
    describe: "Define projects and their tasks"
  }
  
  use Spark.Dsl.Extension,
    sections: [@projects],
    verifiers: [TaskDsl.Verifiers.ValidateProjectDates]
end