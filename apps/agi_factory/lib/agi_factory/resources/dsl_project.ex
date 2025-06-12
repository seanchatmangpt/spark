defmodule AgiFactory.Resources.DslProject do
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer, AshJsonApi.Resource],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "dsl_projects"
    repo AgiFactory.Repo
  end

  json_api do
    type "dsl_project"
    routes do
      base "/dsl_projects"
      get :read
      index :read
      post :create
      patch :update
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false
    attribute :requirements, :string, allow_nil?: false
    attribute :specification, :map
    attribute :generated_code, :string
    attribute :quality_score, :decimal
    attribute :status, :atom, constraints: [one_of: [:draft, :generating, :testing, :deployed, :failed]]
    attribute :metadata, :map, default: %{}
    timestamps()
  end

  relationships do
    has_many :generation_requests, AgiFactory.Resources.GenerationRequest
    has_many :quality_assessments, AgiFactory.Resources.QualityAssessment
    has_many :evolution_cycles, AgiFactory.Resources.EvolutionCycle
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :generate_from_requirements do
      accept [:name, :requirements]
      
      change AgiFactory.Changes.ParseRequirements
      change AgiFactory.Changes.CreateSpecification
      change set_attribute(:status, :generating)
      
      after_action AgiFactory.AfterActions.TriggerGeneration
    end
    
    update :complete_generation do
      accept [:generated_code, :quality_score]
      
      change set_attribute(:status, :testing)
      change AgiFactory.Changes.ValidateGeneration
      
      after_action AgiFactory.AfterActions.DeployIfReady
    end
    
    update :start_evolution do
      change set_attribute(:status, :evolving)
      after_action AgiFactory.AfterActions.StartEvolutionCycle
    end
  end
  
  validations do
    validate {AgiFactory.Validations.RequirementsFormat, []}
    validate {AgiFactory.Validations.GeneratedCodeQuality, minimum_score: 80}
  end
  
  calculations do
    calculate :health_score, :decimal do
      calculation AgiFactory.Calculations.HealthScore
    end
    
    calculate :evolution_potential, :decimal do
      calculation AgiFactory.Calculations.EvolutionPotential
    end
  end
end