defmodule AgiFactory.Repo.Migrations.CreateDslProjects do
  use Ecto.Migration

  def change do
    create table(:dsl_projects, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :requirements, :text, null: false
      add :specification, :map
      add :generated_code, :text
      add :quality_score, :decimal
      add :status, :string, null: false, default: "draft"
      add :metadata, :map, default: %{}
      
      timestamps()
    end
    
    create index(:dsl_projects, [:status])
    create index(:dsl_projects, [:quality_score])
    create unique_index(:dsl_projects, [:name])
  end
end