defmodule Examples.PhoenixChatApi do
  @moduledoc """
  AsyncAPI specification for a Phoenix-based chat application.
  
  This example demonstrates how to define a complete chat API using AsyncAPI DSL
  that can be used to generate Phoenix channels and WebSocket endpoints.
  """
  
  use AsyncApi

  # Root-level configuration
  id "urn:com:example:phoenix-chat"
  default_content_type "application/json"

  info do
    title "Phoenix Chat API"
    version "1.0.0"
    description """
    Real-time chat application API built with Phoenix WebSockets.
    
    Supports multiple chat rooms, private messages, user presence tracking,
    and real-time notifications.
    """
    
    contact do
      name "Chat API Support"
      url "https://example.com/support"
      email "chat-support@example.com"
    end
    
    license do
      name "MIT"
      url "https://opensource.org/licenses/MIT"
    end
    
    tags do
      tag :chat do
        name "Chat"
        description "Chat room operations"
      end
      
      tag :presence do
        name "Presence"
        description "User presence tracking"
      end
      
      tag :notifications do
        name "Notifications"
        description "Real-time notifications"
      end
    end
  end

  servers do
    server :production, "wss://chat.example.com" do
      protocol :websockets
      description "Production WebSocket server"
      
      variables do
        variable :environment do
          default "prod"
          description "Environment name"
          enum ["prod", "staging"]
        end
      end
      
      bindings [
        websockets: [
          method: "GET",
          headers: %{
            "Authorization" => %{
              type: "string",
              description: "Bearer token for authentication"
            }
          }
        ]
      ]
    end
    
    server :development, "ws://localhost:4000" do
      protocol :websockets
      description "Development WebSocket server"
    end
  end

  channels do
    channel "/chat/room/{roomId}" do
      description "Chat room for real-time messaging"
      
      parameters do
        parameter :roomId do
          description "Unique identifier for the chat room"
          schema do
            type :string
            pattern "^[a-zA-Z0-9_-]+$"
            min_length 1
            max_length 50
          end
        end
      end
      
      bindings [
        websockets: [
          method: "GET",
          query: %{
            "user_id" => %{
              type: "string",
              description: "ID of the user joining the room"
            }
          }
        ]
      ]
    end
    
    channel "/chat/private/{userId}" do
      description "Private messaging channel between two users"
      
      parameters do
        parameter :userId do
          description "ID of the user to chat with"
          schema do
            type :string
            format "uuid"
          end
        end
      end
    end
    
    channel "/presence/room/{roomId}" do
      description "User presence tracking for a specific room"
      
      parameters do
        parameter :roomId do
          description "Room ID for presence tracking"
          schema do
            type :string
            pattern "^[a-zA-Z0-9_-]+$"
          end
        end
      end
    end
    
    channel "/notifications/user/{userId}" do
      description "Personal notifications channel"
      
      parameters do
        parameter :userId do
          description "User ID for notifications"
          schema do
            type :string
            format "uuid"
          end
        end
      end
    end
  end

  operations do
    # Chat room operations
    operation :sendMessage do
      action :send
      channel "/chat/room/{roomId}"
      summary "Send a message to a chat room"
      description "Sends a new message to all users in the specified chat room"
      message :chatMessage
      tags [:chat]
      
      reply do
        address "/chat/room/{roomId}/ack"
        message :messageAcknowledgment
      end
    end
    
    operation :receiveMessage do
      action :receive
      channel "/chat/room/{roomId}"
      summary "Receive messages from a chat room"
      description "Receives new messages sent to the chat room"
      message :chatMessage
      tags [:chat]
    end
    
    operation :joinRoom do
      action :send
      channel "/chat/room/{roomId}"
      summary "Join a chat room"
      description "Join a chat room and start receiving messages"
      message :joinRoomMessage
      tags [:chat]
    end
    
    operation :leaveRoom do
      action :send
      channel "/chat/room/{roomId}"
      summary "Leave a chat room"
      description "Leave a chat room and stop receiving messages"
      message :leaveRoomMessage
      tags [:chat]
    end
    
    # Private messaging operations
    operation :sendPrivateMessage do
      action :send
      channel "/chat/private/{userId}"
      summary "Send a private message"
      description "Send a private message to another user"
      message :privateMessage
      tags [:chat]
    end
    
    operation :receivePrivateMessage do
      action :receive
      channel "/chat/private/{userId}"
      summary "Receive private messages"
      description "Receive private messages from other users"
      message :privateMessage
      tags [:chat]
    end
    
    # Presence operations
    operation :userJoined do
      action :receive
      channel "/presence/room/{roomId}"
      summary "User joined room notification"
      description "Notification when a user joins the room"
      message :presenceUpdate
      tags [:presence]
    end
    
    operation :userLeft do
      action :receive
      channel "/presence/room/{roomId}"
      summary "User left room notification"
      description "Notification when a user leaves the room"
      message :presenceUpdate
      tags [:presence]
    end
    
    # Notification operations
    operation :receiveNotification do
      action :receive
      channel "/notifications/user/{userId}"
      summary "Receive personal notifications"
      description "Receive real-time notifications for the user"
      message :notification
      tags [:notifications]
    end
  end

  components do
    messages do
      message :chatMessage do
        title "Chat Message"
        summary "A message sent in a chat room"
        description "Represents a chat message with content, author, and metadata"
        payload :chatMessagePayload
        
        headers do
          header "x-message-id" do
            description "Unique message identifier"
            schema do
              type :string
              format "uuid"
            end
          end
          
          header "x-timestamp" do
            description "Message timestamp"
            schema do
              type :string
              format "date-time"
            end
          end
        end
      end
      
      message :privateMessage do
        title "Private Message"
        summary "A private message between two users"
        payload :privateMessagePayload
      end
      
      message :joinRoomMessage do
        title "Join Room Message"
        summary "Message sent when joining a room"
        payload :joinRoomPayload
      end
      
      message :leaveRoomMessage do
        title "Leave Room Message"
        summary "Message sent when leaving a room"
        payload :leaveRoomPayload
      end
      
      message :presenceUpdate do
        title "Presence Update"
        summary "User presence change notification"
        payload :presenceUpdatePayload
      end
      
      message :notification do
        title "User Notification"
        summary "Real-time notification for a user"
        payload :notificationPayload
      end
      
      message :messageAcknowledgment do
        title "Message Acknowledgment"
        summary "Confirmation that a message was received"
        payload :messageAckPayload
      end
    end

    schemas do
      schema :chatMessagePayload do
        type :object
        description "Payload for chat messages"
        
        property :id, :string do
          description "Unique message identifier"
          format "uuid"
        end
        
        property :content, :string do
          description "Message content"
          min_length 1
          max_length 1000
        end
        
        property :author, :object do
          description "Message author information"
          
          property :id, :string do
            description "Author user ID"
            format "uuid"
          end
          
          property :username, :string do
            description "Author username"
            min_length 1
            max_length 50
          end
          
          property :avatar_url, :string do
            description "Author avatar URL"
            format "uri"
          end
          
          required [:id, :username]
        end
        
        property :room_id, :string do
          description "Chat room identifier"
        end
        
        property :timestamp, :string do
          description "Message timestamp"
          format "date-time"
        end
        
        property :message_type, :string do
          description "Type of message"
          enum ["text", "image", "file", "system"]
          default "text"
        end
        
        property :metadata, :object do
          description "Additional message metadata"
          additional_properties true
        end
        
        required [:id, :content, :author, :room_id, :timestamp]
      end
      
      schema :privateMessagePayload do
        type :object
        description "Payload for private messages"
        
        property :id, :string do
          description "Unique message identifier"
          format "uuid"
        end
        
        property :content, :string do
          description "Message content"
          min_length 1
          max_length 1000
        end
        
        property :from_user_id, :string do
          description "Sender user ID"
          format "uuid"
        end
        
        property :to_user_id, :string do
          description "Recipient user ID"
          format "uuid"
        end
        
        property :timestamp, :string do
          description "Message timestamp"
          format "date-time"
        end
        
        property :read, :boolean do
          description "Whether the message has been read"
          default false
        end
        
        required [:id, :content, :from_user_id, :to_user_id, :timestamp]
      end
      
      schema :joinRoomPayload do
        type :object
        description "Payload when joining a room"
        
        property :user_id, :string do
          description "User ID joining the room"
          format "uuid"
        end
        
        property :username, :string do
          description "Username of the joining user"
        end
        
        property :room_id, :string do
          description "Room being joined"
        end
        
        property :timestamp, :string do
          description "Join timestamp"
          format "date-time"
        end
        
        required [:user_id, :username, :room_id, :timestamp]
      end
      
      schema :leaveRoomPayload do
        type :object
        description "Payload when leaving a room"
        
        property :user_id, :string do
          description "User ID leaving the room"
          format "uuid"
        end
        
        property :room_id, :string do
          description "Room being left"
        end
        
        property :timestamp, :string do
          description "Leave timestamp"
          format "date-time"
        end
        
        required [:user_id, :room_id, :timestamp]
      end
      
      schema :presenceUpdatePayload do
        type :object
        description "User presence update information"
        
        property :user_id, :string do
          description "User ID"
          format "uuid"
        end
        
        property :username, :string do
          description "Username"
        end
        
        property :status, :string do
          description "Presence status"
          enum ["online", "away", "busy", "offline"]
        end
        
        property :room_id, :string do
          description "Room ID"
        end
        
        property :timestamp, :string do
          description "Status change timestamp"
          format "date-time"
        end
        
        property :metadata, :object do
          description "Additional presence metadata"
          additional_properties true
        end
        
        required [:user_id, :username, :status, :room_id, :timestamp]
      end
      
      schema :notificationPayload do
        type :object
        description "User notification payload"
        
        property :id, :string do
          description "Notification ID"
          format "uuid"
        end
        
        property :type, :string do
          description "Notification type"
          enum ["mention", "direct_message", "room_invite", "system"]
        end
        
        property :title, :string do
          description "Notification title"
        end
        
        property :message, :string do
          description "Notification message"
        end
        
        property :user_id, :string do
          description "Target user ID"
          format "uuid"
        end
        
        property :from_user_id, :string do
          description "Source user ID (if applicable)"
          format "uuid"
        end
        
        property :room_id, :string do
          description "Related room ID (if applicable)"
        end
        
        property :timestamp, :string do
          description "Notification timestamp"
          format "date-time"
        end
        
        property :read, :boolean do
          description "Whether notification has been read"
          default false
        end
        
        property :action_url, :string do
          description "URL for notification action"
          format "uri"
        end
        
        required [:id, :type, :title, :message, :user_id, :timestamp]
      end
      
      schema :messageAckPayload do
        type :object
        description "Message acknowledgment payload"
        
        property :message_id, :string do
          description "ID of the acknowledged message"
          format "uuid"
        end
        
        property :status, :string do
          description "Acknowledgment status"
          enum ["received", "delivered", "error"]
        end
        
        property :timestamp, :string do
          description "Acknowledgment timestamp"
          format "date-time"
        end
        
        property :error_message, :string do
          description "Error message if status is error"
        end
        
        required [:message_id, :status, :timestamp]
      end
    end

    security_schemes do
      security_scheme :bearerAuth do
        type :http
        scheme "bearer"
        bearer_format "JWT"
        description "JWT token authentication"
      end
      
      security_scheme :apiKey do
        type :api_key
        in :query
        name "api_key"
        description "API key authentication"
      end
    end
  end

  # Global security requirements
  security do
    security_requirement do
      bearer_auth []
    end
  end
end