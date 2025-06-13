# Getting Started with AsyncAPI DSL

This guide will walk you through creating your first AsyncAPI specification using the AsyncAPI DSL for Elixir.

## Installation

Add the AsyncAPI DSL to your project's dependencies:

```elixir
# mix.exs
def deps do
  [
    {:async_api_dsl, "~> 1.0"}
  ]
end
```

Run `mix deps.get` to install the dependency.

## Your First AsyncAPI Specification

Let's create a simple chat application API specification:

```elixir
# lib/my_app/chat_api.ex
defmodule MyApp.ChatApi do
  use AsyncApi

  info do
    title "Chat Application API"
    version "1.0.0"
    description "Real-time chat application using WebSockets"
  end

  servers do
    server :production, "wss://chat.example.com" do
      protocol :websockets
      description "Production chat server"
    end
  end

  channels do
    channel "/chat/{roomId}" do
      description "Chat room for real-time messaging"
      
      parameters do
        parameter :roomId do
          description "The chat room identifier"
          schema do
            type :string
            pattern "^[a-zA-Z0-9_-]+$"
          end
        end
      end
    end
  end

  operations do
    operation :sendMessage do
      action :send
      channel "/chat/{roomId}"
      summary "Send a message to the chat room"
      message :chatMessage
    end

    operation :receiveMessage do
      action :receive
      channel "/chat/{roomId}"
      summary "Receive messages from the chat room"
      message :chatMessage
    end
  end

  components do
    messages do
      message :chatMessage do
        title "Chat Message"
        summary "A message sent in a chat room"
        payload :chatMessagePayload
      end
    end

    schemas do
      schema :chatMessagePayload do
        type :object
        title "Chat Message Payload"
        
        property :id, :string do
          description "Unique message identifier"
          format "uuid"
        end
        
        property :userId, :string do
          description "ID of the user sending the message"
        end
        
        property :username, :string do
          description "Display name of the user"
          min_length 1
          max_length 50
        end
        
        property :content, :string do
          description "The message content"
          min_length 1
          max_length 1000
        end
        
        property :timestamp, :string do
          description "When the message was sent"
          format "date-time"
        end
        
        required [:id, :userId, :username, :content, :timestamp]
      end
    end
  end
end
```

## Generate the Specification

Now you can generate the AsyncAPI specification file:

```bash
# Generate JSON specification
mix async_api.gen MyApp.ChatApi

# Generate YAML specification
mix async_api.gen MyApp.ChatApi --format yaml

# Generate both formats
mix async_api.gen MyApp.ChatApi --format json,yaml
```

This will create specification files in the `spec/` directory.

## Runtime Usage

You can also work with the specification programmatically:

```elixir
# Get the full specification as a map
spec = AsyncApi.to_spec(MyApp.ChatApi)

# Export to JSON string
json_spec = AsyncApi.Export.to_string(MyApp.ChatApi, :json)

# Save to a custom location
AsyncApi.Export.to_file(MyApp.ChatApi, "priv/static/chat_api.json")

# Query the specification at runtime
operations = AsyncApi.Info.operations(MyApp.ChatApi)
channels = AsyncApi.Info.channels(MyApp.ChatApi)
messages = AsyncApi.Info.component_messages(MyApp.ChatApi)

# Check if specific elements exist
has_send_op = AsyncApi.Info.has_operation?(MyApp.ChatApi, :sendMessage)
has_chat_channel = AsyncApi.Info.has_channel?(MyApp.ChatApi, "/chat/{roomId}")
```

## Key Concepts

### Information Section

The `info` section contains metadata about your API:

```elixir
info do
  title "My API"
  version "1.0.0"
  description "API description"
  terms_of_service "https://example.com/terms"
  
  contact do
    name "API Support"
    url "https://example.com/support"
    email "support@example.com"
  end
  
  license do
    name "MIT"
    url "https://opensource.org/licenses/MIT"
  end
end
```

### Servers

Define the servers where your API is available:

```elixir
servers do
  server :production, "wss://api.example.com" do
    protocol :websockets
    description "Production server"
    
    variables do
      variable :environment do
        enum ["prod", "staging"]
        default "prod"
        description "Environment name"
      end
    end
  end
end
```

### Channels

Channels represent the topics or routes where messages flow:

```elixir
channels do
  channel "/user/{userId}/notifications" do
    description "User-specific notifications"
    
    parameters do
      parameter :userId do
        description "The user ID"
        schema do
          type :string
          pattern "^[0-9]+$"
        end
      end
    end
  end
end
```

### Operations (AsyncAPI 3.0)

Operations define what actions can be performed:

```elixir
operations do
  operation :sendNotification do
    action :send
    channel "/user/{userId}/notifications"
    summary "Send a notification to a user"
    message :notification
    
    # Optional reply for request-response patterns
    reply do
      address "/user/{userId}/notifications/ack"
      message :acknowledgment
    end
  end
end
```

### Components

Reusable components include messages and schemas:

```elixir
components do
  messages do
    message :notification do
      title "User Notification"
      payload :notificationPayload
      
      correlation_id do
        location "$message.header#/correlationId"
        description "Correlation ID for tracking"
      end
    end
  end

  schemas do
    schema :notificationPayload do
      type :object
      
      property :type, :string do
        enum ["info", "warning", "error"]
      end
      
      property :message, :string do
        min_length 1
        max_length 500
      end
      
      required [:type, :message]
    end
  end
end
```

## Advanced Features

### Security Schemes

Define authentication and authorization:

```elixir
components do
  security_schemes do
    security_scheme :apiKey do
      type :apiKey
      name "X-API-Key"
      location :header
      description "API key authentication"
    end

    security_scheme :oauth2 do
      type :oauth2
      description "OAuth2 authentication"
      
      flows do
        authorization_code do
          authorization_url "https://example.com/oauth/authorize"
          token_url "https://example.com/oauth/token"
          
          scopes do
            scope "read", "Read access"
            scope "write", "Write access"
          end
        end
      end
    end
  end
end
```

### Protocol Bindings

Add protocol-specific configuration:

```elixir
servers do
  server :kafka, "kafka.example.com:9092" do
    protocol :kafka
    
    bindings [
      kafka: [
        schema_registry_url: "https://schema-registry.example.com"
      ]
    ]
  end
end

channels do
  channel "user.events" do
    bindings [
      kafka: [
        topic: "user-events",
        partitions: 3,
        replicas: 2
      ]
    ]
  end
end
```

### Message Examples

Provide examples for better documentation:

```elixir
messages do
  message :userEvent do
    payload :userEventPayload
    
    examples do
      example :login do
        summary "User login event"
        description "Triggered when a user logs in"
        payload %{
          userId: "12345",
          eventType: "login",
          timestamp: "2024-01-01T12:00:00Z"
        }
      end
    end
  end
end
```

## Integration with Phoenix

For Phoenix applications, you can integrate the AsyncAPI DSL with your channels:

```elixir
# Define the API specification
defmodule MyAppWeb.SocketAPI do
  use AsyncApi

  info do
    title "MyApp WebSocket API"
    version "1.0.0"
  end

  # Match your Phoenix channels
  channels do
    channel "room:lobby" do
      description "Lobby chat room"
    end
    
    channel "user:{user_id}" do
      description "User-specific channel"
    end
  end

  operations do
    operation :joinRoom do
      action :send
      channel "room:lobby"
      message :joinMessage
    end
  end
end

# Use in your Phoenix endpoint
defmodule MyAppWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :my_app

  # Generate API documentation
  def api_spec do
    AsyncApi.to_spec(MyAppWeb.SocketAPI)
  end
end
```

## Configuration

Configure the AsyncAPI DSL in your application:

```elixir
# config/config.exs
config :async_api_dsl,
  default_export_formats: [:json, :yaml],
  output_directory: "priv/static/api-specs",
  strict_validation: true,
  pretty_print: true
```

## Next Steps

- Read the [full API documentation](https://hexdocs.pm/async_api_dsl)
- Explore the [AsyncAPI 3.0 specification](https://www.asyncapi.com/docs/reference/specification/v3.0.0)
- Check out more [examples and patterns](../examples/)
- Learn about [advanced validation and testing](../guides/validation.md)

## Common Patterns

### Microservices Event Bus

```elixir
defmodule MyApp.EventBus do
  use AsyncApi

  info do
    title "Microservices Event Bus"
    version "2.1.0"
  end

  servers do
    server :message_broker, "amqp://rabbitmq.internal:5672" do
      protocol :amqp
    end
  end

  # Service-to-service events
  channels do
    channel "user.lifecycle" do
      description "User lifecycle events"
    end
    
    channel "order.processing" do
      description "Order processing events"
    end
  end
end
```

### IoT Data Streaming

```elixir
defmodule MyApp.IoTStreams do
  use AsyncApi

  info do
    title "IoT Data Streaming API"
    version "1.0.0"
  end

  servers do
    server :mqtt_broker, "mqtt://iot.example.com:1883" do
      protocol :mqtt
    end
  end

  channels do
    channel "sensors/{deviceId}/temperature" do
      description "Temperature sensor readings"
    end
    
    channel "sensors/{deviceId}/status" do
      description "Device status updates"
    end
  end
end
```

This guide should get you started with the AsyncAPI DSL. The next step is to explore the full capabilities and start defining your own event-driven APIs!