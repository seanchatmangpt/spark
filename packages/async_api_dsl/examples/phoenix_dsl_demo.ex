defmodule Examples.PhoenixDslDemo do
  @moduledoc """
  Complete example demonstrating Phoenix channels using AsyncAPI DSL.
  
  This module shows how to create a full-featured chat channel with
  routing, validation, handlers, and scoped permissions.
  """
  
  use AsyncApi.PhoenixDsl, api: Examples.PhoenixChatApi
  
  # Global authentication requirement
  plug AsyncApi.ChannelPlugs.ensure_authenticated()
  plug AsyncApi.ChannelPlugs.log_event(level: :info)
  plug AsyncApi.ChannelPlugs.time_request()
  
  # Custom join logic
  join fn topic, payload, socket ->
    case authorize_join(topic, payload, socket) do
      {:ok, room_id} ->
        socket = socket
        |> assign(:room_id, room_id)
        |> assign(:joined_at, DateTime.utc_now())
        
        # Track presence
        Examples.PhoenixChannels.Presence.track_user(socket, socket.assigns.user_id, %{
          username: socket.assigns.username,
          room_id: room_id
        })
        
        {:ok, %{status: "joined", room_id: room_id}, socket}
        
      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end
  
  # Direct message handling
  event "message:create", Examples.PhoenixDslDemo.MessageHandler, :create
  event "message:update", Examples.PhoenixDslDemo.MessageHandler, :update
  event "message:delete", Examples.PhoenixDslDemo.MessageHandler, :delete
  
  # Inline handlers for simple operations
  handle "room:join", fn payload, bindings, socket ->
    room_id = socket.assigns.room_id
    user_info = %{
      user_id: socket.assigns.user_id,
      username: socket.assigns.username,
      room_id: room_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    broadcast_from(socket, "user:joined", user_info)
    {:reply, {:ok, %{status: "announced"}}, socket}
  end
  
  handle "room:leave", fn _payload, _bindings, socket ->
    user_info = %{
      user_id: socket.assigns.user_id,
      username: socket.assigns.username,
      room_id: socket.assigns.room_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    broadcast_from(socket, "user:left", user_info)
    {:stop, :normal, socket}
  end
  
  handle "typing:start", fn _payload, _bindings, socket ->
    typing_info = %{
      user_id: socket.assigns.user_id,
      username: socket.assigns.username,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    broadcast_from(socket, "typing:start", typing_info)
    {:noreply, socket}
  end
  
  handle "typing:stop", fn _payload, _bindings, socket ->
    typing_info = %{
      user_id: socket.assigns.user_id,
      username: socket.assigns.username,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    broadcast_from(socket, "typing:stop", typing_info)
    {:noreply, socket}
  end
  
  # Delegate all presence events to a dedicated handler
  delegate "presence:", Examples.PhoenixDslDemo.PresenceHandler
  
  # Admin scope with special permissions
  scope "admin:" do
    plug AsyncApi.ChannelPlugs.check_permission([:admin, :moderator])
    
    event "user:kick", Examples.PhoenixDslDemo.AdminHandler, :kick_user
    event "user:ban", Examples.PhoenixDslDemo.AdminHandler, :ban_user
    event "room:*", Examples.PhoenixDslDemo.AdminHandler, :manage_room
    
    handle "broadcast:all", fn payload, _bindings, socket ->
      admin_broadcast = %{
        message: payload["message"],
        from_admin: socket.assigns.username,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        type: "admin_broadcast"
      }
      
      # Broadcast to all rooms (implement your logic)
      broadcast_admin_message(admin_broadcast)
      
      {:reply, {:ok, %{status: "broadcast_sent"}}, socket}
    end
  end
  
  # Moderation scope
  scope "mod:" do
    plug AsyncApi.ChannelPlugs.check_permission([:moderator, :admin])
    plug AsyncApi.ChannelPlugs.rate_limit(window: 10_000, limit: 20)  # Stricter rate limiting
    
    event "message:flag", Examples.PhoenixDslDemo.ModerationHandler, :flag_message
    event "user:warn", Examples.PhoenixDslDemo.ModerationHandler, :warn_user
    event "user:mute", Examples.PhoenixDslDemo.ModerationHandler, :mute_user
  end
  
  # Catch-all for unknown events
  delegate Examples.PhoenixDslDemo.DefaultHandler
  
  # Private helper functions
  
  defp authorize_join(topic, payload, socket) do
    case extract_room_id_from_topic(topic) do
      {:ok, room_id} ->
        user_id = socket.assigns.user_id
        
        cond do
          not room_exists?(room_id) ->
            {:error, "room_not_found"}
            
          not user_can_join_room?(user_id, room_id) ->
            {:error, "access_denied"}
            
          room_is_full?(room_id) ->
            {:error, "room_full"}
            
          true ->
            {:ok, room_id}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp extract_room_id_from_topic(topic) do
    case String.split(topic, ":") do
      ["chat", "room", room_id] when room_id != "" ->
        {:ok, room_id}
        
      _ ->
        {:error, "invalid_topic_format"}
    end
  end
  
  defp room_exists?(room_id) do
    # Implement your room existence check
    # This could query a database, check Redis, etc.
    room_id != "nonexistent"
  end
  
  defp user_can_join_room?(user_id, room_id) do
    # Implement your authorization logic
    # Check if user is banned, has required permissions, etc.
    not user_banned_from_room?(user_id, room_id)
  end
  
  defp user_banned_from_room?(_user_id, _room_id) do
    # Implement ban checking logic
    false
  end
  
  defp room_is_full?(room_id) do
    # Check if room has reached maximum capacity
    current_count = Examples.PhoenixChannels.Presence.get_room_user_count(room_id)
    max_capacity = get_room_max_capacity(room_id)
    
    current_count >= max_capacity
  end
  
  defp get_room_max_capacity(_room_id) do
    # Get room-specific capacity or default
    Application.get_env(:async_api_dsl, :default_room_capacity, 100)
  end
  
  defp broadcast_admin_message(message) do
    # Broadcast admin message to all rooms
    # This is a simplified implementation
    Phoenix.PubSub.broadcast(MyApp.PubSub, "admin:broadcasts", {:admin_broadcast, message})
  end
end

# Message Handler
defmodule Examples.PhoenixDslDemo.MessageHandler do
  use AsyncApi.ChannelHandler
  
  # Rate limiting for message creation
  plug AsyncApi.ChannelPlugs.rate_limit(window: 60_000, limit: 30) when action in [:create]
  
  # Validation for all message operations
  plug AsyncApi.ChannelPlugs.validate_payload(required: ["content"]) when action in [:create, :update]
  
  def create(payload, _bindings, socket) do
    message_data = %{
      id: AsyncApi.ChannelHandler.generate_id(),
      content: payload["content"],
      author: %{
        id: AsyncApi.ChannelHandler.current_user_id(socket),
        username: socket.assigns.username,
        avatar_url: payload["author"]["avatar_url"]
      },
      room_id: socket.assigns.room_id,
      timestamp: AsyncApi.ChannelHandler.timestamp(),
      message_type: payload["message_type"] || "text",
      metadata: payload["metadata"] || %{}
    }
    
    case create_message(message_data) do
      {:ok, message} ->
        broadcast_from(socket, "message:created", message)
        AsyncApi.ChannelHandler.reply_success(socket, message)
        
      {:error, reason} ->
        AsyncApi.ChannelHandler.reply_error(socket, "creation_failed", %{details: reason})
    end
  end
  
  def update(payload, bindings, socket) do
    message_id = AsyncApi.ChannelHandler.get_binding(bindings, "message_id")
    user_id = AsyncApi.ChannelHandler.current_user_id(socket)
    
    case update_message(message_id, payload, user_id) do
      {:ok, message} ->
        broadcast_from(socket, "message:updated", message)
        AsyncApi.ChannelHandler.reply_success(socket, message)
        
      {:error, :not_found} ->
        AsyncApi.ChannelHandler.reply_error(socket, "message_not_found")
        
      {:error, :unauthorized} ->
        AsyncApi.ChannelHandler.reply_error(socket, "unauthorized")
        
      {:error, reason} ->
        AsyncApi.ChannelHandler.reply_error(socket, "update_failed", %{details: reason})
    end
  end
  
  def delete(payload, bindings, socket) do
    message_id = AsyncApi.ChannelHandler.get_binding(bindings, "message_id")
    user_id = AsyncApi.ChannelHandler.current_user_id(socket)
    
    case delete_message(message_id, user_id) do
      {:ok, message} ->
        broadcast_from(socket, "message:deleted", %{message_id: message.id})
        AsyncApi.ChannelHandler.reply_success(socket, %{deleted: true})
        
      {:error, :not_found} ->
        AsyncApi.ChannelHandler.reply_error(socket, "message_not_found")
        
      {:error, :unauthorized} ->
        AsyncApi.ChannelHandler.reply_error(socket, "unauthorized")
    end
  end
  
  # Private business logic functions
  
  defp create_message(message_data) do
    # Simulate message creation - replace with actual database logic
    {:ok, message_data}
  end
  
  defp update_message(message_id, payload, user_id) do
    # Simulate message update - replace with actual database logic
    case find_message(message_id) do
      {:ok, message} ->
        if message.author.id == user_id do
          updated_message = %{message | 
            content: payload["content"],
            updated_at: AsyncApi.ChannelHandler.timestamp()
          }
          {:ok, updated_message}
        else
          {:error, :unauthorized}
        end
        
      error ->
        error
    end
  end
  
  defp delete_message(message_id, user_id) do
    # Simulate message deletion - replace with actual database logic
    case find_message(message_id) do
      {:ok, message} ->
        if message.author.id == user_id do
          {:ok, message}
        else
          {:error, :unauthorized}
        end
        
      error ->
        error
    end
  end
  
  defp find_message(_message_id) do
    # Simulate message lookup - replace with actual database logic
    {:error, :not_found}
  end
end

# Presence Handler
defmodule Examples.PhoenixDslDemo.PresenceHandler do
  use AsyncApi.ChannelHandler
  
  def handle_in("presence:" <> event, payload, bindings, socket) do
    case event do
      "get_users" ->
        users = Examples.PhoenixChannels.Presence.list_room_users(socket.assigns.room_id)
        AsyncApi.ChannelHandler.reply_success(socket, %{users: users})
        
      "update_status" ->
        status = payload["status"]
        user_id = AsyncApi.ChannelHandler.current_user_id(socket)
        
        case Examples.PhoenixChannels.Presence.update_user_status(socket, user_id, status) do
          {:ok, _meta} ->
            broadcast_from(socket, "presence:status_updated", %{
              user_id: user_id,
              status: status,
              timestamp: AsyncApi.ChannelHandler.timestamp()
            })
            AsyncApi.ChannelHandler.reply_success(socket)
            
          {:error, reason} ->
            AsyncApi.ChannelHandler.reply_error(socket, "status_update_failed", %{reason: reason})
        end
        
      _ ->
        AsyncApi.ChannelHandler.reply_error(socket, "unknown_presence_event", %{event: event})
    end
  end
end

# Admin Handler
defmodule Examples.PhoenixDslDemo.AdminHandler do
  use AsyncApi.ChannelHandler
  
  def kick_user(payload, _bindings, socket) do
    target_user_id = payload["user_id"]
    reason = payload["reason"] || "No reason provided"
    
    # Implement user kicking logic
    case kick_user_from_room(target_user_id, socket.assigns.room_id, reason) do
      :ok ->
        broadcast_from(socket, "admin:user_kicked", %{
          user_id: target_user_id,
          reason: reason,
          kicked_by: socket.assigns.username,
          timestamp: AsyncApi.ChannelHandler.timestamp()
        })
        AsyncApi.ChannelHandler.reply_success(socket)
        
      {:error, reason} ->
        AsyncApi.ChannelHandler.reply_error(socket, "kick_failed", %{reason: reason})
    end
  end
  
  def ban_user(payload, _bindings, socket) do
    target_user_id = payload["user_id"]
    reason = payload["reason"] || "No reason provided"
    duration = payload["duration"]  # in minutes, nil for permanent
    
    case ban_user_from_room(target_user_id, socket.assigns.room_id, reason, duration) do
      :ok ->
        broadcast_from(socket, "admin:user_banned", %{
          user_id: target_user_id,
          reason: reason,
          duration: duration,
          banned_by: socket.assigns.username,
          timestamp: AsyncApi.ChannelHandler.timestamp()
        })
        AsyncApi.ChannelHandler.reply_success(socket)
        
      {:error, reason} ->
        AsyncApi.ChannelHandler.reply_error(socket, "ban_failed", %{reason: reason})
    end
  end
  
  def manage_room(payload, bindings, socket) do
    action = AsyncApi.ChannelHandler.get_binding(bindings, "wildcard_1")
    
    case action do
      "lock" ->
        lock_room(socket.assigns.room_id)
        broadcast_from(socket, "room:locked", %{
          locked_by: socket.assigns.username,
          timestamp: AsyncApi.ChannelHandler.timestamp()
        })
        AsyncApi.ChannelHandler.reply_success(socket)
        
      "unlock" ->
        unlock_room(socket.assigns.room_id)
        broadcast_from(socket, "room:unlocked", %{
          unlocked_by: socket.assigns.username,
          timestamp: AsyncApi.ChannelHandler.timestamp()
        })
        AsyncApi.ChannelHandler.reply_success(socket)
        
      _ ->
        AsyncApi.ChannelHandler.reply_error(socket, "unknown_room_action", %{action: action})
    end
  end
  
  defp kick_user_from_room(_user_id, _room_id, _reason), do: :ok
  defp ban_user_from_room(_user_id, _room_id, _reason, _duration), do: :ok
  defp lock_room(_room_id), do: :ok
  defp unlock_room(_room_id), do: :ok
end

# Moderation Handler
defmodule Examples.PhoenixDslDemo.ModerationHandler do
  use AsyncApi.ChannelHandler
  
  def flag_message(payload, _bindings, socket) do
    message_id = payload["message_id"]
    reason = payload["reason"]
    
    case flag_message_for_review(message_id, reason, socket.assigns.user_id) do
      :ok ->
        # Notify moderators
        broadcast_to_moderators("message:flagged", %{
          message_id: message_id,
          reason: reason,
          flagged_by: socket.assigns.username,
          timestamp: AsyncApi.ChannelHandler.timestamp()
        })
        
        AsyncApi.ChannelHandler.reply_success(socket)
        
      {:error, reason} ->
        AsyncApi.ChannelHandler.reply_error(socket, "flag_failed", %{reason: reason})
    end
  end
  
  def warn_user(payload, _bindings, socket) do
    target_user_id = payload["user_id"]
    warning_message = payload["message"]
    
    case issue_warning(target_user_id, warning_message, socket.assigns.user_id) do
      :ok ->
        # Send warning to target user
        send_warning_to_user(target_user_id, warning_message, socket.assigns.username)
        AsyncApi.ChannelHandler.reply_success(socket)
        
      {:error, reason} ->
        AsyncApi.ChannelHandler.reply_error(socket, "warning_failed", %{reason: reason})
    end
  end
  
  def mute_user(payload, _bindings, socket) do
    target_user_id = payload["user_id"]
    duration = payload["duration"] || 300  # 5 minutes default
    
    case mute_user_in_room(target_user_id, socket.assigns.room_id, duration) do
      :ok ->
        broadcast_from(socket, "user:muted", %{
          user_id: target_user_id,
          duration: duration,
          muted_by: socket.assigns.username,
          timestamp: AsyncApi.ChannelHandler.timestamp()
        })
        AsyncApi.ChannelHandler.reply_success(socket)
        
      {:error, reason} ->
        AsyncApi.ChannelHandler.reply_error(socket, "mute_failed", %{reason: reason})
    end
  end
  
  defp flag_message_for_review(_message_id, _reason, _flagger_id), do: :ok
  defp issue_warning(_target_user_id, _message, _moderator_id), do: :ok
  defp mute_user_in_room(_user_id, _room_id, _duration), do: :ok
  defp broadcast_to_moderators(_event, _payload), do: :ok
  defp send_warning_to_user(_user_id, _message, _moderator_name), do: :ok
end

# Default Handler (catch-all)
defmodule Examples.PhoenixDslDemo.DefaultHandler do
  use AsyncApi.ChannelHandler
  
  def handle_in(event, payload, bindings, socket) do
    Logger.warning("Unhandled event: #{event} with payload: #{inspect(payload)}")
    
    AsyncApi.ChannelHandler.reply_error(socket, "unknown_event", %{
      event: event,
      suggestion: "Check the API documentation for supported events"
    })
  end
end