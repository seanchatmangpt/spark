defmodule AgiFactory.Resources.DslProject do
  @moduledoc """
  DSL Project resource representing a complete DSL generation lifecycle.
  
  A DSL Project captures the journey from natural language requirements
  to a fully generated, tested, and deployed DSL implementation.
  """
  
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer, AshJsonApi.Resource],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "dsl_projects"
    repo AgiFactory.Repo
    
    references do
      reference :generation_requests, on_delete: :delete
      reference :quality_assessments, on_delete: :delete
      reference :evolution_cycles, on_delete: :delete
    end
  end

  json_api do
    type "dsl_project"
    routes do
      base "/api/dsl_projects"
      get :read
      index :read
      post :create
      post :generate_from_requirements
      patch :update
      delete :destroy
    end
  end

  attributes do
    uuid_primary_key :id
    
    attribute :name, :string do
      allow_nil? false
      constraints [min_length: 2, max_length: 100]
    end
    
    attribute :requirements, :string do
      allow_nil? false
      constraints [min_length: 10, max_length: 10000]
    end
    
    attribute :specification, :map do
      description "Parsed and structured requirements specification"
    end
    
    attribute :generated_code, :string do
      description "The final generated DSL implementation"
      constraints [max_length: 100000]
    end
    
    attribute :quality_score, :decimal do
      description "Overall quality score (0-100)"
      constraints [min: 0, max: 100]
    end
    
    attribute :status, :atom do
      description "Current project status"
      constraints [one_of: [:draft, :generating, :testing, :deployed, :failed, :evolving]]
      default :draft
    end
    
    attribute :complexity, :atom do
      description "Estimated complexity level"
      constraints [one_of: [:simple, :standard, :advanced, :enterprise]]
    end
    
    attribute :metadata, :map do
      description "Additional project metadata and configuration"
      default %{}
    end
    
    attribute :completed_at, :utc_datetime do
      description "When the project was completed"
    end
    
    attribute :deployed_at, :utc_datetime do
      description "When the project was deployed"
    end
    
    timestamps()
  end

  relationships do
    has_many :generation_requests, AgiFactory.Resources.GenerationRequest do
      description "All generation attempts for this project"
    end
    
    has_many :quality_assessments, AgiFactory.Resources.QualityAssessment do
      description "Quality evaluations performed on this project"
    end
    
    has_many :evolution_cycles, AgiFactory.Resources.EvolutionCycle do
      description "Evolution cycles that have been run on this project"
    end
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :generate_from_requirements do
      description "Creates a project and starts the generation workflow"
      accept [:name, :requirements]
      
      argument :generation_options, :map do
        description "Options for the generation workflow"
        default %{}
      end
      
      change AgiFactory.Changes.ParseRequirements
      change AgiFactory.Changes.CreateSpecification
      change AgiFactory.Changes.EstimateComplexity
      change set_attribute(:status, :generating)
      
      after_action AgiFactory.AfterActions.TriggerGeneration
    end
    
    update :complete_generation do
      description "Marks generation as complete with results"
      accept [:generated_code, :quality_score]
      
      argument :test_results, :map do
        description "Results from automated testing"
        default %{}
      end
      
      change AgiFactory.Changes.ValidateGeneration
      change AgiFactory.Changes.ProcessTestResults
      change set_attribute(:status, :testing)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
      
      after_action AgiFactory.AfterActions.DeployIfReady
    end
    
    update :deploy do
      description "Deploys the generated DSL"
      accept []
      
      change AgiFactory.Changes.ValidateDeploymentReadiness
      change set_attribute(:status, :deployed)
      change set_attribute(:deployed_at, &DateTime.utc_now/0)
      
      after_action AgiFactory.AfterActions.NotifyDeployment
    end
    
    update :start_evolution do
      description "Begins continuous evolution for this project"
      accept []
      
      argument :evolution_options, :map do
        description "Options for evolution process"
        default %{}
      end
      
      change set_attribute(:status, :evolving)
      
      after_action AgiFactory.AfterActions.StartEvolutionCycle
    end
    
    update :mark_failed do
      description "Marks the project as failed with error details"
      accept []
      
      argument :error_details, :map do
        description "Details about the failure"
        allow_nil? false
      end
      
      change AgiFactory.Changes.RecordFailure
      change set_attribute(:status, :failed)
    end
    
    read :by_status do
      description "Read projects by status"
      
      argument :status, :atom do
        description "Status to filter by"
        allow_nil? false
        constraints [one_of: [:draft, :generating, :testing, :deployed, :failed, :evolving]]
      end
      
      filter expr(status == ^arg(:status))
    end
    
    read :high_quality do
      description "Read projects with high quality scores"
      
      argument :minimum_score, :decimal do
        description "Minimum quality score threshold"
        default 80.0
      end
      
      filter expr(quality_score >= ^arg(:minimum_score))
    end
    
    read :recent do
      description "Read recently created projects"
      
      argument :days, :integer do
        description "Number of days back to look"
        default 7
      end
      
      filter expr(inserted_at >= ago(^arg(:days), :day))
      prepare build(sort: [inserted_at: :desc])
    end
  end
  
  validations do
    validate {AgiFactory.Validations.RequirementsFormat, []}
    validate {AgiFactory.Validations.UniqueProjectName, []}
    validate {AgiFactory.Validations.GeneratedCodeQuality, minimum_score: 70}
  end
  
  calculations do
    calculate :health_score, :decimal do
      description "Overall health score combining quality and status"
      calculation AgiFactory.Calculations.HealthScore
    end
    
    calculate :evolution_potential, :decimal do
      description "Potential for successful evolution"
      calculation AgiFactory.Calculations.EvolutionPotential
    end
    
    calculate :generation_time, :integer do
      description "Time taken for generation in seconds"
      calculation AgiFactory.Calculations.GenerationTime
    end
    
    calculate :days_since_deployment, :integer do
      description "Days since deployment"
      calculation AgiFactory.Calculations.DaysSinceDeployment
    end
  end

  aggregates do
    count :generation_count, :generation_requests do
      description "Total number of generation attempts"
    end
    
    count :quality_assessment_count, :quality_assessments do
      description "Number of quality assessments performed"
    end
    
    avg :average_quality_score, :quality_assessments, :overall_score do
      description "Average quality score across all assessments"
    end
    
    max :best_quality_score, :quality_assessments, :overall_score do
      description "Best quality score achieved"
    end
  end

  identities do
    identity :unique_name, [:name] do
      description "Project names must be unique"
    end
  end

  def description do
    """
    DSL Project represents the complete lifecycle of DSL generation,
    from initial requirements through generation, testing, deployment,
    and continuous evolution.
    """
  end
end