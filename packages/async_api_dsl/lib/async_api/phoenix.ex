defmodule AsyncApi.Phoenix do
  @moduledoc """
  Phoenix Framework integration for AsyncAPI specifications.
  
  Provides utilities for integrating AsyncAPI specifications with Phoenix applications,
  including WebSocket channels, LiveView hooks, and automatic endpoint generation.
  
  ## Features
  
  - Generate Phoenix channels from AsyncAPI operations
  - LiveView integration for real-time updates
  - Automatic WebSocket endpoint configuration
  - Message validation middleware
  - Broadcasting helpers
  - Presence integration
  
  ## Usage
  
      defmodule MyAppWeb.EventSocket do
        use Phoenix.Socket
        use AsyncApi.Phoenix.Socket, api: MyApp.EventApi
        
        # Channels are automatically configured from AsyncAPI spec
      end
      
      defmodule MyAppWeb.EventChannel do
        use Phoenix.Channel
        use AsyncApi.Phoenix.Channel, 
          api: MyApp.EventApi,
          operation: :receiveUserEvents,
          validate_messages: true
      end
      
      defmodule MyAppWeb.DashboardLive do
        use Phoenix.LiveView
        use AsyncApi.Phoenix.LiveView, api: MyApp.EventApi
        
        def mount(_params, _session, socket) do
          # Automatically subscribe to relevant channels
          socket = subscribe_to_api_events(socket, [:userCreated, :userUpdated])
          {:ok, socket}
        end
      end
  """

  @doc """
  Generate Phoenix socket configuration from AsyncAPI specification.
  """
  defmacro __using__(opts) do
    api_module = Keyword.fetch!(opts, :api)
    
    quote do
      import AsyncApi.Phoenix
      
      @async_api_module unquote(api_module)
      @async_api_channels AsyncApi.Phoenix.extract_channels(@async_api_module)
      
      # Configure channels from AsyncAPI spec
      Module.eval_quoted(__MODULE__, AsyncApi.Phoenix.generate_channel_routes(@async_api_channels))
    end
  end

  @doc """
  Extract channel configurations from AsyncAPI specification.
  """
  def extract_channels(api_module) do
    spec = AsyncApi.to_spec(api_module)
    channels = spec[:channels] || %{}
    operations = spec[:operations] || %{}
    
    channels
    |> Enum.map(fn {channel_name, channel} ->
      # Find operations for this channel
      channel_operations = operations
      |> Enum.filter(fn {_op_name, operation} -> 
        operation[:channel] == to_string(channel_name)
      end)
      
      %{
        name: channel_name,
        path: to_string(channel_name),
        description: channel[:description],
        operations: channel_operations,
        parameters: extract_channel_parameters(channel),
        websocket_bindings: extract_websocket_bindings(channel)
      }
    end)
  end

  @doc """
  Generate Phoenix channel route definitions.
  """
  def generate_channel_routes(channels) do
    channels
    |> Enum.map(fn channel ->
      channel_module = channel_module_name(channel.name)
      
      quote do
        channel unquote(channel.path), unquote(channel_module)
      end
    end)
  end

  @doc """
  Generate Phoenix channel module code.
  """
  def generate_channel_module(api_module, channel_name, opts \\ []) do
    channels = extract_channels(api_module)
    channel = Enum.find(channels, fn ch -> ch.name == channel_name end)
    
    if channel do
      module_name = Keyword.get(opts, :module_name, channel_module_name(channel_name))
      validate_messages = Keyword.get(opts, :validate_messages, true)
      
      """
      defmodule #{module_name} do
        @moduledoc \"\"\"
        Generated Phoenix channel for #{channel_name}.
        
        #{channel.description || ""}
        
        This channel handles the following operations:
        #{generate_operation_docs(channel.operations)}
        \"\"\"
        
        use Phoenix.Channel
        require Logger
        
        alias AsyncApi.Validator
        
        @api_module #{api_module}
        @channel_name :#{channel_name}
        @validate_messages #{validate_messages}
        
        # Channel callbacks
        
        def join("#{channel.path}", payload, socket) do
          #{generate_join_logic(channel)}
        end
        
        #{generate_handle_in_functions(channel.operations, validate_messages)}
        
        #{generate_handle_info_functions(channel.operations)}
        
        # Helper functions
        
        #{generate_validation_helpers(validate_messages)}
        
        #{generate_broadcasting_helpers(channel)}
        
        #{generate_parameter_extraction(channel)}
      end
      """
    else
      {:error, "Channel #{channel_name} not found in AsyncAPI specification"}
    end
  end

  @doc """
  Generate LiveView integration helpers.
  """
  defmacro use_liveview_integration(opts) do
    api_module = Keyword.fetch!(opts, :api)
    
    quote do
      import AsyncApi.Phoenix.LiveView
      
      @async_api_module unquote(api_module)
      
      defp subscribe_to_api_events(socket, event_types) when is_list(event_types) do
        Enum.reduce(event_types, socket, fn event_type, acc_socket ->
          subscribe_to_api_event(acc_socket, event_type)
        end)
      end
      
      defp subscribe_to_api_event(socket, event_type) do
        channels = AsyncApi.Phoenix.extract_channels(@async_api_module)
        
        # Find channels that handle this event type
        relevant_channels = Enum.filter(channels, fn channel ->
          Enum.any?(channel.operations, fn {_op_name, operation} ->
            operation[:message] == event_type && operation[:action] == :receive
          end)
        end)
        
        # Subscribe to relevant channel topics
        Enum.each(relevant_channels, fn channel ->
          topic = build_topic_name(channel.path, socket.assigns)
          Phoenix.PubSub.subscribe(MyApp.PubSub, topic)
        end)
        
        socket
      end
      
      defp handle_api_event(socket, event_type, payload) do
        case AsyncApi.Validator.validate_message(@async_api_module, event_type, payload) do
          :ok ->
            handle_validated_api_event(socket, event_type, payload)
          {:error, errors} ->
            Logger.warning("Invalid API event \#{event_type}: \#{inspect(errors)}")
            socket
        end
      end
      
      # Override this function to handle specific API events
      defp handle_validated_api_event(socket, event_type, payload) do
        Logger.info("Received API event \#{event_type}: \#{inspect(payload)}")
        socket
      end
      
      defoverridable handle_validated_api_event: 3
    end
  end

  @doc """
  Generate WebSocket endpoint configuration.
  """
  def generate_websocket_endpoint(api_module, opts \\ []) do
    endpoint_module = Keyword.get(opts, :module_name, "#{api_module}.Endpoint")
    socket_module = Keyword.get(opts, :socket_module, "#{api_module}.Socket")
    path = Keyword.get(opts, :path, "/socket")
    
    """
    defmodule #{endpoint_module} do
      @moduledoc \"\"\"
      Generated WebSocket endpoint for #{api_module}.
      \"\"\"
      
      use Phoenix.Endpoint, otp_app: #{opts[:otp_app] || ":my_app"}
      
      # WebSocket configuration
      socket "#{path}", #{socket_module},
        websocket: [
          timeout: 45_000,
          max_frame_size: #{opts[:max_frame_size] || "64_000"},
          compress: #{opts[:compress] || "false"}
        ],
        longpoll: #{opts[:longpoll] || "false"}
      
      # Additional endpoint configuration...
    end
    """
  end

  @doc """
  Generate message broadcasting utilities.
  """
  def generate_broadcaster(api_module, opts \\ []) do
    module_name = Keyword.get(opts, :module_name, "#{api_module}.Broadcaster")
    pubsub_module = Keyword.get(opts, :pubsub_module, "MyApp.PubSub")
    
    spec = AsyncApi.to_spec(api_module)
    operations = spec[:operations] || %{}
    
    send_operations = operations
    |> Enum.filter(fn {_name, op} -> op[:action] == :send end)
    
    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Message broadcasting utilities for #{api_module}.
      \"\"\"
      
      require Logger
      alias AsyncApi.Validator
      
      @pubsub #{pubsub_module}
      @api_module #{api_module}
      
      #{generate_broadcast_functions(send_operations)}
      
      # Generic broadcast function
      def broadcast(topic, event_type, payload, opts \\\\ []) do
        case Validator.validate_message(@api_module, event_type, payload) do
          :ok ->
            message = %{
              event: event_type,
              payload: payload,
              timestamp: System.system_time(:millisecond),
              metadata: Keyword.get(opts, :metadata, %{})
            }
            
            Phoenix.PubSub.broadcast(@pubsub, topic, {:api_event, message})
          
          {:error, errors} ->
            Logger.error("Failed to broadcast invalid message \#{event_type}: \#{inspect(errors)}")
            {:error, {:validation_failed, errors}}
        end
      end
      
      # Broadcast to all subscribers of a channel
      def broadcast_to_channel(channel_name, event_type, payload, opts \\\\ []) do
        topic = "channel:\#{channel_name}"
        broadcast(topic, event_type, payload, opts)
      end
      
      # Broadcast to specific user
      def broadcast_to_user(user_id, event_type, payload, opts \\\\ []) do
        topic = "user:\#{user_id}"
        broadcast(topic, event_type, payload, opts)
      end
    end
    """
  end

  @doc """
  Generate Presence integration.
  """
  def generate_presence_module(api_module, opts \\ []) do
    module_name = Keyword.get(opts, :module_name, "#{api_module}.Presence")
    pubsub_module = Keyword.get(opts, :pubsub_module, "MyApp.PubSub")
    
    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Presence tracking for #{api_module} WebSocket connections.
      \"\"\"
      
      use Phoenix.Presence, 
        otp_app: #{opts[:otp_app] || ":my_app"},
        pubsub_server: #{pubsub_module}
      
      alias AsyncApi.Phoenix
      
      @api_module #{api_module}
      
      def track_connection(socket, user_id, metadata \\\\ %{}) do
        track(socket, user_id, %{
          online_at: inspect(System.system_time(:second)),
          channel: socket.topic,
          api_module: @api_module,
          metadata: metadata
        })
      end
      
      def get_users_in_channel(channel) do
        list(channel)
        |> Enum.map(fn {user_id, %{metas: [meta | _]}} ->
          %{
            user_id: user_id,
            online_at: meta.online_at,
            metadata: meta.metadata
          }
        end)
      end
      
      def get_user_channels(user_id) do
        # Find all channels where this user is present
        channels = Phoenix.extract_channels(@api_module)
        
        Enum.filter(channels, fn channel ->
          channel.path
          |> list()
          |> Map.has_key?(user_id)
        end)
      end
    end
    """
  end

  # Private helper functions

  defp extract_channel_parameters(channel) do
    channel[:parameters] || %{}
  end

  defp extract_websocket_bindings(channel) do
    get_in(channel, [:bindings, :websockets]) || %{}
  end

  defp channel_module_name(channel_name) do
    channel_name
    |> to_string()
    |> String.split("/")
    |> Enum.map(&Macro.camelize/1)
    |> Enum.join("")
    |> then(&"#{&1}Channel")
  end

  defp generate_operation_docs(operations) do
    operations
    |> Enum.map(fn {op_name, operation} ->
      "- #{op_name} (#{operation[:action]}): #{operation[:summary] || "No description"}"
    end)
    |> Enum.join("\n        ")
  end

  defp generate_join_logic(channel) do
    if Enum.empty?(channel.parameters) do
      """
      # No parameters to validate
          Logger.info("User joined channel #{channel.path}")
          {:ok, socket}
      """
    else
      """
      # Validate channel parameters
          case validate_channel_parameters(payload) do
            :ok ->
              Logger.info("User joined channel #{channel.path} with params: \#{inspect(payload)}")
              {:ok, assign(socket, :channel_params, payload)}
            {:error, errors} ->
              Logger.warning("Invalid join parameters for #{channel.path}: \#{inspect(errors)}")
              {:error, %{reason: "invalid_parameters", details: errors}}
          end
      """
    end
  end

  defp generate_handle_in_functions(operations, validate_messages) do
    operations
    |> Enum.filter(fn {_name, op} -> op[:action] == :send end)
    |> Enum.map(fn {op_name, operation} ->
      generate_handle_in_function(op_name, operation, validate_messages)
    end)
    |> Enum.join("\n\n  ")
  end

  defp generate_handle_in_function(op_name, operation, validate_messages) do
    event_name = to_string(op_name)
    message_type = operation[:message]
    
    validation_code = if validate_messages do
      """
      case validate_message(:#{message_type}, payload) do
          :ok ->
            handle_#{Macro.underscore(to_string(op_name))}(payload, socket)
          {:error, errors} ->
            Logger.warning("Invalid message for #{op_name}: \#{inspect(errors)}")
            {:reply, {:error, %{reason: "validation_failed", details: errors}}, socket}
        end
      """
    else
      """
      handle_#{Macro.underscore(to_string(op_name))}(payload, socket)
      """
    end
    
    """
    def handle_in("#{event_name}", payload, socket) do
      #{validation_code}
    end
    
    # Override this function to implement business logic
    defp handle_#{Macro.underscore(to_string(op_name))}(payload, socket) do
      Logger.info("Handling #{op_name}: \#{inspect(payload)}")
      {:noreply, socket}
    end
    """
  end

  defp generate_handle_info_functions(operations) do
    operations
    |> Enum.filter(fn {_name, op} -> op[:action] == :receive end)
    |> Enum.map(fn {op_name, operation} ->
      generate_handle_info_function(op_name, operation)
    end)
    |> Enum.join("\n\n  ")
  end

  defp generate_handle_info_function(op_name, operation) do
    event_name = to_string(op_name)
    message_type = operation[:message]
    
    """
    def handle_info({:api_event, %{event: :#{message_type}} = message}, socket) do
      # Broadcast #{op_name} event to client
      push(socket, "#{event_name}", %{
        payload: message.payload,
        timestamp: message.timestamp,
        metadata: message.metadata
      })
      
      {:noreply, socket}
    end
    """
  end

  defp generate_validation_helpers(true) do
    """
    defp validate_message(message_type, payload) do
      Validator.validate_message(@api_module, message_type, payload)
    end
    
    defp validate_channel_parameters(params) do
      # Implement parameter validation based on AsyncAPI channel parameters
      :ok
    end
    """
  end

  defp generate_validation_helpers(false) do
    """
    defp validate_channel_parameters(_params) do
      :ok
    end
    """
  end

  defp generate_broadcasting_helpers(channel) do
    """
    defp broadcast_to_channel(event_type, payload, opts \\\\ []) do
      topic = socket.topic
      AsyncApi.Phoenix.Broadcaster.broadcast(topic, event_type, payload, opts)
    end
    
    defp broadcast_to_all_channels(event_type, payload, opts \\\\ []) do
      base_topic = "#{channel.path}"
      AsyncApi.Phoenix.Broadcaster.broadcast_to_channel(base_topic, event_type, payload, opts)
    end
    """
  end

  defp generate_parameter_extraction(channel) do
    if Enum.empty?(channel.parameters) do
      """
      defp extract_parameters(_socket) do
        %{}
      end
      """
    else
      """
      defp extract_parameters(socket) do
        socket.assigns[:channel_params] || %{}
      end
      
      defp get_parameter(socket, param_name) do
        params = extract_parameters(socket)
        Map.get(params, param_name)
      end
      """
    end
  end

  defp generate_broadcast_functions(send_operations) do
    send_operations
    |> Enum.map(fn {op_name, operation} ->
      function_name = "broadcast_#{Macro.underscore(to_string(op_name))}"
      message_type = operation[:message]
      
      """
      @doc \"\"\"
      Broadcast #{op_name} message.
      
      #{operation[:summary] || ""}
      \"\"\"
      def #{function_name}(topic, payload, opts \\\\ []) do
        broadcast(topic, :#{message_type}, payload, opts)
      end
      """
    end)
    |> Enum.join("\n\n  ")
  end
end

defmodule AsyncApi.Phoenix.LiveView do
  @moduledoc """
  LiveView integration helpers for AsyncAPI.
  """

  defmacro __using__(opts) do
    AsyncApi.Phoenix.use_liveview_integration(opts)
  end

  def build_topic_name(channel_path, assigns) do
    # Replace parameters in channel path with actual values from assigns
    Regex.replace(~r/\{(\w+)\}/, channel_path, fn _, param ->
      Map.get(assigns, String.to_atom(param), param)
    end)
  end
end

defmodule AsyncApi.Phoenix.Channel do
  @moduledoc """
  Phoenix Channel integration for AsyncAPI.
  """

  defmacro __using__(opts) do
    api_module = Keyword.fetch!(opts, :api)
    operation = Keyword.get(opts, :operation)
    validate_messages = Keyword.get(opts, :validate_messages, true)

    quote do
      import AsyncApi.Phoenix.Channel
      
      @async_api_module unquote(api_module)
      @async_api_operation unquote(operation)
      @validate_messages unquote(validate_messages)
      
      # Add channel-specific helpers
      defp api_module, do: @async_api_module
      defp operation, do: @async_api_operation
      defp validate_messages?, do: @validate_messages
    end
  end
end