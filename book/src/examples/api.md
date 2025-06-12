# API Definition DSL

> *"Good API design is like good architecture. It looks obvious in retrospect, but requires deep thought and multiple iterations to achieve."* - Anonymous

This chapter demonstrates building a sophisticated API definition DSL that generates OpenAPI specifications, handles authentication, manages middleware, and provides type-safe route definitions—all while maintaining the clarity and expressiveness that makes DSLs powerful.

## Problem Domain: REST API Complexity

Modern REST APIs involve complex concerns:

**Route Management**: Hundreds of endpoints with different HTTP methods, parameters, and responses
**Authentication**: Multiple auth strategies (JWT, API keys, OAuth) with different requirements per endpoint
**Middleware**: Cross-cutting concerns like rate limiting, CORS, logging, validation
**Documentation**: OpenAPI specs that stay synchronized with actual implementation
**Validation**: Request/response validation with clear error messages
**Versioning**: API evolution without breaking existing clients

Traditional approaches scatter these concerns across multiple files and systems, making maintenance difficult and consistency elusive.

## DSL Vision

Our API DSL should enable developers to express complex API designs declaratively:

```elixir
defmodule MyApp.API do
  use MyApp.ApiDsl
  
  api do
    version "v1"
    base_path "/api/v1"
    title "MyApp API"
    description "Production API for MyApp services"
  end
  
  authentication do
    strategy :jwt do
      issuer "myapp.com"
      audience "api"
      secret {:system, "JWT_SECRET"}
    end
    
    strategy :api_key do
      header "X-API-Key"
      lookup &MyApp.Auth.find_api_key/1
    end
  end
  
  middleware do
    use :cors, origins: ["https://myapp.com"]
    use :rate_limit, requests_per_minute: 1000
    use :request_id
    use :logging
  end
  
  resources do
    resource :users do
      description "User management operations"
      
      endpoint :list do
        method :get
        path "/users"
        auth :optional
        middleware [:rate_limit]
        
        parameters do
          query :page, :integer, default: 1, min: 1
          query :limit, :integer, default: 20, min: 1, max: 100
          query :filter, :string, description: "Search filter"
        end
        
        responses do
          ok :user_list, description: "List of users"
          unauthorized :error
          too_many_requests :rate_limit_error
        end
      end
      
      endpoint :create do
        method :post
        path "/users"
        auth :required, strategies: [:jwt, :api_key]
        middleware [:rate_limit, :request_validation]
        
        request_body :user_create_params do
          field :email, :string, required: true, format: :email
          field :name, :string, required: true, min_length: 2
          field :role, :string, enum: [:user, :admin], default: :user
        end
        
        responses do
          created :user, description: "Created user"
          bad_request :validation_error
          unauthorized :error
          conflict :user_exists_error
        end
      end
      
      endpoint :show do
        method :get
        path "/users/{id}"
        auth :optional
        
        parameters do
          path :id, :uuid, required: true, description: "User ID"
          query :include, {:array, :string}, enum: [:profile, :settings]
        end
        
        responses do
          ok :user, description: "User details"
          not_found :error
        end
      end
      
      endpoint :update do
        method :put
        path "/users/{id}"
        auth :required
        middleware [:ownership_check]
        
        parameters do
          path :id, :uuid, required: true
        end
        
        request_body :user_update_params do
          field :name, :string, min_length: 2
          field :email, :string, format: :email
        end
        
        responses do
          ok :user
          bad_request :validation_error
          unauthorized :error
          forbidden :ownership_error
          not_found :error
        end
      end
      
      endpoint :delete do
        method :delete
        path "/users/{id}"
        auth :required, roles: [:admin]
        
        parameters do
          path :id, :uuid, required: true
        end
        
        responses do
          no_content :empty
          unauthorized :error
          forbidden :permission_error
          not_found :error
        end
      end
    end
    
    resource :posts do
      description "Blog post operations"
      base_path "/posts"
      
      endpoint :list do
        method :get
        auth :optional
        
        parameters do
          query :author_id, :uuid
          query :published, :boolean, default: true
          query :tags, {:array, :string}
        end
        
        responses do
          ok :post_list
        end
      end
      
      endpoint :create do
        method :post
        auth :required
        
        request_body :post_create_params do
          field :title, :string, required: true, max_length: 200
          field :content, :string, required: true
          field :tags, {:array, :string}, default: []
          field :published, :boolean, default: false
        end
        
        responses do
          created :post
          bad_request :validation_error
          unauthorized :error
        end
      end
    end
  end
  
  schemas do
    schema :user do
      field :id, :uuid
      field :email, :string, format: :email
      field :name, :string
      field :role, :string, enum: [:user, :admin]
      field :created_at, :datetime
      field :updated_at, :datetime
    end
    
    schema :user_list do
      field :users, {:array, :user}
      field :total, :integer
      field :page, :integer
      field :pages, :integer
    end
    
    schema :post do
      field :id, :uuid
      field :title, :string
      field :content, :string
      field :author_id, :uuid
      field :tags, {:array, :string}
      field :published, :boolean
      field :created_at, :datetime
      field :updated_at, :datetime
    end
    
    schema :error do
      field :error, :string
      field :message, :string
      field :details, :map, required: false
    end
    
    schema :validation_error do
      field :error, :string, default: "validation_failed"
      field :fields, {:array, :field_error}
    end
    
    schema :field_error do
      field :field, :string
      field :message, :string
      field :code, :string
    end
  end
end
```

## Implementation

### Entity Definitions

```elixir
# lib/my_app/api_dsl/entities.ex
defmodule MyApp.ApiDsl.Entities do
  
  defmodule Api do
    defstruct [:version, :base_path, :title, :description, :contact, :license]
  end
  
  defmodule AuthStrategy do
    defstruct [:name, :type, :config]
  end
  
  defmodule Authentication do
    defstruct [strategies: []]
  end
  
  defmodule Middleware do
    defstruct [:name, :config, :order]
  end
  
  defmodule Parameter do
    defstruct [:name, :type, :location, :required, :default, :description, :constraints]
  end
  
  defmodule RequestBody do
    defstruct [:name, :content_type, :schema, :required, :description]
  end
  
  defmodule Response do
    defstruct [:status, :schema, :description, :headers]
  end
  
  defmodule Endpoint do
    defstruct [
      :name, :method, :path, :description, :auth, :middleware,
      parameters: [], request_body: nil, responses: []
    ]
  end
  
  defmodule Resource do
    defstruct [:name, :description, :base_path, endpoints: []]
  end
  
  defmodule Schema do
    defstruct [:name, :description, fields: []]
  end
  
  defmodule Field do
    defstruct [:name, :type, :required, :default, :description, :constraints]
  end
end
```

### Core Extension

```elixir
# lib/my_app/api_dsl/extension.ex
defmodule MyApp.ApiDsl.Extension do
  alias MyApp.ApiDsl.Entities
  
  # Parameter entity for endpoint parameters
  @parameter %Spark.Dsl.Entity{
    name: :parameter,
    target: Entities.Parameter,
    identifier: :name,
    args: [:name, :type],
    schema: [
      name: [type: :atom, required: true],
      type: [type: {:custom, __MODULE__, :validate_type, []}, required: true],
      location: [type: {:one_of, [:path, :query, :header]}, default: :query],
      required: [type: :boolean, default: false],
      default: [type: :any],
      description: [type: :string],
      min: [type: :integer],
      max: [type: :integer],
      min_length: [type: :integer],
      max_length: [type: :integer],
      format: [type: :atom],
      enum: [type: {:list, :any}]
    ]
  }
  
  # Nested parameters section
  @parameters %Spark.Dsl.Section{
    name: :parameters,
    entities: [@parameter],
    describe: "Define endpoint parameters"
  }
  
  # Field entity for schema definitions
  @field %Spark.Dsl.Entity{
    name: :field,
    target: Entities.Field,
    identifier: :name,
    args: [:name, :type],
    schema: [
      name: [type: :atom, required: true],
      type: [type: {:custom, __MODULE__, :validate_type, []}, required: true],
      required: [type: :boolean, default: false],
      default: [type: :any],
      description: [type: :string],
      min: [type: :integer],
      max: [type: :integer],
      min_length: [type: :integer],
      max_length: [type: :integer],
      format: [type: :atom],
      enum: [type: {:list, :any}]
    ]
  }
  
  # Request body entity
  @request_body %Spark.Dsl.Entity{
    name: :request_body,
    target: Entities.RequestBody,
    args: [:name],
    entities: [field: @field],
    schema: [
      name: [type: :atom, required: true],
      content_type: [type: :string, default: "application/json"],
      required: [type: :boolean, default: true],
      description: [type: :string]
    ]
  }
  
  # Response entity
  @response %Spark.Dsl.Entity{
    name: :response,
    target: Entities.Response,
    args: [:status, :schema],
    schema: [
      status: [type: {:custom, __MODULE__, :validate_status, []}, required: true],
      schema: [type: :atom],
      description: [type: :string],
      headers: [type: {:map, :string}]
    ]
  }
  
  # Responses section
  @responses %Spark.Dsl.Section{
    name: :responses,
    entities: [@response],
    describe: "Define endpoint responses"
  }
  
  # Endpoint entity
  @endpoint %Spark.Dsl.Entity{
    name: :endpoint,
    target: Entities.Endpoint,
    identifier: :name,
    args: [:name],
    sections: [@parameters, @responses],
    entities: [request_body: @request_body],
    schema: [
      name: [type: :atom, required: true],
      method: [type: {:one_of, [:get, :post, :put, :patch, :delete]}, required: true],
      path: [type: :string],
      description: [type: :string],
      auth: [type: {:custom, __MODULE__, :validate_auth, []}],
      middleware: [type: {:list, :atom}, default: []]
    ]
  }
  
  # Resource entity
  @resource %Spark.Dsl.Entity{
    name: :resource,
    target: Entities.Resource,
    identifier: :name,
    args: [:name],
    entities: [endpoint: @endpoint],
    schema: [
      name: [type: :atom, required: true],
      description: [type: :string],
      base_path: [type: :string]
    ]
  }
  
  # Schema entity
  @schema %Spark.Dsl.Entity{
    name: :schema,
    target: Entities.Schema,
    identifier: :name,
    args: [:name],
    entities: [field: @field],
    schema: [
      name: [type: :atom, required: true],
      description: [type: :string]
    ]
  }
  
  # Top-level sections
  @api %Spark.Dsl.Section{
    name: :api,
    schema: [
      version: [type: :string, required: true],
      base_path: [type: :string, default: "/api"],
      title: [type: :string, required: true],
      description: [type: :string]
    ]
  }
  
  @authentication %Spark.Dsl.Section{
    name: :authentication,
    schema: [
      default_strategy: [type: :atom],
      required_by_default: [type: :boolean, default: false]
    ]
  }
  
  @middleware %Spark.Dsl.Section{
    name: :middleware,
    schema: [
      global: [type: {:list, :atom}, default: []]
    ]
  }
  
  @resources %Spark.Dsl.Section{
    name: :resources,
    entities: [@resource]
  }
  
  @schemas %Spark.Dsl.Section{
    name: :schemas,
    entities: [@schema]
  }
  
  use Spark.Dsl.Extension,
    sections: [@api, @authentication, @middleware, @resources, @schemas],
    transformers: [
      MyApp.ApiDsl.Transformers.GenerateRoutes,
      MyApp.ApiDsl.Transformers.ValidateReferences,
      MyApp.ApiDsl.Transformers.GenerateOpenApi
    ],
    verifiers: [
      MyApp.ApiDsl.Verifiers.ValidateEndpoints,
      MyApp.ApiDsl.Verifiers.ValidateSchemas
    ]
  
  # Custom validators
  def validate_type(type) when type in [:string, :integer, :boolean, :uuid, :datetime, :map] do
    {:ok, type}
  end
  def validate_type({:array, inner_type}) when inner_type in [:string, :integer, :boolean] do
    {:ok, {:array, inner_type}}
  end
  def validate_type(type) do
    {:error, "Invalid type: #{inspect(type)}"}
  end
  
  def validate_status(status) when status in [:ok, :created, :no_content, :bad_request, 
                                              :unauthorized, :forbidden, :not_found, 
                                              :conflict, :too_many_requests, :internal_server_error] do
    {:ok, status}
  end
  def validate_status(status) when is_integer(status) and status >= 100 and status < 600 do
    {:ok, status}
  end
  def validate_status(status) do
    {:error, "Invalid HTTP status: #{inspect(status)}"}
  end
  
  def validate_auth(:required), do: {:ok, :required}
  def validate_auth(:optional), do: {:ok, :optional}
  def validate_auth({:required, opts}) when is_list(opts), do: {:ok, {:required, opts}}
  def validate_auth(nil), do: {:ok, nil}
  def validate_auth(auth) do
    {:error, "Invalid auth specification: #{inspect(auth)}"}
  end
end
```

### Transformers for Code Generation

```elixir
# lib/my_app/api_dsl/transformers/generate_routes.ex
defmodule MyApp.ApiDsl.Transformers.GenerateRoutes do
  @moduledoc """
  Generates route definitions from API DSL.
  """
  
  use Spark.Dsl.Transformer
  
  alias MyApp.ApiDsl.Info
  
  @impl true
  def transform(dsl_state) do
    routes = generate_routes(dsl_state)
    
    {:ok, Spark.Dsl.Transformer.persist(dsl_state, :generated_routes, routes)}
  end
  
  defp generate_routes(dsl_state) do
    resources = Info.resources(dsl_state)
    api_config = Info.api(dsl_state)
    
    Enum.flat_map(resources, fn resource ->
      Enum.map(resource.endpoints, fn endpoint ->
        %{
          method: endpoint.method,
          path: build_path(api_config.base_path, resource.base_path, endpoint.path),
          handler: {resource.name, endpoint.name},
          auth: endpoint.auth,
          middleware: endpoint.middleware,
          parameters: endpoint.parameters,
          responses: endpoint.responses
        }
      end)
    end)
  end
  
  defp build_path(base, resource_base, endpoint_path) do
    [base, resource_base, endpoint_path]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("")
    |> String.replace("//", "/")
  end
end
```

```elixir
# lib/my_app/api_dsl/transformers/generate_open_api.ex
defmodule MyApp.ApiDsl.Transformers.GenerateOpenApi do
  @moduledoc """
  Generates OpenAPI 3.0 specification from API DSL.
  """
  
  use Spark.Dsl.Transformer
  
  alias MyApp.ApiDsl.Info
  
  @impl true
  def transform(dsl_state) do
    openapi_spec = generate_openapi_spec(dsl_state)
    
    {:ok, Spark.Dsl.Transformer.persist(dsl_state, :openapi_spec, openapi_spec)}
  end
  
  defp generate_openapi_spec(dsl_state) do
    api_config = Info.api(dsl_state)
    resources = Info.resources(dsl_state)
    schemas = Info.schemas(dsl_state)
    
    %{
      openapi: "3.0.0",
      info: %{
        title: api_config.title,
        version: api_config.version,
        description: api_config.description
      },
      servers: [
        %{url: api_config.base_path}
      ],
      paths: generate_paths(resources, api_config),
      components: %{
        schemas: generate_schema_definitions(schemas),
        securitySchemes: generate_security_schemes(dsl_state)
      }
    }
  end
  
  defp generate_paths(resources, api_config) do
    resources
    |> Enum.flat_map(fn resource ->
      Enum.map(resource.endpoints, fn endpoint ->
        path = build_openapi_path(api_config.base_path, resource.base_path, endpoint.path)
        operation = generate_operation(endpoint, resource)
        
        {path, %{String.downcase(to_string(endpoint.method)) => operation}}
      end)
    end)
    |> Enum.reduce(%{}, fn {path, operation}, acc ->
      Map.merge(acc, %{path => operation}, fn _k, v1, v2 -> Map.merge(v1, v2) end)
    end)
  end
  
  defp generate_operation(endpoint, resource) do
    %{
      summary: endpoint.description || "#{resource.name} #{endpoint.name}",
      operationId: "#{resource.name}_#{endpoint.name}",
      parameters: generate_openapi_parameters(endpoint.parameters),
      responses: generate_openapi_responses(endpoint.responses)
    }
    |> maybe_add_request_body(endpoint.request_body)
    |> maybe_add_security(endpoint.auth)
  end
  
  defp generate_openapi_parameters(parameters) do
    Enum.map(parameters, fn param ->
      %{
        name: to_string(param.name),
        in: to_string(param.location),
        required: param.required,
        description: param.description,
        schema: type_to_openapi_schema(param.type)
      }
    end)
  end
  
  defp generate_openapi_responses(responses) do
    responses
    |> Enum.map(fn response ->
      status_code = status_to_code(response.status)
      content = if response.schema do
        %{
          "application/json" => %{
            schema: %{"$ref" => "#/components/schemas/#{response.schema}"}
          }
        }
      else
        %{}
      end
      
      {to_string(status_code), %{
        description: response.description || status_description(response.status),
        content: content
      }}
    end)
    |> Enum.into(%{})
  end
  
  defp maybe_add_request_body(operation, nil), do: operation
  defp maybe_add_request_body(operation, request_body) do
    Map.put(operation, :requestBody, %{
      required: request_body.required,
      description: request_body.description,
      content: %{
        request_body.content_type => %{
          schema: %{"$ref" => "#/components/schemas/#{request_body.name}"}
        }
      }
    })
  end
  
  defp maybe_add_security(operation, nil), do: operation
  defp maybe_add_security(operation, :optional), do: operation
  defp maybe_add_security(operation, :required) do
    Map.put(operation, :security, [%{"bearerAuth" => []}])
  end
  defp maybe_add_security(operation, {:required, _opts}) do
    Map.put(operation, :security, [%{"bearerAuth" => []}])
  end
  
  defp generate_schema_definitions(schemas) do
    schemas
    |> Enum.map(fn schema ->
      properties = Enum.into(schema.fields, %{}, fn field ->
        {to_string(field.name), type_to_openapi_schema(field.type)}
      end)
      
      required = schema.fields
      |> Enum.filter(& &1.required)
      |> Enum.map(&to_string(&1.name))
      
      schema_def = %{
        type: "object",
        properties: properties
      }
      
      schema_def = if length(required) > 0 do
        Map.put(schema_def, :required, required)
      else
        schema_def
      end
      
      {to_string(schema.name), schema_def}
    end)
    |> Enum.into(%{})
  end
  
  defp generate_security_schemes(_dsl_state) do
    %{
      "bearerAuth" => %{
        type: "http",
        scheme: "bearer",
        bearerFormat: "JWT"
      }
    }
  end
  
  defp type_to_openapi_schema(:string), do: %{type: "string"}
  defp type_to_openapi_schema(:integer), do: %{type: "integer"}
  defp type_to_openapi_schema(:boolean), do: %{type: "boolean"}
  defp type_to_openapi_schema(:uuid), do: %{type: "string", format: "uuid"}
  defp type_to_openapi_schema(:datetime), do: %{type: "string", format: "date-time"}
  defp type_to_openapi_schema({:array, inner_type}) do
    %{type: "array", items: type_to_openapi_schema(inner_type)}
  end
  
  defp build_openapi_path(base, resource_base, endpoint_path) do
    [base, resource_base, endpoint_path]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("")
    |> String.replace("//", "/")
    |> String.replace("{", "{")
    |> String.replace("}", "}")
  end
  
  defp status_to_code(:ok), do: 200
  defp status_to_code(:created), do: 201
  defp status_to_code(:no_content), do: 204
  defp status_to_code(:bad_request), do: 400
  defp status_to_code(:unauthorized), do: 401
  defp status_to_code(:forbidden), do: 403
  defp status_to_code(:not_found), do: 404
  defp status_to_code(:conflict), do: 409
  defp status_to_code(:too_many_requests), do: 429
  defp status_to_code(:internal_server_error), do: 500
  defp status_to_code(code) when is_integer(code), do: code
  
  defp status_description(:ok), do: "Success"
  defp status_description(:created), do: "Created"
  defp status_description(:no_content), do: "No Content"
  defp status_description(:bad_request), do: "Bad Request"
  defp status_description(:unauthorized), do: "Unauthorized"
  defp status_description(:forbidden), do: "Forbidden"
  defp status_description(:not_found), do: "Not Found"
  defp status_description(:conflict), do: "Conflict"
  defp status_description(:too_many_requests), do: "Too Many Requests"
  defp status_description(:internal_server_error), do: "Internal Server Error"
  defp status_description(_), do: "Response"
end
```

### Info Module

```elixir
# lib/my_app/api_dsl/info.ex
defmodule MyApp.ApiDsl.Info do
  use Spark.InfoGenerator,
    extension: MyApp.ApiDsl.Extension,
    sections: [:api, :authentication, :middleware, :resources, :schemas]
  
  @doc """
  Get generated routes for the API.
  """
  def routes(module) do
    Spark.Dsl.Extension.get_persisted(module, :generated_routes, [])
  end
  
  @doc """
  Get OpenAPI specification for the API.
  """
  def openapi_spec(module) do
    Spark.Dsl.Extension.get_persisted(module, :openapi_spec, %{})
  end
  
  @doc """
  Find a specific endpoint by resource and name.
  """
  def find_endpoint(module, resource_name, endpoint_name) do
    case resource(module, resource_name) do
      {:ok, resource} ->
        Enum.find(resource.endpoints, &(&1.name == endpoint_name))
      
      :error ->
        nil
    end
  end
  
  @doc """
  Get all endpoints across all resources.
  """
  def all_endpoints(module) do
    module
    |> resources()
    |> Enum.flat_map(& &1.endpoints)
  end
  
  @doc """
  Generate route helpers for Phoenix router.
  """
  def phoenix_routes(module) do
    routes(module)
    |> Enum.map(fn route ->
      %{
        method: route.method,
        path: route.path,
        plug: {MyApp.ApiController, route.handler},
        opts: [
          auth: route.auth,
          middleware: route.middleware
        ]
      }
    end)
  end
end
```

## Integration Examples

### Phoenix Integration

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router
  
  alias MyApp.ApiDsl.Info
  
  # Generate routes from DSL
  for route <- Info.phoenix_routes(MyApp.API) do
    match route.method, route.path, MyAppWeb.ApiController, route.handler, route.opts
  end
end
```

### OpenAPI Documentation

```elixir
# lib/my_app/api_docs.ex
defmodule MyApp.ApiDocs do
  @moduledoc """
  Serves OpenAPI documentation generated from DSL.
  """
  
  alias MyApp.ApiDsl.Info
  
  def openapi_json do
    MyApp.API
    |> Info.openapi_spec()
    |> Jason.encode!()
  end
  
  def serve_docs(conn, _params) do
    spec = openapi_json()
    
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, spec)
  end
end
```

### Runtime Validation

```elixir
# lib/my_app/api_validator.ex
defmodule MyApp.ApiValidator do
  alias MyApp.ApiDsl.Info
  
  def validate_request(resource_name, endpoint_name, params) do
    case Info.find_endpoint(MyApp.API, resource_name, endpoint_name) do
      nil ->
        {:error, :endpoint_not_found}
      
      endpoint ->
        validate_parameters(endpoint.parameters, params)
    end
  end
  
  defp validate_parameters(param_defs, params) do
    Enum.reduce_while(param_defs, {:ok, %{}}, fn param_def, {:ok, acc} ->
      case validate_parameter(param_def, params) do
        {:ok, value} ->
          {:cont, {:ok, Map.put(acc, param_def.name, value)}}
        
        {:error, _} = error ->
          {:halt, error}
      end
    end)
  end
  
  defp validate_parameter(param_def, params) do
    value = Map.get(params, to_string(param_def.name))
    
    cond do
      param_def.required and is_nil(value) ->
        {:error, "#{param_def.name} is required"}
      
      not is_nil(value) ->
        validate_type(param_def.type, value)
      
      true ->
        {:ok, param_def.default}
    end
  end
  
  defp validate_type(:string, value) when is_binary(value), do: {:ok, value}
  defp validate_type(:integer, value) when is_integer(value), do: {:ok, value}
  defp validate_type(:boolean, value) when is_boolean(value), do: {:ok, value}
  defp validate_type(:uuid, value) when is_binary(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, "Invalid UUID format"}
    end
  end
  defp validate_type(type, value) do
    {:error, "Expected #{type}, got #{inspect(value)}"}
  end
end
```

## Benefits Realized

This API DSL demonstrates several powerful benefits:

**Single Source of Truth**: API structure, validation, documentation, and routes all derive from one definition.

**Compile-Time Safety**: Invalid configurations are caught before deployment.

**Automatic Documentation**: OpenAPI specs stay synchronized with implementation.

**Type Safety**: Request/response validation happens automatically.

**Team Productivity**: New endpoints follow established patterns automatically.

**Maintenance**: Changes propagate consistently across all API concerns.

**Testing**: API behavior can be tested independently of implementation.

## Advanced Features

The DSL can be extended with additional sophisticated features:

**Rate Limiting**: Per-endpoint rate limiting configuration
**Caching**: Response caching strategies
**Monitoring**: Automatic metrics collection
**Security**: Advanced authentication and authorization
**Versioning**: API version management and migration
**Testing**: Automatic test case generation

This API DSL showcases how Spark enables building sophisticated, production-ready domain languages that solve real business problems while maintaining clarity and maintainability.

*The best APIs feel inevitable—as if they're the natural way to express the domain. Achieving this requires the careful design patterns that DSLs make possible.*