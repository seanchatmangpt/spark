# Spark Generators Cookbook 👨‍🍳

**Practical recipes for building DSLs with Spark generators**

This cookbook provides step-by-step recipes for common DSL patterns using Spark generators. Each recipe includes the exact commands, generated code examples, and real-world usage patterns.

## 📖 How to Use This Cookbook

- **🥡 Pick a recipe** that matches your use case
- **📋 Copy the commands** and run them in your project  
- **🔧 Customize** the generated code for your specific needs
- **🧪 Test** with the provided examples

## 🍳 Recipe Index

### Basic Recipes
- [🏗️ Configuration DSL](#️-recipe-configuration-dsl)
- [📊 Resource Management DSL](#-recipe-resource-management-dsl)
- [🔑 Authentication DSL](#-recipe-authentication-dsl)
- [📋 Form Validation DSL](#-recipe-form-validation-dsl)

### Intermediate Recipes  
- [🚀 API Definition DSL](#-recipe-api-definition-dsl)
- [⚡ Workflow Engine DSL](#-recipe-workflow-engine-dsl)
- [🎯 Feature Flag DSL](#-recipe-feature-flag-dsl)
- [📈 Analytics Tracking DSL](#-recipe-analytics-tracking-dsl)

### Advanced Recipes
- [🌐 Multi-Tenant DSL](#-recipe-multi-tenant-dsl)  
- [🔄 State Machine DSL](#-recipe-state-machine-dsl)
- [📊 Query Builder DSL](#-recipe-query-builder-dsl)
- [🎨 UI Component DSL](#-recipe-ui-component-dsl)

---

## 🏗️ Recipe: Configuration DSL

**Create a DSL for application configuration with environments, services, and feature flags.**

### Ingredients
- Configuration sections for different environments
- Service definitions with connection details
- Feature flags with rollout percentages
- Validation for required settings

### Commands
```bash
# Step 1: Create the main configuration DSL
mix spark.gen.dsl MyApp.ConfigDsl \
  --section environments \
  --section services \
  --section features \
  --entity environment:name:atom \
  --entity service:name:module \
  --entity feature:name:atom \
  --opt global_timeout:pos_integer:30000 \
  --examples

# Step 2: Add configuration validation
mix spark.gen.verifier MyApp.Verifiers.ValidateConfig \
  --dsl MyApp.ConfigDsl \
  --sections environments,services \
  --checks required_envs,valid_services \
  --examples

# Step 3: Add defaults and transformations  
mix spark.gen.transformer MyApp.Transformers.AddConfigDefaults \
  --dsl MyApp.ConfigDsl \
  --persist config_defaults \
  --examples

# Step 4: Add runtime introspection
mix spark.gen.info MyApp.ConfigDsl.Info \
  --extension MyApp.ConfigDsl \
  --sections environments,services,features \
  --functions get_env_config,find_service \
  --examples
```

### Generated Usage
```elixir
defmodule MyApp.Config do
  use MyApp.ConfigDsl

  environment :production do
    database_url "postgresql://prod-db:5432/myapp"
    redis_url "redis://prod-cache:6379"
    log_level :info
  end

  environment :development do  
    database_url "postgresql://localhost:5432/myapp_dev"
    redis_url "redis://localhost:6379"
    log_level :debug
  end

  service :payment_gateway do
    url "https://api.stripe.com"
    api_key System.get_env("STRIPE_API_KEY")
    timeout 10_000
  end

  feature :new_checkout do
    enabled true
    rollout 0.25
    description "New checkout flow"
  end
end

# Runtime usage
prod_config = MyApp.ConfigDsl.Info.get_env_config(MyApp.Config, :production)
payment_service = MyApp.ConfigDsl.Info.find_service(MyApp.Config, :payment_gateway)
```

### Customization Tips
- Add environment-specific validation in the verifier
- Use transformers to merge environment variables
- Create helper functions for common configuration patterns

---

## 📊 Recipe: Resource Management DSL

**Build a DSL for defining resources with fields, relationships, and operations.**

### Ingredients
- Resource definitions with fields
- Relationship mappings
- CRUD operations with permissions
- Automatic schema generation

### Commands
```bash
# Step 1: Create the resource DSL
mix spark.gen.dsl MyApp.ResourceDsl \
  --section resources \
  --section relationships \
  --entity resource:name:module \
  --entity relationship:name:atom \
  --entity field:name:atom \
  --examples

# Step 2: Add field entity with detailed schema
mix spark.gen.entity MyApp.Entities.Field \
  --identifier name:atom \
  --args name,type \
  --examples

# Step 3: Add relationship validation
mix spark.gen.verifier MyApp.Verifiers.ValidateRelationships \
  --dsl MyApp.ResourceDsl \
  --sections resources,relationships \
  --checks valid_foreign_keys,no_circular_refs \
  --examples

# Step 4: Add schema generation transformer
mix spark.gen.transformer MyApp.Transformers.GenerateSchema \
  --dsl MyApp.ResourceDsl \
  --persist resource_schemas \
  --examples

# Step 5: Add resource introspection
mix spark.gen.info MyApp.ResourceDsl.Info \
  --extension MyApp.ResourceDsl \
  --sections resources,relationships \
  --functions get_fields,find_relationship \
  --examples
```

### Generated Usage
```elixir
defmodule MyApp.UserResource do
  use MyApp.ResourceDsl

  resource :users do
    field :id, :uuid, primary_key: true
    field :email, :string, unique: true, required: true
    field :name, :string, required: true
    field :age, :integer, min: 0, max: 150
    field :created_at, :utc_datetime, auto: true
    field :updated_at, :utc_datetime, auto: true
  end

  relationship :has_many_posts do
    target MyApp.PostResource
    foreign_key :user_id
    on_delete :delete_all
  end

  relationship :belongs_to_organization do
    target MyApp.OrganizationResource
    foreign_key :organization_id
    required true
  end
end

# Runtime usage
fields = MyApp.ResourceDsl.Info.get_fields(MyApp.UserResource)
posts_rel = MyApp.ResourceDsl.Info.find_relationship(MyApp.UserResource, :has_many_posts)
```

### Customization Tips
- Add field type validation in the verifier
- Use transformers to generate database migrations
- Create permissions system with role-based access

---

## 🔑 Recipe: Authentication DSL

**Create a DSL for authentication strategies, policies, and user management.**

### Ingredients
- Authentication strategies (JWT, OAuth, API key)
- Permission policies with roles
- User session management
- Security validations

### Commands
```bash
# Step 1: Create authentication DSL
mix spark.gen.dsl MyApp.AuthDsl \
  --section strategies \
  --section policies \
  --section sessions \
  --entity strategy:name:module \
  --entity policy:name:atom \
  --entity session:name:atom \
  --opt default_timeout:pos_integer:3600 \
  --examples

# Step 2: Add security validation
mix spark.gen.verifier MyApp.Verifiers.ValidateSecurity \
  --dsl MyApp.AuthDsl \
  --sections strategies,policies \
  --checks secure_strategies,valid_policies \
  --examples

# Step 3: Add authentication transformer
mix spark.gen.transformer MyApp.Transformers.BuildAuthFlow \
  --dsl MyApp.AuthDsl \
  --persist auth_pipeline \
  --examples

# Step 4: Add auth introspection
mix spark.gen.info MyApp.AuthDsl.Info \
  --extension MyApp.AuthDsl \
  --sections strategies,policies,sessions \
  --functions get_strategy,check_permission \
  --examples
```

### Generated Usage
```elixir
defmodule MyApp.Auth do
  use MyApp.AuthDsl

  strategy :jwt do
    secret System.get_env("JWT_SECRET")
    expiry :timer.hours(24)
    algorithm "HS256"
    issuer "myapp"
  end

  strategy :oauth_google do
    client_id System.get_env("GOOGLE_CLIENT_ID")
    client_secret System.get_env("GOOGLE_CLIENT_SECRET")
    redirect_uri "https://myapp.com/auth/google/callback"
    scopes ["email", "profile"]
  end

  policy :admin_only do
    requires_role :admin
    resources [:users, :settings, :analytics]
  end

  policy :user_own_data do
    requires_role :user
    condition &user_owns_resource?/2
    resources [:profile, :posts]
  end

  session :web do
    store :ets
    timeout :timer.hours(8)
    secure true
    http_only true
  end
end

# Runtime usage
strategy = MyApp.AuthDsl.Info.get_strategy(MyApp.Auth, :jwt)
can_access? = MyApp.AuthDsl.Info.check_permission(MyApp.Auth, user, :admin_only, :users)
```

---

## 📋 Recipe: Form Validation DSL

**Build a DSL for form validation with rules, sanitization, and error handling.**

### Ingredients
- Form field definitions with types
- Validation rules and custom validators
- Sanitization and transformation
- Error message customization

### Commands
```bash
# Step 1: Create form validation DSL
mix spark.gen.dsl MyApp.FormDsl \
  --section forms \
  --section validators \
  --entity form:name:module \
  --entity field:name:atom \
  --entity validator:name:module \
  --examples

# Step 2: Add validation logic
mix spark.gen.verifier MyApp.Verifiers.ValidateFormRules \
  --dsl MyApp.FormDsl \
  --sections forms,validators \
  --checks valid_field_types,required_validators \
  --examples

# Step 3: Add form processing transformer
mix spark.gen.transformer MyApp.Transformers.BuildFormProcessor \
  --dsl MyApp.FormDsl \
  --persist form_processors \
  --examples

# Step 4: Add form introspection
mix spark.gen.info MyApp.FormDsl.Info \
  --extension MyApp.FormDsl \
  --sections forms,validators \
  --functions get_form_fields,get_validators \
  --examples
```

### Generated Usage
```elixir
defmodule MyApp.UserForm do
  use MyApp.FormDsl

  form :registration do
    field :email do
      type :string
      required true
      sanitize &String.trim/1
      validate :email_format
      validate :unique_email
    end

    field :password do
      type :string
      required true
      min_length 8
      validate :strong_password
      confirm_field :password_confirmation
    end

    field :name do
      type :string
      required true
      sanitize &sanitize_name/1
      max_length 100
    end

    field :age do
      type :integer
      min 13
      max 120
      transform &String.to_integer/1
    end
  end

  validator :email_format do
    rule ~r/^[^\s]+@[^\s]+\.[^\s]+$/
    message "Must be a valid email address"
  end

  validator :unique_email do
    function &MyApp.Users.email_unique?/1
    message "Email already exists"
  end
end

# Runtime usage
form_fields = MyApp.FormDsl.Info.get_form_fields(MyApp.UserForm, :registration)
validators = MyApp.FormDsl.Info.get_validators(MyApp.UserForm)
```

---

## 🚀 Recipe: API Definition DSL

**Create a comprehensive DSL for defining REST APIs with routes, middleware, and documentation.**

### Ingredients
- API version management
- Route definitions with parameters
- Middleware pipeline configuration
- Automatic OpenAPI documentation

### Commands
```bash
# Step 1: Create API DSL
mix spark.gen.dsl MyApp.ApiDsl \
  --section apis \
  --section routes \
  --section middleware \
  --entity api:version:atom \
  --entity route:path:string \
  --entity middleware:name:module \
  --opt base_url:string \
  --examples

# Step 2: Add route validation
mix spark.gen.verifier MyApp.Verifiers.ValidateRoutes \
  --dsl MyApp.ApiDsl \
  --sections routes,middleware \
  --checks valid_paths,no_duplicate_routes \
  --examples

# Step 3: Add API documentation generator
mix spark.gen.transformer MyApp.Transformers.GenerateOpenAPI \
  --dsl MyApp.ApiDsl \
  --persist openapi_spec \
  --examples

# Step 4: Add API introspection
mix spark.gen.info MyApp.ApiDsl.Info \
  --extension MyApp.ApiDsl \
  --sections apis,routes,middleware \
  --functions get_routes,find_route \
  --examples
```

### Generated Usage
```elixir
defmodule MyApp.API do
  use MyApp.ApiDsl

  api :v1 do
    base_url "/api/v1"
    documentation "MyApp API v1"
    deprecated false
  end

  middleware :cors do
    origins ["https://myapp.com", "https://app.myapp.com"]
    methods [:get, :post, :put, :delete]
    headers ["Content-Type", "Authorization"]
  end

  middleware :rate_limit do
    requests_per_minute 100
    key_generator &extract_api_key/1
  end

  route "/users" do
    method :get
    controller MyApp.Controllers.UsersController
    action :index
    middleware [:cors, :rate_limit]
    
    parameters do
      query :page, :integer, default: 1
      query :limit, :integer, default: 20, max: 100
    end
    
    responses do
      ok :users_list
      unauthorized :error
    end
  end

  route "/users/:id" do
    method :get
    controller MyApp.Controllers.UsersController
    action :show
    middleware [:cors]
    
    parameters do
      path :id, :uuid, required: true
    end
  end
end

# Runtime usage
routes = MyApp.ApiDsl.Info.get_routes(MyApp.API, :v1)
user_route = MyApp.ApiDsl.Info.find_route(MyApp.API, "/users/:id")
```

---

## ⚡ Recipe: Workflow Engine DSL

**Build a DSL for defining workflows with states, transitions, and actions.**

### Ingredients
- Workflow state definitions
- State transitions with conditions
- Actions and side effects
- Event handling and notifications

### Commands
```bash
# Step 1: Create workflow DSL
mix spark.gen.dsl MyApp.WorkflowDsl \
  --section workflows \
  --section states \
  --section transitions \
  --entity workflow:name:atom \
  --entity state:name:atom \
  --entity transition:name:atom \
  --examples

# Step 2: Add workflow validation
mix spark.gen.verifier MyApp.Verifiers.ValidateWorkflow \
  --dsl MyApp.WorkflowDsl \
  --sections workflows,states,transitions \
  --checks valid_initial_state,reachable_states \
  --examples

# Step 3: Add workflow execution transformer
mix spark.gen.transformer MyApp.Transformers.BuildWorkflowEngine \
  --dsl MyApp.WorkflowDsl \
  --persist workflow_graphs \
  --examples

# Step 4: Add workflow introspection
mix spark.gen.info MyApp.WorkflowDsl.Info \
  --extension MyApp.WorkflowDsl \
  --sections workflows,states,transitions \
  --functions get_workflow,next_states \
  --examples
```

### Generated Usage
```elixir
defmodule MyApp.OrderWorkflow do
  use MyApp.WorkflowDsl

  workflow :order_processing do
    initial_state :pending
    description "Order processing workflow"
  end

  state :pending do
    description "Order received, awaiting payment"
    timeout :timer.minutes(30)
    on_enter &send_confirmation/1
    on_timeout &cancel_order/1
  end

  state :paid do
    description "Payment received, preparing shipment"
    on_enter &charge_payment/1
    on_enter &reserve_inventory/1
  end

  state :shipped do
    description "Order shipped to customer"
    final true
    on_enter &send_tracking_info/1
  end

  state :cancelled do
    description "Order cancelled"
    final true
    on_enter &refund_payment/1
  end

  transition :process_payment do
    from :pending
    to :paid
    condition &payment_valid?/1
    action &process_payment/1
    on_failure &handle_payment_failure/1
  end

  transition :ship_order do
    from :paid
    to :shipped
    condition &inventory_available?/1
    action &create_shipment/1
  end

  transition :cancel_order do
    from [:pending, :paid]
    to :cancelled
    action &cancel_processing/1
  end
end

# Runtime usage
workflow = MyApp.WorkflowDsl.Info.get_workflow(MyApp.OrderWorkflow, :order_processing)
next_states = MyApp.WorkflowDsl.Info.next_states(MyApp.OrderWorkflow, :pending)
```

---

## 🎯 Recipe: Feature Flag DSL

**Create a DSL for managing feature flags with targeting, rollouts, and analytics.**

### Ingredients
- Feature flag definitions with metadata
- User targeting and segmentation
- Percentage rollouts and A/B testing  
- Analytics and performance tracking

### Commands
```bash
# Step 1: Create feature flag DSL
mix spark.gen.dsl MyApp.FeatureDsl \
  --section features \
  --section segments \
  --section experiments \
  --entity feature:name:atom \
  --entity segment:name:atom \
  --entity experiment:name:atom \
  --opt global_enabled:boolean:true \
  --examples

# Step 2: Add feature validation
mix spark.gen.verifier MyApp.Verifiers.ValidateFeatures \
  --dsl MyApp.FeatureDsl \
  --sections features,segments \
  --checks valid_rollouts,no_conflicts \
  --examples

# Step 3: Add feature evaluation transformer
mix spark.gen.transformer MyApp.Transformers.BuildFeatureEvaluator \
  --dsl MyApp.FeatureDsl \
  --persist feature_rules \
  --examples

# Step 4: Add feature introspection
mix spark.gen.info MyApp.FeatureDsl.Info \
  --extension MyApp.FeatureDsl \
  --sections features,segments,experiments \
  --functions get_feature,is_enabled \
  --examples
```

### Generated Usage
```elixir
defmodule MyApp.Features do
  use MyApp.FeatureDsl

  segment :beta_users do
    condition &user_has_role?(&1, :beta)
    description "Beta testing users"
  end

  segment :premium_users do
    condition &user_has_subscription?(&1, :premium)
    description "Premium subscribers"
  end

  feature :new_dashboard do
    description "Redesigned user dashboard"
    enabled true
    rollout 0.25
    segments [:beta_users]
    
    analytics do
      track_events [:page_view, :interaction]
      conversion_goal :dashboard_engagement
    end
  end

  feature :advanced_search do
    description "Enhanced search functionality"
    enabled true
    segments [:premium_users]
    
    dependencies [:elasticsearch_index]
    kill_switch true
  end

  experiment :checkout_flow_ab do
    description "A/B test for checkout flow"
    variants do
      variant :control, weight: 50
      variant :optimized, weight: 50
    end
    
    success_metric :conversion_rate
    minimum_sample_size 1000
  end
end

# Runtime usage
feature = MyApp.FeatureDsl.Info.get_feature(MyApp.Features, :new_dashboard)
enabled? = MyApp.FeatureDsl.Info.is_enabled(MyApp.Features, :new_dashboard, user)
```

---

## 📈 Recipe: Analytics Tracking DSL

**Build a DSL for defining analytics events, funnels, and reporting.**

### Ingredients
- Event definitions with properties
- Funnel and conversion tracking
- Custom metrics and KPIs
- Real-time dashboard configuration

### Commands
```bash
# Step 1: Create analytics DSL
mix spark.gen.dsl MyApp.AnalyticsDsl \
  --section events \
  --section funnels \
  --section metrics \
  --entity event:name:atom \
  --entity funnel:name:atom \
  --entity metric:name:atom \
  --examples

# Step 2: Add analytics validation
mix spark.gen.verifier MyApp.Verifiers.ValidateAnalytics \
  --dsl MyApp.AnalyticsDsl \
  --sections events,funnels \
  --checks valid_event_properties,valid_funnels \
  --examples

# Step 3: Add tracking transformer
mix spark.gen.transformer MyApp.Transformers.BuildTracker \
  --dsl MyApp.AnalyticsDsl \
  --persist tracking_config \
  --examples

# Step 4: Add analytics introspection
mix spark.gen.info MyApp.AnalyticsDsl.Info \
  --extension MyApp.AnalyticsDsl \
  --sections events,funnels,metrics \
  --functions get_event,track_event \
  --examples
```

### Generated Usage
```elixir
defmodule MyApp.Analytics do
  use MyApp.AnalyticsDsl

  event :user_signup do
    properties do
      property :source, :string, required: true
      property :campaign, :string
      property :device_type, :string
      property :timestamp, :utc_datetime, auto: true
    end
    
    destinations [:mixpanel, :google_analytics]
    sampling_rate 1.0
  end

  event :purchase_completed do
    properties do
      property :amount, :decimal, required: true
      property :currency, :string, default: "USD"
      property :product_ids, {:list, :string}
      property :discount_code, :string
    end
    
    destinations [:revenue_tracking, :customer_db]
    high_priority true
  end

  funnel :signup_to_purchase do
    description "User journey from signup to first purchase"
    
    steps do
      step :signup, event: :user_signup
      step :profile_complete, event: :profile_completed
      step :first_purchase, event: :purchase_completed
    end
    
    time_window :timer.days(7)
    conversion_windows [
      {1, :timer.hours(24)},
      {2, :timer.days(3)},
      {3, :timer.days(7)}
    ]
  end

  metric :monthly_revenue do
    query """
    SELECT SUM(amount) 
    FROM events 
    WHERE event_name = 'purchase_completed' 
    AND timestamp >= date_trunc('month', NOW())
    """
    
    refresh_interval :timer.hours(1)
    alert_threshold 10000
  end
end

# Runtime usage
event = MyApp.AnalyticsDsl.Info.get_event(MyApp.Analytics, :user_signup)
MyApp.AnalyticsDsl.Info.track_event(MyApp.Analytics, :user_signup, %{source: "google"})
```

---

## 🌐 Recipe: Multi-Tenant DSL

**Create a DSL for multi-tenant applications with tenant isolation and configuration.**

### Ingredients
- Tenant definitions with schemas
- Data isolation strategies
- Tenant-specific configurations
- Migration and deployment management

### Commands
```bash
# Step 1: Create multi-tenant DSL
mix spark.gen.dsl MyApp.TenantDsl \
  --section tenants \
  --section schemas \
  --section isolation \
  --entity tenant:name:atom \
  --entity schema:name:atom \
  --entity isolation_rule:name:atom \
  --opt default_schema:string:public \
  --examples

# Step 2: Add tenant validation
mix spark.gen.verifier MyApp.Verifiers.ValidateTenants \
  --dsl MyApp.TenantDsl \
  --sections tenants,schemas \
  --checks unique_schemas,valid_isolation \
  --examples

# Step 3: Add tenant resolver transformer
mix spark.gen.transformer MyApp.Transformers.BuildTenantResolver \
  --dsl MyApp.TenantDsl \
  --persist tenant_config \
  --examples

# Step 4: Add tenant introspection
mix spark.gen.info MyApp.TenantDsl.Info \
  --extension MyApp.TenantDsl \
  --sections tenants,schemas \
  --functions get_tenant,resolve_schema \
  --examples
```

### Generated Usage
```elixir
defmodule MyApp.Tenancy do
  use MyApp.TenantDsl

  tenant :acme_corp do
    schema "acme_corp"
    subdomain "acme"
    plan :enterprise
    
    features [:advanced_analytics, :custom_branding]
    limits [users: 1000, storage: "100GB"]
    
    database do
      isolation :schema
      migration_strategy :automatic
    end
  end

  tenant :startup_inc do
    schema "startup_inc"  
    subdomain "startup"
    plan :pro
    
    features [:basic_analytics]
    limits [users: 50, storage: "10GB"]
    
    database do
      isolation :schema
      migration_strategy :manual
    end
  end

  schema :shared do
    tables [:users, :organizations, :plans]
    isolation :row_level_security
  end

  isolation_rule :user_data do
    strategy :schema_based
    enforce_on [:users, :projects, :files]
    fallback :deny
  end
end

# Runtime usage
tenant = MyApp.TenantDsl.Info.get_tenant(MyApp.Tenancy, :acme_corp)
schema = MyApp.TenantDsl.Info.resolve_schema(MyApp.Tenancy, subdomain: "acme")
```

---

## 🔄 Recipe: State Machine DSL

**Build a comprehensive DSL for state machines with guards, actions, and event handling.**

### Ingredients
- State definitions with entry/exit actions
- Event-driven transitions with guards
- Hierarchical and parallel states
- State machine composition

### Commands
```bash
# Step 1: Create state machine DSL
mix spark.gen.dsl MyApp.StateMachineDsl \
  --section machines \
  --section states \
  --section events \
  --entity machine:name:atom \
  --entity state:name:atom \
  --entity event:name:atom \
  --examples

# Step 2: Add state machine validation
mix spark.gen.verifier MyApp.Verifiers.ValidateStateMachine \
  --dsl MyApp.StateMachineDsl \
  --sections machines,states,events \
  --checks valid_transitions,reachable_states \
  --examples

# Step 3: Add state machine compiler
mix spark.gen.transformer MyApp.Transformers.CompileStateMachine \
  --dsl MyApp.StateMachineDsl \
  --persist state_machines \
  --examples

# Step 4: Add state machine introspection
mix spark.gen.info MyApp.StateMachineDsl.Info \
  --extension MyApp.StateMachineDsl \
  --sections machines,states,events \
  --functions get_machine,current_state \
  --examples
```

### Generated Usage
```elixir
defmodule MyApp.UserStateMachine do
  use MyApp.StateMachineDsl

  machine :user_lifecycle do
    initial_state :inactive
    context MyApp.User
  end

  state :inactive do
    on_enter &log_user_inactive/1
    
    transitions do
      on_event :activate, to: :active, guard: &email_verified?/1
      on_event :delete, to: :deleted
    end
  end

  state :active do
    on_enter &welcome_user/1
    on_exit &log_user_leaving/1
    
    substates do
      initial_state :free
      
      state :free do
        transitions do
          on_event :upgrade, to: :premium, action: &process_upgrade/1
          on_event :trial, to: :trial, guard: &eligible_for_trial?/1
        end
      end
      
      state :premium do
        on_enter &setup_premium_features/1
        
        transitions do
          on_event :downgrade, to: :free, action: &process_downgrade/1
          on_event :cancel, to: :cancelled
        end
      end
      
      state :trial do
        timeout {:days, 14}
        on_timeout :expire_trial
        
        transitions do
          on_event :convert, to: :premium
          on_event :expire_trial, to: :free
        end
      end
    end
    
    transitions do
      on_event :suspend, to: :suspended, guard: &policy_violation?/1
      on_event :deactivate, to: :inactive
    end
  end

  state :suspended do
    on_enter &notify_suspension/1
    
    transitions do
      on_event :reinstate, to: :active, guard: &violation_resolved?/1
      on_event :delete, to: :deleted
    end
  end

  state :deleted do
    final true
    on_enter &anonymize_user_data/1
  end

  event :activate do
    data [:email_verification_token]
    description "Activate user account"
  end

  event :upgrade do
    data [:plan_id, :payment_method]
    description "Upgrade to premium plan"
  end
end

# Runtime usage
machine = MyApp.StateMachineDsl.Info.get_machine(MyApp.UserStateMachine, :user_lifecycle)
current = MyApp.StateMachineDsl.Info.current_state(user_instance)
```

---

## 📊 Recipe: Query Builder DSL

**Create a DSL for building complex database queries with type safety and optimization.**

### Ingredients
- Table and field definitions
- Query operations (select, where, join, etc.)
- Aggregate functions and grouping
- Query optimization and caching

### Commands
```bash
# Step 1: Create query builder DSL
mix spark.gen.dsl MyApp.QueryDsl \
  --section tables \
  --section queries \
  --section functions \
  --entity table:name:atom \
  --entity query:name:atom \
  --entity function:name:atom \
  --examples

# Step 2: Add query validation
mix spark.gen.verifier MyApp.Verifiers.ValidateQueries \
  --dsl MyApp.QueryDsl \
  --sections tables,queries \
  --checks valid_table_refs,type_safety \
  --examples

# Step 3: Add query compiler
mix spark.gen.transformer MyApp.Transformers.CompileQueries \
  --dsl MyApp.QueryDsl \
  --persist compiled_queries \
  --examples

# Step 4: Add query introspection
mix spark.gen.info MyApp.QueryDsl.Info \
  --extension MyApp.QueryDsl \
  --sections tables,queries \
  --functions get_query,execute_query \
  --examples
```

### Generated Usage
```elixir
defmodule MyApp.Queries do
  use MyApp.QueryDsl

  table :users do
    field :id, :uuid, primary_key: true
    field :email, :string, unique: true
    field :name, :string
    field :created_at, :utc_datetime
    field :organization_id, :uuid
    
    indexes do
      index [:email], unique: true
      index [:organization_id]
      index [:created_at]
    end
  end

  table :posts do
    field :id, :uuid, primary_key: true
    field :title, :string
    field :content, :text
    field :user_id, :uuid, references: :users
    field :published_at, :utc_datetime
    field :view_count, :integer, default: 0
  end

  query :active_users do
    description "Users who have posted in the last 30 days"
    
    from :users
    join :posts, on: [user_id: :id]
    where posts: [published_at: {:>=, days_ago(30)}]
    select users: [:id, :email, :name]
    group_by users: [:id]
    having posts: [count: {:>=, 1}]
    order_by users: [created_at: :desc]
    
    cache_ttl :timer.minutes(5)
  end

  query :user_post_stats do
    description "User posting statistics"
    
    from :users
    left_join :posts, on: [user_id: :id]
    select [
      users: [:id, :email, :name],
      posts: [
        total_posts: count(:id),
        total_views: sum(:view_count),
        avg_views: avg(:view_count),
        last_post: max(:published_at)
      ]
    ]
    group_by users: [:id]
    order_by posts: [total_posts: :desc]
  end

  function :days_ago do
    args [:days]
    returns :utc_datetime
    sql "NOW() - INTERVAL ? DAY"
  end

  function :count do
    args [:field]
    returns :integer
    sql "COUNT(?)"
    aggregate true
  end
end

# Runtime usage
query = MyApp.QueryDsl.Info.get_query(MyApp.Queries, :active_users)
results = MyApp.QueryDsl.Info.execute_query(MyApp.Queries, :active_users, %{})
```

---

## 🎨 Recipe: UI Component DSL

**Build a DSL for defining reusable UI components with props, events, and styling.**

### Ingredients
- Component definitions with props
- Event handling and lifecycle hooks
- Styling and theming system
- Component composition and slots

### Commands
```bash
# Step 1: Create UI component DSL
mix spark.gen.dsl MyApp.ComponentDsl \
  --section components \
  --section themes \
  --section layouts \
  --entity component:name:atom \
  --entity theme:name:atom \
  --entity layout:name:atom \
  --examples

# Step 2: Add component validation
mix spark.gen.verifier MyApp.Verifiers.ValidateComponents \
  --dsl MyApp.ComponentDsl \
  --sections components,themes \
  --checks valid_props,theme_consistency \
  --examples

# Step 3: Add component compiler
mix spark.gen.transformer MyApp.Transformers.CompileComponents \
  --dsl MyApp.ComponentDsl \
  --persist component_registry \
  --examples

# Step 4: Add component introspection
mix spark.gen.info MyApp.ComponentDsl.Info \
  --extension MyApp.ComponentDsl \
  --sections components,themes \
  --functions get_component,render_component \
  --examples
```

### Generated Usage
```elixir
defmodule MyApp.Components do
  use MyApp.ComponentDsl

  theme :default do
    colors do
      primary "#3B82F6"
      secondary "#6B7280"
      success "#10B981"
      danger "#EF4444"
      warning "#F59E0B"
    end
    
    spacing do
      xs "0.25rem"
      sm "0.5rem"
      md "1rem"
      lg "1.5rem"
      xl "2rem"
    end
    
    typography do
      font_family "Inter, sans-serif"
      font_sizes [xs: "0.75rem", sm: "0.875rem", base: "1rem", lg: "1.125rem"]
    end
  end

  component :button do
    props do
      prop :variant, {:one_of, [:primary, :secondary, :danger]}, default: :primary
      prop :size, {:one_of, [:sm, :md, :lg]}, default: :md
      prop :disabled, :boolean, default: false
      prop :loading, :boolean, default: false
      prop :icon, :string
      prop :children, :string, required: true
    end
    
    events do
      event :click, data: [:mouse_event]
      event :focus
      event :blur
    end
    
    styles do
      base "inline-flex items-center justify-center rounded-md font-medium transition-colors"
      
      variants do
        variant :primary, "bg-primary text-white hover:bg-primary/90"
        variant :secondary, "bg-secondary text-white hover:bg-secondary/90"
        variant :danger, "bg-danger text-white hover:bg-danger/90"
      end
      
      sizes do
        size :sm, "px-3 py-2 text-sm"
        size :md, "px-4 py-2 text-base"
        size :lg, "px-6 py-3 text-lg"
      end
      
      states do
        disabled "opacity-50 cursor-not-allowed"
        loading "opacity-75 cursor-wait"
      end
    end
    
    template """
    <button 
      class={@computed_classes}
      disabled={@disabled or @loading}
      phx-click={@click}
    >
      <%= if @loading do %>
        <div class="animate-spin mr-2">⟳</div>
      <% end %>
      
      <%= if @icon do %>
        <icon name={@icon} class="mr-2" />
      <% end %>
      
      <%= @children %>
    </button>
    """
  end

  component :card do
    props do
      prop :title, :string
      prop :subtitle, :string
      prop :padding, {:one_of, [:sm, :md, :lg]}, default: :md
      prop :shadow, {:one_of, [:none, :sm, :md, :lg]}, default: :md
    end
    
    slots do
      slot :header
      slot :body, required: true
      slot :footer
    end
    
    styles do
      base "bg-white rounded-lg border border-gray-200"
      
      paddings do
        padding :sm, "p-4"
        padding :md, "p-6"
        padding :lg, "p-8"
      end
      
      shadows do
        shadow :none, "shadow-none"
        shadow :sm, "shadow-sm"
        shadow :md, "shadow-md"
        shadow :lg, "shadow-lg"
      end
    end
  end

  layout :dashboard do
    props do
      prop :sidebar_open, :boolean, default: true
      prop :user, :map, required: true
    end
    
    regions do
      region :sidebar, width: "256px"
      region :header, height: "64px"
      region :main, flex: true
      region :footer, height: "48px"
    end
    
    template """
    <div class="min-h-screen bg-gray-50">
      <aside class={["fixed inset-y-0 left-0 z-50 w-64 bg-white shadow-lg", 
                     unless(@sidebar_open, do: "-translate-x-full")]}>
        <%= render_slot(@sidebar) %>
      </aside>
      
      <div class={["min-h-screen", if(@sidebar_open, do: "lg:pl-64")]}>
        <header class="bg-white shadow-sm h-16 flex items-center px-6">
          <%= render_slot(@header) %>
        </header>
        
        <main class="flex-1 p-6">
          <%= render_slot(@main) %>
        </main>
        
        <footer class="bg-gray-100 h-12 flex items-center px-6">
          <%= render_slot(@footer) %>
        </footer>
      </div>
    </div>
    """
  end
end

# Runtime usage in templates
component = MyApp.ComponentDsl.Info.get_component(MyApp.Components, :button)
MyApp.ComponentDsl.Info.render_component(MyApp.Components, :button, %{variant: :primary, children: "Click me"})
```

---

## 🔧 Tips for Recipe Success

### 1. **Start Simple, Iterate**
- Begin with basic structure
- Add complexity incrementally
- Test each addition thoroughly

### 2. **Use `--examples` Always**
- Generate comprehensive documentation
- Get usage patterns automatically
- Help future developers understand

### 3. **Test Your DSLs**
```bash
# Create a test module for each recipe
mix spark.gen.dsl MyApp.TestDsl --section test --examples
```

### 4. **Customize Generated Code**
- Generated code is a starting point
- Modify to fit your exact needs
- Add business-specific validations

### 5. **Plan Your Architecture**
- Design sections and entities first
- Consider data flow and dependencies
- Think about user experience

### 6. **Performance Considerations**
- Use transformers for heavy processing
- Cache frequently accessed data
- Profile with large datasets

## 🎉 Conclusion

This cookbook provides practical recipes for building sophisticated DSLs with Spark generators. Each recipe follows proven patterns and can be customized for your specific needs.

**Next Steps:**
1. Pick a recipe that matches your use case
2. Run the commands in your project
3. Customize the generated code
4. Test thoroughly with real data
5. Share your improvements with the community!

**Happy Cooking! 👨‍🍳🔥**