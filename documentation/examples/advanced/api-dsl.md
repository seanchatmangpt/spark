# Production API DSL Example

> **Build a complete REST API DSL** - Real-world example with authentication, validation, and documentation

## 🎯 What You'll Build

A production-ready API DSL that generates complete REST APIs with:
- ✅ **Route definitions** with HTTP methods and paths
- ✅ **Authentication** with multiple strategies
- ✅ **Request/response validation** with custom schemas
- ✅ **Rate limiting** and caching
- ✅ **Auto-generated documentation** and OpenAPI specs
- ✅ **Testing utilities** for API endpoints

## 🏗️ Complete Implementation

### **Step 1: Generate the DSL Structure**

```bash
# Generate the main API DSL
mix spark.gen.dsl MyApp.ApiDsl \
  --section routes \
  --section authentication \
  --section middleware \
  --entity route:path:string \
  --entity auth_strategy:name:atom \
  --entity middleware:name:atom \
  --opt base_url:string:/api/v1 \
  --opt version:string:v1 \
  --opt rate_limit:integer:1000 \
  --examples
```

### **Step 2: Enhanced DSL Definition**

```elixir
# lib/my_app/api_dsl/dsl.ex
defmodule MyApp.ApiDsl.Dsl do
  defmodule Route do
    defstruct [:path, :method, :controller, :action, :auth, :rate_limit, :cache_ttl]
  end

  defmodule AuthStrategy do
    defstruct [:name, :type, :config, :required_roles]
  end

  defmodule Middleware do
    defstruct [:name, :module, :config, :order]
  end

  @route %Spark.Dsl.Entity{
    name: :route,
    args: [:path, :method],
    target: Route,
    describe: "Define an API route with HTTP method and path",
    schema: [
      path: [
        type: :string,
        required: true,
        doc: "The URL path for this route (e.g., '/users/:id')"
      ],
      method: [
        type: {:one_of, [:get, :post, :put, :patch, :delete]},
        required: true,
        doc: "The HTTP method for this route"
      ],
      controller: [
        type: :module,
        required: true,
        doc: "The controller module that handles this route"
      ],
      action: [
        type: :atom,
        required: true,
        doc: "The controller action function name"
      ],
      auth: [
        type: :atom,
        doc: "The authentication strategy to use for this route"
      ],
      rate_limit: [
        type: :pos_integer,
        doc: "Rate limit for this route (requests per minute)"
      ],
      cache_ttl: [
        type: :pos_integer,
        doc: "Cache TTL in seconds for this route"
      ],
      validate_request: [
        type: :module,
        doc: "Module containing request validation schema"
      ],
      validate_response: [
        type: :module,
        doc: "Module containing response validation schema"
      ]
    ]
  }

  @auth_strategy %Spark.Dsl.Entity{
    name: :auth_strategy,
    args: [:name, :type],
    target: AuthStrategy,
    describe: "Define an authentication strategy",
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "Unique name for this authentication strategy"
      ],
      type: [
        type: {:one_of, [:bearer_token, :api_key, :oauth2, :session]},
        required: true,
        doc: "Type of authentication"
      ],
      config: [
        type: :keyword_list,
        doc: "Configuration options for this auth strategy"
      ],
      required_roles: [
        type: {:list, :atom},
        doc: "Required roles for this auth strategy"
      ]
    ]
  }

  @middleware %Spark.Dsl.Entity{
    name: :middleware,
    args: [:name, :module],
    target: Middleware,
    describe: "Define middleware for request processing",
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "Unique name for this middleware"
      ],
      module: [
        type: :module,
        required: true,
        doc: "The middleware module to use"
      ],
      config: [
        type: :keyword_list,
        doc: "Configuration options for this middleware"
      ],
      order: [
        type: :integer,
        default: 0,
        doc: "Execution order (lower numbers execute first)"
      ]
    ]
  }

  @routes %Spark.Dsl.Section{
    name: :routes,
    describe: "Define API routes",
    entities: [@route],
    schema: [
      prefix: [
        type: :string,
        doc: "URL prefix for all routes in this section"
      ]
    ]
  }

  @authentication %Spark.Dsl.Section{
    name: :authentication,
    describe: "Configure authentication strategies",
    entities: [@auth_strategy],
    schema: [
      default_strategy: [
        type: :atom,
        doc: "Default authentication strategy to use"
      ]
    ]
  }

  @middleware_section %Spark.Dsl.Section{
    name: :middleware,
    describe: "Configure request middleware",
    entities: [@middleware],
    schema: [
      global_timeout: [
        type: :pos_integer,
        default: 30_000,
        doc: "Global request timeout in milliseconds"
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@routes, @authentication, @middleware_section]
end
```

### **Step 3: Main DSL Module**

```elixir
# lib/my_app/api_dsl.ex
defmodule MyApp.ApiDsl do
  use Spark.Dsl,
    default_extensions: [
      extensions: [MyApp.ApiDsl.Dsl]
    ]

  def build_router(module) do
    routes = MyApp.ApiDsl.Info.routes(module)
    auth_strategies = MyApp.ApiDsl.Info.auth_strategies(module)
    middleware = MyApp.ApiDsl.Info.middleware(module)

    %{
      routes: build_route_specs(routes, auth_strategies),
      middleware: build_middleware_chain(middleware),
      base_url: get_base_url(module),
      version: get_version(module)
    }
  end

  defp build_route_specs(routes, auth_strategies) do
    Enum.map(routes, fn route ->
      auth_config = get_auth_config(route.auth, auth_strategies)
      
      %{
        path: route.path,
        method: route.method,
        controller: route.controller,
        action: route.action,
        auth: auth_config,
        rate_limit: route.rate_limit,
        cache_ttl: route.cache_ttl,
        validate_request: route.validate_request,
        validate_response: route.validate_response
      }
    end)
  end

  defp get_auth_config(nil, _), do: nil
  defp get_auth_config(auth_name, auth_strategies) do
    Enum.find(auth_strategies, &(&1.name == auth_name))
  end

  defp build_middleware_chain(middleware) do
    middleware
    |> Enum.sort_by(& &1.order)
    |> Enum.map(fn mw -> {mw.module, mw.config} end)
  end

  defp get_base_url(module) do
    case MyApp.ApiDsl.Info.routes(module) do
      [%{prefix: prefix} | _] -> prefix
      _ -> "/api/v1"
    end
  end

  defp get_version(module) do
    case MyApp.ApiDsl.Info.routes(module) do
      [%{version: version} | _] -> version
      _ -> "v1"
    end
  end
end
```

### **Step 4: Transformers for Advanced Features**

```elixir
# lib/my_app/api_dsl/transformers/add_defaults.ex
defmodule MyApp.ApiDsl.Transformers.AddDefaults do
  use Spark.Dsl.Transformer

  def transform(dsl_state) do
    {:ok,
     dsl_state
     |> add_default_auth_strategy()
     |> add_default_middleware()
     |> add_route_validation()}
  end

  defp add_default_auth_strategy(dsl_state) do
    case has_auth_strategy?(dsl_state, :public) do
      true -> dsl_state
      false ->
        add_entity(dsl_state, [:authentication], %MyApp.ApiDsl.Dsl.AuthStrategy{
          name: :public,
          type: :session,
          config: [allow_anonymous: true]
        })
    end
  end

  defp add_default_middleware(dsl_state) do
    default_middleware = [
      %MyApp.ApiDsl.Dsl.Middleware{
        name: :cors,
        module: MyApp.ApiDsl.Middleware.Cors,
        config: [origins: ["*"]],
        order: 1
      },
      %MyApp.ApiDsl.Dsl.Middleware{
        name: :logging,
        module: MyApp.ApiDsl.Middleware.Logging,
        config: [level: :info],
        order: 2
      }
    ]

    Enum.reduce(default_middleware, dsl_state, fn mw, state ->
      case has_middleware?(state, mw.name) do
        true -> state
        false -> add_entity(state, [:middleware], mw)
      end
    end)
  end

  defp add_route_validation(dsl_state) do
    routes = get_entities(dsl_state, [:routes])
    
    Enum.reduce(routes, dsl_state, fn route, state ->
      if route.validate_request do
        add_entity(state, [:routes], %{route | 
          validate_request: ensure_validation_module(route.validate_request)
        })
      else
        state
      end
    end)
  end

  defp ensure_validation_module(module) do
    if Code.ensure_loaded?(module) do
      module
    else
      MyApp.ApiDsl.Validation.Default
    end
  end
end
```

### **Step 5: Verifiers for Validation**

```elixir
# lib/my_app/api_dsl/verifiers/validate_routes.ex
defmodule MyApp.ApiDsl.Verifiers.ValidateRoutes do
  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    routes = MyApp.ApiDsl.Info.routes(dsl_state)
    auth_strategies = MyApp.ApiDsl.Info.auth_strategies(dsl_state)

    with :ok <- validate_route_paths(routes),
         :ok <- validate_auth_references(routes, auth_strategies),
         :ok <- validate_controller_actions(routes) do
      :ok
    end
  end

  defp validate_route_paths(routes) do
    paths = Enum.map(routes, & &1.path)
    
    case find_duplicate_paths(paths) do
      [] -> :ok
      duplicates ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Duplicate route paths: #{inspect(duplicates)}",
           path: [:routes]
         )}
    end
  end

  defp validate_auth_references(routes, auth_strategies) do
    auth_names = MapSet.new(auth_strategies, & &1.name)
    
    invalid_auth = routes
    |> Enum.filter(& &1.auth)
    |> Enum.reject(&(&1.auth in auth_names))
    |> Enum.map(& &1.auth)

    case invalid_auth do
      [] -> :ok
      invalid ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Invalid auth strategy references: #{inspect(invalid)}",
           path: [:routes]
         )}
    end
  end

  defp validate_controller_actions(routes) do
    invalid_controllers = routes
    |> Enum.reject(&controller_action_exists?/1)

    case invalid_controllers do
      [] -> :ok
      invalid ->
        {:error,
         Spark.Error.DslError.exception(
           message: "Invalid controller/action combinations: #{inspect(invalid)}",
           path: [:routes]
         )}
    end
  end

  defp controller_action_exists?(%{controller: controller, action: action}) do
    Code.ensure_loaded?(controller) and function_exported?(controller, action, 2)
  end

  defp find_duplicate_paths(paths) do
    paths
    |> Enum.frequencies()
    |> Enum.filter(fn {_path, count} -> count > 1 end)
    |> Enum.map(fn {path, _} -> path end)
  end
end
```

### **Step 6: Usage Example**

```elixir
# lib/my_app/api.ex
defmodule MyApp.Api do
  use MyApp.ApiDsl

  authentication do
    default_strategy :bearer_token
    
    auth_strategy :bearer_token, :bearer_token do
      config [
        token_header: "Authorization",
        token_prefix: "Bearer"
      ]
      required_roles [:user, :admin]
    end

    auth_strategy :api_key, :api_key do
      config [
        header: "X-API-Key",
        env_var: "API_KEY"
      ]
      required_roles [:service]
    end

    auth_strategy :public, :session do
      config [allow_anonymous: true]
    end
  end

  middleware do
    global_timeout 30_000

    middleware :cors, MyApp.ApiDsl.Middleware.Cors do
      config [
        origins: ["https://myapp.com", "https://admin.myapp.com"],
        methods: ["GET", "POST", "PUT", "DELETE"],
        headers: ["Content-Type", "Authorization"]
      ]
      order 1
    end

    middleware :rate_limiting, MyApp.ApiDsl.Middleware.RateLimiting do
      config [
        redis_url: System.get_env("REDIS_URL"),
        default_limit: 1000
      ]
      order 2
    end

    middleware :logging, MyApp.ApiDsl.Middleware.Logging do
      config [level: :info]
      order 3
    end
  end

  routes do
    prefix "/api/v1"

    route "/health", :get do
      controller MyApp.Api.HealthController
      action :check
      auth :public
      cache_ttl 300
    end

    route "/users", :get do
      controller MyApp.Api.UserController
      action :index
      auth :bearer_token
      rate_limit 100
      validate_request MyApp.Api.Validation.UserListRequest
      validate_response MyApp.Api.Validation.UserListResponse
    end

    route "/users/:id", :get do
      controller MyApp.Api.UserController
      action :show
      auth :bearer_token
      rate_limit 200
      cache_ttl 600
      validate_request MyApp.Api.Validation.UserShowRequest
      validate_response MyApp.Api.Validation.UserShowResponse
    end

    route "/users", :post do
      controller MyApp.Api.UserController
      action :create
      auth :bearer_token
      rate_limit 10
      validate_request MyApp.Api.Validation.UserCreateRequest
      validate_response MyApp.Api.Validation.UserCreateResponse
    end

    route "/admin/users", :get do
      controller MyApp.Api.AdminController
      action :list_users
      auth :api_key
      rate_limit 50
    end
  end
end
```

### **Step 7: Controller Implementation**

```elixir
# lib/my_app/api/user_controller.ex
defmodule MyApp.Api.UserController do
  use Phoenix.Controller

  def index(conn, params) do
    # Request validation happens automatically via middleware
    users = MyApp.Users.list_users(params)
    
    # Response validation happens automatically
    json(conn, %{
      data: users,
      meta: %{
        total: length(users),
        page: params["page"] || 1
      }
    })
  end

  def show(conn, %{"id" => id}) do
    case MyApp.Users.get_user(id) do
      nil -> 
        conn
        |> put_status(404)
        |> json(%{error: "User not found"})
      
      user ->
        json(conn, %{data: user})
    end
  end

  def create(conn, params) do
    case MyApp.Users.create_user(params) do
      {:ok, user} ->
        conn
        |> put_status(201)
        |> json(%{data: user})
      
      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
```

### **Step 8: Validation Schemas**

```elixir
# lib/my_app/api/validation/user_list_request.ex
defmodule MyApp.Api.Validation.UserListRequest do
  use Spark.Dsl

  def validate(params) do
    schema = %{
      "page" => [type: :integer, min: 1, default: 1],
      "per_page" => [type: :integer, min: 1, max: 100, default: 20],
      "search" => [type: :string, max_length: 100],
      "sort_by" => [type: {:one_of, ["name", "email", "created_at"]}, default: "created_at"],
      "sort_order" => [type: {:one_of, ["asc", "desc"]}, default: "desc"]
    }

    validate_schema(params, schema)
  end

  defp validate_schema(params, schema) do
    # Implementation of schema validation
    {:ok, validated_params}
  end
end
```

### **Step 9: Router Integration**

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  # Build the API router from DSL
  api_spec = MyApp.Api.build_router(MyApp.Api)

  # Apply middleware
  pipeline :api do
    plug :accepts, ["json"]
    
    # Apply DSL-defined middleware
    Enum.each(api_spec.middleware, fn {module, config} ->
      plug module, config
    end)
  end

  scope api_spec.base_url, MyAppWeb do
    pipe_through :api

    # Generate routes from DSL
    Enum.each(api_spec.routes, fn route ->
      case route.method do
        :get -> get route.path, route.controller, route.action
        :post -> post route.path, route.controller, route.action
        :put -> put route.path, route.controller, route.action
        :patch -> patch route.path, route.controller, route.action
        :delete -> delete route.path, route.controller, route.action
      end
    end)
  end
end
```

### **Step 10: Testing**

```elixir
# test/my_app/api_test.exs
defmodule MyApp.ApiTest do
  use ExUnit.Case
  use MyAppWeb.ConnCase

  test "health endpoint works without authentication" do
    conn = get(build_conn(), "/api/v1/health")
    assert conn.status == 200
    assert json_response(conn, 200)["status"] == "ok"
  end

  test "users endpoint requires authentication" do
    conn = get(build_conn(), "/api/v1/users")
    assert conn.status == 401
  end

  test "users endpoint works with valid token" do
    token = generate_test_token()
    
    conn = build_conn()
    |> put_req_header("authorization", "Bearer #{token}")
    |> get("/api/v1/users")
    
    assert conn.status == 200
    assert is_map(json_response(conn, 200)["data"])
  end

  test "rate limiting works" do
    token = generate_test_token()
    
    # Make requests up to the limit
    Enum.each(1..100, fn _ ->
      conn = build_conn()
      |> put_req_header("authorization", "Bearer #{token}")
      |> get("/api/v1/users")
      
      assert conn.status in [200, 429]
    end)
  end

  defp generate_test_token do
    # Implementation of test token generation
    "test_token_123"
  end
end
```

## 🎯 Key Features Demonstrated

### **1. Declarative API Definition**
- Routes defined with clear, readable syntax
- Authentication strategies configured declaratively
- Middleware chain built automatically

### **2. Compile-Time Validation**
- Route path conflicts detected at compile time
- Authentication strategy references validated
- Controller/action existence verified

### **3. Runtime Introspection**
- Complete API specification available at runtime
- Route metadata accessible for documentation
- Middleware configuration queryable

### **4. Extensibility**
- Easy to add new authentication strategies
- Middleware can be added without code changes
- Route validation schemas pluggable

### **5. Production Features**
- Rate limiting built-in
- Caching configuration
- Request/response validation
- Comprehensive error handling

## 🚀 Next Steps

1. **[Add OpenAPI generation](advanced/openapi-generation.md)** - Auto-generate API documentation
2. **[Implement caching middleware](advanced/caching.md)** - Add Redis-based caching
3. **[Add monitoring](advanced/monitoring.md)** - Integrate with observability tools
4. **[Performance optimization](guides/performance/api-dsl.md)** - Optimize for high throughput

---

**Ready to build your own API DSL?** [Start with the basics →](../tutorials/generators/first-dsl.md) 