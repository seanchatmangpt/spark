defmodule Examples.PhoenixChannels.Socket do
  @moduledoc """
  Phoenix Socket implementation using AsyncAPI DSL specification.
  
  This socket automatically configures channels based on the 
  Examples.PhoenixChatApi AsyncAPI specification and provides
  authentication, transport configuration, and channel routing.
  """
  
  use Phoenix.Socket
  use AsyncApi.Phoenix.Socket, api: Examples.PhoenixChatApi
  
  require Logger
  
  ## Channels
  # These channels are automatically configured from the AsyncAPI spec
  # but we can also define them explicitly for clarity
  
  channel "chat:room:*", Examples.PhoenixChannels.ChatRoomChannel
  channel "chat:private:*", Examples.PhoenixChannels.PrivateMessageChannel
  channel "presence:room:*", Examples.PhoenixChannels.PresenceChannel
  channel "notifications:user:*", Examples.PhoenixChannels.NotificationChannel
  
  # Socket params can be validated here before connecting
  @impl true
  def connect(params, socket, _connect_info) do
    case authenticate_user(params) do
      {:ok, user} ->
        socket = socket
        |> assign(:user_id, user.id)
        |> assign(:username, user.username)
        |> assign(:authenticated, true)
        |> assign(:connected_at, DateTime.utc_now())
        |> assign(:rate_limits, %{})
        
        Logger.info("User #{user.username} (#{user.id}) connected via WebSocket")
        
        {:ok, socket}
        
      {:error, reason} ->
        Logger.warning("WebSocket connection rejected: #{inspect(reason)}")
        :error
    end
  end
  
  # Socket IDs are used to identify socket connections for broadcasting
  @impl true
  def id(socket) do
    case socket.assigns[:user_id] do
      nil -> nil
      user_id -> "user_socket:#{user_id}"
    end
  end
  
  # Handle socket-level messages (before they reach channels)
  @impl true
  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{pong: true, timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}}, socket}
  end
  
  def handle_in("heartbeat", _payload, socket) do
    # Update last seen timestamp
    socket = assign(socket, :last_heartbeat, DateTime.utc_now())
    {:reply, {:ok, %{status: "alive"}}, socket}
  end
  
  def handle_in("get_socket_info", _payload, socket) do
    info = %{
      user_id: socket.assigns[:user_id],
      username: socket.assigns[:username],
      connected_at: socket.assigns[:connected_at] |> DateTime.to_iso8601(),
      last_heartbeat: socket.assigns[:last_heartbeat] |> DateTime.to_iso8601(),
      transport: socket.transport,
      api_version: get_api_version()
    }
    
    {:reply, {:ok, info}, socket}
  end
  
  # Global rate limiting at socket level
  def handle_in(_event, _payload, socket) do
    case check_global_rate_limit(socket) do
      :ok ->
        # Let the message pass through to channels
        {:noreply, socket}
        
      {:error, :rate_limited} ->
        {:reply, {:error, %{
          reason: "global_rate_limit",
          message: "Too many requests. Please slow down."
        }}, socket}
    end
  end
  
  # Handle socket-level info messages
  @impl true
  def handle_info({:disconnect, reason}, socket) do
    user_id = socket.assigns[:user_id]
    username = socket.assigns[:username]
    
    Logger.info("Disconnecting user #{username} (#{user_id}): #{reason}")
    
    # Broadcast user disconnection to relevant channels
    broadcast_user_disconnection(socket, reason)
    
    {:stop, reason, socket}
  end
  
  def handle_info({:force_disconnect, reason}, socket) do
    {:reply, {:error, %{reason: "force_disconnect", message: reason}}, socket}
    {:stop, :normal, socket}
  end
  
  def handle_info({:global_notification, notification}, socket) do
    # Send global notifications to all connected users
    push(socket, "global_notification", notification)
    {:noreply, socket}
  end
  
  # Authentication functions
  
  defp authenticate_user(params) do
    case params["token"] || params[:token] do
      nil ->
        {:error, "authentication_token_required"}
        
      token when is_binary(token) ->
        case verify_token(token) do
          {:ok, user} -> {:ok, user}
          {:error, reason} -> {:error, reason}
        end
        
      _ ->
        {:error, "invalid_token_format"}
    end
  end
  
  defp verify_token(token) do
    # This is a simplified example - implement actual JWT verification
    # or your authentication system
    case String.starts_with?(token, "valid_") do
      true ->
        # Extract user info from token
        user_id = String.replace_prefix(token, "valid_", "")
        {:ok, %{
          id: user_id,
          username: "user_#{user_id}",
          roles: ["user"],
          authenticated_at: DateTime.utc_now()
        }}
        
      false ->
        {:error, "invalid_token"}
    end
  end
  
  # Rate limiting functions
  
  defp check_global_rate_limit(socket) do
    # Implement global rate limiting per socket
    # This is a simplified example
    now = System.monotonic_time(:millisecond)
    rate_limits = socket.assigns[:rate_limits] || %{}
    
    window_start = rate_limits[:window_start] || now
    request_count = rate_limits[:count] || 0
    
    window_duration = 60_000  # 1 minute
    max_requests = 1000       # 1000 requests per minute
    
    if now - window_start > window_duration do
      # Reset window
      socket = assign(socket, :rate_limits, %{
        window_start: now,
        count: 1
      })
      :ok
    else
      if request_count >= max_requests do
        {:error, :rate_limited}
      else
        socket = assign(socket, :rate_limits, %{
          window_start: window_start,
          count: request_count + 1
        })
        :ok
      end
    end
  end
  
  # Utility functions
  
  defp get_api_version do
    # Get version from AsyncAPI specification
    spec = AsyncApi.to_spec(Examples.PhoenixChatApi)
    get_in(spec, [:info, :version]) || "1.0.0"
  end
  
  defp broadcast_user_disconnection(socket, reason) do
    user_id = socket.assigns[:user_id]
    username = socket.assigns[:username]
    
    disconnection_event = %{
      user_id: user_id,
      username: username,
      reason: to_string(reason),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    # Broadcast to all channels this user was connected to
    # This would typically query which rooms the user was in
    user_rooms = Examples.PhoenixChannels.Presence.get_user_rooms(user_id)
    
    Enum.each(user_rooms, fn room_id ->
      topic = "chat:room:#{room_id}"
      Phoenix.PubSub.broadcast(MyApp.PubSub, topic, {:user_disconnected, disconnection_event})
    end)
  end
  
  @doc """
  Broadcast a message to all connected sockets.
  """
  def broadcast_to_all(event, payload) do
    MyAppWeb.Endpoint.broadcast("user_socket:*", event, payload)
  end
  
  @doc """
  Broadcast a message to a specific user across all their connections.
  """
  def broadcast_to_user(user_id, event, payload) do
    MyAppWeb.Endpoint.broadcast("user_socket:#{user_id}", event, payload)
  end
  
  @doc """
  Get connection statistics.
  """
  def get_connection_stats do
    # This would typically use Phoenix.Tracker or similar
    # to get real connection statistics
    %{
      total_connections: 0,  # Implement actual count
      authenticated_connections: 0,  # Implement actual count
      channels_active: 0,  # Implement actual count
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end
end