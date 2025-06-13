defmodule Examples.PhoenixChannels.ChatRoomChannel do
  @moduledoc """
  Phoenix Channel implementation for chat rooms using AsyncAPI DSL.
  
  This channel is generated from the Examples.PhoenixChatApi AsyncAPI specification
  and handles real-time chat messaging for room-based conversations.
  
  ## Features
  - Real-time message broadcasting
  - User presence tracking
  - Message validation
  - Room parameter handling
  - Automatic acknowledgments
  
  ## Usage
  
  Add to your Phoenix Socket:
  
      channel "/chat/room/*", Examples.PhoenixChannels.ChatRoomChannel
  
  """
  
  use Phoenix.Channel
  use AsyncApi.Phoenix.Channel, 
    api: Examples.PhoenixChatApi,
    operation: :sendMessage,
    validate_messages: true
  
  require Logger
  
  alias Examples.PhoenixChatApi
  alias AsyncApi.Validator
  alias Phoenix.PubSub
  
  # Channel configuration
  @max_message_length 1000
  @rate_limit_window 60_000  # 1 minute
  @rate_limit_count 100      # 100 messages per minute
  
  # Channel lifecycle callbacks
  
  def join("chat:room:" <> room_id, params, socket) do
    case validate_join_params(room_id, params, socket) do
      {:ok, validated_params} ->
        socket = socket
        |> assign(:room_id, room_id)
        |> assign(:user_id, validated_params["user_id"])
        |> assign(:username, validated_params["username"])
        |> assign(:joined_at, DateTime.utc_now())
        |> track_rate_limit()
        
        # Track user presence
        track_user_presence(socket)
        
        # Notify room of new user
        broadcast_user_joined(socket)
        
        # Send recent messages to new user
        send_recent_messages(socket)
        
        Logger.info("User #{validated_params["username"]} joined room #{room_id}")
        
        {:ok, %{
          status: "joined",
          room_id: room_id,
          user_count: get_room_user_count(room_id),
          recent_messages_sent: true
        }, socket}
        
      {:error, reason} ->
        Logger.warning("Failed to join room #{room_id}: #{inspect(reason)}")
        {:error, %{reason: reason}}
    end
  end
  
  def terminate(reason, socket) do
    room_id = socket.assigns[:room_id]
    username = socket.assigns[:username]
    
    if room_id && username do
      broadcast_user_left(socket)
      Logger.info("User #{username} left room #{room_id} (#{reason})")
    end
    
    :ok
  end
  
  # Message handling
  
  def handle_in("send_message", payload, socket) do
    case validate_and_process_message(payload, socket) do
      {:ok, processed_message} ->
        case check_rate_limit(socket) do
          :ok ->
            # Broadcast message to all room subscribers
            broadcast_message(socket, processed_message)
            
            # Send acknowledgment
            {:reply, {:ok, %{
              message_id: processed_message.id,
              status: "delivered",
              timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
            }}, socket}
            
          {:error, :rate_limited} ->
            {:reply, {:error, %{
              reason: "rate_limited",
              message: "Too many messages. Please slow down."
            }}, socket}
        end
        
      {:error, reason} ->
        {:reply, {:error, %{
          reason: "validation_failed",
          details: reason
        }}, socket}
    end
  end
  
  def handle_in("join_room", payload, socket) do
    # Handle explicit join room message (already joined via channel join)
    user_id = socket.assigns[:user_id]
    room_id = socket.assigns[:room_id]
    username = socket.assigns[:username]
    
    join_message = %{
      id: UUID.uuid4(),
      user_id: user_id,
      username: username,
      room_id: room_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    case Validator.validate_message(PhoenixChatApi, :joinRoomMessage, join_message) do
      :ok ->
        broadcast_from(socket, "user_joined", join_message)
        {:reply, {:ok, %{status: "announced"}}, socket}
        
      {:error, errors} ->
        {:reply, {:error, %{reason: "validation_failed", details: errors}}, socket}
    end
  end
  
  def handle_in("leave_room", _payload, socket) do
    # Handle graceful leave
    broadcast_user_left(socket)
    {:stop, :normal, socket}
  end
  
  def handle_in("get_room_info", _payload, socket) do
    room_id = socket.assigns[:room_id]
    
    room_info = %{
      room_id: room_id,
      user_count: get_room_user_count(room_id),
      users: get_room_users(room_id),
      created_at: socket.assigns[:joined_at] |> DateTime.to_iso8601()
    }
    
    {:reply, {:ok, room_info}, socket}
  end
  
  # Handle incoming broadcasts from other processes
  
  def handle_info({:new_message, message}, socket) do
    push(socket, "receive_message", message)
    {:noreply, socket}
  end
  
  def handle_info({:user_joined, user_info}, socket) do
    push(socket, "user_joined", user_info)
    {:noreply, socket}
  end
  
  def handle_info({:user_left, user_info}, socket) do
    push(socket, "user_left", user_info)
    {:noreply, socket}
  end
  
  def handle_info({:notification, notification}, socket) do
    # Handle room-level notifications
    push(socket, "notification", notification)
    {:noreply, socket}
  end
  
  # Private helper functions
  
  defp validate_join_params(room_id, params, socket) do
    with {:ok, user_id} <- validate_user_id(params["user_id"]),
         {:ok, username} <- validate_username(params["username"]),
         :ok <- validate_room_access(room_id, user_id, socket) do
      {:ok, %{
        "user_id" => user_id,
        "username" => username,
        "room_id" => room_id
      }}
    else
      {:error, reason} -> {:error, reason}
      :error -> {:error, "invalid_parameters"}
    end
  end
  
  defp validate_user_id(nil), do: {:error, "user_id_required"}
  defp validate_user_id(user_id) when is_binary(user_id) do
    case UUID.info(user_id) do
      {:ok, _} -> {:ok, user_id}
      {:error, _} -> {:error, "invalid_user_id_format"}
    end
  end
  defp validate_user_id(_), do: {:error, "user_id_must_be_string"}
  
  defp validate_username(nil), do: {:error, "username_required"}
  defp validate_username(username) when is_binary(username) do
    cond do
      String.length(username) < 1 -> {:error, "username_too_short"}
      String.length(username) > 50 -> {:error, "username_too_long"}
      not Regex.match?(~r/^[a-zA-Z0-9_-]+$/, username) -> {:error, "invalid_username_format"}
      true -> {:ok, username}
    end
  end
  defp validate_username(_), do: {:error, "username_must_be_string"}
  
  defp validate_room_access(room_id, user_id, socket) do
    # Add your room access validation logic here
    # For example, check if user has permission to join room
    # This is a simplified example
    case Regex.match?(~r/^[a-zA-Z0-9_-]+$/, room_id) do
      true -> :ok
      false -> {:error, "invalid_room_id_format"}
    end
  end
  
  defp validate_and_process_message(payload, socket) do
    user_id = socket.assigns[:user_id]
    username = socket.assigns[:username]
    room_id = socket.assigns[:room_id]
    
    # Create full message structure
    message = %{
      id: UUID.uuid4(),
      content: payload["content"],
      author: %{
        id: user_id,
        username: username,
        avatar_url: payload["author"]["avatar_url"]
      },
      room_id: room_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      message_type: payload["message_type"] || "text",
      metadata: payload["metadata"] || %{}
    }
    
    # Validate against AsyncAPI schema
    case Validator.validate_message(PhoenixChatApi, :chatMessage, message) do
      :ok -> 
        # Additional business logic validation
        case validate_message_content(message.content) do
          :ok -> {:ok, message}
          error -> error
        end
        
      {:error, errors} ->
        {:error, errors}
    end
  end
  
  defp validate_message_content(content) when is_binary(content) do
    cond do
      String.length(content) == 0 -> {:error, "message_cannot_be_empty"}
      String.length(content) > @max_message_length -> {:error, "message_too_long"}
      contains_forbidden_content?(content) -> {:error, "forbidden_content"}
      true -> :ok
    end
  end
  defp validate_message_content(_), do: {:error, "content_must_be_string"}
  
  defp contains_forbidden_content?(content) do
    # Add your content filtering logic here
    # This is a simple example
    forbidden_words = ["spam", "abuse"]
    content_lower = String.downcase(content)
    Enum.any?(forbidden_words, &String.contains?(content_lower, &1))
  end
  
  defp track_user_presence(socket) do
    # Use Phoenix.Presence to track user in room
    topic = "chat:room:#{socket.assigns.room_id}"
    user_id = socket.assigns.user_id
    
    {:ok, _} = Examples.PhoenixChannels.Presence.track(socket, user_id, %{
      username: socket.assigns.username,
      joined_at: socket.assigns.joined_at,
      status: "online"
    })
  end
  
  defp broadcast_message(socket, message) do
    topic = "chat:room:#{socket.assigns.room_id}"
    
    # Broadcast to room subscribers
    PubSub.broadcast(MyApp.PubSub, topic, {:new_message, message})
    
    # Also send via channel broadcast
    broadcast_from(socket, "receive_message", message)
  end
  
  defp broadcast_user_joined(socket) do
    user_info = %{
      user_id: socket.assigns.user_id,
      username: socket.assigns.username,
      status: "online",
      room_id: socket.assigns.room_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    case Validator.validate_message(PhoenixChatApi, :presenceUpdate, user_info) do
      :ok ->
        broadcast_from(socket, "user_joined", user_info)
        
        # Also broadcast to presence channel
        topic = "presence:room:#{socket.assigns.room_id}"
        PubSub.broadcast(MyApp.PubSub, topic, {:user_joined, user_info})
        
      {:error, errors} ->
        Logger.error("Failed to validate user joined message: #{inspect(errors)}")
    end
  end
  
  defp broadcast_user_left(socket) do
    user_info = %{
      user_id: socket.assigns.user_id,
      username: socket.assigns.username,
      status: "offline",
      room_id: socket.assigns.room_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    case Validator.validate_message(PhoenixChatApi, :presenceUpdate, user_info) do
      :ok ->
        broadcast_from(socket, "user_left", user_info)
        
        # Also broadcast to presence channel
        topic = "presence:room:#{socket.assigns.room_id}"
        PubSub.broadcast(MyApp.PubSub, topic, {:user_left, user_info})
        
      {:error, errors} ->
        Logger.error("Failed to validate user left message: #{inspect(errors)}")
    end
  end
  
  defp send_recent_messages(socket) do
    # Send last 50 messages to newly joined user
    # This would typically fetch from a database
    room_id = socket.assigns.room_id
    
    # Simulated recent messages - replace with actual database query
    recent_messages = get_recent_messages(room_id, 50)
    
    Enum.each(recent_messages, fn message ->
      push(socket, "receive_message", message)
    end)
  end
  
  defp get_recent_messages(_room_id, _limit) do
    # Placeholder - implement database query
    []
  end
  
  defp get_room_user_count(room_id) do
    topic = "chat:room:#{room_id}"
    Examples.PhoenixChannels.Presence.list(topic) |> map_size()
  end
  
  defp get_room_users(room_id) do
    topic = "chat:room:#{room_id}"
    
    Examples.PhoenixChannels.Presence.list(topic)
    |> Enum.map(fn {user_id, %{metas: [meta | _]}} ->
      %{
        user_id: user_id,
        username: meta.username,
        joined_at: meta.joined_at,
        status: meta.status
      }
    end)
  end
  
  defp track_rate_limit(socket) do
    # Initialize rate limiting for this socket
    assign(socket, :message_count, 0)
    |> assign(:rate_limit_window_start, System.monotonic_time(:millisecond))
  end
  
  defp check_rate_limit(socket) do
    now = System.monotonic_time(:millisecond)
    window_start = socket.assigns[:rate_limit_window_start] || now
    message_count = socket.assigns[:message_count] || 0
    
    if now - window_start > @rate_limit_window do
      # Reset window
      socket = assign(socket, :rate_limit_window_start, now)
      |> assign(:message_count, 1)
      :ok
    else
      if message_count >= @rate_limit_count do
        {:error, :rate_limited}
      else
        assign(socket, :message_count, message_count + 1)
        :ok
      end
    end
  end
end