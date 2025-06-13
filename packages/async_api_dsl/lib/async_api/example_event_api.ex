defmodule AsyncApi.ExampleEventApi do
  @moduledoc """
  Example Event API showcasing Phoenix Channel integration with AsyncAPI.
  
  This module demonstrates how to integrate Phoenix Channels with AsyncAPI
  specifications, providing real-time WebSocket communication with full
  AsyncAPI documentation and validation.
  """

  use AsyncApi
  use GenServer
  
  require Logger

  # AsyncAPI Specification with Phoenix Channel focus
  info do
    title "Phoenix Channel Event API"
    version "1.0.0"
    description """
    Real-time event API using Phoenix Channels with complete AsyncAPI
    specification for WebSocket communication patterns.
    """
  end

  servers do
    server :phoenix_endpoint, "ws://localhost:4000/socket" do
      protocol :websockets
      description "Phoenix WebSocket endpoint"
      
      bindings [
        websockets: [
          query: %{
            token: %{
              description: "Authentication token for channel access",
              type: :string
            },
            vsn: %{
              description: "Phoenix channel version",
              type: :string,
              default: "2.0.0"
            }
          }
        ]
      ]
    end
  end

  channels do
    channel "room:lobby" do
      description "Main lobby chat room"
      
      bindings [
        websockets: [
          method: "GET",
          query: %{
            room_id: %{
              type: :string,
              description: "Room identifier"
            }
          },
          headers: %{
            "X-User-ID" => %{
              type: :string,
              description: "User identifier"
            }
          }
        ]
      ]
    end
    
    channel "user:{user_id}" do
      description "Private user channel"
      
      parameter :user_id do
        description "User ID for private channel"
        schema [type: :string, format: "uuid"]
      end
    end
    
    channel "presence:room:{room_id}" do
      description "Room presence tracking"
      
      parameter :room_id do
        description "Room ID for presence tracking"
        schema [type: :string]
      end
    end
  end

  components do
    schemas do
      schema :chat_message do
        type :object
        description "Chat message payload"
        
        property :id, :string do
          description "Message ID"
          format "uuid"
        end
        
        property :user_id, :string do
          description "Sender user ID"
          format "uuid"
        end
        
        property :username, :string do
          description "Sender username"
          min_length 1
          max_length 50
        end
        
        property :content, :string do
          description "Message content"
          min_length 1
          max_length 1000
        end
        
        property :timestamp, :string do
          description "Message timestamp"
          format "date-time"
        end
        
        property :room_id, :string do
          description "Room identifier"
        end
        
        required [:id, :user_id, :username, :content, :timestamp]
      end
      
      schema :user_presence do
        type :object
        description "User presence information"
        
        property :user_id, :string do
          description "User ID"
          format "uuid"
        end
        
        property :username, :string do
          description "Username"
        end
        
        property :status, :string do
          description "User status"
          enum ["online", "away", "busy", "offline"]
        end
        
        property :joined_at, :string do
          description "When user joined"
          format "date-time"
        end
        
        property :metadata, :object do
          description "Additional user metadata"
          additional_properties true
        end
        
        required [:user_id, :username, :status, :joined_at]
      end
      
      schema :typing_indicator do
        type :object
        description "Typing indicator event"
        
        property :user_id, :string do
          description "User who is typing"
          format "uuid"
        end
        
        property :username, :string do
          description "Username of typing user"
        end
        
        property :is_typing, :boolean do
          description "Whether user is currently typing"
        end
        
        property :room_id, :string do
          description "Room where typing is occurring"
        end
        
        required [:user_id, :username, :is_typing]
      end
    end

    messages do
      message :chat_message do
        title "Chat Room Message"
        summary "Message sent in a chat room"
        content_type "application/json"
        payload :chat_message
      end
    
      message :user_joined do
        title "User Joined Channel"
        summary "Event when user joins a channel"
        content_type "application/json"
        payload :user_presence
      end
    
    message :user_left do
      title "User Left Channel"  
      summary "Event when user leaves a channel"
      content_type "application/json"
      payload :user_presence
    end
    
    message :typing_event do
      title "User Typing Indicator"
      summary "Real-time typing indicator"
      content_type "application/json"
      payload :typing_indicator
    end
    end
  end

  operations do
    operation :sendChatMessage do
      action :send
      channel "room:lobby"
      message :chat_message
      summary "Send chat message to room"
      description "Send a chat message to the specified room"
      
      bindings [
        websockets: [
          event: "new_message",
          ack: true
        ]
      ]
    end
    
    operation :receiveChatMessage do
      action :receive
      channel "room:lobby"
      message :chat_message
      summary "Receive chat messages from room"
      description "Subscribe to chat messages in the room"
      
      bindings [
        websockets: [
          event: "new_message"
        ]
      ]
    end
    
    operation :joinRoom do
      action :send
      channel "room:lobby"
      message :user_joined
      summary "Join chat room"
      description "Join a chat room and announce presence"
      
      bindings [
        websockets: [
          event: "phx_join",
          ack: true
        ]
      ]
    end
    
    operation :leaveRoom do
      action :send
      channel "room:lobby"
      message :user_left
      summary "Leave chat room"
      description "Leave chat room and announce departure"
      
      bindings [
        websockets: [
          event: "phx_leave"
        ]
      ]
    end
    
    operation :userJoined do
      action :receive
      channel "room:lobby"
      message :user_joined
      summary "Receive user joined events"
      description "Get notified when users join the room"
      
      bindings [
        websockets: [
          event: "user_joined"
        ]
      ]
    end
    
    operation :userLeft do
      action :receive
      channel "room:lobby"
      message :user_left
      summary "Receive user left events"
      description "Get notified when users leave the room"
      
      bindings [
        websockets: [
          event: "user_left"
        ]
      ]
    end
    
    operation :startTyping do
      action :send
      channel "room:lobby"
      message :typing_event
      summary "Indicate user is typing"
      description "Send typing indicator to room"
      
      bindings [
        websockets: [
          event: "typing_start"
        ]
      ]
    end
    
    operation :stopTyping do
      action :send
      channel "room:lobby"
      message :typing_event
      summary "Indicate user stopped typing"
      description "Send stop typing indicator to room"
      
      bindings [
        websockets: [
          event: "typing_stop"
        ]
      ]
    end
    
    operation :receiveTyping do
      action :receive
      channel "room:lobby"
      message :typing_event
      summary "Receive typing indicators"
      description "Get notified of typing activity in room"
      
      bindings [
        websockets: [
          event: "typing"
        ]
      ]
    end
    
    operation :sendPrivateMessage do
      action :send
      channel "user:{user_id}"
      message :chat_message
      summary "Send private message"
      description "Send private message to specific user"
      
      bindings [
        websockets: [
          event: "private_message",
          ack: true
        ]
      ]
    end
    
    operation :receivePrivateMessage do
      action :receive
      channel "user:{user_id}"
      message :chat_message
      summary "Receive private messages"
      description "Subscribe to private messages"
      
      bindings [
        websockets: [
          event: "private_message"
        ]
      ]
    end
  end

  # GenServer implementation
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Starting Example Event API (Phoenix Channels)...")
    
    state = %{
      opts: opts,
      active_rooms: %{},
      user_presence: %{},
      message_history: [],
      start_time: System.system_time(:millisecond)
    }
    
    # Start simulating channel activity
    schedule_channel_activity()
    
    {:ok, state}
  end

  @impl true
  def handle_info(:channel_activity, state) do
    # Simulate Phoenix Channel activity
    simulate_chat_message(state)
    simulate_user_presence_change(state)
    
    # Schedule next activity
    schedule_channel_activity()
    
    {:noreply, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      uptime: System.system_time(:millisecond) - state.start_time,
      active_rooms: map_size(state.active_rooms),
      online_users: map_size(state.user_presence),
      message_count: length(state.message_history)
    }
    
    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:chat_message, message}, state) do
    Logger.debug("Processing chat message: #{inspect(message)}")
    
    updated_history = [message | state.message_history]
    |> Enum.take(100)  # Keep last 100 messages
    
    {:noreply, %{state | message_history: updated_history}}
  end

  @impl true
  def handle_cast({:user_joined, user}, state) do
    Logger.info("User joined: #{user.username}")
    
    updated_presence = Map.put(state.user_presence, user.user_id, user)
    
    {:noreply, %{state | user_presence: updated_presence}}
  end

  @impl true
  def handle_cast({:user_left, user}, state) do
    Logger.info("User left: #{user.username}")
    
    updated_presence = Map.delete(state.user_presence, user.user_id)
    
    {:noreply, %{state | user_presence: updated_presence}}
  end

  # Public API functions
  def send_chat_message(message) do
    GenServer.cast(__MODULE__, {:chat_message, message})
  end

  def user_joined(user) do
    GenServer.cast(__MODULE__, {:user_joined, user})
  end

  def user_left(user) do
    GenServer.cast(__MODULE__, {:user_left, user})
  end

  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  def get_online_users do
    GenServer.call(__MODULE__, :get_online_users)
  end

  def get_recent_messages(limit \\ 10) do
    GenServer.call(__MODULE__, {:get_recent_messages, limit})
  end

  # Private helper functions
  defp schedule_channel_activity do
    # Schedule next activity in 3-8 seconds
    delay = 3000 + :rand.uniform(5000)
    Process.send_after(self(), :channel_activity, delay)
  end

  defp simulate_chat_message(state) do
    usernames = ["alice", "bob", "charlie", "diana", "eve"]
    messages = [
      "Hello everyone!",
      "How's everyone doing?",
      "Great weather today!",
      "Anyone working on interesting projects?",
      "Thanks for the help earlier",
      "See you all later!",
      "Good morning!",
      "Have a great day!"
    ]
    
    message = %{
      id: "msg_#{:rand.uniform(100000)}",
      user_id: "user_#{:rand.uniform(1000)}",
      username: Enum.random(usernames),
      content: Enum.random(messages),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      room_id: "lobby"
    }
    
    send_chat_message(message)
  end

  defp simulate_user_presence_change(state) do
    usernames = ["alice", "bob", "charlie", "diana", "eve"]
    
    if :rand.uniform() > 0.7 do
      # Simulate user joining
      user = %{
        user_id: "user_#{:rand.uniform(1000)}",
        username: Enum.random(usernames),
        status: "online",
        joined_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        metadata: %{
          device: Enum.random(["web", "mobile", "desktop"]),
          location: Enum.random(["US", "UK", "CA", "AU"])
        }
      }
      
      user_joined(user)
    end
  end
end