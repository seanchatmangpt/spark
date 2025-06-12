# Day 3: Architecture and Extensibility

> *"The best architectures, requirements, and designs emerge from self-organizing teams."* - Agile Manifesto

Welcome to Day 3! Today we evolve from building individual DSLs to creating extensible architectures that entire communities can enhance. You'll master plugin systems, advanced verifier patterns, and build a sophisticated workflow engine that others can extend.

## Daily Objectives

By the end of Day 3, you will:
- ✅ Design extensible DSL architectures with plugin systems
- ✅ Master advanced verifier patterns for complex business rules
- ✅ Build a workflow engine DSL with extension points
- ✅ Understand community-driven DSL development
- ✅ Apply sophisticated composition and inheritance patterns

## Pre-Day Reflection

**Last Night's Assignment Review:**
- What business domain did you research for potential extension?
- How do different teams in your organization approach similar problems differently?
- What makes software systems extensible without becoming complex?
- What extension patterns have you seen work well in other tools?

---

## Morning Session (9:00-12:00)

### Opening Check-in (9:00-9:15)
**Team Sharing (10 minutes):**
- Share one insight from yesterday's API gateway lab
- Describe the business domain you researched for extension
- Explain what extension needs you identified
- Get feedback on your extension strategy

**Group Discussion (5 minutes):**
- Common patterns across different extension needs
- Instructor highlights architectural principles

### Extensible Architecture Principles (9:15-10:15)

#### The Extension Challenge

**Monolithic DSL Problem:**
```elixir
# Everything hardcoded in one place
defmodule WorkflowDsl.Extension do
  @step %Spark.Dsl.Entity{
    name: :step,
    schema: [
      type: [type: {:one_of, [:email, :slack, :webhook, :approval]}],
      # All step types hardcoded!
    ]
  }
end
```

**Plugin-Based Solution:**
```elixir
# Core provides framework, plugins add capabilities
defmodule WorkflowDsl.Core do
  @step %Spark.Dsl.Entity{
    name: :step,
    schema: [
      type: [type: {:custom, __MODULE__, :validate_step_type, []}],
      # Validation delegates to plugin registry
    ]
  }
end

defmodule WorkflowDsl.Plugins.EmailPlugin do
  use WorkflowDsl.Plugin
  
  step_type :email do
    schema [
      to: [type: {:list, :string}, required: true],
      subject: [type: :string, required: true],
      template: [type: :string, required: true]
    ]
  end
end
```

#### Architectural Patterns for Extensibility

**1. Plugin Registry Pattern:**
```elixir
defmodule WorkflowDsl.PluginRegistry do
  use GenServer
  
  def register_plugin(plugin_module) do
    GenServer.call(__MODULE__, {:register, plugin_module})
  end
  
  def get_step_types do
    GenServer.call(__MODULE__, :get_step_types)
  end
  
  def validate_step_type(type) do
    step_types = get_step_types()
    if type in step_types do
      {:ok, type}
    else
      {:error, "Unknown step type: #{type}. Available: #{inspect(step_types)}"}
    end
  end
end
```

**2. Extension Point Pattern:**
```elixir
defmodule WorkflowDsl.ExtensionPoints do
  @callback step_schema(atom()) :: keyword()
  @callback validate_step_config(atom(), map()) :: {:ok, map()} | {:error, String.t()}
  @callback execute_step(atom(), map(), map()) :: {:ok, map()} | {:error, String.t()}
  
  def register_extension(module) do
    if function_exported?(module, :step_schema, 1) do
      PluginRegistry.register_plugin(module)
    else
      {:error, "Module must implement step_schema/1 callback"}
    end
  end
end
```

**3. Composition Over Inheritance:**
```elixir
defmodule WorkflowDsl.Core.StepBehaviors do
  defmacro __using__(opts) do
    behavior = Keyword.fetch!(opts, :behavior)
    
    quote do
      @behavior WorkflowDsl.StepBehavior
      
      case unquote(behavior) do
        :notification -> use WorkflowDsl.Behaviors.Notification
        :approval -> use WorkflowDsl.Behaviors.Approval
        :integration -> use WorkflowDsl.Behaviors.Integration
      end
    end
  end
end
```

#### Case Study: Workflow Engine Evolution

**Phase 1: Monolithic (Original)**
```elixir
# All workflow types hardcoded
workflow do
  step :send_email do
    to ["user@example.com"]
    subject "Welcome!"
  end
  
  step :create_ticket do
    system :jira
    project "PROJ"
  end
end
```

**Phase 2: Plugin-Based (Extensible)**
```elixir
# Core provides structure, plugins add step types
defmodule MyApp.WorkflowConfig do
  use WorkflowDsl
  
  # Load plugins for step types we need
  plugin EmailPlugin
  plugin JiraPlugin
  plugin SlackPlugin
  plugin CustomApprovalPlugin  # Custom business logic
  
  workflow :onboarding do
    trigger :user_signup
    
    step :welcome_email do
      template "welcome"
      to "{{user.email}}"
      delay :timer.minutes(5)
    end
    
    step :manager_approval do
      approver "{{user.manager}}"
      timeout :timer.hours(24)
      escalation :skip  # Custom business rule
    end
    
    step :provision_accounts do
      parallel [
        {:jira_account, project: "USERS"},
        {:slack_invite, channel: "#general"},
        {:github_invite, team: "{{user.department}}"}
      ]
    end
  end
end
```

### Break (10:15-10:30)

### Advanced Verifier Patterns (10:30-11:30)

#### Beyond Basic Validation

**Multi-Entity Cross-Validation:**
```elixir
defmodule WorkflowDsl.Verifiers.ValidateWorkflowIntegrity do
  use Spark.Dsl.Verifier
  
  alias WorkflowDsl.Info
  
  def verify(dsl_state) do
    workflows = Info.workflows(dsl_state)
    plugins = Info.loaded_plugins(dsl_state)
    
    with :ok <- validate_step_types(workflows, plugins),
         :ok <- validate_dependencies(workflows),
         :ok <- validate_resource_limits(workflows),
         :ok <- validate_security_policies(workflows) do
      :ok
    end
  end
  
  defp validate_step_types(workflows, plugins) do
    available_types = get_available_step_types(plugins)
    
    invalid_steps = 
      workflows
      |> Enum.flat_map(& &1.steps)
      |> Enum.reject(&(&1.type in available_types))
    
    case invalid_steps do
      [] -> :ok
      invalid -> 
        types = Enum.map(invalid, &{&1.name, &1.type})
        {:error, build_error("Invalid step types found", types)}
    end
  end
  
  defp validate_dependencies(workflows) do
    Enum.reduce_while(workflows, :ok, fn workflow, :ok ->
      case check_circular_dependencies(workflow.steps) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end
end
```

**Business Rule Verification:**
```elixir
defmodule WorkflowDsl.Verifiers.BusinessRules do
  use Spark.Dsl.Verifier
  
  def verify(dsl_state) do
    workflows = Info.workflows(dsl_state)
    
    Enum.reduce_while(workflows, :ok, fn workflow, :ok ->
      with :ok <- validate_approval_chain(workflow),
           :ok <- validate_notification_requirements(workflow),
           :ok <- validate_compliance_rules(workflow),
           :ok <- validate_resource_allocation(workflow) do
        {:cont, :ok}
      else
        error -> {:halt, error}
      end
    end)
  end
  
  defp validate_approval_chain(workflow) do
    approval_steps = Enum.filter(workflow.steps, &(&1.type == :approval))
    
    cond do
      # High-value workflows require manager approval
      workflow.estimated_value > 10_000 and 
      not has_manager_approval?(approval_steps) ->
        {:error, "High-value workflows require manager approval"}
      
      # Financial workflows require two-person approval
      workflow.category == :financial and
      length(approval_steps) < 2 ->
        {:error, "Financial workflows require dual approval"}
      
      # External integrations require security review
      has_external_integrations?(workflow) and
      not has_security_approval?(approval_steps) ->
        {:error, "External integrations require security approval"}
      
      true -> :ok
    end
  end
  
  defp validate_compliance_rules(workflow) do
    # Industry-specific compliance validation
    case Application.get_env(:workflow_dsl, :industry) do
      :healthcare -> validate_hipaa_compliance(workflow)
      :finance -> validate_sox_compliance(workflow)
      :government -> validate_fisma_compliance(workflow)
      _ -> :ok
    end
  end
end
```

**Dynamic Validation Based on Configuration:**
```elixir
defmodule WorkflowDsl.Verifiers.PolicyEnforcement do
  use Spark.Dsl.Verifier
  
  def verify(dsl_state) do
    policies = load_organization_policies()
    workflows = Info.workflows(dsl_state)
    
    Enum.reduce_while(workflows, :ok, fn workflow, :ok ->
      case apply_policies(workflow, policies) do
        :ok -> {:cont, :ok}
        {:violations, violations} -> 
          {:halt, {:error, build_policy_error(violations)}}
      end
    end)
  end
  
  defp load_organization_policies do
    # Load from external configuration, database, or API
    %{
      max_parallel_steps: 5,
      required_approvers: ["manager", "security"],
      allowed_integrations: [:slack, :email, :jira],
      data_retention_days: 90,
      audit_requirements: [:all_approvals, :external_calls]
    }
  end
  
  defp apply_policies(workflow, policies) do
    violations = []
    
    violations = 
      if count_parallel_steps(workflow) > policies.max_parallel_steps do
        ["Too many parallel steps"] ++ violations
      else
        violations
      end
    
    violations =
      if not has_required_approvers?(workflow, policies.required_approvers) do
        ["Missing required approvers"] ++ violations
      else
        violations
      end
    
    case violations do
      [] -> :ok
      violations -> {:violations, violations}
    end
  end
end
```

### Transformer Deep Dive: Code Generation (11:30-12:00)

#### Advanced Code Generation Patterns

**Multi-Pass Transformation:**
```elixir
defmodule WorkflowDsl.Transformers.GenerateExecutionPlan do
  use Spark.Dsl.Transformer
  
  # First pass: Analyze dependencies
  def transform(dsl_state) do
    workflows = get_entities(dsl_state, [:workflows])
    
    enhanced_workflows = 
      Enum.map(workflows, fn workflow ->
        execution_plan = build_execution_plan(workflow)
        %{workflow | execution_plan: execution_plan}
      end)
    
    {:ok, set_entities(dsl_state, [:workflows], enhanced_workflows)}
  end
  
  defp build_execution_plan(workflow) do
    steps = workflow.steps
    
    %{
      sequential_phases: identify_sequential_phases(steps),
      parallel_groups: identify_parallel_groups(steps),
      critical_path: calculate_critical_path(steps),
      resource_requirements: calculate_resources(steps),
      estimated_duration: calculate_duration(steps)
    }
  end
end
```

**Cross-Module Code Generation:**
```elixir
defmodule WorkflowDsl.Transformers.GenerateModules do
  use Spark.Dsl.Transformer
  
  def transform(dsl_state) do
    workflows = get_entities(dsl_state, [:workflows])
    module_name = get_option(dsl_state, [], :module)
    
    # Generate execution modules for each workflow
    generated_modules = 
      Enum.map(workflows, &generate_workflow_module(&1, module_name))
    
    # Generate coordinator module
    coordinator_module = generate_coordinator_module(workflows, module_name)
    
    all_modules = [coordinator_module | generated_modules]
    
    {:ok, persist(dsl_state, :generated_modules, all_modules)}
  end
  
  defp generate_workflow_module(workflow, base_module) do
    module_name = Module.concat(base_module, workflow.name)
    
    module_ast = quote do
      defmodule unquote(module_name) do
        @workflow_config unquote(Macro.escape(workflow))
        
        def execute(context \\ %{}) do
          WorkflowDsl.Runtime.execute_workflow(@workflow_config, context)
        end
        
        def validate_context(context) do
          WorkflowDsl.Runtime.validate_workflow_context(@workflow_config, context)
        end
        
        def get_required_permissions do
          unquote(Macro.escape(calculate_permissions(workflow)))
        end
        
        # Generate step-specific functions
        unquote_splicing(generate_step_functions(workflow.steps))
      end
    end
    
    {module_name, module_ast}
  end
  
  defp generate_step_functions(steps) do
    Enum.map(steps, fn step ->
      function_name = :"execute_#{step.name}"
      
      quote do
        def unquote(function_name)(context) do
          step_config = unquote(Macro.escape(step))
          WorkflowDsl.Runtime.execute_step(step_config, context)
        end
      end
    end)
  end
end
```

**Runtime Code Compilation:**
```elixir
defmodule WorkflowDsl.Transformers.CompileRuntime do
  use Spark.Dsl.Transformer
  
  def after_compile?, do: true
  
  def transform(dsl_state) do
    generated_modules = get_persisted(dsl_state, :generated_modules, [])
    
    # Compile generated modules at runtime
    Enum.each(generated_modules, fn {module_name, module_ast} ->
      Code.eval_quoted(module_ast)
    end)
    
    {:ok, dsl_state}
  end
end
```

---

## Afternoon Lab Session (1:00-5:00)

### Lab 3.1: Extensible Workflow Engine (1:00-3:30)

**Business Context:**
Your organization has diverse workflow needs across departments:
- **HR**: Employee onboarding, performance reviews, leave approvals
- **Sales**: Lead qualification, contract approvals, customer onboarding  
- **Engineering**: Code deployment, incident response, release management
- **Finance**: Purchase approvals, budget reviews, compliance audits

Each department has unique requirements, but the underlying workflow patterns are similar. You need a system that provides common infrastructure while allowing departmental customization.

**Your Mission:**
Build an extensible workflow engine that supports plugins for department-specific step types while maintaining consistent execution and monitoring.

#### Core Architecture Design (30 minutes)

**Step 1: Define the Plugin Interface**

```elixir
# lib/workflow_dsl/plugin.ex
defmodule WorkflowDsl.Plugin do
  @doc """
  Behavior for workflow step plugins.
  
  Each plugin must implement these callbacks to integrate with the workflow engine.
  """
  
  @callback step_types() :: [atom()]
  @callback step_schema(atom()) :: keyword()
  @callback validate_step(atom(), map()) :: {:ok, map()} | {:error, String.t()}
  @callback execute_step(atom(), map(), map()) :: {:ok, map()} | {:error, String.t()}
  @callback rollback_step(atom(), map(), map()) :: :ok | {:error, String.t()}
  
  @optional_callbacks [rollback_step: 3]
  
  defmacro __using__(_opts) do
    quote do
      @behavior WorkflowDsl.Plugin
      
      def register do
        WorkflowDsl.PluginRegistry.register_plugin(__MODULE__)
      end
      
      # Helper for defining step types
      defmacro step_type(name, opts \\ []) do
        quote do
          @step_types Map.put(@step_types || %{}, unquote(name), unquote(opts))
        end
      end
      
      # Generate step_types/0 from accumulated step_type definitions
      @before_compile WorkflowDsl.Plugin
    end
  end
  
  defmacro __before_compile__(env) do
    step_types = Module.get_attribute(env.module, :step_types, %{})
    
    quote do
      def step_types, do: Map.keys(unquote(Macro.escape(step_types)))
      def step_schemas, do: unquote(Macro.escape(step_types))
    end
  end
end
```

**Step 2: Create Core Workflow Entities**

```elixir
# lib/workflow_dsl/entities.ex
defmodule WorkflowDsl.Entities do
  defmodule Workflow do
    defstruct [
      :name,
      :description,
      :trigger,
      :category,
      :estimated_value,
      :timeout,
      :retry_policy,
      :error_handling,
      steps: [],
      metadata: %{},
      execution_plan: nil
    ]
  end
  
  defmodule Step do
    defstruct [
      :name,
      :type,
      :description,
      :config,
      :dependencies,
      :conditions,
      :timeout,
      :retry_attempts,
      :on_failure,
      :parallel_group,
      metadata: %{}
    ]
  end
  
  defmodule Trigger do
    defstruct [
      :type,
      :config,
      :conditions,
      :schedule,
      metadata: %{}
    ]
  end
  
  defmodule RetryPolicy do
    defstruct [
      :max_attempts,
      :backoff_strategy,
      :backoff_base,
      :max_backoff,
      :retry_conditions
    ]
  end
end
```

#### Plugin Development (45 minutes)

**Step 3: Build Department-Specific Plugins**

```elixir
# lib/workflow_dsl/plugins/hr_plugin.ex
defmodule WorkflowDsl.Plugins.HrPlugin do
  use WorkflowDsl.Plugin
  
  step_type :employee_record do
    schema [
      action: [type: {:one_of, [:create, :update, :deactivate]}, required: true],
      employee_id: [type: :string],
      fields: [type: :keyword_list, default: []],
      notify_manager: [type: :boolean, default: true]
    ]
  end
  
  step_type :background_check do
    schema [
      provider: [type: {:one_of, [:acme_bg, :secure_check]}, required: true],
      check_types: [type: {:list, :atom}, default: [:criminal, :employment]],
      urgency: [type: {:one_of, [:standard, :expedited]}, default: :standard]
    ]
  end
  
  step_type :equipment_request do
    schema [
      items: [type: {:list, :string}, required: true],
      department: [type: :string, required: true],
      delivery_date: [type: :date],
      approver: [type: :string]
    ]
  end
  
  def step_schema(step_type) do
    step_schemas()[step_type]
  end
  
  def validate_step(:employee_record, config) do
    case config do
      %{action: :create, employee_id: nil} ->
        {:error, "employee_id required for create action"}
      %{action: :update, fields: []} ->
        {:error, "fields required for update action"}
      _ ->
        {:ok, config}
    end
  end
  
  def validate_step(:background_check, config) do
    if config.urgency == :expedited and length(config.check_types) > 2 do
      {:error, "Expedited checks limited to 2 types maximum"}
    else
      {:ok, config}
    end
  end
  
  def validate_step(step_type, config), do: {:ok, config}
  
  def execute_step(:employee_record, config, context) do
    # Integration with HR system
    case HrSystem.execute_employee_action(config, context) do
      {:ok, result} -> 
        {:ok, Map.put(context, :employee_record_result, result)}
      {:error, reason} ->
        {:error, "HR system error: #{reason}"}
    end
  end
  
  def execute_step(:background_check, config, context) do
    # Integration with background check provider
    provider = Map.fetch!(config, :provider)
    
    case BackgroundCheckService.request_check(provider, config, context) do
      {:ok, check_id} ->
        {:ok, Map.put(context, :background_check_id, check_id)}
      {:error, reason} ->
        {:error, "Background check failed: #{reason}"}
    end
  end
  
  def execute_step(:equipment_request, config, context) do
    # Integration with equipment management system
    case EquipmentSystem.request_items(config, context) do
      {:ok, request_id} ->
        {:ok, Map.put(context, :equipment_request_id, request_id)}
      {:error, reason} ->
        {:error, "Equipment request failed: #{reason}"}
    end
  end
end
```

```elixir
# lib/workflow_dsl/plugins/engineering_plugin.ex
defmodule WorkflowDsl.Plugins.EngineeringPlugin do
  use WorkflowDsl.Plugin
  
  step_type :code_deployment do
    schema [
      environment: [type: {:one_of, [:staging, :production]}, required: true],
      service: [type: :string, required: true],
      version: [type: :string, required: true],
      rollback_version: [type: :string],
      health_checks: [type: {:list, :string}, default: ["/health"]],
      canary_percentage: [type: :integer, default: 10]
    ]
  end
  
  step_type :database_migration do
    schema [
      migration_file: [type: :string, required: true],
      database: [type: :string, required: true],
      backup_required: [type: :boolean, default: true],
      dry_run: [type: :boolean, default: false]
    ]
  end
  
  step_type :security_scan do
    schema [
      scan_type: [type: {:one_of, [:sast, :dast, :dependency]}, required: true],
      target: [type: :string, required: true],
      severity_threshold: [type: {:one_of, [:low, :medium, :high, :critical]}, default: :medium],
      fail_on_findings: [type: :boolean, default: true]
    ]
  end
  
  def validate_step(:code_deployment, config) do
    cond do
      config.environment == :production and is_nil(config.rollback_version) ->
        {:error, "Production deployments require rollback_version"}
      config.canary_percentage < 1 or config.canary_percentage > 50 ->
        {:error, "Canary percentage must be between 1 and 50"}
      true ->
        {:ok, config}
    end
  end
  
  def validate_step(:database_migration, config) do
    if config.backup_required and config.database in ["production", "prod"] do
      if String.contains?(config.migration_file, "DROP") do
        {:error, "DROP operations require explicit backup confirmation"}
      else
        {:ok, config}
      end
    else
      {:ok, config}
    end
  end
  
  def validate_step(step_type, config), do: {:ok, config}
  
  def execute_step(:code_deployment, config, context) do
    case DeploymentService.deploy(config, context) do
      {:ok, deployment_id} ->
        # Wait for health checks
        case wait_for_health_checks(config.health_checks, config.service) do
          :ok -> {:ok, Map.put(context, :deployment_id, deployment_id)}
          {:error, reason} -> {:error, "Health check failed: #{reason}"}
        end
      {:error, reason} ->
        {:error, "Deployment failed: #{reason}"}
    end
  end
  
  def execute_step(:security_scan, config, context) do
    case SecurityScanner.run_scan(config, context) do
      {:ok, %{findings: findings}} ->
        critical_findings = filter_critical_findings(findings, config.severity_threshold)
        
        if config.fail_on_findings and length(critical_findings) > 0 do
          {:error, "Security scan found #{length(critical_findings)} critical issues"}
        else
          {:ok, Map.put(context, :security_scan_results, findings)}
        end
      {:error, reason} ->
        {:error, "Security scan failed: #{reason}"}
    end
  end
  
  defp wait_for_health_checks(endpoints, service) do
    # Implementation would check health endpoints
    :ok
  end
  
  defp filter_critical_findings(findings, threshold) do
    # Implementation would filter by severity
    []
  end
end
```

#### Core DSL Extension (30 minutes)

**Step 4: Define the Main DSL Extension**

```elixir
# lib/workflow_dsl/extension.ex
defmodule WorkflowDsl.Extension do
  alias WorkflowDsl.Entities
  
  @retry_policy %Spark.Dsl.Entity{
    name: :retry_policy,
    target: Entities.RetryPolicy,
    schema: [
      max_attempts: [type: :pos_integer, default: 3],
      backoff_strategy: [type: {:one_of, [:linear, :exponential]}, default: :exponential],
      backoff_base: [type: :pos_integer, default: 1000],
      max_backoff: [type: :pos_integer, default: 30_000],
      retry_conditions: [type: {:list, :atom}, default: [:timeout, :service_unavailable]]
    ]
  }
  
  @trigger %Spark.Dsl.Entity{
    name: :trigger,
    target: Entities.Trigger,
    args: [:type],
    schema: [
      type: [type: {:one_of, [:manual, :scheduled, :webhook, :event]}, required: true],
      config: [type: :keyword_list, default: []],
      conditions: [type: :keyword_list, default: []],
      schedule: [type: :string]
    ]
  }
  
  @step %Spark.Dsl.Entity{
    name: :step,
    target: Entities.Step,
    args: [:name, :type],
    entities: [retry_policy: @retry_policy],
    schema: [
      name: [type: :atom, required: true],
      type: [type: {:custom, __MODULE__, :validate_step_type, []}, required: true],
      description: [type: :string],
      config: [type: :keyword_list, default: []],
      dependencies: [type: {:list, :atom}, default: []],
      conditions: [type: :keyword_list, default: []],
      timeout: [type: :pos_integer, default: 30_000],
      retry_attempts: [type: :non_neg_integer, default: 0],
      on_failure: [type: {:one_of, [:continue, :fail, :retry]}, default: :fail],
      parallel_group: [type: :atom],
      metadata: [type: :keyword_list, default: []]
    ]
  }
  
  @workflow %Spark.Dsl.Entity{
    name: :workflow,
    target: Entities.Workflow,
    args: [:name],
    entities: [step: @step, trigger: @trigger, retry_policy: @retry_policy],
    schema: [
      name: [type: :atom, required: true],
      description: [type: :string],
      category: [type: :atom],
      estimated_value: [type: :pos_integer],
      timeout: [type: :pos_integer, default: :timer.hours(1)],
      error_handling: [type: {:one_of, [:fail_fast, :continue_on_error]}, default: :fail_fast],
      metadata: [type: :keyword_list, default: []]
    ]
  }
  
  @workflows %Spark.Dsl.Section{
    name: :workflows,
    entities: [@workflow]
  }
  
  @plugin %Spark.Dsl.Entity{
    name: :plugin,
    args: [:module],
    schema: [
      module: [type: :atom, required: true],
      config: [type: :keyword_list, default: []]
    ]
  }
  
  @plugins %Spark.Dsl.Section{
    name: :plugins,
    entities: [@plugin]
  }
  
  use Spark.Dsl.Extension,
    sections: [@plugins, @workflows],
    transformers: [
      WorkflowDsl.Transformers.LoadPlugins,
      WorkflowDsl.Transformers.ValidateStepTypes,
      WorkflowDsl.Transformers.GenerateExecutionPlan,
      WorkflowDsl.Transformers.GenerateModules
    ],
    verifiers: [
      WorkflowDsl.Verifiers.ValidateWorkflowIntegrity,
      WorkflowDsl.Verifiers.BusinessRules,
      WorkflowDsl.Verifiers.PolicyEnforcement
    ]
  
  def validate_step_type(type) do
    available_types = WorkflowDsl.PluginRegistry.get_step_types()
    
    if type in available_types do
      {:ok, type}
    else
      {:error, "Unknown step type: #{type}. Register plugin or check available types: #{inspect(available_types)}"}
    end
  end
end
```

#### Integration Testing (25 minutes)

**Step 5: Comprehensive Usage Example**

```elixir
# lib/my_company/hr_workflows.ex
defmodule MyCompany.HrWorkflows do
  use WorkflowDsl
  
  # Load the plugins we need for HR workflows
  plugins do
    plugin WorkflowDsl.Plugins.HrPlugin
    plugin WorkflowDsl.Plugins.EmailPlugin
    plugin WorkflowDsl.Plugins.SlackPlugin
    plugin WorkflowDsl.Plugins.ApprovalPlugin
  end
  
  workflows do
    workflow :employee_onboarding do
      description "Complete employee onboarding process"
      category :hr
      estimated_value 50_000  # Annual salary impact
      timeout :timer.hours(72)
      
      trigger :manual do
        conditions [required_fields: [:employee_name, :department, :manager, :start_date]]
      end
      
      # Phase 1: Preparation
      step :background_check, :background_check do
        description "Verify employee background"
        config [
          provider: :acme_bg,
          check_types: [:criminal, :employment, :education],
          urgency: :standard
        ]
        timeout :timer.hours(24)
        
        retry_policy do
          max_attempts 2
          backoff_strategy :linear
          retry_conditions [:timeout, :provider_unavailable]
        end
      end
      
      step :equipment_request, :equipment_request do
        description "Request employee equipment"
        dependencies [:background_check]
        config [
          items: ["laptop", "monitor", "keyboard", "mouse"],
          department: "{{employee.department}}",
          delivery_date: "{{employee.start_date}}"
        ]
      end
      
      # Phase 2: Account Setup (parallel)
      step :create_employee_record, :employee_record do
        description "Create employee in HR system"
        dependencies [:background_check]
        parallel_group :account_setup
        config [
          action: :create,
          fields: [
            name: "{{employee.name}}",
            department: "{{employee.department}}",
            manager: "{{employee.manager}}",
            start_date: "{{employee.start_date}}"
          ],
          notify_manager: true
        ]
      end
      
      step :email_account, :email_provisioning do
        description "Create email account"
        dependencies [:background_check]
        parallel_group :account_setup
        config [
          username: "{{employee.preferred_username}}",
          department: "{{employee.department}}",
          groups: ["all-employees", "{{employee.department}}"]
        ]
      end
      
      step :slack_invite, :slack_invitation do
        description "Invite to company Slack"
        dependencies [:email_account]
        config [
          email: "{{employee.email}}",
          channels: ["#general", "#{{employee.department}}", "#announcements"],
          welcome_message: true
        ]
      end
      
      # Phase 3: Manager Approval
      step :manager_approval, :approval do
        description "Manager confirms onboarding completion"
        dependencies [:create_employee_record, :equipment_request, :slack_invite]
        config [
          approver: "{{employee.manager}}",
          approval_type: :onboarding_completion,
          timeout: :timer.hours(8),
          reminder_interval: :timer.hours(2)
        ]
        on_failure :continue  # Don't block completion
      end
      
      # Phase 4: Welcome
      step :welcome_email, :email do
        description "Send welcome email with next steps"
        dependencies [:manager_approval]
        config [
          to: "{{employee.email}}",
          template: "employee_welcome",
          attachments: ["employee_handbook.pdf", "benefits_guide.pdf"]
        ]
      end
      
      step :calendar_invite, :calendar_event do
        description "Schedule first-day meeting"
        dependencies [:manager_approval]
        config [
          attendees: ["{{employee.email}}", "{{employee.manager}}", "hr@company.com"],
          title: "First Day Check-in - {{employee.name}}",
          duration: :timer.minutes(30),
          date: "{{employee.start_date}}",
          time: "09:00"
        ]
      end
    end
    
    workflow :performance_review do
      description "Quarterly performance review process"
      category :hr
      
      trigger :scheduled do
        schedule "0 0 1 */3 *"  # First day of every quarter
      end
      
      step :generate_review_forms, :form_generation do
        description "Generate personalized review forms"
        config [
          form_type: :quarterly_review,
          employees: :all_active,
          include_peer_feedback: true
        ]
      end
      
      step :notify_employees, :bulk_email do
        description "Notify employees review period has started"
        dependencies [:generate_review_forms]
        config [
          template: "review_notification",
          recipients: "{{generated_forms.employees}}",
          deadline: "{{Date.add(Date.utc_today(), 14)}}"
        ]
      end
      
      step :reminder_sequence, :scheduled_reminders do
        description "Send reminders for incomplete reviews"
        dependencies [:notify_employees]
        config [
          schedules: [
            {7, "First reminder"},
            {3, "Second reminder"},
            {1, "Final reminder"}
          ],
          template: "review_reminder"
        ]
      end
      
      step :manager_reviews, :approval do
        description "Managers complete their reviews"
        dependencies [:notify_employees]
        config [
          approver_group: :managers,
          approval_type: :performance_review,
          parallel: true,
          timeout: :timer.days(14)
        ]
      end
      
      step :hr_summary, :report_generation do
        description "Generate HR summary report"
        dependencies [:manager_reviews, :reminder_sequence]
        config [
          report_type: :performance_summary,
          include_metrics: [:completion_rate, :average_scores, :improvement_areas],
          recipients: ["hr-leadership@company.com"]
        ]
      end
    end
  end
end
```

### Break (3:30-3:45)

### Lab 3.2: Advanced Architecture Patterns (3:45-4:45)

#### Dynamic Plugin Loading (20 minutes)

**Step 6: Runtime Plugin Management**

```elixir
# lib/workflow_dsl/plugin_manager.ex
defmodule WorkflowDsl.PluginManager do
  use GenServer
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  def load_plugin(plugin_module, config \\ []) do
    GenServer.call(__MODULE__, {:load_plugin, plugin_module, config})
  end
  
  def unload_plugin(plugin_module) do
    GenServer.call(__MODULE__, {:unload_plugin, plugin_module})
  end
  
  def reload_plugin(plugin_module, config \\ []) do
    GenServer.call(__MODULE__, {:reload_plugin, plugin_module, config})
  end
  
  def list_plugins do
    GenServer.call(__MODULE__, :list_plugins)
  end
  
  def get_plugin_status(plugin_module) do
    GenServer.call(__MODULE__, {:get_status, plugin_module})
  end
  
  # GenServer callbacks
  def init(_) do
    {:ok, %{plugins: %{}, plugin_configs: %{}}}
  end
  
  def handle_call({:load_plugin, plugin_module, config}, _from, state) do
    case validate_plugin(plugin_module) do
      :ok ->
        case plugin_module.register() do
          :ok ->
            new_state = %{
              state | 
              plugins: Map.put(state.plugins, plugin_module, :loaded),
              plugin_configs: Map.put(state.plugin_configs, plugin_module, config)
            }
            {:reply, :ok, new_state}
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call({:unload_plugin, plugin_module}, _from, state) do
    case Map.get(state.plugins, plugin_module) do
      :loaded ->
        WorkflowDsl.PluginRegistry.unregister_plugin(plugin_module)
        new_state = %{
          state |
          plugins: Map.delete(state.plugins, plugin_module),
          plugin_configs: Map.delete(state.plugin_configs, plugin_module)
        }
        {:reply, :ok, new_state}
      nil ->
        {:reply, {:error, :not_loaded}, state}
    end
  end
  
  defp validate_plugin(plugin_module) do
    required_functions = [:step_types, :step_schema, :validate_step, :execute_step]
    
    missing_functions = 
      required_functions
      |> Enum.filter(fn func -> not function_exported?(plugin_module, func, 2) end)
    
    case missing_functions do
      [] -> :ok
      missing -> {:error, "Plugin missing required functions: #{inspect(missing)}"}
    end
  end
end
```

#### Configuration-Driven Workflows (20 minutes)

**Step 7: External Configuration Support**

```elixir
# lib/workflow_dsl/config_loader.ex
defmodule WorkflowDsl.ConfigLoader do
  @doc """
  Load workflow configurations from external sources
  """
  
  def load_from_file(path) do
    case File.read(path) do
      {:ok, content} ->
        case Path.extname(path) do
          ".json" -> Jason.decode(content)
          ".yaml" -> YamlElixir.read_from_string(content)
          ".toml" -> Toml.decode(content)
          ext -> {:error, "Unsupported file type: #{ext}"}
        end
      {:error, reason} ->
        {:error, "Failed to read file: #{reason}"}
    end
  end
  
  def load_from_database(workflow_id) do
    # Load from database
    case WorkflowConfigRepo.get(workflow_id) do
      nil -> {:error, :not_found}
      config -> {:ok, config}
    end
  end
  
  def load_from_api(api_url) do
    # Load from external API
    case HTTPClient.get(api_url) do
      {:ok, %{status: 200, body: body}} ->
        Jason.decode(body)
      {:ok, %{status: status}} ->
        {:error, "API returned status #{status}"}
      {:error, reason} ->
        {:error, "API request failed: #{reason}"}
    end
  end
  
  def convert_to_dsl(config) do
    """
    defmodule DynamicWorkflow do
      use WorkflowDsl
      
      #{generate_plugins_section(config["plugins"])}
      
      workflows do
        #{generate_workflows_section(config["workflows"])}
      end
    end
    """
  end
  
  defp generate_plugins_section(plugins) when is_list(plugins) do
    plugin_statements = 
      Enum.map(plugins, fn plugin ->
        "plugin #{plugin["module"]}"
      end)
    
    """
    plugins do
      #{Enum.join(plugin_statements, "\n    ")}
    end
    """
  end
  
  defp generate_workflows_section(workflows) when is_list(workflows) do
    Enum.map(workflows, &generate_workflow/1)
    |> Enum.join("\n\n    ")
  end
  
  defp generate_workflow(workflow) do
    steps = generate_steps(workflow["steps"])
    
    """
    workflow :#{workflow["name"]} do
      description "#{workflow["description"]}"
      category :#{workflow["category"]}
      
      #{steps}
    end
    """
  end
  
  defp generate_steps(steps) when is_list(steps) do
    Enum.map(steps, &generate_step/1)
    |> Enum.join("\n\n      ")
  end
  
  defp generate_step(step) do
    config_lines = 
      Enum.map(step["config"], fn {key, value} ->
        "#{key}: #{inspect(value)}"
      end)
      |> Enum.join(",\n        ")
    
    """
    step :#{step["name"]}, :#{step["type"]} do
      description "#{step["description"]}"
      config [
        #{config_lines}
      ]
    end
    """
  end
end
```

#### Performance Optimization (20 minutes)

**Step 8: Workflow Execution Optimization**

```elixir
# lib/workflow_dsl/execution_optimizer.ex
defmodule WorkflowDsl.ExecutionOptimizer do
  @doc """
  Optimize workflow execution plans for performance
  """
  
  def optimize_execution_plan(workflow) do
    steps = workflow.steps
    
    %{
      parallel_batches: identify_parallel_batches(steps),
      critical_path: calculate_critical_path(steps),
      resource_pools: organize_resource_pools(steps),
      caching_opportunities: identify_caching_opportunities(steps),
      estimated_duration: calculate_total_duration(steps)
    }
  end
  
  defp identify_parallel_batches(steps) do
    # Group steps that can run in parallel
    dependency_graph = build_dependency_graph(steps)
    
    levels = topological_sort_levels(dependency_graph)
    
    Enum.map(levels, fn level_steps ->
      parallel_groups = group_by_parallel_group(level_steps)
      
      %{
        sequential_steps: Map.get(parallel_groups, nil, []),
        parallel_groups: Map.delete(parallel_groups, nil)
      }
    end)
  end
  
  defp calculate_critical_path(steps) do
    # Find the longest path through the workflow
    dependency_graph = build_dependency_graph(steps)
    
    # Calculate earliest start times
    earliest_starts = calculate_earliest_starts(dependency_graph)
    
    # Calculate latest start times
    latest_starts = calculate_latest_starts(dependency_graph)
    
    # Critical path consists of steps where earliest = latest
    critical_steps = 
      Enum.filter(steps, fn step ->
        earliest_starts[step.name] == latest_starts[step.name]
      end)
    
    %{
      steps: critical_steps,
      total_duration: calculate_path_duration(critical_steps),
      bottlenecks: identify_bottlenecks(critical_steps)
    }
  end
  
  defp organize_resource_pools(steps) do
    # Group steps by resource requirements
    steps
    |> Enum.group_by(&get_resource_type/1)
    |> Enum.map(fn {resource_type, resource_steps} ->
      {resource_type, %{
        steps: resource_steps,
        max_concurrent: calculate_max_concurrent(resource_type),
        scheduling_strategy: get_scheduling_strategy(resource_type)
      }}
    end)
    |> Map.new()
  end
  
  defp identify_caching_opportunities(steps) do
    # Find steps with repeated configurations or expensive operations
    expensive_steps = Enum.filter(steps, &is_expensive_step?/1)
    
    cacheable_operations = 
      Enum.filter(expensive_steps, fn step ->
        has_deterministic_output?(step) and has_stable_config?(step)
      end)
    
    %{
      cacheable_steps: cacheable_operations,
      cache_keys: Enum.map(cacheable_operations, &generate_cache_key/1),
      estimated_savings: calculate_cache_savings(cacheable_operations)
    }
  end
  
  defp is_expensive_step?(step) do
    # Heuristics for identifying expensive operations
    expensive_types = [:database_migration, :security_scan, :deployment, :backup]
    step.type in expensive_types or (step.timeout || 0) > 60_000
  end
  
  defp has_deterministic_output?(step) do
    # Check if step produces same output for same input
    deterministic_types = [:database_migration, :file_processing, :report_generation]
    step.type in deterministic_types
  end
  
  defp generate_cache_key(step) do
    :crypto.hash(:sha256, :erlang.term_to_binary({step.type, step.config}))
    |> Base.encode16(case: :lower)
  end
end
```

### Lab Review and Architecture Discussion (4:45-5:00)

#### Demonstration and Sharing (10 minutes)

**Each team demonstrates:**
- Their extensible workflow engine in action
- One custom plugin they developed
- Advanced feature they implemented (optimization, dynamic loading, etc.)
- How their architecture supports community extension

#### Architecture Patterns Review (5 minutes)

**Key Architectural Insights:**
1. **Plugin Systems**: How to balance flexibility with consistency
2. **Extension Points**: Strategic places to allow customization
3. **Composition Patterns**: Building complex behavior from simple pieces
4. **Performance Considerations**: Optimizing extensible systems
5. **Community Development**: Enabling others to extend your DSL

---

## Evening Wrap-up (5:00-6:00)

### Individual Reflection (5:00-5:15)

**Journal about today's architectural insights:**
1. What was the most challenging aspect of designing for extensibility?
2. How did plugin architecture change your thinking about DSL design?
3. Which performance optimization techniques were most valuable?
4. What would you do differently in your architecture?
5. How do you see building community around extensible DSLs?

### Team Presentations (5:15-5:45)

**5-minute presentations per team:**
- Demo your workflow engine with plugins
- Explain your most innovative architectural pattern
- Share your biggest design challenge and solution
- Describe how your architecture enables community contribution

### Tomorrow's Preview (5:45-6:00)

**Day 4: Production Deployment and CI/CD**

Tomorrow we focus on:
- **Production-ready DSL deployment** with real infrastructure
- **CI/CD integration** for DSL-driven applications  
- **Monitoring and observability** for DSL-based systems
- **Real-world deployment pipeline DSL** with full automation
- **Operational excellence** for DSL systems

**Tonight's Assignment:**
1. **Reading**: "Production Deployment" chapter
2. **Research**: Investigate your organization's current deployment processes and pain points
3. **Design thinking**: How could DSLs improve deployment reliability and speed?

---

## Day 3 Success Criteria

You've mastered Day 3 if you can:

- [ ] **Design plugin architectures** that enable community extension
- [ ] **Build sophisticated verifiers** that enforce complex business rules
- [ ] **Create extensible systems** without sacrificing simplicity
- [ ] **Optimize DSL performance** for production workloads
- [ ] **Think in communities** rather than just individual use cases
- [ ] **Balance flexibility and consistency** in extensible designs
- [ ] **Plan for evolution** of DSL-based systems

### Key Insights to Remember

**Extensible Architecture:**
- Plugin systems enable community contribution while maintaining consistency
- Extension points must be strategically chosen and well-documented
- Performance optimization is crucial for production extensible systems

**Advanced Spark Patterns:**
- Verifiers enable sophisticated business rule enforcement
- Transformers can generate entire modules and optimization plans
- Multi-pass transformation enables complex code generation

**Community Thinking:**
- Design for the community you want to create
- Documentation and examples are crucial for adoption
- Balance power with simplicity to enable contribution

Tomorrow we take these sophisticated architectures and deploy them to production with full CI/CD integration. The extensible patterns you've learned today become the foundation for enterprise-scale DSL systems.

**Outstanding architecture work today! You're thinking like a true DSL platform engineer.** 🏗️