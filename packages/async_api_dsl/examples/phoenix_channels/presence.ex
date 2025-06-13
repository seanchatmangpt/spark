defmodule Examples.PhoenixChannels.Presence do
  @moduledoc """
  Phoenix Presence implementation for chat application.
  
  Tracks user presence across chat rooms and provides real-time updates
  when users join, leave, or change their status.
  """
  
  use Phoenix.Presence,
    otp_app: :async_api_dsl,
    pubsub_server: MyApp.PubSub
  
  alias Examples.PhoenixChatApi
  alias AsyncApi.Validator
  require Logger
  
  @doc """
  Track a user's presence in a chat room.
  """
  def track_user(socket, user_id, user_data \\ %{}) do
    default_data = %{
      online_at: System.system_time(:second),
      username: user_data[:username] || "Anonymous",
      status: "online",
      room_id: socket.assigns[:room_id]
    }
    
    meta = Map.merge(default_data, user_data)
    track(socket, user_id, meta)
  end
  
  @doc """
  Get all users currently present in a room.
  """
  def list_room_users(room_id) do
    topic = "chat:room:#{room_id}"
    
    list(topic)
    |> Enum.map(fn {user_id, %{metas: metas}} ->
      # Get the most recent meta (last in list)
      meta = List.last(metas)
      
      %{
        user_id: user_id,
        username: meta.username,
        status: meta.status,
        online_at: meta.online_at,
        room_id: meta.room_id
      }
    end)
    |> Enum.sort_by(& &1.online_at, :desc)
  end
  
  @doc """
  Get user count for a specific room.
  """
  def get_room_user_count(room_id) do
    topic = "chat:room:#{room_id}"
    list(topic) |> map_size()
  end
  
  @doc """
  Update user status (online, away, busy, etc.).
  """
  def update_user_status(socket, user_id, status) when status in ["online", "away", "busy", "offline"] do
    case get_by_key(socket.topic, user_id) do
      [] -> 
        {:error, :user_not_found}
        
      presences ->
        # Get current meta and update status
        current_meta = presences |> List.last() |> Map.get(:metas) |> List.last()
        updated_meta = Map.put(current_meta, :status, status)
        
        # Update presence
        update(socket, user_id, updated_meta)
        
        # Broadcast status change
        broadcast_status_change(socket, user_id, updated_meta)
        
        {:ok, updated_meta}
    end
  end
  
  @doc """
  Get all rooms where a user is currently present.
  """
  def get_user_rooms(user_id) do
    # This is a simplified implementation
    # In a real app, you might want to maintain a separate index
    all_rooms = ["general", "random", "tech", "gaming"]  # Replace with actual room list
    
    Enum.filter(all_rooms, fn room_id ->
      topic = "chat:room:#{room_id}"
      case get_by_key(topic, user_id) do
        [] -> false
        _ -> true
      end
    end)
  end
  
  @doc """
  Handle presence diffs and broadcast appropriate messages.
  """
  def handle_diff(socket, diff) do
    room_id = socket.assigns[:room_id]
    
    # Handle joins
    for {user_id, %{metas: metas}} <- diff.joins do
      meta = List.last(metas)
      
      presence_update = %{
        user_id: user_id,
        username: meta.username,
        status: meta.status,
        room_id: room_id,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        metadata: %{
          online_at: meta.online_at
        }
      }
      
      case Validator.validate_message(PhoenixChatApi, :presenceUpdate, presence_update) do
        :ok ->
          Phoenix.Channel.broadcast(socket, "presence_state", %{
            event: "user_joined",
            user: presence_update
          })
          
        {:error, errors} ->
          Logger.error("Invalid presence update for join: #{inspect(errors)}")
      end
    end
    
    # Handle leaves
    for {user_id, %{metas: metas}} <- diff.leaves do
      meta = List.last(metas)
      
      presence_update = %{
        user_id: user_id,
        username: meta.username,
        status: "offline",
        room_id: room_id,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        metadata: %{
          online_at: meta.online_at
        }
      }
      
      case Validator.validate_message(PhoenixChatApi, :presenceUpdate, presence_update) do
        :ok ->
          Phoenix.Channel.broadcast(socket, "presence_state", %{
            event: "user_left",
            user: presence_update
          })
          
        {:error, errors} ->
          Logger.error("Invalid presence update for leave: #{inspect(errors)}")
      end
    end
    
    :ok
  end
  
  @doc """
  Get presence statistics for monitoring.
  """
  def get_presence_stats do
    # Get stats across all rooms
    all_rooms = ["general", "random", "tech", "gaming"]  # Replace with actual room list
    
    stats = Enum.map(all_rooms, fn room_id ->
      topic = "chat:room:#{room_id}"
      user_count = list(topic) |> map_size()
      
      users_by_status = list(topic)
      |> Enum.group_by(fn {_user_id, %{metas: metas}} ->
        List.last(metas).status
      end)
      |> Enum.map(fn {status, users} -> {status, length(users)} end)
      |> Enum.into(%{})
      
      %{
        room_id: room_id,
        total_users: user_count,
        users_by_status: users_by_status
      }
    end)
    
    total_users = Enum.sum(Enum.map(stats, & &1.total_users))
    
    %{
      total_users: total_users,
      room_stats: stats,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end
  
  # Private helper functions
  
  defp broadcast_status_change(socket, user_id, meta) do
    room_id = socket.assigns[:room_id]
    
    presence_update = %{
      user_id: user_id,
      username: meta.username,
      status: meta.status,
      room_id: room_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      metadata: %{
        online_at: meta.online_at
      }
    }
    
    case Validator.validate_message(PhoenixChatApi, :presenceUpdate, presence_update) do
      :ok ->
        Phoenix.Channel.broadcast(socket, "presence_state", %{
          event: "status_changed",
          user: presence_update
        })
        
      {:error, errors} ->
        Logger.error("Invalid presence update for status change: #{inspect(errors)}")
    end
  end
end