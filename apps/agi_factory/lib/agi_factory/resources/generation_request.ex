defmodule AgiFactory.Resources.GenerationRequest do
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer, AshJsonApi.Resource],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "generation_requests"
    repo AgiFactory.Repo
  end

  json_api do
    type "generation_request"
    routes do
      base "/generation_requests"
      get :read
      index :read
      post :create
      patch :update
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :strategy_type, :atom, constraints: [one_of: [:template, :pattern_based, :example_driven, :hybrid, :ai_assisted]]
    attribute :parameters, :map, default: %{}
    attribute :status, :atom, constraints: [one_of: [:pending, :processing, :completed, :failed]], default: :pending
    attribute :priority, :integer, default: 1
    attribute :result, :map
    attribute :error_message, :string
    attribute :started_at, :utc_datetime
    attribute :completed_at, :utc_datetime
    timestamps()
  end

  relationships do
    belongs_to :dsl_project, AgiFactory.Resources.DslProject
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :queue_generation do
      accept [:strategy_type, :parameters, :priority]
      argument :dsl_project_id, :uuid, allow_nil?: false
      
      change manage_relationship(:dsl_project_id, :dsl_project, type: :replace)
      change set_attribute(:status, :pending)
      
      after_action AgiFactory.AfterActions.QueueGeneration
    end
    
    update :start_processing do
      change set_attribute(:status, :processing)
      change set_attribute(:started_at, &DateTime.utc_now/0)
    end
    
    update :complete_processing do
      accept [:result]
      
      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
      
      after_action AgiFactory.AfterActions.NotifyCompletion
    end
    
    update :mark_failed do
      accept [:error_message]
      
      change set_attribute(:status, :failed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
  end

  calculations do
    calculate :duration, :integer do
      calculation fn query, _context ->
        from q in query,
          select: fragment("EXTRACT(EPOCH FROM (? - ?))", q.completed_at, q.started_at)
      end
    end
    
    calculate :is_overdue, :boolean do
      calculation fn query, _context ->
        from q in query,
          select: fragment("NOW() - ? > INTERVAL '10 minutes'", q.started_at)
      end
    end
  end
end