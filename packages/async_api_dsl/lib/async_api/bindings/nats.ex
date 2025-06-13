defmodule AsyncApi.Bindings.Nats do
  @moduledoc """
  NATS protocol bindings for AsyncAPI specifications.
  
  Provides support for NATS messaging patterns including:
  - Core NATS publish/subscribe
  - JetStream persistent messaging
  - Request-reply patterns
  - Queue groups for load balancing
  - Key-Value stores
  - Object stores
  
  ## Usage
  
      defmodule MyApp.NatsEventApi do
        use AsyncApi
        
        servers do
          server :nats_server, "nats://nats.example.com:4222" do
            protocol :nats
            
            bindings [
              nats: [
                cluster_id: "my-cluster",
                client_id: "my-app",
                jetstream_enabled: true,
                max_reconnects: 10,
                reconnect_wait: 2000,
                connection_timeout: 5000
              ]
            ]
          end
        end
        
        channels do
          channel "user.events" do
            description "User event stream"
            
            bindings [
              nats: [
                subject: "user.events.>",
                queue_group: "user-processors",
                jetstream: %{
                  stream: "USER_EVENTS",
                  durable_name: "user-event-processor",
                  deliver_policy: :new,
                  ack_policy: :explicit,
                  max_deliver: 3,
                  ack_wait: 30_000,
                  replay_policy: :instant
                }
              ]
            ]
          end
          
          channel "user.commands" do
            description "User command requests"
            
            bindings [
              nats: [
                subject: "user.cmd.{action}",
                reply_to: "user.cmd.reply.{requestId}",
                timeout: 5000
              ]
            ]
          end
        end
        
        operations do
          operation :publishUserEvent do
            action :send
            channel "user.events"
            message :userEvent
            
            bindings [
              nats: [
                headers: %{
                  "Content-Type" => "application/json",
                  "Source" => "user-service"
                },
                message_id_header: "Nats-Msg-Id"
              ]
            ]
          end
          
          operation :receiveUserEvent do
            action :receive
            channel "user.events"
            message :userEvent
            
            bindings [
              nats: [
                consumer_config: %{
                  max_waiting: 100,
                  max_ack_pending: 1000,
                  heartbeat_interval: 5000
                }
              ]
            ]
          end
        end
      end
  """

  @type deliver_policy :: :all | :last | :new | :by_start_sequence | :by_start_time
  @type ack_policy :: :none | :all | :explicit
  @type replay_policy :: :instant | :original
  @type storage_type :: :file | :memory
  @type discard_policy :: :old | :new

  @doc """
  Generate NATS configuration from AsyncAPI specification.
  
  Creates connection and stream configurations for NATS clients.
  """
  def generate_nats_config(api_module, opts \\ []) do
    spec = AsyncApi.to_spec(api_module)
    
    %{
      connection: extract_connection_config(spec, opts),
      jetstream: extract_jetstream_config(spec, opts),
      subjects: extract_subject_mappings(spec),
      consumers: extract_consumer_configs(spec),
      producers: extract_producer_configs(spec)
    }
  end

  @doc """
  Generate NATS JetStream configuration.
  
  Creates stream and consumer configurations for persistent messaging.
  """
  def generate_jetstream_config(api_module, opts \\ []) do
    spec = AsyncApi.to_spec(api_module)
    
    %{
      streams: extract_stream_configs(spec),
      consumers: extract_jetstream_consumers(spec),
      key_value_stores: extract_kv_stores(spec),
      object_stores: extract_object_stores(spec)
    }
  end

  @doc """
  Generate NATS client code for various languages.
  """
  def generate_client_code(api_module, opts \\ []) do
    language = Keyword.get(opts, :language, :elixir)
    
    case language do
      :elixir -> generate_elixir_client(api_module, opts)
      :go -> generate_go_client(api_module, opts)
      :javascript -> generate_js_client(api_module, opts)
      :python -> generate_python_client(api_module, opts)
      _ -> {:error, "Unsupported language: #{language}"}
    end
  end

  @doc """
  Validate NATS bindings in an AsyncAPI specification.
  """
  def validate_nats_bindings(api_module) do
    spec = AsyncApi.to_spec(api_module)
    errors = []
    
    # Validate server bindings
    errors = validate_server_bindings(spec, errors)
    
    # Validate channel bindings
    errors = validate_channel_bindings(spec, errors)
    
    # Validate operation bindings
    errors = validate_operation_bindings(spec, errors)
    
    # Validate JetStream configurations
    errors = validate_jetstream_configs(spec, errors)
    
    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  @doc """
  Extract NATS subject patterns from AsyncAPI channels.
  """
  def extract_subject_patterns(api_module) do
    spec = AsyncApi.to_spec(api_module)
    channels = spec[:channels] || %{}
    
    channels
    |> Enum.filter(fn {_name, channel} ->
      has_nats_bindings?(channel)
    end)
    |> Enum.map(fn {channel_name, channel} ->
      nats_bindings = get_nats_bindings(channel)
      subject = nats_bindings[:subject] || to_string(channel_name)
      
      %{
        channel: channel_name,
        subject: subject,
        wildcard: String.contains?(subject, "*") || String.contains?(subject, ">"),
        queue_group: nats_bindings[:queue_group]
      }
    end)
  end

  @doc """
  Generate NATS monitoring and metrics configuration.
  """
  def generate_monitoring_config(api_module, opts \\ []) do
    spec = AsyncApi.to_spec(api_module)
    
    %{
      metrics: extract_metrics_config(spec, opts),
      health_checks: extract_health_check_config(spec, opts),
      logging: extract_logging_config(spec, opts),
      tracing: extract_tracing_config(spec, opts)
    }
  end

  # Private helper functions

  defp extract_connection_config(spec, opts) do
    servers = spec[:servers] || %{}
    
    base_config = %{
      servers: extract_server_urls(servers),
      name: Keyword.get(opts, :client_name, "AsyncAPI Client"),
      max_reconnects: -1,
      reconnect_wait: 2000,
      connection_timeout: 5000,
      ping_interval: 120_000,
      max_pings_out: 2
    }
    
    # Merge with server-specific NATS bindings
    server_config = servers
    |> Enum.find_value(fn {_name, server} ->
      get_nats_bindings(server)
    end) || %{}
    
    Map.merge(base_config, server_config)
  end

  defp extract_server_urls(servers) do
    servers
    |> Enum.filter(fn {_name, server} ->
      url = server[:url] || ""
      String.starts_with?(url, "nats://") || String.starts_with?(url, "tls://")
    end)
    |> Enum.map(fn {_name, server} -> server[:url] end)
  end

  defp extract_jetstream_config(spec, _opts) do
    channels = spec[:channels] || %{}
    
    jetstream_channels = channels
    |> Enum.filter(fn {_name, channel} ->
      nats_bindings = get_nats_bindings(channel)
      nats_bindings && nats_bindings[:jetstream]
    end)
    
    if Enum.empty?(jetstream_channels) do
      %{enabled: false}
    else
      %{
        enabled: true,
        domain: extract_jetstream_domain(spec),
        api_prefix: extract_jetstream_api_prefix(spec)
      }
    end
  end

  defp extract_jetstream_domain(spec) do
    servers = spec[:servers] || %{}
    
    servers
    |> Enum.find_value(fn {_name, server} ->
      nats_bindings = get_nats_bindings(server)
      nats_bindings && nats_bindings[:jetstream_domain]
    end)
  end

  defp extract_jetstream_api_prefix(spec) do
    servers = spec[:servers] || %{}
    
    servers
    |> Enum.find_value(fn {_name, server} ->
      nats_bindings = get_nats_bindings(server)
      nats_bindings && nats_bindings[:jetstream_api_prefix]
    end) || "$JS.API"
  end

  defp extract_subject_mappings(spec) do
    channels = spec[:channels] || %{}
    
    Enum.into(channels, %{}, fn {channel_name, channel} ->
      nats_bindings = get_nats_bindings(channel)
      subject = if nats_bindings, do: nats_bindings[:subject], else: to_string(channel_name)
      
      {channel_name, subject || to_string(channel_name)}
    end)
  end

  defp extract_consumer_configs(spec) do
    operations = spec[:operations] || %{}
    channels = spec[:channels] || %{}
    
    operations
    |> Enum.filter(fn {_name, operation} -> operation[:action] == :receive end)
    |> Enum.map(fn {operation_name, operation} ->
      channel_name = operation[:channel]
      channel = Map.get(channels, String.to_atom(channel_name))
      
      nats_bindings = get_nats_bindings(channel)
      operation_bindings = get_operation_nats_bindings(operation)
      
      consumer_config = build_consumer_config(operation_name, nats_bindings, operation_bindings)
      
      {operation_name, consumer_config}
    end)
    |> Enum.into(%{})
  end

  defp extract_producer_configs(spec) do
    operations = spec[:operations] || %{}
    channels = spec[:channels] || %{}
    
    operations
    |> Enum.filter(fn {_name, operation} -> operation[:action] == :send end)
    |> Enum.map(fn {operation_name, operation} ->
      channel_name = operation[:channel]
      channel = Map.get(channels, String.to_atom(channel_name))
      
      nats_bindings = get_nats_bindings(channel)
      operation_bindings = get_operation_nats_bindings(operation)
      
      producer_config = build_producer_config(operation_name, nats_bindings, operation_bindings)
      
      {operation_name, producer_config}
    end)
    |> Enum.into(%{})
  end

  defp build_consumer_config(operation_name, channel_bindings, operation_bindings) do
    base_config = %{
      name: to_string(operation_name),
      queue_group: channel_bindings[:queue_group]
    }
    
    # Add JetStream consumer config if present
    jetstream_config = channel_bindings[:jetstream]
    consumer_config = operation_bindings[:consumer_config] || %{}
    
    if jetstream_config do
      jetstream_consumer_config = %{
        durable_name: jetstream_config[:durable_name],
        deliver_policy: jetstream_config[:deliver_policy] || :new,
        ack_policy: jetstream_config[:ack_policy] || :explicit,
        max_deliver: jetstream_config[:max_deliver] || 3,
        ack_wait: jetstream_config[:ack_wait] || 30_000,
        replay_policy: jetstream_config[:replay_policy] || :instant,
        max_waiting: consumer_config[:max_waiting] || 100,
        max_ack_pending: consumer_config[:max_ack_pending] || 1000,
        heartbeat_interval: consumer_config[:heartbeat_interval] || 5000
      }
      
      Map.merge(base_config, %{jetstream: jetstream_consumer_config})
    else
      base_config
    end
  end

  defp build_producer_config(operation_name, channel_bindings, operation_bindings) do
    %{
      name: to_string(operation_name),
      subject: channel_bindings[:subject],
      headers: operation_bindings[:headers] || %{},
      message_id_header: operation_bindings[:message_id_header],
      timeout: channel_bindings[:timeout] || operation_bindings[:timeout] || 5000,
      reply_to: channel_bindings[:reply_to]
    }
  end

  defp extract_stream_configs(spec) do
    channels = spec[:channels] || %{}
    
    channels
    |> Enum.filter(fn {_name, channel} ->
      nats_bindings = get_nats_bindings(channel)
      nats_bindings && nats_bindings[:jetstream]
    end)
    |> Enum.map(fn {channel_name, channel} ->
      nats_bindings = get_nats_bindings(channel)
      jetstream_config = nats_bindings[:jetstream]
      
      stream_config = %{
        name: jetstream_config[:stream] || String.upcase(to_string(channel_name)),
        subjects: [nats_bindings[:subject] || to_string(channel_name)],
        retention: jetstream_config[:retention] || :limits,
        storage: jetstream_config[:storage] || :file,
        discard: jetstream_config[:discard] || :old,
        max_consumers: jetstream_config[:max_consumers] || -1,
        max_msgs: jetstream_config[:max_msgs] || -1,
        max_bytes: jetstream_config[:max_bytes] || -1,
        max_age: jetstream_config[:max_age] || 0,
        max_msg_size: jetstream_config[:max_msg_size] || -1,
        duplicate_window: jetstream_config[:duplicate_window] || 120_000_000_000, # 2 minutes in nanoseconds
        replicas: jetstream_config[:replicas] || 1
      }
      
      {jetstream_config[:stream] || String.upcase(to_string(channel_name)), stream_config}
    end)
    |> Enum.into(%{})
  end

  defp extract_jetstream_consumers(spec) do
    extract_consumer_configs(spec)
    |> Enum.filter(fn {_name, config} -> Map.has_key?(config, :jetstream) end)
    |> Enum.into(%{})
  end

  defp extract_kv_stores(spec) do
    servers = spec[:servers] || %{}
    
    servers
    |> Enum.flat_map(fn {_name, server} ->
      nats_bindings = get_nats_bindings(server)
      
      case nats_bindings[:kv_stores] do
        nil -> []
        stores when is_list(stores) -> stores
        store when is_map(store) -> [store]
      end
    end)
  end

  defp extract_object_stores(spec) do
    servers = spec[:servers] || %{}
    
    servers
    |> Enum.flat_map(fn {_name, server} ->
      nats_bindings = get_nats_bindings(server)
      
      case nats_bindings[:object_stores] do
        nil -> []
        stores when is_list(stores) -> stores
        store when is_map(store) -> [store]
      end
    end)
  end

  defp has_nats_bindings?(item) do
    get_nats_bindings(item) != nil
  end

  defp get_nats_bindings(item) do
    get_in(item, [:bindings, :nats])
  end

  defp get_operation_nats_bindings(operation) do
    get_in(operation, [:bindings, :nats]) || %{}
  end

  defp generate_elixir_client(api_module, opts) do
    config = generate_nats_config(api_module, opts)
    module_name = Keyword.get(opts, :module_name, "#{api_module}.NatsClient")
    
    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Generated NATS client for #{api_module}.
      \"\"\"
      
      use GenServer
      require Logger
      
      @connection_config #{inspect(config.connection, pretty: true)}
      @jetstream_config #{inspect(config.jetstream, pretty: true)}
      @subjects #{inspect(config.subjects, pretty: true)}
      
      def start_link(opts \\\\ []) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end
      
      def init(opts) do
        connection_config = Keyword.get(opts, :connection, @connection_config)
        
        case :nats.connect(connection_config) do
          {:ok, conn} -> 
            state = %{
              connection: conn,
              jetstream: nil,
              subscriptions: %{}
            }
            
            # Initialize JetStream if enabled
            state = if @jetstream_config.enabled do
              case :nats_jetstream.new(conn) do
                {:ok, js} -> %{state | jetstream: js}
                {:error, reason} -> 
                  Logger.warning("Failed to initialize JetStream: \#{inspect(reason)}")
                  state
              end
            else
              state
            end
            
            {:ok, state}
          
          {:error, reason} ->
            {:stop, {:connection_failed, reason}}
        end
      end
      
      #{generate_elixir_publisher_methods(config.producers)}
      
      #{generate_elixir_subscriber_methods(config.consumers)}
      
      #{generate_elixir_jetstream_methods(config.jetstream)}
      
      def handle_info({:nats_msg, subject, reply_to, payload}, state) do
        # Handle incoming messages
        Logger.debug("Received message on \#{subject}: \#{payload}")
        {:noreply, state}
      end
      
      def terminate(_reason, state) do
        if state.connection do
          :nats.close(state.connection)
        end
        :ok
      end
    end
    """
  end

  defp generate_elixir_publisher_methods(producers) do
    producers
    |> Enum.map(fn {operation_name, config} ->
      function_name = Macro.underscore(to_string(operation_name))
      subject = config[:subject] || to_string(operation_name)
      
      """
      def #{function_name}(payload, opts \\\\ []) do
        GenServer.call(__MODULE__, {:publish, "#{subject}", payload, opts})
      end
      """
    end)
    |> Enum.join("\n  ")
  end

  defp generate_elixir_subscriber_methods(consumers) do
    consumers
    |> Enum.map(fn {operation_name, config} ->
      function_name = "subscribe_#{Macro.underscore(to_string(operation_name))}"
      
      """
      def #{function_name}(callback, opts \\\\ []) do
        GenServer.call(__MODULE__, {:subscribe, #{inspect(config)}, callback, opts})
      end
      """
    end)
    |> Enum.join("\n  ")
  end

  defp generate_elixir_jetstream_methods(jetstream_config) do
    if jetstream_config[:enabled] do
      """
      def publish_to_stream(stream, subject, payload, opts \\\\ []) do
        GenServer.call(__MODULE__, {:jetstream_publish, stream, subject, payload, opts})
      end
      
      def consume_from_stream(stream, consumer, callback, opts \\\\ []) do
        GenServer.call(__MODULE__, {:jetstream_consume, stream, consumer, callback, opts})
      end
      
      def create_stream(config) do
        GenServer.call(__MODULE__, {:create_stream, config})
      end
      
      def create_consumer(stream, config) do
        GenServer.call(__MODULE__, {:create_consumer, stream, config})
      end
      """
    else
      ""
    end
  end

  defp generate_go_client(api_module, opts) do
    config = generate_nats_config(api_module, opts)
    package_name = Keyword.get(opts, :package, "client")
    
    jetstream_init_code = if config.jetstream.enabled do
      "js, err = jetstream.New(conn)\n        if err != nil {\n            log.Printf(\"Failed to initialize JetStream: %v\", err)\n        }"
    else
      ""
    end
    
    go_code = "package " <> package_name <> "\n\n" <>
    "import (\n" <>
    "    \"context\"\n" <>
    "    \"fmt\"\n" <>
    "    \"log\"\n" <>
    "    \"time\"\n" <>
    "    \n" <>
    "    \"github.com/nats-io/nats.go\"\n" <>
    "    \"github.com/nats-io/nats.go/jetstream\"\n" <>
    ")\n\n" <>
    "type NatsClient struct {\n" <>
    "    conn *nats.Conn\n" <>
    "    js   jetstream.JetStream\n" <>
    "    subs map[string]*nats.Subscription\n" <>
    "}\n\n" <>
    "func NewNatsClient() (*NatsClient, error) {\n" <>
    "    conn, err := nats.Connect(\"" <> Enum.join(config.connection.servers, ",") <> "\")\n" <>
    "    if err != nil {\n" <>
    "        return nil, fmt.Errorf(\"failed to connect to NATS: %w\", err)\n" <>
    "    }\n" <>
    "    \n" <>
    "    var js jetstream.JetStream\n" <>
    "    " <> jetstream_init_code <> "\n" <>
    "    \n" <>
    "    return &NatsClient{\n" <>
    "        conn: conn,\n" <>
    "        js:   js,\n" <>
    "        subs: make(map[string]*nats.Subscription),\n" <>
    "    }, nil\n" <>
    "}\n\n" <>
    "func (c *NatsClient) Close() {\n" <>
    "    for _, sub := range c.subs {\n" <>
    "        sub.Unsubscribe()\n" <>
    "    }\n" <>
    "    c.conn.Close()\n" <>
    "}\n\n" <>
    generate_go_publisher_methods(config.producers) <> "\n\n" <>
    generate_go_subscriber_methods(config.consumers) <> "\n"
    
    {:ok, go_code}
  end

  defp generate_js_client(api_module, opts) do
    config = generate_nats_config(api_module, opts)
    
    jetstream_init_code = if config.jetstream.enabled do
      "this.jetstream = this.connection.jetstream();"
    else
      ""
    end
    
    js_code = "const { connect, StringCodec } = require('nats');\n" <>
    "const { jetstreamManager } = require('nats');\n\n" <>
    "class NatsClient {\n" <>
    "    constructor() {\n" <>
    "        this.connection = null;\n" <>
    "        this.jetstream = null;\n" <>
    "        this.subscriptions = new Map();\n" <>
    "        this.stringCodec = StringCodec();\n" <>
    "    }\n" <>
    "    \n" <>
    "    async connect() {\n" <>
    "        try {\n" <>
    "            this.connection = await connect({\n" <>
    "                servers: " <> inspect(config.connection.servers) <> ",\n" <>
    "                maxReconnectAttempts: " <> to_string(config.connection.max_reconnects) <> ",\n" <>
    "                reconnectTimeWait: " <> to_string(config.connection.reconnect_wait) <> ",\n" <>
    "                timeout: " <> to_string(config.connection.connection_timeout) <> "\n" <>
    "            });\n" <>
    "            \n" <>
    "            " <> jetstream_init_code <> "\n" <>
    "            \n" <>
    "            console.log('Connected to NATS');\n" <>
    "        } catch (error) {\n" <>
    "            console.error('Failed to connect to NATS:', error);\n" <>
    "            throw error;\n" <>
    "        }\n" <>
    "    }\n" <>
    "    \n" <>
    "    async close() {\n" <>
    "        for (const [, subscription] of this.subscriptions) {\n" <>
    "            subscription.unsubscribe();\n" <>
    "        }\n" <>
    "        await this.connection.close();\n" <>
    "    }\n" <>
    "    \n" <>
    generate_js_publisher_methods(config.producers) <> "\n" <>
    "    \n" <>
    generate_js_subscriber_methods(config.consumers) <> "\n" <>
    "}\n\n" <>
    "module.exports = { NatsClient };\n"
    
    {:ok, js_code}
  end

  defp generate_python_client(api_module, opts) do
    config = generate_nats_config(api_module, opts)
    class_name = Keyword.get(opts, :class_name, "NatsClient")
    
    jetstream_init_code = if config.jetstream.enabled do
      "self.jetstream = self.connection.jetstream()"
    else
      ""
    end
    
    python_code = "import asyncio\n" <>
    "import json\n" <>
    "import logging\n" <>
    "from typing import Callable, Optional, Dict, Any\n\n" <>
    "import nats\n" <>
    "from nats.js import JetStreamContext\n\n\n" <>
    "class " <> class_name <> ":\n" <>
    "    \"\"\"Generated NATS client for " <> to_string(api_module) <> "\"\"\"\n" <>
    "    \n" <>
    "    def __init__(self):\n" <>
    "        self.connection: Optional[nats.NATS] = None\n" <>
    "        self.jetstream: Optional[JetStreamContext] = None\n" <>
    "        self.subscriptions: Dict[str, Any] = {}\n" <>
    "        self.logger = logging.getLogger(__name__)\n" <>
    "    \n" <>
    "    async def connect(self):\n" <>
    "        \"\"\"Connect to NATS server\"\"\"\n" <>
    "        try:\n" <>
    "            self.connection = await nats.connect(\n" <>
    "                servers=" <> inspect(config.connection.servers) <> ",\n" <>
    "                max_reconnect_attempts=" <> to_string(config.connection.max_reconnects) <> ",\n" <>
    "                reconnect_time_wait=" <> to_string(config.connection.reconnect_wait / 1000) <> ",\n" <>
    "                connect_timeout=" <> to_string(config.connection.connection_timeout / 1000) <> "\n" <>
    "            )\n" <>
    "            \n" <>
    "            " <> jetstream_init_code <> "\n" <>
    "            \n" <>
    "            self.logger.info(\"Connected to NATS\")\n" <>
    "        except Exception as e:\n" <>
    "            self.logger.error(f\"Failed to connect to NATS: {e}\")\n" <>
    "            raise\n" <>
    "    \n" <>
    "    async def close(self):\n" <>
    "        \"\"\"Close NATS connection and cleanup subscriptions\"\"\"\n" <>
    "        for subscription in self.subscriptions.values():\n" <>
    "            if hasattr(subscription, 'unsubscribe'):\n" <>
    "                await subscription.unsubscribe()\n" <>
    "        \n" <>
    "        if self.connection:\n" <>
    "            await self.connection.close()\n" <>
    "    \n" <>
    generate_python_publisher_methods(config.producers) <> "\n" <>
    "    \n" <>
    generate_python_subscriber_methods(config.consumers) <> "\n"
    
    {:ok, python_code}
  end

  defp validate_server_bindings(spec, errors) do
    servers = spec[:servers] || %{}
    
    Enum.reduce(servers, errors, fn {server_name, server}, acc ->
      url = server[:url] || ""
      
      if String.starts_with?(url, "nats://") || String.starts_with?(url, "tls://") do
        nats_bindings = get_nats_bindings(server)
        
        if nats_bindings do
          validate_server_nats_bindings(server_name, nats_bindings, acc)
        else
          acc
        end
      else
        acc
      end
    end)
  end

  defp validate_server_nats_bindings(_server_name, _bindings, errors) do
    # Add server-specific validation here
    errors
  end

  defp validate_channel_bindings(spec, errors) do
    channels = spec[:channels] || %{}
    
    Enum.reduce(channels, errors, fn {channel_name, channel}, acc ->
      nats_bindings = get_nats_bindings(channel)
      
      if nats_bindings do
        validate_channel_nats_bindings(channel_name, nats_bindings, acc)
      else
        acc
      end
    end)
  end

  defp validate_channel_nats_bindings(channel_name, bindings, errors) do
    errors = if subject = bindings[:subject] do
      if !is_binary(subject) || String.trim(subject) == "" do
        ["Channel #{channel_name}: NATS subject must be a non-empty string" | errors]
      else
        errors
      end
    else
      errors
    end
    
    # Validate JetStream configuration
    errors = if jetstream_config = bindings[:jetstream] do
      validate_jetstream_channel_config(channel_name, jetstream_config, errors)
    else
      errors
    end
    
    errors
  end

  defp validate_jetstream_channel_config(channel_name, config, errors) do
    errors = if !config[:stream] do
      ["Channel #{channel_name}: JetStream configuration missing stream name" | errors]
    else
      errors
    end
    
    # Validate deliver policy
    valid_deliver_policies = [:all, :last, :new, :by_start_sequence, :by_start_time]
    errors = if deliver_policy = config[:deliver_policy] do
      if !Enum.member?(valid_deliver_policies, deliver_policy) do
        ["Channel #{channel_name}: Invalid deliver_policy #{deliver_policy}" | errors]
      else
        errors
      end
    else
      errors
    end
    
    # Validate ack policy
    valid_ack_policies = [:none, :all, :explicit]
    errors = if ack_policy = config[:ack_policy] do
      if !Enum.member?(valid_ack_policies, ack_policy) do
        ["Channel #{channel_name}: Invalid ack_policy #{ack_policy}" | errors]
      else
        errors
      end
    else
      errors
    end
    
    errors
  end

  defp validate_operation_bindings(spec, errors) do
    operations = spec[:operations] || %{}
    
    Enum.reduce(operations, errors, fn {operation_name, operation}, acc ->
      nats_bindings = get_operation_nats_bindings(operation)
      
      if nats_bindings && !Enum.empty?(nats_bindings) do
        validate_operation_nats_bindings(operation_name, nats_bindings, acc)
      else
        acc
      end
    end)
  end

  defp validate_operation_nats_bindings(_operation_name, _bindings, errors) do
    # Add operation-specific validation here
    errors
  end

  defp validate_jetstream_configs(spec, errors) do
    stream_configs = extract_stream_configs(spec)
    
    Enum.reduce(stream_configs, errors, fn {stream_name, config}, acc ->
      validate_stream_config(stream_name, config, acc)
    end)
  end

  defp validate_stream_config(stream_name, config, errors) do
    errors = if !config[:subjects] || Enum.empty?(config[:subjects]) do
      ["Stream #{stream_name}: Must have at least one subject" | errors]
    else
      errors
    end
    
    # Validate storage type
    valid_storage_types = [:file, :memory]
    errors = if storage = config[:storage] do
      if !Enum.member?(valid_storage_types, storage) do
        ["Stream #{stream_name}: Invalid storage type #{storage}" | errors]
      else
        errors
      end
    else
      errors
    end
    
    # Validate discard policy
    valid_discard_policies = [:old, :new]
    errors = if discard = config[:discard] do
      if !Enum.member?(valid_discard_policies, discard) do
        ["Stream #{stream_name}: Invalid discard policy #{discard}" | errors]
      else
        errors
      end
    else
      errors
    end
    
    errors
  end

  defp extract_metrics_config(_spec, _opts) do
    %{
      enabled: true,
      port: 8222,
      path: "/metrics",
      include_connection_metrics: true,
      include_jetstream_metrics: true
    }
  end

  defp extract_health_check_config(_spec, _opts) do
    %{
      enabled: true,
      port: 8222,
      path: "/healthz",
      interval: 30_000
    }
  end

  defp extract_logging_config(_spec, _opts) do
    %{
      level: :info,
      format: :json,
      include_trace_context: true
    }
  end

  defp extract_tracing_config(_spec, _opts) do
    %{
      enabled: true,
      service_name: "nats-client",
      sample_rate: 0.1
    }
  end

  # Go client method generation helpers
  defp generate_go_publisher_methods(producers) do
    producers
    |> Enum.map(fn {operation_name, config} ->
      function_name = Macro.camelize(to_string(operation_name))
      subject = config[:subject] || to_string(operation_name)
      
      "func (c *NatsClient) " <> function_name <> "(payload []byte) error {\n" <>
      "    return c.conn.Publish(\"" <> subject <> "\", payload)\n" <>
      "}"
    end)
    |> Enum.join("\n")
  end

  defp generate_go_subscriber_methods(consumers) do
    consumers
    |> Enum.map(fn {operation_name, config} ->
      function_name = "Subscribe" <> Macro.camelize(to_string(operation_name))
      
      jetstream_code = if Map.has_key?(config, :jetstream) do
        "consumer, err := c.js.CreateOrUpdateConsumer(ctx, \"" <> to_string(config.jetstream[:stream]) <> "\", jetstream.ConsumerConfig{\n" <>
        "        Durable: \"" <> to_string(config.jetstream[:durable_name]) <> "\",\n" <>
        "        DeliverPolicy: jetstream.DeliverNewPolicy,\n" <>
        "    })\n" <>
        "    if err != nil {\n" <>
        "        return err\n" <>
        "    }\n" <>
        "    \n" <>
        "    _, err = consumer.Consume(handler)\n" <>
        "    return err"
      else
        "sub, err := c.conn.Subscribe(\"" <> to_string(config[:subject] || to_string(operation_name)) <> "\", handler)\n" <>
        "    if err != nil {\n" <>
        "        return err\n" <>
        "    }\n" <>
        "    c.subs[\"" <> to_string(operation_name) <> "\"] = sub\n" <>
        "    return nil"
      end
      
      method_start = "func (c *NatsClient) " <> function_name <> "(ctx context.Context, handler nats.MsgHandler) error {\n"
      method_body = "    " <> jetstream_code <> "\n"
      method_end = "}"
      
      method_start <> method_body <> method_end
    end)
    |> Enum.join("\n")
  end

  # JavaScript client method generation helpers
  defp generate_js_publisher_methods(producers) do
    producers
    |> Enum.map(fn {operation_name, config} ->
      function_name = Macro.underscore(to_string(operation_name))
      subject = config[:subject] || to_string(operation_name)
      
      publish_code = if config[:reply_to] do
        "return await this.connection.request('" <> subject <> "', data, { timeout: " <> to_string(config[:timeout] || 5000) <> " });"
      else
        "this.connection.publish('" <> subject <> "', data);"
      end
      
      "async " <> function_name <> "(payload) {\n" <>
      "    const data = typeof payload === 'string' ? this.stringCodec.encode(payload) : payload;\n" <>
      "    " <> publish_code <> "\n" <>
      "}"
    end)
    |> Enum.join("\n    ")
  end

  defp generate_js_subscriber_methods(consumers) do
    consumers
    |> Enum.map(fn {operation_name, config} ->
      function_name = "subscribe" <> Macro.camelize(to_string(operation_name))
      
      jetstream_code = if Map.has_key?(config, :jetstream) do
        "const consumer = await this.jetstream.consumers.get('" <> to_string(config.jetstream[:stream]) <> "', '" <> to_string(config.jetstream[:durable_name]) <> "');\n" <>
        "        const subscription = await consumer.consume({\n" <>
        "            callback: (msg) => {\n" <>
        "                const payload = this.stringCodec.decode(msg.data);\n" <>
        "                handler(payload, msg);\n" <>
        "                msg.ack();\n" <>
        "            }\n" <>
        "        });"
      else
        "const subscription = this.connection.subscribe('" <> to_string(config[:subject] || to_string(operation_name)) <> "', {\n" <>
        "            callback: (err, msg) => {\n" <>
        "                if (err) {\n" <>
        "                    console.error('Subscription error:', err);\n" <>
        "                    return;\n" <>
        "                }\n" <>
        "                const payload = this.stringCodec.decode(msg.data);\n" <>
        "                handler(payload, msg);\n" <>
        "            }\n" <>
        "        });"
      end
      
      "async " <> function_name <> "(handler) {\n" <>
      "    " <> jetstream_code <> "\n" <>
      "    this.subscriptions.set('" <> to_string(operation_name) <> "', subscription);\n" <>
      "    return subscription;\n" <>
      "}"
    end)
    |> Enum.join("\n    ")
  end

  # Python client method generation helpers
  defp generate_python_publisher_methods(producers) do
    producers
    |> Enum.map(fn {operation_name, config} ->
      function_name = Macro.underscore(to_string(operation_name))
      subject = config[:subject] || to_string(operation_name)
      
      timeout_val = (config[:timeout] || 5000) / 1000
      
      publish_code = if config[:reply_to] do
        "try:\\n            response = await self.connection.request('" <> subject <> "', data, timeout=timeout)\\n            return json.loads(response.data.decode())\\n        except Exception as e:\\n            self.logger.error(f'Request failed: {e}')\\n            raise"
      else
        "await self.connection.publish('" <> subject <> "', data)"
      end
      
      "async def " <> function_name <> "(self, payload: Any, timeout: float = " <> to_string(timeout_val) <> ") -> Optional[Any]:\\n" <>
      "    \\\"\\\"\\\"Publish to " <> subject <> "\\\"\\\"\\\"\\n" <>
      "    data = json.dumps(payload).encode() if not isinstance(payload, bytes) else payload\\n" <>
      "    " <> publish_code
    end)
    |> Enum.join("\n    ")
  end

  defp generate_python_subscriber_methods(consumers) do
    consumers
    |> Enum.map(fn {operation_name, config} ->
      function_name = "subscribe_#{Macro.underscore(to_string(operation_name))}"
      
      jetstream_code = if Map.has_key?(config, :jetstream) do
        "consumer = await self.jetstream.consumer('" <> to_string(config.jetstream[:stream]) <> "', '" <> to_string(config.jetstream[:durable_name]) <> "')\\n" <>
        "        async def message_handler(msg):\\n" <>
        "            try:\\n" <>
        "                payload = json.loads(msg.data.decode())\\n" <>
        "                await handler(payload, msg)\\n" <>
        "                await msg.ack()\\n" <>
        "            except Exception as e:\\n" <>
        "                self.logger.error(f'Message handling error: {e}')\\n" <>
        "                await msg.nak()\\n" <>
        "        \\n" <>
        "        subscription = await consumer.subscribe(message_handler)"
      else
        "async def message_handler(msg):\\n" <>
        "            try:\\n" <>
        "                payload = json.loads(msg.data.decode())\\n" <>
        "                await handler(payload, msg)\\n" <>
        "            except Exception as e:\\n" <>
        "                self.logger.error(f'Message handling error: {e}')\\n" <>
        "        \\n" <>
        "        subscription = await self.connection.subscribe('" <> to_string(config[:subject] || to_string(operation_name)) <> "', cb=message_handler)"
      end
      
      "async def " <> function_name <> "(self, handler: Callable) -> Any:\\n" <>
      "    \\\"\\\"\\\"Subscribe to " <> to_string(config[:subject] || to_string(operation_name)) <> "\\\"\\\"\\\"\\n" <>
      "    " <> jetstream_code <> "\\n" <>
      "    self.subscriptions['" <> to_string(operation_name) <> "'] = subscription\\n" <>
      "    return subscription"
    end)
    |> Enum.join("\n    ")
  end
end