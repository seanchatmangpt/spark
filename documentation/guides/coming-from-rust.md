# Coming from Rust: Your First Elixir DSL with Spark

## Welcome, Rust Developer! 🦀 → 🧪

If you're coming from Rust, you already understand the value of type safety, pattern matching, and functional programming. Spark DSL and Ash bring many of Rust's compile-time guarantees to the domain of configuration management and API generation, but with the added benefits of hot code reloading, fault tolerance, and distributed systems built-in.

## The Mental Model Bridge

### Rust vs Elixir: Shared Values, Different Approaches

```rust
// Rust: Compile-time safety through ownership & borrowing
struct UserConfig {
    permissions: Vec<String>,
    settings: HashMap<String, String>,
}

impl UserConfig {
    fn add_permission(&mut self, perm: String) {
        self.permissions.push(perm);  // Moves ownership
    }
    
    fn validate(&self) -> Result<(), ConfigError> {
        if self.permissions.is_empty() {
            Err(ConfigError::NoPermissions)
        } else {
            Ok(())
        }
    }
}
```

```elixir
# Elixir: Runtime safety through immutability & pattern matching
defmodule UserConfig do
  # Pattern matching for control flow (like Rust's match)
  def validate_permissions([]), do: {:error, :no_permissions}
  def validate_permissions(perms), do: {:ok, perms}
  
  # Immutable data transformation (like Rust's functional style)
  def add_permission(permissions, new_perm) do
    [new_perm | permissions]  # Returns new list, no borrowing needed
  end
end
```

**Key Similarities:**
- ✅ **Pattern matching** - Both languages excel at this
- ✅ **Immutable data** - Default in Elixir, encouraged in Rust
- ✅ **Functional programming** - Both support functional paradigms
- ✅ **Type safety** - Rust at compile-time, Elixir through specs/dialyzer

**Key Differences:**
- 🔄 **Memory management** - Rust: ownership/borrowing, Elixir: garbage collection
- 🔄 **Error handling** - Rust: `Result<T, E>`, Elixir: `{:ok, value} | {:error, reason}`
- 🔄 **Concurrency** - Rust: threads + async, Elixir: actor model + lightweight processes

## What You Already Know (Rust → Elixir Mappings)

### Pattern Matching & Enums
```rust
// Rust: Pattern matching on enums
enum ApiResponse {
    Success(User),
    NotFound,
    ServerError(String),
}

match response {
    ApiResponse::Success(user) => process_user(user),
    ApiResponse::NotFound => handle_not_found(),
    ApiResponse::ServerError(msg) => log_error(msg),
}
```

```elixir
# Elixir: Pattern matching on tuples/atoms (very similar!)
# Common return pattern: {:ok, value} | {:error, reason}
case api_response do
  {:ok, user} -> process_user(user)
  {:error, :not_found} -> handle_not_found()
  {:error, {:server_error, msg}} -> log_error(msg)
end
```

### Option/Result Types
```rust
// Rust: Option and Result types
fn find_user(id: u32) -> Option<User> {
    users.iter().find(|u| u.id == id).cloned()
}

fn parse_config(data: &str) -> Result<Config, ParseError> {
    serde_json::from_str(data)
        .map_err(|e| ParseError::Json(e))
}
```

```elixir
# Elixir: Similar patterns with tuples
def find_user(users, id) do
  case Enum.find(users, &(&1.id == id)) do
    nil -> {:error, :not_found}
    user -> {:ok, user}
  end
end

def parse_config(data) do
  case Jason.decode(data) do
    {:ok, parsed} -> {:ok, parsed}
    {:error, reason} -> {:error, {:parse_error, reason}}
  end
end
```

### Structs and Data
```rust
// Rust: Structs with methods
#[derive(Debug, Clone)]
struct User {
    id: u32,
    email: String,
    name: String,
}

impl User {
    fn new(id: u32, email: String, name: String) -> Self {
        User { id, email, name }
    }
    
    fn is_valid(&self) -> bool {
        self.email.contains('@')
    }
}
```

```elixir
# Elixir: Structs with functions in modules
defmodule User do
  defstruct [:id, :email, :name]
  
  def new(id, email, name) do
    %User{id: id, email: email, name: name}
  end
  
  def valid?(%User{email: email}) do
    String.contains?(email, "@")
  end
end
```

### Collections and Iterators
```rust
// Rust: Iterator chains
let adults: Vec<_> = users
    .iter()
    .filter(|u| u.age >= 18)
    .map(|u| &u.name)
    .collect();

let total: u32 = prices
    .iter()
    .sum();
```

```elixir
# Elixir: Enum module (similar to Rust iterators)
adults = 
  users
  |> Enum.filter(&(&1.age >= 18))
  |> Enum.map(& &1.name)

total = Enum.sum(prices)
```

## Your First Spark DSL: Type-Safe Configuration

### The Problem You Know from Rust Config Files

```rust
// Rust: Using serde for configuration
use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Serialize)]
struct DatabaseConfig {
    host: String,
    port: u16,
    name: String,
}

#[derive(Debug, Deserialize, Serialize)]
struct Permission {
    action: String,
    resource: String,
}

#[derive(Debug, Deserialize, Serialize)]
struct AppConfig {
    database: DatabaseConfig,
    permissions: Vec<Permission>,
    debug: bool,
}

// Manual validation (tedious and error-prone)
impl AppConfig {
    fn validate(&self) -> Result<(), ConfigError> {
        if self.database.port < 1024 {
            return Err(ConfigError::InvalidPort);
        }
        if self.permissions.is_empty() {
            return Err(ConfigError::NoPermissions);
        }
        // ... more validation logic
        Ok(())
    }
}
```

### The Spark DSL Solution (Compile-Time Validation)

```elixir
defmodule MyApp.Config do
  use Spark.Dsl

  dsl do
    section :database do
      entity :connection do
        attribute :host, :string, required: true
        attribute :port, :integer, required: true, default: 5432
        attribute :name, :string, required: true
        
        # Custom validation (like Rust's custom derive)
        validate {MyApp.Validators, :validate_port}
      end
    end

    section :permissions do
      entity :permission do
        attribute :action, :atom, required: true
        attribute :resource, :string, required: true
      end
    end

    section :features do
      entity :feature do
        attribute :name, :atom, required: true
        attribute :enabled, :boolean, default: false
      end
    end
  end
end

defmodule MyApp.Validators do
  def validate_port(changeset) do
    case Ecto.Changeset.get_field(changeset, :port) do
      port when port < 1024 -> 
        Ecto.Changeset.add_error(changeset, :port, "must be >= 1024")
      _ -> 
        changeset
    end
  end
end

# Usage: Compile-time validated configuration
defmodule MyApp.ProductionConfig do
  use MyApp.Config

  database do
    connection do
      host "prod-db.example.com"
      port 5432  # Validated at compile time!
      name "myapp_prod"
    end
  end

  permissions do
    permission do
      action :read      # Atom, not string - type safe!
      resource "users"
    end
    
    permission do
      action :write
      resource "posts"
    end
  end
end
```

**What You Gained (vs Rust config crates):**
- ✅ **Compile-time validation** - Like Rust's type system but for config
- ✅ **DSL syntax** - More readable than TOML/JSON
- ✅ **Introspection** - Query config structure at runtime
- ✅ **Hot reloading** - Change config without restart (unlike Rust)
- ✅ **Zero boilerplate** - No manual serialization/deserialization

## Comparing with Rust Ecosystem Tools

### Instead of Serde + Validation
```rust
// Rust: Serde + validator crate
use serde::{Deserialize, Serialize};
use validator::{Validate, ValidationError};

#[derive(Debug, Deserialize, Serialize, Validate)]
struct DatabaseConfig {
    #[validate(length(min = 1))]
    host: String,
    
    #[validate(range(min = 1024, max = 65535))]
    port: u16,
    
    #[validate(length(min = 1))]
    name: String,
}

// Runtime validation
let config: DatabaseConfig = toml::from_str(&config_string)?;
config.validate()?;  // Can fail at runtime
```

```elixir
# Spark DSL: Validation built into schema definition
defmodule MyApp.Config do
  use Spark.Dsl

  dsl do
    section :database do
      entity :connection do
        attribute :host, :string, 
          required: true,
          constraints: [min_length: 1]
        
        attribute :port, :integer,
          required: true,
          constraints: [min: 1024, max: 65535]
        
        attribute :name, :string,
          required: true, 
          constraints: [min_length: 1]
      end
    end
  end
end

# Validation happens at compile time - no runtime failures!
```

### Instead of Clap for CLI Configuration
```rust
// Rust: Clap for command-line interfaces
use clap::{Arg, App, SubCommand};

let matches = App::new("myapp")
    .version("1.0")
    .about("My application")
    .arg(Arg::with_name("config")
        .short("c")
        .long("config")
        .value_name("FILE")
        .help("Sets a custom config file")
        .takes_value(true))
    .subcommand(SubCommand::with_name("server")
        .about("Start the server")
        .arg(Arg::with_name("port")
            .short("p")
            .long("port")
            .value_name("PORT")
            .help("Port to bind to")))
    .get_matches();
```

```elixir
# Spark DSL can generate CLI interfaces too
defmodule MyApp.CLI do
  use Spark.Dsl

  dsl do
    section :commands do
      entity :command do
        attribute :name, :atom, required: true
        attribute :description, :string, required: true
        attribute :args, {:array, :string}, default: []
        attribute :options, {:array, :string}, default: []
      end
    end
  end
end

defmodule MyApp.CLIConfig do
  use MyApp.CLI

  commands do
    command do
      name :server
      description "Start the server"
      options ["--port", "--config"]
    end
    
    command do
      name :migrate
      description "Run database migrations"
      args ["direction"]
    end
  end
end

# Auto-generate CLI parser from DSL
# Mix tasks, help text, validation all generated
```

### Instead of Actix-web Route Macros
```rust
// Rust: Actix-web with manual route definition
use actix_web::{web, App, HttpServer, Result, HttpResponse};

#[derive(serde::Deserialize)]
struct CreateUser {
    email: String,
    name: String,
}

async fn create_user(user: web::Json<CreateUser>) -> Result<HttpResponse> {
    // Manual validation
    if !user.email.contains('@') {
        return Ok(HttpResponse::BadRequest().json("Invalid email"));
    }
    
    // Manual database interaction
    let new_user = User::create(&user.email, &user.name).await?;
    Ok(HttpResponse::Created().json(new_user))
}

async fn get_users() -> Result<HttpResponse> {
    let users = User::find_all().await?;
    Ok(HttpResponse::Ok().json(users))
}

// Manual route registration
fn configure_routes(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::resource("/users")
            .route(web::get().to(get_users))
            .route(web::post().to(create_user))
    );
}
```

```elixir
# Elixir: Ash Resource - generates everything automatically
defmodule MyApp.User do
  use Ash.Resource, 
    domain: MyApp.Domain,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    attribute :email, :string, allow_nil?: false
    attribute :name, :string, allow_nil?: false
    timestamps()
  end

  validations do
    validate format(:email, ~r/@/, message: "Invalid email")
  end

  actions do
    defaults [:create, :read, :update, :destroy]
  end
end

# Phoenix router - one line gives you full REST API
defmodule MyAppWeb.Router do
  scope "/api" do
    ash_resources [MyApp.User]  # Generates all CRUD endpoints
  end
end

# Auto-generated:
# GET    /users      (with pagination, filtering, sorting)
# POST   /users      (with validation, error handling)
# GET    /users/:id  (with error handling)
# PATCH  /users/:id  (with validation)
# DELETE /users/:id  (with soft delete support)
```

## Installation and Setup

### 1. Install Elixir (Similar to Installing Rust)
```bash
# macOS (like 'brew install rust')
brew install elixir

# Ubuntu/Debian
apt install elixir

# Windows - Download from https://elixir-lang.org/install.html

# Verify installation
elixir --version
```

### 2. Create Your First Project
```bash
# Like 'cargo new myapp'
mix new myapp
cd myapp

# Edit dependencies (like Cargo.toml)
```

Edit `mix.exs` (similar to `Cargo.toml`):
```elixir
defp deps do
  [
    {:spark, "~> 2.0"},
    {:ash, "~> 3.0"},
    {:ash_postgres, "~> 2.0"},   # Like tokio-postgres
    {:ecto_sql, "~> 3.0"},       # Like diesel ORM
    {:jason, "~> 1.0"},          # Like serde_json
    {:ex_doc, "~> 0.28", only: :dev}  # Like rustdoc
  ]
end
```

```bash
# Install dependencies (like 'cargo build')
mix deps.get
```

### 3. Your First DSL Module
Create `lib/myapp/resource_config.ex`:
```elixir
defmodule MyApp.ResourceConfig do
  use Spark.Dsl

  dsl do
    section :resources do
      entity :resource do
        attribute :name, :atom, required: true
        attribute :permissions, {:array, :atom}, default: []
        attribute :rate_limit, :integer, default: 1000
        attribute :cache_ttl, :integer, default: 300
      end
    end
  end
end
```

Create `lib/myapp/api_resources.ex`:
```elixir
defmodule MyApp.ApiResources do
  use MyApp.ResourceConfig

  resources do
    resource do
      name :users
      permissions [:read, :write]
      rate_limit 500
      cache_ttl 600
    end

    resource do
      name :posts
      permissions [:read, :write, :delete]
      rate_limit 1000
    end
  end
end
```

### 4. Test It Works
```bash
# Start interactive Elixir (like 'cargo run' in REPL mode)
iex -S mix

# Query your configuration
iex> MyApp.ApiResources.resources()
[
  %{name: :users, permissions: [:read, :write], rate_limit: 500, cache_ttl: 600},
  %{name: :posts, permissions: [:read, :write, :delete], rate_limit: 1000, cache_ttl: 300}
]
```

## Memory Safety and Performance

### Rust vs Elixir: Different Safety Guarantees

```rust
// Rust: Compile-time memory safety through ownership
fn process_users(mut users: Vec<User>) -> Vec<User> {
    users.retain(|u| u.active);  // Mutates in place, no GC needed
    users.sort_by_key(|u| u.created_at);
    users  // Ownership transferred
}

// Zero-cost abstractions, predictable performance
let result: u64 = data
    .iter()
    .filter(|&&x| x > 10)
    .map(|&x| x as u64)
    .sum();  // Compiles to tight loop, no allocations
```

```elixir
# Elixir: Runtime safety through immutability + process isolation
def process_users(users) do
  users
  |> Enum.filter(& &1.active)
  |> Enum.sort_by(& &1.created_at)
  # Returns new list, original unchanged
  # GC handles memory, processes are isolated
end

# Concurrent by default, fault-tolerant
users
|> Task.async_stream(&process_user/1, max_concurrency: 10)
|> Enum.map(fn {:ok, result} -> result end)
```

**Trade-offs:**
- **Rust**: Faster execution, zero-cost abstractions, compile-time safety
- **Elixir**: Simpler concurrency, fault tolerance, hot code reloading

### When to Choose Each
```rust
// Rust: Choose for CPU-intensive, performance-critical code
// Game engines, system programming, embedded systems
fn matrix_multiply(a: &Matrix, b: &Matrix) -> Matrix {
    // Optimized tight loops, no GC pauses
}
```

```elixir
# Elixir: Choose for distributed systems, high availability
# Web services, IoT backends, real-time systems
defmodule GameServer do
  use GenServer
  
  # Handles thousands of concurrent game sessions
  # Self-healing, hot-swappable code
  def handle_call({:move, player, position}, _from, state) do
    # Game logic here
  end
end
```

## Testing Your DSL (Like Rust Tests)

```rust
// Rust: Unit tests with cargo test
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_config_validation() {
        let config = AppConfig {
            database: DatabaseConfig {
                host: "localhost".to_string(),
                port: 5432,
                name: "test".to_string(),
            },
            permissions: vec![],
            debug: true,
        };
        
        assert!(config.validate().is_err());
    }
}
```

```elixir
# Elixir: ExUnit tests (similar to Rust's test framework)
defmodule MyApp.ResourceConfigTest do
  use ExUnit.Case

  test "resource configuration validation" do
    # Test DSL compilation
    resources = MyApp.ApiResources.resources()
    
    user_resource = Enum.find(resources, &(&1.name == :users))
    assert user_resource.rate_limit == 500
    assert :read in user_resource.permissions
  end
  
  test "invalid configuration fails at compile time" do
    # This would be caught during compilation, not runtime
    assert_raise Spark.Error.DslError, fn ->
      defmodule InvalidConfig do
        use MyApp.ResourceConfig
        
        resources do
          resource do
            # Missing required 'name' attribute - compile error!
            permissions [:read]
          end
        end
      end
    end
  end
end
```

```bash
# Run tests (like 'cargo test')
mix test
```

## Advanced: Fault Tolerance (Rust's Result vs Elixir's Supervisors)

### Rust: Explicit Error Handling
```rust
// Rust: Manual error propagation with Result
fn fetch_user_data(id: u32) -> Result<UserData, AppError> {
    let user = database::find_user(id)?;
    let profile = api::fetch_profile(&user.email)?;
    let preferences = cache::get_preferences(id)?;
    
    Ok(UserData {
        user,
        profile, 
        preferences,
    })
}

// Handle errors explicitly at each call site
match fetch_user_data(123) {
    Ok(data) => process_data(data),
    Err(AppError::Database(e)) => log_db_error(e),
    Err(AppError::Network(e)) => retry_later(e),
    Err(AppError::Cache(e)) => use_default_preferences(),
}
```

### Elixir: Supervisor Trees (Let It Crash Philosophy)
```elixir
# Elixir: Fault-tolerant by design with supervisor trees
defmodule MyApp.UserWorker do
  use GenServer
  
  def fetch_user_data(id) do
    # If any of these crash, supervisor restarts the process
    user = Database.find_user!(id)
    profile = API.fetch_profile!(user.email)  
    preferences = Cache.get_preferences!(id)
    
    %UserData{
      user: user,
      profile: profile,
      preferences: preferences
    }
  end
  
  # GenServer automatically handles crashes and restarts
end

defmodule MyApp.Supervisor do
  use Supervisor
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  def init(_init_arg) do
    children = [
      {MyApp.UserWorker, []},
      {MyApp.Database, []},
      {MyApp.Cache, []},
    ]
    
    # If any worker crashes, restart it automatically
    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

## Performance Patterns

### Rust: Zero-Cost Abstractions
```rust
// Rust: Compile-time optimizations
fn sum_positive_numbers(numbers: &[i32]) -> i32 {
    numbers
        .iter()
        .filter(|&&x| x > 0)
        .sum()  // Compiles to efficient loop, no intermediate allocations
}
```

### Elixir: Process-Level Concurrency
```elixir
# Elixir: Concurrent processing with lightweight processes
def sum_positive_numbers(numbers) do
  numbers
  |> Task.async_stream(fn x -> if x > 0, do: x, else: 0 end)
  |> Enum.reduce(0, fn {:ok, x}, acc -> acc + x end)
end

# Or for CPU-intensive work, use all cores
def parallel_map(collection, func) do
  collection
  |> Task.async_stream(func, max_concurrency: System.schedulers_online())
  |> Enum.map(fn {:ok, result} -> result end)
end
```

## Common Gotchas for Rust Developers

### 1. No Ownership/Borrowing (Everything is Copied/Garbage Collected)
```elixir
# This creates new data structures, doesn't move ownership
list = [1, 2, 3]
new_list = [0 | list]  # list is still [1, 2, 3], new_list is [0, 1, 2, 3]

user = %{name: "Alice", age: 30}
updated_user = %{user | age: 31}  # user is unchanged, updated_user is new
```

### 2. Pattern Matching is More Flexible Than Rust's
```elixir
# Can match on values, not just structure
case http_response do
  {:ok, %{status: 200, body: body}} -> parse_success(body)
  {:ok, %{status: 404}} -> handle_not_found()
  {:ok, %{status: status}} when status >= 500 -> handle_server_error()
  {:error, %{reason: :timeout}} -> retry_request()
end
```

### 3. Dynamic Typing (But Use Typespecs for Documentation)
```elixir
# Elixir is dynamically typed, but you can add type annotations
@spec calculate_total([%{price: number()}]) :: number()
def calculate_total(items) do
  Enum.sum_by(items, & &1.price)
end

# Use Dialyzer for static analysis (like Rust's type checker)
# mix dialyzer
```

### 4. Different Error Handling Philosophy
```elixir
# Elixir: "Let it crash" - don't handle every error
def risky_operation do
  # If this fails, let the process crash and restart
  Database.critical_operation!()
end

# vs. defensive programming for expected errors
def user_operation(user_id) do
  case Users.find(user_id) do
    {:ok, user} -> process_user(user)
    {:error, :not_found} -> {:error, "User not found"}
  end
end
```

## Migration Path: Gradual Adoption

### Start with Configuration Management
```elixir
# Replace your TOML/JSON config with a DSL
defmodule MyApp.ServiceConfig do
  use Spark.Dsl
  
  dsl do
    section :services do
      entity :service do
        attribute :name, :atom, required: true
        attribute :endpoint, :string, required: true
        attribute :timeout_ms, :integer, default: 5000
        attribute :retries, :integer, default: 3
      end
    end
  end
end
```

### Then Add API Generation
```elixir
# Replace manual REST API code with Ash resources
defmodule MyApp.User do
  use Ash.Resource, domain: MyApp.Domain
  
  # Automatically generates CRUD operations
  attributes do
    uuid_primary_key :id
    attribute :email, :string, allow_nil?: false
  end
  
  actions do
    defaults [:create, :read, :update, :destroy]
  end
end
```

### Finally, Build Complex DSLs
```elixir
# Create domain-specific languages for your business logic
defmodule MyApp.WorkflowDSL do
  use Spark.Dsl
  
  # Define workflows declaratively instead of imperative code
end
```

## Next Steps

1. **Read the [Ash Getting Started Guide](https://ash-hq.org/docs/guides/ash/latest/tutorials/get-started.html)** - Auto-generated APIs
2. **Try [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/installation.html)** - Real-time web interfaces
3. **Explore [OTP Design Principles](https://elixir-lang.org/getting-started/mix-otp/introduction-to-mix.html)** - Fault-tolerant systems
4. **Join the [Elixir Forum](https://elixirforum.com/)** - Active community with many ex-Rust developers

## Resources for Rust Developers

- **[Elixir for Rust Developers](https://elixir-lang.org/getting-started/introduction.html)**
- **[Pattern Matching Comparison](https://elixirschool.com/en/lessons/basics/pattern_matching/)**
- **[Concurrency vs Parallelism in Elixir](https://elixir-lang.org/getting-started/processes.html)**
- **[Fault Tolerance with OTP](https://elixir-lang.org/getting-started/mix-otp/supervisor-and-application.html)**

Remember: You're not losing Rust's safety guarantees - you're trading compile-time safety for runtime resilience and hot code reloading. The pattern matching, functional programming, and type thinking you know from Rust will serve you well in Elixir! 🦀➡️🧪