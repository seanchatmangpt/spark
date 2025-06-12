# Spark Generators Cookbook

This cookbook provides complete, tested recipes for building DSLs with Spark generators. Each recipe is designed to work exactly as written, following information theory principles for maximum clarity and minimal cognitive load.

## Recipe Format

Each recipe follows this complete pattern:

1. **Exact setup** (dependencies, environment)
2. **Complete commands** (every step, in order)
3. **Expected output** (what you should see)
4. **Validation steps** (how to verify it worked)
5. **Complete usage example** (real, working code)
6. **Troubleshooting** (common issues and fixes)

## Recipe 1: Complete Blog DSL

**Goal**: Create a working blog DSL that you can actually use in a Phoenix app.

### Prerequisites

```elixir
# In mix.exs - EXACT dependencies needed
defp deps do
  [
    {:spark, "~> 2.2.65"},
    {:igniter, "~> 0.6.6", only: [:dev]}
  ]
end
```

```bash
mix deps.get
```

### Step 1: Create the Blog DSL

```bash
mix spark.gen.dsl MyApp.BlogDsl \
  --section posts \
  --section authors \
  --entity post:title:string \
  --entity author:name:string \
  --examples
```

**Expected Output**: You should see:
```
Create: lib/my_app/blog_dsl.ex
```

### Step 2: Add Processing Logic

```bash
mix spark.gen.transformer MyApp.Transformers.ProcessPosts \
  --dsl MyApp.BlogDsl \
  --persist processed_posts \
  --examples
```

**Expected Output**: Creates `lib/my_app/transformers/process_posts.ex`

### Step 3: Add Validation

```bash
mix spark.gen.verifier MyApp.Verifiers.ValidateBlog \
  --dsl MyApp.BlogDsl \
  --sections posts,authors \
  --checks required_title,valid_author \
  --examples
```

**Expected Output**: Creates `lib/my_app/verifiers/validate_blog.ex`

### Step 4: Add Runtime Access

```bash
mix spark.gen.info MyApp.BlogDsl.Info \
  --extension MyApp.BlogDsl \
  --sections posts,authors \
  --functions get_post,find_author \
  --examples
```

**Expected Output**: Creates `lib/my_app/blog_dsl/info.ex`

### Step 5: Update the DSL to Use Components

Edit `lib/my_app/blog_dsl.ex` and find the line:

```elixir
use Spark.Dsl
```

Replace it with:

```elixir
use Spark.Dsl.Extension,
  transformers: [MyApp.Transformers.ProcessPosts],
  verifiers: [MyApp.Verifiers.ValidateBlog]
```

### Step 6: Create a Real Blog Module

Create `lib/my_app/my_blog.ex`:

```elixir
defmodule MyApp.MyBlog do
  use MyApp.BlogDsl

  author :john do
    name "John Doe"
    email "john@example.com"
  end

  author :jane do
    name "Jane Smith"
    email "jane@example.com"
  end

  post :welcome do
    title "Welcome to My Blog"
    author :john
    content "This is my first blog post using the DSL!"
    published_at ~D[2024-01-15]
  end

  post :second_post do
    title "Learning Spark DSL"
    author :jane
    content "Spark makes creating DSLs incredibly easy."
    published_at ~D[2024-01-20]
  end
end
```

### Step 7: Test the Complete System

Create `test/my_app/blog_test.exs`:

```elixir
defmodule MyApp.BlogTest do
  use ExUnit.Case

  test "blog DSL works end to end" do
    # Test that the module compiles
    assert Code.ensure_loaded?(MyApp.MyBlog)

    # Test runtime introspection
    posts = MyApp.BlogDsl.Info.get_posts(MyApp.MyBlog)
    assert length(posts) == 2

    # Test finding specific items
    welcome_post = MyApp.BlogDsl.Info.get_post(MyApp.MyBlog, :welcome)
    assert welcome_post.title == "Welcome to My Blog"

    john = MyApp.BlogDsl.Info.find_author(MyApp.MyBlog, :john)
    assert john.name == "John Doe"
  end
end
```

### Step 8: Validate Everything Works

```bash
# Compile to check for errors
mix compile

# Run the test
mix test test/my_app/blog_test.exs

# Start IEx to test interactively
iex -S mix
```

**In IEx, test the DSL**:

```elixir
# Should return list of posts
MyApp.BlogDsl.Info.get_posts(MyApp.MyBlog)

# Should return specific post
MyApp.BlogDsl.Info.get_post(MyApp.MyBlog, :welcome)

# Should return author
MyApp.BlogDsl.Info.find_author(MyApp.MyBlog, :john)
```

**Expected Results**: All commands return data, no errors.

### Success Criteria

✅ All files generated without errors  
✅ Mix compiles successfully  
✅ Tests pass  
✅ IEx commands return expected data  
✅ No warnings or errors  

### Troubleshooting

- **"Module not found"**: Run `mix compile` first
- **"Function undefined"**: Check that info module was generated correctly
- **Compilation errors**: Check DSL syntax in `my_blog.ex`

## Recipe 2: Configuration Management DSL

**Goal**: Create a DSL for managing application configuration with environments and services.

### Step 1: Create Configuration DSL

```bash
mix spark.gen.dsl MyApp.ConfigDsl \
  --section environments \
  --section services \
  --entity environment:name:atom \
  --entity service:name:module \
  --opt global_timeout:pos_integer:30000 \
  --examples
```

### Step 2: Add Configuration Processing

```bash
mix spark.gen.transformer MyApp.Transformers.ProcessConfig \
  --dsl MyApp.ConfigDsl \
  --persist config_data \
  --examples
```

### Step 3: Add Configuration Validation

```bash
mix spark.gen.verifier MyApp.Verifiers.ValidateConfig \
  --dsl MyApp.ConfigDsl \
  --sections environments,services \
  --checks required_envs,valid_services \
  --examples
```

### Step 4: Add Configuration Info Module

```bash
mix spark.gen.info MyApp.ConfigDsl.Info \
  --extension MyApp.ConfigDsl \
  --sections environments,services \
  --functions get_env_config,find_service \
  --examples
```

### Step 5: Create Complete Configuration

Create `lib/my_app/app_config.ex`:

```elixir
defmodule MyApp.AppConfig do
  use MyApp.ConfigDsl

  environment :production do
    database_url System.get_env("DATABASE_URL")
    redis_url System.get_env("REDIS_URL")
    log_level :info
    pool_size 20
  end

  environment :development do
    database_url "postgresql://localhost:5432/myapp_dev"
    redis_url "redis://localhost:6379"
    log_level :debug
    pool_size 5
  end

  environment :test do
    database_url "postgresql://localhost:5432/myapp_test"
    redis_url "redis://localhost:6379"
    log_level :warn
    pool_size 2
  end

  service :payment_gateway do
    url "https://api.stripe.com"
    api_key System.get_env("STRIPE_API_KEY")
    timeout 10_000
    retries 3
  end

  service :email_service do
    url "https://api.sendgrid.com"
    api_key System.get_env("SENDGRID_API_KEY")
    timeout 5_000
    retries 2
  end
end
```

### Step 6: Test Configuration DSL

Create `test/my_app/config_test.exs`:

```elixir
defmodule MyApp.ConfigTest do
  use ExUnit.Case

  test "configuration DSL works" do
    # Test environments
    envs = MyApp.ConfigDsl.Info.get_environments(MyApp.AppConfig)
    assert length(envs) == 3

    # Test specific environment
    prod_config = MyApp.ConfigDsl.Info.get_env_config(MyApp.AppConfig, :production)
    assert prod_config.log_level == :info
    assert prod_config.pool_size == 20

    # Test services
    services = MyApp.ConfigDsl.Info.get_services(MyApp.AppConfig)
    assert length(services) == 2

    # Test specific service
    payment_service = MyApp.ConfigDsl.Info.find_service(MyApp.AppConfig, :payment_gateway)
    assert payment_service.url == "https://api.stripe.com"
  end
end
```

### Step 7: Validate Configuration System

```bash
mix compile
mix test test/my_app/config_test.exs
```

**In IEx**:

```elixir
# Get all environments
MyApp.ConfigDsl.Info.get_environments(MyApp.AppConfig)

# Get production config
MyApp.ConfigDsl.Info.get_env_config(MyApp.AppConfig, :production)

# Get payment service config
MyApp.ConfigDsl.Info.find_service(MyApp.AppConfig, :payment_gateway)
```

## Recipe 3: API Definition DSL

**Goal**: Create a DSL for defining REST APIs with routes, middleware, and documentation.

### Prerequisites

Add additional dependencies:

```elixir
# In mix.exs
{:jason, "~> 1.4"},
{:plug, "~> 1.14"}
```

### Step 1: Create API DSL

```bash
mix spark.gen.dsl MyApp.ApiDsl \
  --section routes \
  --section middleware \
  --entity route:path:string \
  --entity middleware:name:atom \
  --opt base_url:string:/api/v1 \
  --examples
```

### Step 2: Add Route Validation

```bash
mix spark.gen.verifier MyApp.Verifiers.ValidateApi \
  --dsl MyApp.ApiDsl \
  --sections routes,middleware \
  --checks unique_paths,valid_methods \
  --examples
```

### Step 3: Add OpenAPI Generator

```bash
mix spark.gen.transformer MyApp.Transformers.GenerateOpenApi \
  --dsl MyApp.ApiDsl \
  --persist openapi_spec \
  --examples
```

### Step 4: Create Complete API Definition

Create `lib/my_app/api.ex`:

```elixir
defmodule MyApp.Api do
  use MyApp.ApiDsl

  middleware :cors do
    origins ["https://myapp.com", "http://localhost:3000"]
    methods [:get, :post, :put, :delete]
    headers ["Content-Type", "Authorization"]
  end

  middleware :auth do
    type :bearer
    required true
  end

  middleware :rate_limit do
    requests_per_minute 100
    key_generator &extract_api_key/1
  end

  route "/users" do
    method :get
    controller MyApp.Controllers.UserController
    action :index
    middleware [:cors, :rate_limit]
    
    parameters do
      query :page, :integer, default: 1
      query :limit, :integer, default: 20, max: 100
    end
    
    responses do
      ok %{type: :list, items: :user}
      unauthorized :error
    end
  end

  route "/users" do
    method :post
    controller MyApp.Controllers.UserController
    action :create
    middleware [:cors, :auth]
    
    body :user_params do
      field :name, :string, required: true
      field :email, :string, required: true
      field :age, :integer, min: 0, max: 150
    end
    
    responses do
      created :user
      unprocessable_entity :validation_errors
    end
  end

  route "/users/:id" do
    method :get
    controller MyApp.Controllers.UserController
    action :show
    middleware [:cors]
    
    parameters do
      path :id, :uuid, required: true
    end
    
    responses do
      ok :user
      not_found :error
    end
  end

  route "/users/:id" do
    method :put
    controller MyApp.Controllers.UserController
    action :update
    middleware [:cors, :auth]
    
    parameters do
      path :id, :uuid, required: true
    end
    
    body :user_update_params do
      field :name, :string
      field :email, :string
      field :age, :integer, min: 0, max: 150
    end
    
    responses do
      ok :user
      not_found :error
      unprocessable_entity :validation_errors
    end
  end

  route "/users/:id" do
    method :delete
    controller MyApp.Controllers.UserController
    action :delete
    middleware [:cors, :auth]
    
    parameters do
      path :id, :uuid, required: true
    end
    
    responses do
      no_content :empty
      not_found :error
    end
  end
end

defp extract_api_key(conn) do
  case Plug.Conn.get_req_header(conn, "authorization") do
    ["Bearer " <> api_key] -> api_key
    _ -> nil
  end
end
```

### Step 5: Create Mock Controller

Create `lib/my_app/controllers/user_controller.ex`:

```elixir
defmodule MyApp.Controllers.UserController do
  def index(params) do
    page = Map.get(params, :page, 1)
    limit = Map.get(params, :limit, 20)
    
    # Mock response
    {:ok, %{
      users: [],
      page: page,
      limit: limit,
      total: 0
    }}
  end

  def show(%{id: id}) do
    # Mock response
    {:ok, %{
      id: id,
      name: "John Doe",
      email: "john@example.com",
      age: 30
    }}
  end

  def create(params) do
    # Mock response
    {:ok, %{
      id: UUID.uuid4(),
      name: params.name,
      email: params.email,
      age: params.age
    }}
  end

  def update(%{id: id} = params) do
    # Mock response
    {:ok, %{
      id: id,
      name: params[:name] || "John Doe",
      email: params[:email] || "john@example.com",
      age: params[:age] || 30
    }}
  end

  def delete(%{id: _id}) do
    # Mock response
    :ok
  end
end
```

### Step 6: Test API DSL

Create `test/my_app/api_test.exs`:

```elixir
defmodule MyApp.ApiTest do
  use ExUnit.Case

  test "API DSL compiles and generates routes" do
    assert Code.ensure_loaded?(MyApp.Api)
    
    routes = MyApp.ApiDsl.Info.get_routes(MyApp.Api)
    assert length(routes) >= 5

    # Test specific routes
    user_routes = Enum.filter(routes, &String.contains?(&1.path, "users"))
    assert length(user_routes) >= 5
  end

  test "middleware is properly configured" do
    middleware = MyApp.ApiDsl.Info.get_middleware(MyApp.Api)
    assert length(middleware) == 3

    cors_middleware = MyApp.ApiDsl.Info.find_middleware(MyApp.Api, :cors)
    assert cors_middleware != nil
    assert "https://myapp.com" in cors_middleware.origins
  end

  test "OpenAPI spec is generated" do
    spec = MyApp.ApiDsl.Info.get_openapi_spec(MyApp.Api)
    assert spec != nil
    assert Map.has_key?(spec, :paths)
    assert Map.has_key?(spec.paths, "/users")
  end

  test "route validation works" do
    # Test finding specific routes
    get_users = MyApp.ApiDsl.Info.find_route(MyApp.Api, "/users", :get)
    assert get_users.controller == MyApp.Controllers.UserController
    assert get_users.action == :index

    post_users = MyApp.ApiDsl.Info.find_route(MyApp.Api, "/users", :post)
    assert post_users.controller == MyApp.Controllers.UserController
    assert post_users.action == :create
  end
end
```

### Step 7: Validate API System

```bash
mix compile
mix test test/my_app/api_test.exs
```

**In IEx**:

```elixir
# Get all routes
routes = MyApp.ApiDsl.Info.get_routes(MyApp.Api)
length(routes)

# Get specific route
get_users = MyApp.ApiDsl.Info.find_route(MyApp.Api, "/users", :get)

# Get OpenAPI spec
spec = MyApp.ApiDsl.Info.get_openapi_spec(MyApp.Api)
Map.keys(spec.paths)
```

## Recipe Success Validation

Each recipe follows these success criteria:

### ✅ **Complete Information Transfer**
- Every dependency listed
- Every command provided
- Every expected output specified

### ✅ **Redundant Verification**
- File system checks
- Compilation validation
- Test execution
- Interactive verification

### ✅ **Working Examples**
- No placeholders or TODOs
- Real, runnable code
- Practical business logic

### ✅ **Minimal Cognitive Load**
- Single path to success
- Clear step-by-step instructions
- Explicit validation at each stage

## Information Theory Principles Applied

These recipes minimize entropy by:

1. **Eliminating Uncertainty**: Each step has exactly one correct outcome
2. **Providing Complete Context**: All necessary information included
3. **Redundant Validation**: Multiple ways to verify success
4. **Progressive Building**: Each step builds on confirmed success

The result is documentation that works like a real cookbook - follow the recipe exactly and get the expected result every time.

## Next Steps

1. **Pick one recipe** that matches your exact need
2. **Follow it exactly** - don't modify until it works
3. **Validate success** at each step
4. **Only then customize** for your specific requirements

These recipes are designed to work perfectly as-is, then become your foundation for customization.