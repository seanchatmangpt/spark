# TaskDsl

A simple task management DSL built with Spark for learning fundamental concepts.

This project demonstrates:
- Basic entity definitions with structs
- Schema validation and type checking
- Nested sections and entities
- Runtime introspection with Info modules
- Custom verifiers for business logic validation

## Installation

Add `task_dsl` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:task_dsl, "~> 0.1.0"}
  ]
end
```

## Usage

Define your projects and tasks using the DSL:

```elixir
defmodule MyTeam.Tasks do
  use TaskDsl
  
  projects do
    project "Website Redesign" do
      description "Complete overhaul of company website"
      start_date ~D[2024-02-01]
      end_date ~D[2024-04-30]
      owner "design_team"
      
      task "Create wireframes" do
        priority :high
        assignee "designer"
        due_date ~D[2024-02-15]
        status :in_progress
        estimated_hours 16
      end
      
      task "Implement frontend" do
        priority :medium
        assignee "frontend_dev"
        due_date ~D[2024-03-15]
        status :todo
        estimated_hours 40
      end
      
      task "User testing" do
        priority :medium
        assignee "ux_researcher"
        due_date ~D[2024-04-01]
        status :todo
        estimated_hours 20
      end
    end
    
    project "Mobile App" do
      description "Native mobile application development"
      owner "mobile_team"
      
      task "Setup React Native" do
        priority :high
        assignee "mobile_dev"
        status :done
        estimated_hours 8
      end
      
      task "Implement authentication" do
        priority :high
        assignee "mobile_dev"
        status :in_progress
        estimated_hours 24
      end
    end
  end
end
```

## Runtime Introspection

Query your task data at runtime:

```elixir
# Get all projects
TaskDsl.Info.projects(MyTeam.Tasks)

# Get specific project
{:ok, project} = TaskDsl.Info.project(MyTeam.Tasks, "Website Redesign")

# Get all tasks across projects
TaskDsl.Info.all_tasks(MyTeam.Tasks)

# Filter tasks by various criteria
TaskDsl.Info.tasks_by_status(MyTeam.Tasks, :in_progress)
TaskDsl.Info.tasks_by_assignee(MyTeam.Tasks, "designer")
TaskDsl.Info.tasks_by_priority(MyTeam.Tasks, :high)

# Get overdue tasks
TaskDsl.Info.overdue_tasks(MyTeam.Tasks)

# Generate project reports
TaskDsl.Info.project_report(MyTeam.Tasks, "Website Redesign")
# =>
# %{
#   project_name: "Website Redesign",
#   description: "Complete overhaul of company website",
#   total_tasks: 3,
#   completed: 0,
#   in_progress: 1,
#   todo: 2,
#   blocked: 0,
#   completion_percentage: 0.0
# }

# Get overall statistics
TaskDsl.Info.summary_stats(MyTeam.Tasks)
```

## Validation

The DSL includes several built-in validations:

- **Date consistency**: Project end dates must be after start dates
- **Task timeline**: Task due dates must fall within project timeline
- **Enum validation**: Priority and status must be valid values
- **Required fields**: Project and task names are required

Example of validation in action:

```elixir
# This will raise a compilation error:
defmodule InvalidTasks do
  use TaskDsl
  
  projects do
    project "Bad Project" do
      start_date ~D[2024-01-01]
      end_date ~D[2023-12-31]  # End before start!
      
      task "Bad Task" do
        due_date ~D[2025-01-01]  # Outside project timeline!
        priority :urgent         # Invalid priority!
      end
    end
  end
end
```

## Learning Objectives

This DSL demonstrates key Spark concepts:

1. **Entity Definition**: How to define data structures for your domain
2. **Schema Validation**: Type checking and constraint validation
3. **Nested Relationships**: Entities containing other entities
4. **Runtime Access**: Using Info modules for data retrieval
5. **Custom Validation**: Business logic validation with verifiers
6. **Documentation**: Self-documenting DSLs with examples

## Testing

Run the test suite:

```bash
mix test
```

Generate documentation:

```bash
mix docs
```

## Next Steps

This basic DSL could be extended with:

- **Transformers**: Automatically add creation timestamps, generate IDs
- **More Entities**: Milestones, dependencies, comments, time tracking
- **Complex Validation**: Resource allocation, scheduling conflicts
- **Integration**: Export to project management tools, calendar integration
- **Reporting**: Gantt charts, burndown charts, team utilization

The patterns learned here scale to much more sophisticated business domains!