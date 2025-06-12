defmodule AgiFactory.Repo.Migrations.CreateEvolutionCycles do
  @moduledoc """
  Migration to create the evolution_cycles table.
  
  Evolution Cycles track continuous improvement attempts on DSL projects,
  including strategy, metrics, and results of evolutionary processes.
  """
  
  use Ecto.Migration

  def up do
    create table(:evolution_cycles, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      
      add :dsl_project_id, references(:dsl_projects, type: :binary_id, on_delete: :delete_all), null: false
      
      add :cycle_number, :integer, null: false
      add :evolution_strategy, :string, null: false, default: "genetic"
      add :status, :string, null: false, default: "initializing"
      add :trigger_reason, :string
      add :baseline_metrics, :map, default: "{}"
      add :target_metrics, :map, default: "{}"
      add :improvements_generated, :integer, default: 0
      add :improvements_tested, :integer, default: 0
      add :improvements_applied, :integer, default: 0
      add :final_metrics, :map, default: "{}"
      add :performance_improvement, :decimal, precision: 8, scale: 4
      add :quality_improvement, :decimal, precision: 8, scale: 4
      add :evolution_data, :map, default: "{}"
      add :lessons_learned, {:array, :text}, default: "{}"
      add :next_cycle_recommendations, {:array, :text}, default: "{}"
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :duration_ms, :bigint
      
      timestamps(type: :utc_datetime)
    end
    
    create index(:evolution_cycles, [:dsl_project_id], 
      name: :evolution_cycles_project_index)
    create index(:evolution_cycles, [:cycle_number], 
      name: :evolution_cycles_cycle_number_index)
    create index(:evolution_cycles, [:evolution_strategy], 
      name: :evolution_cycles_strategy_index)
    create index(:evolution_cycles, [:status], 
      name: :evolution_cycles_status_index)
    create index(:evolution_cycles, [:trigger_reason], 
      name: :evolution_cycles_trigger_reason_index)
    create index(:evolution_cycles, [:started_at], 
      name: :evolution_cycles_started_at_index)
    create index(:evolution_cycles, [:completed_at], 
      name: :evolution_cycles_completed_at_index)
    create index(:evolution_cycles, [:performance_improvement], 
      name: :evolution_cycles_performance_improvement_index)
    create index(:evolution_cycles, [:quality_improvement], 
      name: :evolution_cycles_quality_improvement_index)
    
    # Unique constraint for project + cycle number
    create unique_index(:evolution_cycles, [:dsl_project_id, :cycle_number], 
      name: :evolution_cycles_project_cycle_unique_index)
    
    # Composite indexes for analytics
    create index(:evolution_cycles, [:dsl_project_id, :started_at], 
      name: :evolution_cycles_project_timeline_index)
    create index(:evolution_cycles, [:evolution_strategy, :status], 
      name: :evolution_cycles_strategy_status_index)
    create index(:evolution_cycles, [:status, :started_at], 
      name: :evolution_cycles_status_timeline_index)
    
    # Partial indexes for performance
    create index(:evolution_cycles, [:id], 
      where: "status IN ('initializing', 'analyzing', 'generating', 'testing', 'applying')",
      name: :evolution_cycles_active_index)
    create index(:evolution_cycles, [:id], 
      where: "status = 'completed' AND performance_improvement > 0",
      name: :evolution_cycles_successful_index)
    create index(:evolution_cycles, [:id], 
      where: "performance_improvement > 10 OR quality_improvement > 10",
      name: :evolution_cycles_high_impact_index)
    
    # GIN indexes for JSON fields
    create index(:evolution_cycles, [:baseline_metrics], using: :gin, 
      name: :evolution_cycles_baseline_metrics_gin_index)
    create index(:evolution_cycles, [:target_metrics], using: :gin, 
      name: :evolution_cycles_target_metrics_gin_index)
    create index(:evolution_cycles, [:final_metrics], using: :gin, 
      name: :evolution_cycles_final_metrics_gin_index)
    create index(:evolution_cycles, [:evolution_data], using: :gin, 
      name: :evolution_cycles_evolution_data_gin_index)
    
    # Check constraints
    execute """
    ALTER TABLE evolution_cycles 
    ADD CONSTRAINT evolution_cycles_cycle_number_check 
    CHECK (cycle_number >= 1)
    """
    
    execute """
    ALTER TABLE evolution_cycles 
    ADD CONSTRAINT evolution_cycles_strategy_check 
    CHECK (evolution_strategy IN ('genetic', 'gradient_descent', 'random_search', 'bayesian', 'hybrid'))
    """
    
    execute """
    ALTER TABLE evolution_cycles 
    ADD CONSTRAINT evolution_cycles_status_check 
    CHECK (status IN ('initializing', 'analyzing', 'generating', 'testing', 'applying', 'completed', 'failed'))
    """
    
    execute """
    ALTER TABLE evolution_cycles 
    ADD CONSTRAINT evolution_cycles_trigger_reason_check 
    CHECK (trigger_reason IN ('scheduled', 'performance_degradation', 'quality_issues', 'user_feedback', 'manual'))
    """
    
    execute """
    ALTER TABLE evolution_cycles 
    ADD CONSTRAINT evolution_cycles_improvements_consistency_check 
    CHECK (
      improvements_tested <= improvements_generated AND 
      improvements_applied <= improvements_tested
    )
    """
    
    execute """
    ALTER TABLE evolution_cycles 
    ADD CONSTRAINT evolution_cycles_improvements_non_negative_check 
    CHECK (
      improvements_generated >= 0 AND 
      improvements_tested >= 0 AND 
      improvements_applied >= 0
    )
    """
    
    execute """
    ALTER TABLE evolution_cycles 
    ADD CONSTRAINT evolution_cycles_duration_check 
    CHECK (duration_ms IS NULL OR duration_ms >= 0)
    """
    
    # Logical constraints for completion
    execute """
    ALTER TABLE evolution_cycles 
    ADD CONSTRAINT evolution_cycles_completion_logic_check 
    CHECK (
      (status IN ('initializing', 'analyzing', 'generating', 'testing', 'applying') AND completed_at IS NULL) OR
      (status IN ('completed', 'failed') AND completed_at IS NOT NULL)
    )
    """
    
    execute """
    ALTER TABLE evolution_cycles 
    ADD CONSTRAINT evolution_cycles_timing_logic_check 
    CHECK (
      (started_at IS NULL AND completed_at IS NULL) OR
      (started_at IS NOT NULL AND (completed_at IS NULL OR completed_at >= started_at))
    )
    """
  end

  def down do
    drop table(:evolution_cycles)
  end
end