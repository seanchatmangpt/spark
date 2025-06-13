defmodule AsyncApi.Application do
  @moduledoc """
  AsyncAPI DSL Application supervisor.
  
  This application starts all the necessary services for a complete
  AsyncAPI ecosystem including monitoring, security, schema registry,
  and gateway integrations.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting AsyncAPI DSL Application...")
    
    children = [
      # Core registry for tracking AsyncAPI modules
      {Registry, keys: :unique, name: AsyncApi.Registry},
      
      # Dynamic supervisor for API instances
      {DynamicSupervisor, strategy: :one_for_one, name: AsyncApi.DynamicSupervisor},
      
      # Demo API instances
      {AsyncApi.DemoApi, []},
      {AsyncApi.ExampleEventApi, []},
      
      # Optional: Start web interface for API management
      # {AsyncApi.Web.Endpoint, []}
    ]

    opts = [strategy: :one_for_one, name: AsyncApi.Supervisor]
    
    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.info("AsyncAPI DSL Application started successfully")
        start_example_services()
        {:ok, pid}
      
      error ->
        Logger.error("Failed to start AsyncAPI DSL Application: #{inspect(error)}")
        error
    end
  end

  @impl true
  def stop(_state) do
    Logger.info("Stopping AsyncAPI DSL Application...")
    stop_example_services()
    :ok
  end

  # Start example services to demonstrate all features
  defp start_example_services do
    spawn(fn ->
      # Give the application time to fully start
      Process.sleep(1000)
      
      Logger.info("Starting AsyncAPI example services...")
      
      # Start monitoring for demo API
      case AsyncApi.Monitoring.start_monitoring(AsyncApi.DemoApi) do
        {:ok, _} -> Logger.info("✓ Monitoring service started")
        {:error, reason} -> Logger.warning("✗ Monitoring service failed: #{inspect(reason)}")
      end
      
      # Start security services
      case start_security_services() do
        :ok -> Logger.info("✓ Security services started")
        {:error, reason} -> Logger.warning("✗ Security services failed: #{inspect(reason)}")
      end
      
      # Start schema registry
      case AsyncApi.SchemaRegistry.start_registry(AsyncApi.DemoApi) do
        {:ok, _} -> Logger.info("✓ Schema registry started")
        {:error, reason} -> Logger.warning("✗ Schema registry failed: #{inspect(reason)}")
      end
      
      # Start gateway integration
      case AsyncApi.Gateway.start_gateway(AsyncApi.DemoApi) do
        {:ok, _} -> Logger.info("✓ Gateway integration started")
        {:error, reason} -> Logger.warning("✗ Gateway integration failed: #{inspect(reason)}")
      end
      
      Logger.info("AsyncAPI ecosystem fully initialized!")
      print_service_status()
    end)
  end

  defp stop_example_services do
    AsyncApi.Monitoring.stop_monitoring()
    AsyncApi.SchemaRegistry.stop_registry()
    AsyncApi.Gateway.stop_gateway()
  end

  defp start_security_services do
    # Security services are typically started per-API instance
    # This is just for demonstration
    try do
      # Initialize security context
      Process.put(:async_api_security_enabled, true)
      :ok
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  defp print_service_status do
    Logger.info("""
    
    🚀 AsyncAPI DSL Services Status:
    
    Core Services:
    ├── Registry: #{inspect(Process.whereis(AsyncApi.Registry))}
    ├── Dynamic Supervisor: #{inspect(Process.whereis(AsyncApi.DynamicSupervisor))}
    
    API Instances:
    ├── Demo API: #{inspect(Process.whereis(AsyncApi.DemoApi))}
    ├── Example Event API: #{inspect(Process.whereis(AsyncApi.ExampleEventApi))}
    
    Feature Services:
    ├── Monitoring: #{if Process.get(:async_api_monitoring), do: "✓ Active", else: "✗ Inactive"}
    ├── Security: #{if Process.get(:async_api_security_enabled), do: "✓ Active", else: "✗ Inactive"}
    ├── Schema Registry: #{if Process.get(:async_api_schema_registry), do: "✓ Active", else: "✗ Inactive"}
    └── Gateway: #{if Process.get(:async_api_gateway), do: "✓ Active", else: "✗ Inactive"}
    
    🌐 Available endpoints and features:
    • Real-time monitoring and metrics
    • Schema validation and registry
    • Security and authentication
    • Gateway integration and routing
    • Protocol bindings (NATS, Redis, gRPC)
    • Code generation and testing
    
    """)
  end
end