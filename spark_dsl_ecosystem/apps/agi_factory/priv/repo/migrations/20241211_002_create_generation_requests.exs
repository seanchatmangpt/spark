defmodule AgiFactory.Repo.Migrations.CreateGenerationRequests do
  @moduledoc """
  Migration to create the generation_requests table.
  
  Generation Requests track individual DSL generation attempts,
  enabling analysis of strategy effectiveness and performance.
  """
  
  use Ecto.Migration

  def up do
    create table(:generation_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      
      add :dsl_project_id, references(:dsl_projects, type: :binary_id, on_delete: :delete_all), null: false
      
      add :strategy, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :parameters, :map, default: "{}"
      add :generated_code, :text
      add :quality_metrics, :map, default: "{}"
      add :execution_time_ms, :integer
      add :error_details, :map
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      
      timestamps(type: :utc_datetime)
    end
    
    create index(:generation_requests, [:dsl_project_id], name: :generation_requests_project_index)
    create index(:generation_requests, [:strategy], name: :generation_requests_strategy_index)
    create index(:generation_requests, [:status], name: :generation_requests_status_index)
    create index(:generation_requests, [:started_at], name: :generation_requests_started_at_index)
    create index(:generation_requests, [:completed_at], name: :generation_requests_completed_at_index)
    create index(:generation_requests, [:execution_time_ms], name: :generation_requests_execution_time_index)
    
    # Composite index for project + status queries
    create index(:generation_requests, [:dsl_project_id, :status], 
      name: :generation_requests_project_status_index)
    
    # Composite index for strategy performance analysis
    create index(:generation_requests, [:strategy, :status, :execution_time_ms], 
      name: :generation_requests_strategy_performance_index)
    
    # Partial index for active requests
    create index(:generation_requests, [:id], 
      where: "status IN ('pending', 'running')",
      name: :generation_requests_active_index
    )
    
    # Partial index for completed requests with code
    create index(:generation_requests, [:id], 
      where: "status = 'completed' AND generated_code IS NOT NULL",
      name: :generation_requests_successful_index)
    
    # GIN indexes for JSON fields
    create index(:generation_requests, [:parameters], using: :gin, 
      name: :generation_requests_parameters_gin_index)
    create index(:generation_requests, [:quality_metrics], using: :gin, 
      name: :generation_requests_quality_metrics_gin_index)
    create index(:generation_requests, [:error_details], using: :gin, 
      name: :generation_requests_error_details_gin_index)
    
    # Check constraints
    execute """
    ALTER TABLE generation_requests 
    ADD CONSTRAINT generation_requests_strategy_check 
    CHECK (strategy IN ('template', 'pattern_based', 'example_driven', 'hybrid', 'ai_assisted'))
    """
    
    execute """
    ALTER TABLE generation_requests 
    ADD CONSTRAINT generation_requests_status_check 
    CHECK (status IN ('pending', 'running', 'completed', 'failed', 'cancelled'))
    """
    
    execute """
    ALTER TABLE generation_requests 
    ADD CONSTRAINT generation_requests_execution_time_check 
    CHECK (execution_time_ms IS NULL OR execution_time_ms >= 0)
    """
    
    # Logical constraints
    execute """
    ALTER TABLE generation_requests 
    ADD CONSTRAINT generation_requests_completion_logic_check 
    CHECK (
      (status IN ('pending', 'running') AND completed_at IS NULL) OR
      (status IN ('completed', 'failed', 'cancelled') AND completed_at IS NOT NULL)
    )
    """
    
    execute """
    ALTER TABLE generation_requests 
    ADD CONSTRAINT generation_requests_success_logic_check 
    CHECK (
      (status = 'completed' AND generated_code IS NOT NULL) OR
      (status != 'completed')
    )
    """
  end

  def down do
    drop table(:generation_requests)
  end
end