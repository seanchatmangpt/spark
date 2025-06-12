# Your First DSL

> *"The way to get started is to quit talking and begin doing."* - Walt Disney

This chapter guides you through creating your first Spark DSL from conception to working implementation. We'll build a practical configuration management DSL that demonstrates core concepts while solving a real-world problem.

## The Problem: Application Configuration

Every application needs configuration management. Traditional approaches often lead to:

- **Scattered configuration** across multiple files
- **No validation** of configuration values
- **Runtime errors** from invalid configurations
- **Poor documentation** of available options
- **Difficult testing** of different configurations

We'll create a DSL that addresses these issues elegantly.

## Design Phase: Understanding the Domain

### Domain Analysis

Configuration management involves:

**Environments**: Different settings for development, staging, production
**Services**: External services with URLs, credentials, timeouts
**Features**: Feature flags and toggles
**Resources**: Database connections, caches, queues

### User Stories

As a developer, I want to:
- Define configuration in a clear, readable format
- Validate configuration at compile time
- Access configuration values at runtime
- Document configuration options automatically
- Test different configuration scenarios easily

### DSL Vision

```elixir
defmodule MyApp.Config do
  use MyApp.ConfigDsl
  
  environment :production do
    database_url "postgresql://prod-db:5432/myapp"
    redis_url "redis://prod-cache:6379"
    log_level :info
    max_connections 100
  end
  
  environment :development do
    database_url "postgresql://localhost:5432/myapp_dev" 
    redis_url "redis://localhost:6379"
    log_level :debug
    max_connections 10
  end
  
  service :payment_processor do
    base_url "https://api.stripe.com"
    api_key {:system, "STRIPE_API_KEY"}
    timeout 30_000
    retries 3
  end
  
  feature_flag :new_checkout do
    enabled false
    rollout_percentage 10
  end
end
```

## Implementation Phase

### Step 1: Define Entity Structures

First, define the data structures that represent our domain concepts:

```elixir
# lib/my_app/config_dsl/entities.ex
defmodule MyApp.ConfigDsl.Entities do
  
  defmodule Environment do
    @moduledoc "Represents an environment configuration"
    defstruct [
      :name,
      :database_url,
      :redis_url, 
      :log_level,
      :max_connections,
      options: []
    ]
  end
  
  defmodule Service do
    @moduledoc "Represents an external service configuration"
    defstruct [
      :name,
      :base_url,
      :api_key,
      :timeout,
      :retries,
      headers: [],
      options: []
    ]
  end
  
  defmodule FeatureFlag do
    @moduledoc "Represents a feature flag configuration"
    defstruct [
      :name,
      :enabled,
      :rollout_percentage,
      conditions: [],
      options: []
    ]
  end
end
```

### Step 2: Define DSL Entities

Create the Spark entity definitions:

```elixir
# lib/my_app/config_dsl/extension.ex
defmodule MyApp.ConfigDsl.Extension do
  @moduledoc """
  Core extension for configuration DSL.
  """
  
  alias MyApp.ConfigDsl.Entities
  
  @environment %Spark.Dsl.Entity{
    name: :environment,
    target: Entities.Environment,
    args: [:name],
    describe: "Define environment-specific configuration",
    examples: [
      """
      environment :production do
        database_url "postgresql://prod:5432/myapp"
        log_level :info
        max_connections 100
      end
      """
    ],
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The environment name (e.g., :production, :development)"
      ],
      database_url: [
        type: :string,
        doc: "Database connection URL"
      ],
      redis_url: [
        type: :string,
        doc: "Redis connection URL"  
      ],
      log_level: [
        type: {:one_of, [:debug, :info, :warn, :error]},
        default: :info,
        doc: "Application log level"
      ],
      max_connections: [
        type: :pos_integer,
        default: 10,
        doc: "Maximum number of database connections"
      ]
    ]
  }
  
  @service %Spark.Dsl.Entity{
    name: :service,
    target: Entities.Service,
    args: [:name],
    describe: "Define external service configuration",
    examples: [
      """
      service :payment_processor do
        base_url "https://api.stripe.com"
        api_key {:system, "STRIPE_API_KEY"}
        timeout 30_000
        retries 3
      end
      """
    ],
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The service identifier"
      ],
      base_url: [
        type: :string,
        required: true,
        doc: "Base URL for the service"
      ],
      api_key: [
        type: {:or, [:string, {:tuple, [:atom, :string]}]},
        doc: "API key or system environment variable reference"
      ],
      timeout: [
        type: :pos_integer,
        default: 15_000,
        doc: "Request timeout in milliseconds"
      ],
      retries: [
        type: :non_neg_integer,
        default: 0,
        doc: "Number of retry attempts"
      ]
    ]
  }
  
  @feature_flag %Spark.Dsl.Entity{
    name: :feature_flag,
    target: Entities.FeatureFlag,
    args: [:name],
    describe: "Define feature flag configuration",
    examples: [
      """
      feature_flag :new_checkout do
        enabled false
        rollout_percentage 10
      end
      """
    ],
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The feature flag identifier"
      ],
      enabled: [
        type: :boolean,
        default: false,
        doc: "Whether the feature is enabled"
      ],
      rollout_percentage: [
        type: {:custom, __MODULE__, :validate_percentage, []},
        default: 0,
        doc: "Percentage of users who should see this feature (0-100)"
      ]
    ]
  }
  
  # Custom validator for percentage values
  def validate_percentage(value) when is_integer(value) and value >= 0 and value <= 100 do
    {:ok, value}
  end
  def validate_percentage(value) do
    {:error, "Expected integer between 0 and 100, got: #{inspect(value)}"}
  end
  
  @environments %Spark.Dsl.Section{
    name: :environments,
    describe: "Environment-specific configurations",
    entities: [@environment]
  }
  
  @services %Spark.Dsl.Section{
    name: :services,  
    describe: "External service configurations",
    entities: [@service]
  }
  
  @feature_flags %Spark.Dsl.Section{
    name: :feature_flags,
    describe: "Feature flag configurations", 
    entities: [@feature_flag]
  }
  
  use Spark.Dsl.Extension,
    sections: [@environments, @services, @feature_flags]
end
```

### Step 3: Create the DSL Module

```elixir
# lib/my_app/config_dsl.ex
defmodule MyApp.ConfigDsl do
  @moduledoc """
  A DSL for application configuration management.
  
  This DSL provides a clean, validated way to define application
  configuration across environments, services, and feature flags.
  
  ## Example
  
      defmodule MyApp.Config do
        use MyApp.ConfigDsl
        
        environment :production do
          database_url "postgresql://prod:5432/myapp"
          log_level :info
        end
        
        service :api do
          base_url "https://api.example.com"
          timeout 30_000
        end
        
        feature_flag :new_ui do
          enabled true
          rollout_percentage 50
        end
      end
  """
  
  use Spark.Dsl,
    default_extensions: [extensions: [MyApp.ConfigDsl.Extension]]
end
```

### Step 4: Add Runtime Introspection

```elixir
# lib/my_app/config_dsl/info.ex
defmodule MyApp.ConfigDsl.Info do
  @moduledoc """
  Runtime introspection functions for configuration DSL.
  """
  
  use Spark.InfoGenerator,
    extension: MyApp.ConfigDsl.Extension,
    sections: [:environments, :services, :feature_flags]
  
  @doc """
  Get configuration for a specific environment.
  """
  def environment_config(module, env_name) do
    case environment(module, env_name) do
      {:ok, env} -> {:ok, env}
      :error -> {:error, :environment_not_found}
    end
  end
  
  @doc """
  Get all service configurations as a map.
  """
  def services_map(module) do
    module
    |> services()
    |> Enum.into(%{}, fn service -> {service.name, service} end)
  end
  
  @doc """
  Check if a feature flag is enabled.
  """
  def feature_enabled?(module, flag_name) do
    case feature_flag(module, flag_name) do
      {:ok, flag} -> flag.enabled
      :error -> false
    end
  end
  
  @doc """
  Get feature rollout percentage.
  """
  def feature_rollout(module, flag_name) do
    case feature_flag(module, flag_name) do
      {:ok, flag} -> flag.rollout_percentage
      :error -> 0
    end
  end
end
```

### Step 5: Add Validation

```elixir
# lib/my_app/config_dsl/verifiers/validate_environments.ex
defmodule MyApp.ConfigDsl.Verifiers.ValidateEnvironments do
  @moduledoc """
  Validates environment configurations.
  """
  
  use Spark.Dsl.Verifier
  
  alias MyApp.ConfigDsl.Info
  
  @impl Spark.Dsl.Verifier
  def verify(dsl_state) do
    environments = Info.environments(dsl_state)
    
    with :ok <- validate_required_environments(environments),
         :ok <- validate_database_urls(environments),
         :ok <- validate_connection_limits(environments) do
      :ok
    end
  end
  
  defp validate_required_environments(environments) do
    env_names = Enum.map(environments, & &1.name)
    required = [:development, :test, :production]
    missing = required -- env_names
    
    case missing do
      [] -> :ok
      missing_envs ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Missing required environments: #{inspect(missing_envs)}",
           path: [:environments]
         )}
    end
  end
  
  defp validate_database_urls(environments) do
    invalid_urls =
      environments
      |> Enum.filter(fn env -> env.database_url && not valid_database_url?(env.database_url) end)
      |> Enum.map(& &1.name)
    
    case invalid_urls do
      [] -> :ok
      invalid ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Invalid database URLs in environments: #{inspect(invalid)}",
           path: [:environments]
         )}
    end
  end
  
  defp validate_connection_limits(environments) do
    invalid_limits =
      environments
      |> Enum.filter(fn env -> env.max_connections && env.max_connections > 1000 end)
      |> Enum.map(& &1.name)
    
    case invalid_limits do
      [] -> :ok
      invalid ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Connection limits too high (>1000) in environments: #{inspect(invalid)}",
           path: [:environments]
         )}
    end
  end
  
  defp valid_database_url?(url) do
    String.starts_with?(url, ["postgresql://", "mysql://", "sqlite://"])
  end
end
```

```elixir
# lib/my_app/config_dsl/verifiers/validate_services.ex
defmodule MyApp.ConfigDsl.Verifiers.ValidateServices do
  @moduledoc """
  Validates service configurations.
  """
  
  use Spark.Dsl.Verifier
  
  alias MyApp.ConfigDsl.Info
  
  @impl Spark.Dsl.Verifier
  def verify(dsl_state) do
    services = Info.services(dsl_state)
    
    with :ok <- validate_unique_service_names(services),
         :ok <- validate_service_urls(services),
         :ok <- validate_timeouts(services) do
      :ok
    end
  end
  
  defp validate_unique_service_names(services) do
    names = Enum.map(services, & &1.name)
    duplicates = names -- Enum.uniq(names)
    
    case duplicates do
      [] -> :ok
      dups ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Duplicate service names: #{inspect(dups)}",
           path: [:services]
         )}
    end
  end
  
  defp validate_service_urls(services) do
    invalid_services =
      services
      |> Enum.filter(fn service -> not valid_url?(service.base_url) end)
      |> Enum.map(& &1.name)
    
    case invalid_services do
      [] -> :ok
      invalid ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Invalid URLs in services: #{inspect(invalid)}",
           path: [:services]
         )}
    end
  end
  
  defp validate_timeouts(services) do
    invalid_timeouts =
      services
      |> Enum.filter(fn service -> service.timeout > 300_000 end)  # 5 minutes max
      |> Enum.map(& &1.name)
    
    case invalid_timeouts do
      [] -> :ok
      invalid ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Timeouts too long (>5min) in services: #{inspect(invalid)}",
           path: [:services]
         )}
    end
  end
  
  defp valid_url?(url) do
    String.starts_with?(url, ["http://", "https://"])
  end
end
```

### Step 6: Update Extension with Verifiers

```elixir
# lib/my_app/config_dsl/extension.ex (updated)
defmodule MyApp.ConfigDsl.Extension do
  # ... previous entity definitions ...
  
  use Spark.Dsl.Extension,
    sections: [@environments, @services, @feature_flags],
    verifiers: [
      MyApp.ConfigDsl.Verifiers.ValidateEnvironments,
      MyApp.ConfigDsl.Verifiers.ValidateServices
    ]
end
```

## Testing Your DSL

### Basic Functionality Tests

```elixir
# test/my_app/config_dsl_test.exs
defmodule MyApp.ConfigDslTest do
  use ExUnit.Case, async: true
  
  alias MyApp.ConfigDsl.Info
  
  defmodule TestConfig do
    use MyApp.ConfigDsl
    
    environment :development do
      database_url "postgresql://localhost:5432/test"
      log_level :debug
      max_connections 5
    end
    
    environment :production do
      database_url "postgresql://prod:5432/myapp"
      log_level :info
      max_connections 50
    end
    
    service :payment do
      base_url "https://api.stripe.com"
      api_key {:system, "STRIPE_KEY"}
      timeout 30_000
      retries 3
    end
    
    feature_flag :new_ui do
      enabled true
      rollout_percentage 25
    end
  end
  
  test "defines environments correctly" do
    environments = Info.environments(TestConfig)
    assert length(environments) == 2
    
    dev_env = Info.environment!(TestConfig, :development)
    assert dev_env.database_url == "postgresql://localhost:5432/test"
    assert dev_env.log_level == :debug
    assert dev_env.max_connections == 5
  end
  
  test "defines services correctly" do
    services = Info.services(TestConfig)
    assert length(services) == 1
    
    payment_service = Info.service!(TestConfig, :payment)
    assert payment_service.base_url == "https://api.stripe.com"
    assert payment_service.timeout == 30_000
    assert payment_service.retries == 3
  end
  
  test "defines feature flags correctly" do
    flags = Info.feature_flags(TestConfig)
    assert length(flags) == 1
    
    ui_flag = Info.feature_flag!(TestConfig, :new_ui)
    assert ui_flag.enabled == true
    assert ui_flag.rollout_percentage == 25
  end
  
  test "info helper functions work" do
    assert Info.feature_enabled?(TestConfig, :new_ui) == true
    assert Info.feature_rollout(TestConfig, :new_ui) == 25
    
    services_map = Info.services_map(TestConfig)
    assert Map.has_key?(services_map, :payment)
  end
end
```

### Validation Tests

```elixir
# test/my_app/config_dsl/validation_test.exs
defmodule MyApp.ConfigDsl.ValidationTest do
  use ExUnit.Case, async: true
  
  test "validates required environments" do
    assert_raise Spark.Error.DslError, ~r/Missing required environments/, fn ->
      defmodule InvalidConfig1 do
        use MyApp.ConfigDsl
        
        # Missing required environments
        environment :staging do
          database_url "postgresql://localhost:5432/test"
        end
      end
    end
  end
  
  test "validates database URLs" do
    assert_raise Spark.Error.DslError, ~r/Invalid database URLs/, fn ->
      defmodule InvalidConfig2 do
        use MyApp.ConfigDsl
        
        environment :development do
          database_url "invalid://bad-url"  # Invalid protocol
        end
        
        environment :test do
          database_url "postgresql://localhost:5432/test"
        end
        
        environment :production do
          database_url "postgresql://prod:5432/myapp"
        end
      end
    end
  end
  
  test "validates service URLs" do
    assert_raise Spark.Error.DslError, ~r/Invalid URLs in services/, fn ->
      defmodule InvalidConfig3 do
        use MyApp.ConfigDsl
        
        environment :development do
          database_url "postgresql://localhost:5432/test"
        end
        
        environment :test do
          database_url "postgresql://localhost:5432/test"
        end
        
        environment :production do
          database_url "postgresql://prod:5432/myapp"
        end
        
        service :api do
          base_url "ftp://invalid.com"  # Invalid protocol
        end
      end
    end
  end
  
  test "validates percentage values" do
    assert_raise Spark.Error.DslError, fn ->
      defmodule InvalidConfig4 do
        use MyApp.ConfigDsl
        
        environment :development do
          database_url "postgresql://localhost:5432/test"
        end
        
        environment :test do
          database_url "postgresql://localhost:5432/test"
        end
        
        environment :production do
          database_url "postgresql://prod:5432/myapp"
        end
        
        feature_flag :invalid do
          rollout_percentage 150  # Invalid: > 100
        end
      end
    end
  end
end
```

## Using Your DSL

### Real Application Usage

```elixir
# lib/my_app/config.ex
defmodule MyApp.Config do
  use MyApp.ConfigDsl
  
  environment :development do
    database_url "postgresql://localhost:5432/myapp_dev"
    redis_url "redis://localhost:6379/0"
    log_level :debug
    max_connections 10
  end
  
  environment :test do
    database_url "postgresql://localhost:5432/myapp_test"
    redis_url "redis://localhost:6379/1"
    log_level :warn
    max_connections 5
  end
  
  environment :production do
    database_url {:system, "DATABASE_URL"}
    redis_url {:system, "REDIS_URL"}
    log_level :info
    max_connections 100
  end
  
  service :payment_processor do
    base_url "https://api.stripe.com"
    api_key {:system, "STRIPE_SECRET_KEY"}
    timeout 30_000
    retries 3
  end
  
  service :email_service do
    base_url "https://api.sendgrid.com"
    api_key {:system, "SENDGRID_API_KEY"}
    timeout 15_000
    retries 2
  end
  
  feature_flag :new_checkout_flow do
    enabled false
    rollout_percentage 10
  end
  
  feature_flag :advanced_analytics do
    enabled true
    rollout_percentage 100
  end
end
```

### Runtime Configuration Access

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application
  
  alias MyApp.ConfigDsl.Info
  
  def start(_type, _args) do
    env = Application.get_env(:my_app, :environment, :development)
    
    # Get environment configuration
    env_config = Info.environment_config!(MyApp.Config, env)
    
    # Setup database connection
    database_url = resolve_value(env_config.database_url)
    
    # Setup services
    services = Info.services_map(MyApp.Config)
    
    children = [
      {MyApp.Repo, url: database_url},
      {MyApp.Cache, url: resolve_value(env_config.redis_url)},
      # Configure services based on DSL
      setup_services(services)
    ]
    
    Supervisor.start_link(children, strategy: :one_for_one)
  end
  
  defp resolve_value({:system, env_var}), do: System.get_env(env_var)
  defp resolve_value(value), do: value
  
  defp setup_services(services) do
    # Configure HTTP clients based on service definitions
    # ...
  end
end
```

### Feature Flag Usage

```elixir
# lib/my_app/feature_flags.ex
defmodule MyApp.FeatureFlags do
  alias MyApp.ConfigDsl.Info
  
  def enabled?(flag_name, user_id \\ nil) do
    if Info.feature_enabled?(MyApp.Config, flag_name) do
      rollout = Info.feature_rollout(MyApp.Config, flag_name)
      
      case rollout do
        100 -> true
        0 -> false
        percentage -> user_in_rollout?(user_id, percentage)
      end
    else
      false
    end
  end
  
  defp user_in_rollout?(nil, _percentage), do: false
  defp user_in_rollout?(user_id, percentage) do
    # Consistent hash-based rollout
    hash = :erlang.phash2(user_id, 100)
    hash < percentage
  end
end
```

## What You've Accomplished

Congratulations! You've built a complete, production-ready DSL that:

✅ **Validates configuration** at compile time  
✅ **Provides clear error messages** for invalid configurations  
✅ **Offers runtime introspection** for accessing configuration  
✅ **Supports environment-specific settings**  
✅ **Manages external service configurations**  
✅ **Handles feature flags with rollout percentages**  
✅ **Includes comprehensive tests**  
✅ **Follows Spark best practices**  

## Key Learnings

**Declarative Design**: Your DSL reads like configuration, not code.

**Compile-Time Safety**: Invalid configurations are caught before runtime.

**Domain Focus**: The DSL vocabulary matches the problem domain.

**Extensibility**: New entity types and validation rules can be added easily.

**Testing**: DSL behavior can be thoroughly tested.

## Next Steps

Now that you've mastered the basics, you can:

1. **Add Transformers** - Process configuration at compile time
2. **Create Extensions** - Build reusable DSL components  
3. **Enhance Validation** - Add more sophisticated business rules
4. **Generate Documentation** - Automatically document your configuration options
5. **Build More DSLs** - Apply these patterns to other domains

Your first DSL demonstrates the power of Spark's declarative approach. The same patterns you've learned here scale to much more complex domains and use cases.

*Every expert was once a beginner. Every pro was once an amateur. Every icon was once an unknown.*