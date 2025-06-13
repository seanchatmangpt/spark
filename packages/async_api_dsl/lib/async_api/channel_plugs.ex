defmodule AsyncApi.ChannelPlugs do
  @moduledoc """
  Common plugs for Phoenix channels using AsyncAPI DSL.
  
  Provides reusable middleware for authentication, authorization, 
  rate limiting, validation, and other common channel operations.
  """
  
  @doc """
  Plug behaviour for channel operations.
  """
  @callback call(socket :: Phoenix.Socket.t(), payload :: map(), bindings :: map(), opts :: keyword()) ::
    {:cont, Phoenix.Socket.t(), map(), map()} |
    {:reply, {:ok | :error, map()}, Phoenix.Socket.t()} |
    {:noreply, Phoenix.Socket.t()}
  
  @doc """
  Ensure the user is authenticated.
  
  ## Examples
  
      plug AsyncApi.ChannelPlugs.EnsureAuthenticated
  """
  def ensure_authenticated(socket, payload, bindings, _opts) do
    case socket.assigns[:user_id] || socket.assigns[:current_user_id] do
      nil ->
        {:reply, {:error, %{reason: "authentication_required"}}, socket}
        
      _user_id ->
        {:cont, socket, payload, bindings}
    end
  end
  
  @doc """
  Check user permissions for a specific action.
  
  ## Examples
  
      plug AsyncApi.ChannelPlugs.CheckPermission, :admin
      plug AsyncApi.ChannelPlugs.CheckPermission, [:read_messages, :send_messages]
  """
  def check_permission(socket, payload, bindings, permission) when is_atom(permission) do
    check_permission(socket, payload, bindings, [permission])
  end
  
  def check_permission(socket, payload, bindings, permissions) when is_list(permissions) do
    user_id = socket.assigns[:user_id] || socket.assigns[:current_user_id]
    
    case user_id do
      nil ->
        {:reply, {:error, %{reason: "authentication_required"}}, socket}
        
      user_id ->
        if has_any_permission?(user_id, permissions) do
          {:cont, socket, payload, bindings}
        else
          {:reply, {:error, %{reason: "insufficient_permissions", required: permissions}}, socket}
        end
    end
  end
  
  @doc """
  Rate limiting plug.
  
  ## Examples
  
      plug AsyncApi.ChannelPlugs.RateLimit, window: 60_000, limit: 100
  """
  def rate_limit(socket, payload, bindings, opts) do
    window = Keyword.get(opts, :window, 60_000)  # 1 minute
    limit = Keyword.get(opts, :limit, 100)       # 100 requests
    key = get_rate_limit_key(socket, opts)
    
    case check_rate_limit(key, window, limit) do
      :ok ->
        {:cont, socket, payload, bindings}
        
      {:error, :rate_limited} ->
        {:reply, {:error, %{
          reason: "rate_limited",
          window_ms: window,
          limit: limit,
          message: "Too many requests. Please slow down."
        }}, socket}
    end
  end
  
  @doc """
  Validate payload against a schema.
  
  ## Examples
  
      plug AsyncApi.ChannelPlugs.ValidatePayload, schema: MyApp.Schemas.MessageSchema
  """
  def validate_payload(socket, payload, bindings, opts) do
    schema = Keyword.get(opts, :schema)
    required_fields = Keyword.get(opts, :required, [])
    
    cond do
      schema ->
        case apply(schema, :validate, [payload]) do
          {:ok, validated_payload} ->
            {:cont, socket, validated_payload, bindings}
            
          {:error, errors} ->
            {:reply, {:error, %{reason: "validation_failed", details: errors}}, socket}
        end
        
      not Enum.empty?(required_fields) ->
        case validate_required_fields(payload, required_fields) do
          :ok ->
            {:cont, socket, payload, bindings}
            
          {:error, missing_fields} ->
            {:reply, {:error, %{
              reason: "missing_required_fields",
              missing: missing_fields
            }}, socket}
        end
        
      true ->
        {:cont, socket, payload, bindings}
    end
  end
  
  @doc """
  Log incoming events for debugging/monitoring.
  
  ## Examples
  
      plug AsyncApi.ChannelPlugs.LogEvent
      plug AsyncApi.ChannelPlugs.LogEvent, level: :debug
  """
  def log_event(socket, payload, bindings, opts) do
    level = Keyword.get(opts, :level, :info)
    include_payload = Keyword.get(opts, :include_payload, false)
    
    event = bindings[:event] || "unknown"
    user_id = socket.assigns[:user_id] || "anonymous"
    
    log_message = "Channel event: #{event} from user: #{user_id}"
    
    log_message = if include_payload do
      log_message <> " payload: #{inspect(payload)}"
    else
      log_message
    end
    
    Logger.log(level, log_message)
    
    {:cont, socket, payload, bindings}
  end
  
  @doc """
  Add timing information to socket assigns.
  
  ## Examples
  
      plug AsyncApi.ChannelPlugs.TimeRequest
  """
  def time_request(socket, payload, bindings, _opts) do
    start_time = System.monotonic_time(:microsecond)
    
    socket = Phoenix.Socket.assign(socket, :request_start_time, start_time)
    
    {:cont, socket, payload, bindings}
  end
  
  @doc """
  Ensure the channel topic matches expected patterns.
  
  ## Examples
  
      plug AsyncApi.ChannelPlugs.ValidateTopic, pattern: ~r/^room:\d+$/
  """
  def validate_topic(socket, payload, bindings, opts) do
    pattern = Keyword.get(opts, :pattern)
    allowed_topics = Keyword.get(opts, :allowed, [])
    
    topic = socket.topic
    
    cond do
      pattern && Regex.match?(pattern, topic) ->
        {:cont, socket, payload, bindings}
        
      not Enum.empty?(allowed_topics) && topic in allowed_topics ->
        {:cont, socket, payload, bindings}
        
      pattern || not Enum.empty?(allowed_topics) ->
        {:reply, {:error, %{reason: "invalid_topic", topic: topic}}, socket}
        
      true ->
        {:cont, socket, payload, bindings}
    end
  end
  
  @doc """
  Add CORS headers for WebSocket connections.
  
  ## Examples
  
      plug AsyncApi.ChannelPlugs.CORS, origins: ["https://example.com"]
  """
  def cors(socket, payload, bindings, opts) do
    origins = Keyword.get(opts, :origins, ["*"])
    
    # Add CORS information to socket assigns for potential use
    socket = Phoenix.Socket.assign(socket, :cors_origins, origins)
    
    {:cont, socket, payload, bindings}
  end
  
  @doc """
  Transform payload data.
  
  ## Examples
  
      plug AsyncApi.ChannelPlugs.TransformPayload, transformer: &MyApp.Transformers.sanitize/1
  """
  def transform_payload(socket, payload, bindings, opts) do
    transformer = Keyword.get(opts, :transformer)
    
    case transformer do
      nil ->
        {:cont, socket, payload, bindings}
        
      transformer when is_function(transformer, 1) ->
        case transformer.(payload) do
          {:ok, transformed_payload} ->
            {:cont, socket, transformed_payload, bindings}
            
          {:error, reason} ->
            {:reply, {:error, %{reason: "transformation_failed", details: reason}}, socket}
            
          transformed_payload ->
            {:cont, socket, transformed_payload, bindings}
        end
        
      {module, function} ->
        case apply(module, function, [payload]) do
          {:ok, transformed_payload} ->
            {:cont, socket, transformed_payload, bindings}
            
          {:error, reason} ->
            {:reply, {:error, %{reason: "transformation_failed", details: reason}}, socket}
            
          transformed_payload ->
            {:cont, socket, transformed_payload, bindings}
        end
    end
  end
  
  @doc """
  Add request ID for tracing.
  
  ## Examples
  
      plug AsyncApi.ChannelPlugs.RequestId
  """
  def request_id(socket, payload, bindings, _opts) do
    request_id = generate_request_id()
    
    socket = Phoenix.Socket.assign(socket, :request_id, request_id)
    
    {:cont, socket, payload, bindings}
  end
  
  # Private helper functions
  
  defp has_any_permission?(user_id, permissions) do
    # This is a placeholder - implement your authorization logic
    # You might check against a database, call an authorization service, etc.
    case Application.get_env(:async_api_dsl, :authorization_module) do
      nil ->
        # Default to allowing all permissions if no authorization module configured
        true
        
      auth_module ->
        apply(auth_module, :has_any_permission?, [user_id, permissions])
    end
  end
  
  defp get_rate_limit_key(socket, opts) do
    key_type = Keyword.get(opts, :key, :user_id)
    
    case key_type do
      :user_id ->
        "rate_limit:user:#{socket.assigns[:user_id] || "anonymous"}"
        
      :ip ->
        # Would need to extract IP from socket
        "rate_limit:ip:#{get_socket_ip(socket)}"
        
      :topic ->
        "rate_limit:topic:#{socket.topic}"
        
      custom_key when is_binary(custom_key) ->
        "rate_limit:custom:#{custom_key}"
        
      {module, function} ->
        apply(module, function, [socket])
    end
  end
  
  defp check_rate_limit(key, window, limit) do
    # This is a simplified in-memory rate limiter
    # In production, you'd want to use Redis or a proper rate limiting library
    now = System.monotonic_time(:millisecond)
    
    case :ets.lookup(:rate_limits, key) do
      [] ->
        :ets.insert(:rate_limits, {key, now, 1})
        :ok
        
      [{^key, window_start, count}] ->
        if now - window_start > window do
          # Reset window
          :ets.insert(:rate_limits, {key, now, 1})
          :ok
        else
          if count >= limit do
            {:error, :rate_limited}
          else
            :ets.insert(:rate_limits, {key, window_start, count + 1})
            :ok
          end
        end
    end
  end
  
  defp validate_required_fields(payload, required_fields) do
    missing_fields = Enum.filter(required_fields, fn field ->
      not Map.has_key?(payload, field) or is_nil(Map.get(payload, field))
    end)
    
    case missing_fields do
      [] -> :ok
      missing -> {:error, missing}
    end
  end
  
  defp get_socket_ip(_socket) do
    # Placeholder - extract actual IP from socket
    "127.0.0.1"
  end
  
  defp generate_request_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
  
  @doc """
  Initialize ETS table for rate limiting.
  """
  def init_rate_limiting do
    case :ets.whereis(:rate_limits) do
      :undefined ->
        :ets.new(:rate_limits, [:named_table, :public, :set])
        
      _table ->
        :ok
    end
  end
end