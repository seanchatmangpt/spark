defmodule AgiFactory.Repo.Migrations.CreateDslProjects do
  @moduledoc """
  Migration to create the dsl_projects table.
  
  DSL Projects are the core entity representing the complete lifecycle
  of DSL generation from requirements to deployment.
  """
  
  use Ecto.Migration

  def up do
    # Enable required extensions
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""
    execute "CREATE EXTENSION IF NOT EXISTS \"citext\""
    
    create table(:dsl_projects, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      
      add :name, :citext, null: false
      add :requirements, :text, null: false
      add :specification, :map
      add :generated_code, :text
      add :quality_score, :decimal, precision: 5, scale: 2
      add :status, :string, null: false, default: "draft"
      add :complexity, :string
      add :metadata, :map, default: "{}"
      add :completed_at, :utc_datetime
      add :deployed_at, :utc_datetime
      
      timestamps(type: :utc_datetime)
    end
    
    create unique_index(:dsl_projects, [:name], name: :dsl_projects_unique_name_index)
    create index(:dsl_projects, [:status], name: :dsl_projects_status_index)
    create index(:dsl_projects, [:quality_score], name: :dsl_projects_quality_score_index)
    create index(:dsl_projects, [:complexity], name: :dsl_projects_complexity_index)
    create index(:dsl_projects, [:inserted_at], name: :dsl_projects_inserted_at_index)
    create index(:dsl_projects, [:completed_at], name: :dsl_projects_completed_at_index)
    create index(:dsl_projects, [:deployed_at], name: :dsl_projects_deployed_at_index)
    
    # Partial index for active projects
    create index(:dsl_projects, [:id], 
      where: "status IN ('draft', 'generating', 'testing', 'evolving')",
      name: :dsl_projects_active_index
    )
    
    # GIN index for metadata search
    create index(:dsl_projects, [:metadata], using: :gin, name: :dsl_projects_metadata_gin_index)
    
    # Check constraints
    execute """
    ALTER TABLE dsl_projects 
    ADD CONSTRAINT dsl_projects_status_check 
    CHECK (status IN ('draft', 'generating', 'testing', 'deployed', 'failed', 'evolving'))
    """
    
    execute """
    ALTER TABLE dsl_projects 
    ADD CONSTRAINT dsl_projects_complexity_check 
    CHECK (complexity IN ('simple', 'standard', 'advanced', 'enterprise'))
    """
    
    execute """
    ALTER TABLE dsl_projects 
    ADD CONSTRAINT dsl_projects_quality_score_check 
    CHECK (quality_score IS NULL OR (quality_score >= 0 AND quality_score <= 100))
    """
    
    # Ensure name length constraints
    execute """
    ALTER TABLE dsl_projects 
    ADD CONSTRAINT dsl_projects_name_length_check 
    CHECK (char_length(name) >= 2 AND char_length(name) <= 100)
    """
    
    # Ensure requirements minimum length
    execute """
    ALTER TABLE dsl_projects 
    ADD CONSTRAINT dsl_projects_requirements_length_check 
    CHECK (char_length(requirements) >= 10)
    """
  end

  def down do
    drop table(:dsl_projects)
  end
end