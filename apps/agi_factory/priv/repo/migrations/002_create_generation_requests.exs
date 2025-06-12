defmodule AgiFactory.Repo.Migrations.CreateGenerationRequests do
  use Ecto.Migration

  def change do
    create table(:generation_requests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :dsl_project_id, references(:dsl_projects, type: :binary_id, on_delete: :delete_all), null: false
      add :strategy_type, :string, null: false
      add :parameters, :map, default: %{}
      add :status, :string, null: false, default: "pending"
      add :priority, :integer, default: 1
      add :result, :map
      add :error_message, :text
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      
      timestamps()
    end
    
    create index(:generation_requests, [:dsl_project_id])
    create index(:generation_requests, [:status])
    create index(:generation_requests, [:priority])
    create index(:generation_requests, [:started_at])
  end
end