defmodule HttpApiDsl do
  @moduledoc """
  DSL for defining HTTP APIs with automatic middleware and validation.
  """
  
  defmodule Route do
    @moduledoc "Represents an HTTP route"
    defstruct [:method, :path, :handler, :middleware, :params, :response]
  end
  
  defmodule Middleware do
    @moduledoc "Represents middleware configuration"
    defstruct [:name, :options]
  end
  
  @route %Spark.Dsl.Entity{
    name: :route,
    target: Route,
    args: [:method, :path, :handler],
    schema: [
      method: [type: {:one_of, [:get, :post, :put, :delete, :patch]}, required: true],
      path: [type: :string, required: true],
      handler: [type: :atom, required: true],
      middleware: [type: {:list, :atom}, default: []],
      params: [type: :keyword_list, default: []],
      response: [type: :keyword_list, default: []]
    ]
  }
  
  @middleware %Spark.Dsl.Entity{
    name: :middleware,
    target: Middleware,
    args: [:name],
    schema: [
      name: [type: :atom, required: true],
      options: [type: :keyword_list, default: []]
    ]
  }
  
  @routes %Spark.Dsl.Section{
    name: :routes,
    entities: [@route]
  }
  
  @middlewares %Spark.Dsl.Section{
    name: :middlewares,
    entities: [@middleware]
  }
  
  defmodule AddDefaultMiddleware do
    @moduledoc "Transformer that adds default middleware based on HTTP method"
    use Spark.Dsl.Transformer
    
    def transform(dsl_state) do
      routes = Spark.Dsl.Transformer.get_entities(dsl_state, [:routes])
      
      dsl_state = Enum.reduce(routes, dsl_state, fn route, acc ->
        default_middleware = get_default_middleware(route.method, route.path)
        updated_route = %{route | middleware: default_middleware ++ route.middleware}
        Spark.Dsl.Transformer.replace_entity(acc, [:routes], updated_route, fn entity ->
          entity.method == route.method and entity.path == route.path and entity.handler == route.handler
        end)
      end)
      {:ok, dsl_state}
    end
    
    defp get_default_middleware(:get, _path), do: [:cors]
    defp get_default_middleware(:post, "/admin" <> _), do: [:cors, :csrf, :auth]
    defp get_default_middleware(:post, "/secure" <> _), do: [:cors, :csrf, :auth]  
    defp get_default_middleware(:post, _path), do: [:cors, :csrf]
    defp get_default_middleware(:put, _path), do: [:cors, :csrf, :auth]
    defp get_default_middleware(:delete, _path), do: [:cors, :csrf, :auth]
    defp get_default_middleware(:patch, _path), do: [:cors, :csrf, :auth]
  end
  
  defmodule ValidateRoutes do
    @moduledoc "Verifier that ensures referenced middleware exists"
    use Spark.Dsl.Verifier
    
    def verify(dsl_state) do
      routes = Spark.Dsl.Transformer.get_entities(dsl_state, [:routes])
      middlewares = Spark.Dsl.Transformer.get_entities(dsl_state, [:middlewares])
      
      middleware_names = Enum.map(middlewares, & &1.name) |> MapSet.new()
      builtin_middleware = MapSet.new([:cors, :csrf, :auth])
      available_middleware = MapSet.union(middleware_names, builtin_middleware)
      
      for route <- routes do
        for middleware <- route.middleware do
          unless middleware in available_middleware do
            {:error,
              Spark.Error.DslError.exception(
                message: "Route #{route.method} #{route.path} uses undefined middleware: #{middleware}",
                path: [:routes]
              )}
          end
        end
      end
      |> List.flatten()
      |> Enum.find(fn
        {:error, _} -> true
        _ -> false
      end)
      |> case do
        nil -> :ok
        error -> error
      end
    end
  end
  
  use Spark.Dsl.Extension,
    sections: [@routes, @middlewares],
    transformers: [AddDefaultMiddleware],
    verifiers: [ValidateRoutes]

  use Spark.Dsl, default_extensions: [extensions: [__MODULE__]]
end

defmodule HttpApiDsl.Info do
  @moduledoc """
  Info module for HttpApiDsl providing runtime introspection.
  """
  
  use Spark.InfoGenerator, 
    extension: HttpApiDsl, 
    sections: [:routes, :middlewares]
  
  @doc """
  Get routes for a specific HTTP method.
  """
  def routes_for_method(module, method) do
    routes(module)
    |> Enum.filter(&(&1.method == method))
  end
  
  @doc """
  Get a specific route by method and path.
  """
  def get_route(module, method, path) do
    routes(module)
    |> Enum.find(&(&1.method == method and &1.path == path))
  end
  
  @doc """
  Get all middleware names used across all routes.
  """
  def all_middleware_names(module) do
    routes(module)
    |> Enum.flat_map(& &1.middleware)
    |> Enum.uniq()
  end
  
  @doc """
  Generate OpenAPI specification from routes.
  """
  def to_openapi(module, info \\ %{}) do
    routes = routes(module)
    
    paths = routes
    |> Enum.group_by(& &1.path)
    |> Enum.map(fn {path, path_routes} ->
      operations = path_routes
      |> Enum.map(fn route ->
        {route.method, %{
          "summary" => "#{route.method |> to_string() |> String.upcase()} #{path}",
          "operationId" => Atom.to_string(route.handler),
          "responses" => %{
            "200" => %{"description" => "Success"}
          }
        }}
      end)
      |> Enum.into(%{})
      
      {path, operations}
    end)
    |> Enum.into(%{})
    
    %{
      "openapi" => "3.0.0",
      "info" => Map.merge(%{
        "title" => "API",
        "version" => "1.0.0"
      }, info),
      "paths" => paths
    }
  end
end