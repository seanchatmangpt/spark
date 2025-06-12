defmodule TaskDsl do
  @moduledoc """
  A simple task management DSL for learning Spark fundamentals.
  
  This DSL demonstrates basic concepts including:
  - Entity definitions with structs
  - Schema validation 
  - Nested sections and entities
  - Runtime introspection
  
  ## Example Usage
  
      defmodule TeamTasks do
        use TaskDsl
        
        projects do
          project "Spark Workshop" do
            description "Learn to build DSLs with Spark"
            
            task "Setup environment" do
              priority :high
              assignee "participants"
              due_date ~D[2024-01-20]
              status :done
            end
            
            task "Build first DSL" do
              priority :high
              assignee "participants"  
              status :in_progress
            end
          end
        end
      end
  """
  
  use Spark.Dsl,
    default_extensions: [extensions: [TaskDsl.Extension]]
end