defmodule AgiFactory.Repo.Migrations.CreateQualityAssessments do
  @moduledoc """
  Migration to create the quality_assessments table.
  
  Quality Assessments provide comprehensive evaluation of generated
  DSL implementations across multiple quality dimensions.
  """
  
  use Ecto.Migration

  def up do
    create table(:quality_assessments, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      
      add :dsl_project_id, references(:dsl_projects, type: :binary_id, on_delete: :delete_all), null: false
      add :generation_request_id, references(:generation_requests, type: :binary_id, on_delete: :nilify_all)
      
      add :assessment_type, :string, null: false, default: "automatic"
      add :overall_score, :decimal, precision: 5, scale: 2, null: false
      add :code_quality_score, :decimal, precision: 5, scale: 2
      add :performance_score, :decimal, precision: 5, scale: 2
      add :usability_score, :decimal, precision: 5, scale: 2
      add :maintainability_score, :decimal, precision: 5, scale: 2
      add :compliance_score, :decimal, precision: 5, scale: 2
      add :detailed_metrics, :map, default: "{}"
      add :issues_found, {:array, :map}, default: "[]"
      add :recommendations, {:array, :text}, default: "{}"
      add :assessment_duration_ms, :integer
      add :assessor_metadata, :map, default: "{}"
      
      timestamps(type: :utc_datetime)
    end
    
    create index(:quality_assessments, [:dsl_project_id], 
      name: :quality_assessments_project_index)
    create index(:quality_assessments, [:generation_request_id], 
      name: :quality_assessments_generation_request_index)
    create index(:quality_assessments, [:assessment_type], 
      name: :quality_assessments_type_index)
    create index(:quality_assessments, [:overall_score], 
      name: :quality_assessments_overall_score_index)
    create index(:quality_assessments, [:inserted_at], 
      name: :quality_assessments_inserted_at_index)
    
    # Score range indexes for performance
    create index(:quality_assessments, [:overall_score], 
      where: "overall_score >= 90",
      name: :quality_assessments_excellent_index)
    create index(:quality_assessments, [:overall_score], 
      where: "overall_score >= 80 AND overall_score < 90",
      name: :quality_assessments_good_index)
    create index(:quality_assessments, [:overall_score], 
      where: "overall_score < 70",
      name: :quality_assessments_needs_improvement_index)
    
    # Composite indexes for analytics
    create index(:quality_assessments, [:dsl_project_id, :inserted_at], 
      name: :quality_assessments_project_timeline_index)
    create index(:quality_assessments, [:assessment_type, :overall_score], 
      name: :quality_assessments_type_score_index)
    
    # GIN indexes for JSON fields
    create index(:quality_assessments, [:detailed_metrics], using: :gin, 
      name: :quality_assessments_detailed_metrics_gin_index)
    create index(:quality_assessments, [:issues_found], using: :gin, 
      name: :quality_assessments_issues_found_gin_index)
    create index(:quality_assessments, [:assessor_metadata], using: :gin, 
      name: :quality_assessments_assessor_metadata_gin_index)
    
    # Check constraints for score ranges
    execute """
    ALTER TABLE quality_assessments 
    ADD CONSTRAINT quality_assessments_assessment_type_check 
    CHECK (assessment_type IN ('automatic', 'manual', 'hybrid', 'peer_review'))
    """
    
    execute """
    ALTER TABLE quality_assessments 
    ADD CONSTRAINT quality_assessments_overall_score_check 
    CHECK (overall_score >= 0 AND overall_score <= 100)
    """
    
    execute """
    ALTER TABLE quality_assessments 
    ADD CONSTRAINT quality_assessments_code_quality_score_check 
    CHECK (code_quality_score IS NULL OR (code_quality_score >= 0 AND code_quality_score <= 100))
    """
    
    execute """
    ALTER TABLE quality_assessments 
    ADD CONSTRAINT quality_assessments_performance_score_check 
    CHECK (performance_score IS NULL OR (performance_score >= 0 AND performance_score <= 100))
    """
    
    execute """
    ALTER TABLE quality_assessments 
    ADD CONSTRAINT quality_assessments_usability_score_check 
    CHECK (usability_score IS NULL OR (usability_score >= 0 AND usability_score <= 100))
    """
    
    execute """
    ALTER TABLE quality_assessments 
    ADD CONSTRAINT quality_assessments_maintainability_score_check 
    CHECK (maintainability_score IS NULL OR (maintainability_score >= 0 AND maintainability_score <= 100))
    """
    
    execute """
    ALTER TABLE quality_assessments 
    ADD CONSTRAINT quality_assessments_compliance_score_check 
    CHECK (compliance_score IS NULL OR (compliance_score >= 0 AND compliance_score <= 100))
    """
    
    execute """
    ALTER TABLE quality_assessments 
    ADD CONSTRAINT quality_assessments_duration_check 
    CHECK (assessment_duration_ms IS NULL OR assessment_duration_ms >= 0)
    """
  end

  def down do
    drop table(:quality_assessments)
  end
end