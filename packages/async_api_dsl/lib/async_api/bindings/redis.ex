defmodule AsyncApi.Bindings.Redis do
  @moduledoc """
  Redis Streams protocol bindings for AsyncAPI specifications.
  
  Provides support for Redis messaging patterns including:
  - Redis Streams for event sourcing and message logs
  - Pub/Sub for real-time messaging
  - Lists for work queues
  - Consumer groups for load balancing
  - Redis clustering support
  
  ## Usage
  
      defmodule MyApp.RedisEventApi do
        use AsyncApi
        
        servers do
          server :redis_server, "redis://redis.example.com:6379" do
            protocol :redis
            
            bindings [
              redis: [
                database: 0,
                password: "your-password",
                connection_pool_size: 10,
                socket_timeout: 5000,
                connect_timeout: 5000,
                max_retries: 3
              ]
            ]
          end
        end
        
        channels do
          channel "user.events" do
            description "User event stream"
            
            bindings [
              redis: [
                stream_key: "user:events",
                max_length: 10000,
                consumer_group: "user-processors",
                consumer_name: "processor-1",
                block_timeout: 1000,
                count: 10,
                auto_claim_min_idle_time: 30000
              ]
            ]
          end
          
          channel "notifications" do
            description "Real-time notifications"
            
            bindings [
              redis: [
                type: :pubsub,
                pattern: "notifications:*",
                channels: ["notifications:user", "notifications:system"]
              ]
            ]
          end
          
          channel "tasks" do
            description "Background task queue"
            
            bindings [
              redis: [
                type: :list,
                key: "task:queue",
                direction: :right,  # RPUSH/LPOP for FIFO
                block_timeout: 5000
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
              redis: [
                fields: %{
                  "user_id" => "dynamic",
                  "event_type" => "static",
                  "timestamp" => "auto",
                  "data" => "payload"
                },
                message_id: "auto",
                max_retries: 3
              ]
            ]
          end
          
          operation :consumeUserEvents do
            action :receive
            channel "user.events"
            message :userEvent
            
            bindings [
              redis: [
                read_from: :group,
                start_id: ">",
                ack_timeout: 30000,
                claim_idle_time: 60000,
                max_deliveries: 3
              ]
            ]
          end
        end
      end
  """

  @type redis_type :: :stream | :pubsub | :list | :set | :zset | :hash
  @type direction :: :left | :right
  @type read_mode :: :group | :individual | :latest

  @doc """
  Generate Redis configuration from AsyncAPI specification.
  
  Creates connection and stream configurations for Redis clients.
  """
  def generate_redis_config(api_module, opts \\ []) do
    spec = AsyncApi.to_spec(api_module)
    
    %{
      connection: extract_connection_config(spec, opts),
      streams: extract_stream_configs(spec),
      pubsub: extract_pubsub_configs(spec),
      lists: extract_list_configs(spec),
      consumers: extract_consumer_configs(spec),
      producers: extract_producer_configs(spec)
    }
  end

  @doc """
  Generate Redis client code for various languages.
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
  Validate Redis bindings in an AsyncAPI specification.
  """
  def validate_redis_bindings(api_module) do
    spec = AsyncApi.to_spec(api_module)
    errors = []
    
    # Validate server bindings
    errors = validate_server_bindings(spec, errors)
    
    # Validate channel bindings
    errors = validate_channel_bindings(spec, errors)
    
    # Validate operation bindings
    errors = validate_operation_bindings(spec, errors)
    
    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  @doc """
  Extract Redis Stream patterns from AsyncAPI channels.
  """
  def extract_stream_patterns(api_module) do
    spec = AsyncApi.to_spec(api_module)
    channels = spec[:channels] || %{}
    
    channels
    |> Enum.filter(fn {_name, channel} ->
      redis_bindings = get_redis_bindings(channel)
      redis_bindings && redis_bindings[:type] in [nil, :stream]
    end)
    |> Enum.map(fn {channel_name, channel} ->
      redis_bindings = get_redis_bindings(channel)
      
      %{
        channel: channel_name,
        stream_key: redis_bindings[:stream_key] || to_string(channel_name),
        consumer_group: redis_bindings[:consumer_group],
        max_length: redis_bindings[:max_length]
      }
    end)
  end

  @doc """
  Generate Redis monitoring and metrics configuration.
  """
  def generate_monitoring_config(api_module, opts \\ []) do
    spec = AsyncApi.to_spec(api_module)
    
    %{
      metrics: extract_metrics_config(spec, opts),
      health_checks: extract_health_check_config(spec, opts),
      logging: extract_logging_config(spec, opts),
      performance: extract_performance_config(spec, opts)
    }
  end

  # Private helper functions

  defp extract_connection_config(spec, opts) do
    servers = spec[:servers] || %{}
    
    base_config = %{
      host: "localhost",
      port: 6379,
      database: 0,
      connection_pool_size: 10,
      socket_timeout: 5000,
      connect_timeout: 5000,
      max_retries: 3,
      retry_backoff: 1000
    }
    
    # Extract connection details from server URLs
    server_config = servers
    |> Enum.find_value(fn {_name, server} ->
      url = server[:url] || ""
      if String.starts_with?(url, "redis://") do
        parse_redis_url(url)
      end
    end) || %{}
    
    # Merge with server-specific Redis bindings
    redis_bindings = servers
    |> Enum.find_value(fn {_name, server} ->
      get_redis_bindings(server)
    end) || %{}
    
    base_config
    |> Map.merge(server_config)
    |> Map.merge(redis_bindings)
    |> Map.merge(Map.new(opts))
  end

  defp parse_redis_url(url) do
    uri = URI.parse(url)
    
    %{
      host: uri.host || "localhost",
      port: uri.port || 6379,
      database: extract_database_from_path(uri.path),
      password: uri.userinfo && String.split(uri.userinfo, ":") |> List.last()
    }
  end

  defp extract_database_from_path(nil), do: 0
  defp extract_database_from_path("/" <> path) do
    case Integer.parse(path) do
      {db, ""} -> db
      _ -> 0
    end
  end
  defp extract_database_from_path(_), do: 0

  defp extract_stream_configs(spec) do
    channels = spec[:channels] || %{}
    
    channels
    |> Enum.filter(fn {_name, channel} ->
      redis_bindings = get_redis_bindings(channel)
      redis_bindings && redis_bindings[:type] in [nil, :stream]
    end)
    |> Enum.map(fn {channel_name, channel} ->
      redis_bindings = get_redis_bindings(channel)
      
      stream_config = %{
        key: redis_bindings[:stream_key] || to_string(channel_name),
        max_length: redis_bindings[:max_length],
        consumer_group: redis_bindings[:consumer_group],
        consumer_name: redis_bindings[:consumer_name],
        block_timeout: redis_bindings[:block_timeout] || 1000,
        count: redis_bindings[:count] || 10,
        auto_claim_min_idle_time: redis_bindings[:auto_claim_min_idle_time] || 30000
      }
      
      {channel_name, stream_config}
    end)
    |> Enum.into(%{})
  end

  defp extract_pubsub_configs(spec) do
    channels = spec[:channels] || %{}
    
    channels
    |> Enum.filter(fn {_name, channel} ->
      redis_bindings = get_redis_bindings(channel)
      redis_bindings && redis_bindings[:type] == :pubsub
    end)
    |> Enum.map(fn {channel_name, channel} ->
      redis_bindings = get_redis_bindings(channel)
      
      pubsub_config = %{
        pattern: redis_bindings[:pattern],
        channels: redis_bindings[:channels] || [to_string(channel_name)]
      }
      
      {channel_name, pubsub_config}
    end)
    |> Enum.into(%{})
  end

  defp extract_list_configs(spec) do
    channels = spec[:channels] || %{}
    
    channels
    |> Enum.filter(fn {_name, channel} ->
      redis_bindings = get_redis_bindings(channel)
      redis_bindings && redis_bindings[:type] == :list
    end)
    |> Enum.map(fn {channel_name, channel} ->
      redis_bindings = get_redis_bindings(channel)
      
      list_config = %{
        key: redis_bindings[:key] || to_string(channel_name),
        direction: redis_bindings[:direction] || :right,
        block_timeout: redis_bindings[:block_timeout] || 5000
      }
      
      {channel_name, list_config}
    end)
    |> Enum.into(%{})
  end

  defp extract_consumer_configs(spec) do
    operations = spec[:operations] || %{}
    channels = spec[:channels] || %{}
    
    operations
    |> Enum.filter(fn {_name, operation} -> operation[:action] == :receive end)
    |> Enum.map(fn {operation_name, operation} ->
      channel_name = operation[:channel]
      channel = Map.get(channels, String.to_atom(channel_name))
      
      redis_bindings = get_redis_bindings(channel)
      operation_bindings = get_operation_redis_bindings(operation)
      
      consumer_config = build_consumer_config(operation_name, redis_bindings, operation_bindings)
      
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
      
      redis_bindings = get_redis_bindings(channel)
      operation_bindings = get_operation_redis_bindings(operation)
      
      producer_config = build_producer_config(operation_name, redis_bindings, operation_bindings)
      
      {operation_name, producer_config}
    end)
    |> Enum.into(%{})
  end

  defp build_consumer_config(operation_name, channel_bindings, operation_bindings) do
    base_config = %{
      name: to_string(operation_name),
      type: channel_bindings[:type] || :stream
    }
    
    case base_config[:type] do
      :stream ->
        %{
          name: to_string(operation_name),
          type: :stream,
          stream_key: channel_bindings[:stream_key],
          consumer_group: channel_bindings[:consumer_group],
          consumer_name: channel_bindings[:consumer_name],
          read_from: operation_bindings[:read_from] || :group,
          start_id: operation_bindings[:start_id] || ">",
          block_timeout: channel_bindings[:block_timeout] || 1000,
          count: channel_bindings[:count] || 10,
          ack_timeout: operation_bindings[:ack_timeout] || 30000,
          claim_idle_time: operation_bindings[:claim_idle_time] || 60000,
          max_deliveries: operation_bindings[:max_deliveries] || 3
        }
      
      :pubsub ->
        %{
          name: to_string(operation_name),
          type: :pubsub,
          pattern: channel_bindings[:pattern],
          channels: channel_bindings[:channels]
        }
      
      :list ->
        %{
          name: to_string(operation_name),
          type: :list,
          key: channel_bindings[:key],
          direction: channel_bindings[:direction] || :right,
          block_timeout: channel_bindings[:block_timeout] || 5000
        }
      
      _ ->
        base_config
    end
  end

  defp build_producer_config(operation_name, channel_bindings, operation_bindings) do
    base_config = %{
      name: to_string(operation_name),
      type: channel_bindings[:type] || :stream
    }
    
    case base_config[:type] do
      :stream ->
        %{
          name: to_string(operation_name),
          type: :stream,
          stream_key: channel_bindings[:stream_key],
          fields: operation_bindings[:fields] || %{},
          message_id: operation_bindings[:message_id] || "auto",
          max_retries: operation_bindings[:max_retries] || 3,
          max_length: channel_bindings[:max_length]
        }
      
      :pubsub ->
        %{
          name: to_string(operation_name),
          type: :pubsub,
          channels: channel_bindings[:channels]
        }
      
      :list ->
        %{
          name: to_string(operation_name),
          type: :list,
          key: channel_bindings[:key],
          direction: channel_bindings[:direction] || :right
        }
      
      _ ->
        base_config
    end
  end

  defp get_redis_bindings(item) do
    get_in(item, [:bindings, :redis])
  end

  defp get_operation_redis_bindings(operation) do
    get_in(operation, [:bindings, :redis]) || %{}
  end

  defp generate_elixir_client(api_module, opts) do
    config = generate_redis_config(api_module, opts)
    module_name = Keyword.get(opts, :module_name, "#{api_module}.RedisClient")
    
    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Generated Redis client for #{api_module}.
      \"\"\"
      
      use GenServer
      require Logger
      
      @connection_config #{inspect(config.connection, pretty: true)}
      @streams #{inspect(config.streams, pretty: true)}
      @pubsub #{inspect(config.pubsub, pretty: true)}
      @lists #{inspect(config.lists, pretty: true)}
      
      def start_link(opts \\\\ []) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end
      
      def init(opts) do
        connection_config = Keyword.get(opts, :connection, @connection_config)
        
        case Redix.start_link(connection_config) do
          {:ok, conn} -> 
            state = %{
              connection: conn,
              subscriptions: %{},
              consumer_groups: %{}
            }
            
            # Initialize consumer groups for streams
            Enum.each(@streams, fn {_channel, config} ->
              if config[:consumer_group] do
                create_consumer_group(conn, config[:key], config[:consumer_group])
              end
            end)
            
            {:ok, state}
          
          {:error, reason} ->
            {:stop, {:connection_failed, reason}}
        end
      end
      
      #{generate_elixir_stream_methods(config.streams)}
      
      #{generate_elixir_pubsub_methods(config.pubsub)}
      
      #{generate_elixir_list_methods(config.lists)}
      
      defp create_consumer_group(conn, stream_key, group_name) do
        case Redix.command(conn, ["XGROUP", "CREATE", stream_key, group_name, "0", "MKSTREAM"]) do
          {:ok, "OK"} -> :ok
          {:error, %Redix.Error{message: "BUSYGROUP" <> _}} -> :ok  # Group already exists
          {:error, reason} -> 
            Logger.warning("Failed to create consumer group: \#{inspect(reason)}")
            :error
        end
      end
      
      def terminate(_reason, state) do
        if state.connection do
          Redix.stop(state.connection)
        end
        :ok
      end
    end
    """
  end

  defp generate_elixir_stream_methods(streams) do
    streams
    |> Enum.map(fn {channel_name, config} ->
      function_name = Macro.underscore(to_string(channel_name))
      
      """
      def publish_#{function_name}(fields, opts \\\\ []) do
        GenServer.call(__MODULE__, {:xadd, "#{config[:key]}", fields, opts})
      end
      
      def consume_#{function_name}(callback, opts \\\\ []) do
        GenServer.call(__MODULE__, {:xreadgroup, #{inspect(config)}, callback, opts})
      end
      
      def ack_#{function_name}(message_id, opts \\\\ []) do
        GenServer.call(__MODULE__, {:xack, "#{config[:key]}", "#{config[:consumer_group]}", message_id, opts})
      end
      """
    end)
    |> Enum.join("\n  ")
  end

  defp generate_elixir_pubsub_methods(pubsub_configs) do
    pubsub_configs
    |> Enum.map(fn {channel_name, config} ->
      function_name = Macro.underscore(to_string(channel_name))
      
      """
      def publish_#{function_name}(message, opts \\\\ []) do
        GenServer.call(__MODULE__, {:publish, #{inspect(config[:channels])}, message, opts})
      end
      
      def subscribe_#{function_name}(callback, opts \\\\ []) do
        GenServer.call(__MODULE__, {:subscribe, #{inspect(config)}, callback, opts})
      end
      """
    end)
    |> Enum.join("\n  ")
  end

  defp generate_elixir_list_methods(list_configs) do
    list_configs
    |> Enum.map(fn {channel_name, config} ->
      function_name = Macro.underscore(to_string(channel_name))
      direction = config[:direction]
      
      push_command = if direction == :left, do: "LPUSH", else: "RPUSH"
      pop_command = if direction == :left, do: "RPOP", else: "LPOP"
      
      """
      def push_#{function_name}(item, opts \\\\ []) do
        GenServer.call(__MODULE__, {:#{String.downcase(push_command)}, "#{config[:key]}", item, opts})
      end
      
      def pop_#{function_name}(opts \\\\ []) do
        GenServer.call(__MODULE__, {:#{String.downcase(pop_command)}, "#{config[:key]}", opts})
      end
      
      def block_pop_#{function_name}(timeout \\\\ #{config[:block_timeout]}, opts \\\\ []) do
        GenServer.call(__MODULE__, {:b#{String.downcase(pop_command)}, "#{config[:key]}", timeout, opts})
      end
      """
    end)
    |> Enum.join("\n  ")
  end

  defp generate_go_client(_api_module, _opts) do
    {:ok, "// Go Redis client generation not yet implemented"}
  end

  defp generate_js_client(_api_module, _opts) do
    {:ok, "// JavaScript Redis client generation not yet implemented"}
  end

  defp generate_python_client(_api_module, _opts) do
    {:ok, "# Python Redis client generation not yet implemented"}
  end

  defp validate_server_bindings(_spec, errors) do
    # Add server validation logic here
    errors
  end

  defp validate_channel_bindings(_spec, errors) do
    # Add channel validation logic here
    errors
  end

  defp validate_operation_bindings(_spec, errors) do
    # Add operation validation logic here
    errors
  end

  defp extract_metrics_config(_spec, _opts) do
    %{
      enabled: true,
      include_connection_metrics: true,
      include_stream_metrics: true,
      include_pubsub_metrics: true
    }
  end

  defp extract_health_check_config(_spec, _opts) do
    %{
      enabled: true,
      ping_interval: 30_000,
      connection_check: true
    }
  end

  defp extract_logging_config(_spec, _opts) do
    %{
      level: :info,
      include_commands: false,
      include_timing: true
    }
  end

  defp extract_performance_config(_spec, _opts) do
    %{
      pipeline_commands: true,
      connection_pooling: true,
      command_timeout: 5000,
      retry_strategy: :exponential_backoff
    }
  end
end