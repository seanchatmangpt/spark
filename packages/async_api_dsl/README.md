# AsyncAPI DSL for Elixir

[![Hex.pm](https://img.shields.io/hexpm/v/async_api_dsl.svg)](https://hex.pm/packages/async_api_dsl)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/async_api_dsl)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A powerful Elixir DSL for defining AsyncAPI 3.0 specifications with compile-time validation and runtime introspection. Built on the [Spark DSL framework](https://hexdocs.pm/spark).

## ✨ Features

- 🚀 **Full AsyncAPI 3.0 Support** - Complete specification support with operations, reply patterns, and enhanced security
- 🔍 **Compile-time Validation** - Catch specification errors early in development with Spark transformers
- 🏃 **Runtime Introspection** - Query your API definitions programmatically with full metadata access
- 📋 **Protocol Bindings** - WebSocket, Kafka, AMQP, HTTP, NATS, Redis, gRPC support
- 🧩 **Reusable Components** - Messages, schemas, security schemes, and parameter definitions
- 📄 **JSON/YAML Export** - Generate specification files for documentation and tooling
- 🛠️ **Mix Tasks** - CLI tools for generating specifications and managing APIs
- ⚡ **High Performance** - Efficient compilation with minimal runtime overhead

## Installation

Add `async_api_dsl` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:async_api_dsl, "~> 1.0"}
  ]
end
```

## Quick Start

```elixir
defmodule MyApp.EventApi do
  use AsyncApi

  info do
    title "User Events API"
    version "1.0.0"
    description "Real-time user event streaming API"
  end

  servers do
    server :production, "wss://api.example.com" do
      protocol :websockets
      description "Production WebSocket server"
    end
  end

  channels do
    channel "/user/{userId}/events" do
      description "User-specific event stream"
      
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

  operations do
    operation :receiveUserEvents do
      action :receive
      channel "/user/{userId}/events"
      message :userEvent
    end
  end

  components do
    messages do
      message :userEvent do
        title "User Event"
        payload :userEventPayload
      end
    end

    schemas do
      schema :userEventPayload do
        type :object
        
        property :eventType, :string do
          description "Type of user event"
          enum ["login", "logout", "purchase"]
        end
        
        property :timestamp, :string do
          description "Event timestamp"
          format "date-time"
        end
        
        required [:eventType, :timestamp]
      end
    end
  end
end
```

## Usage

### Generate AsyncAPI Specification

```elixir
# Generate the specification map
spec = AsyncApi.to_spec(MyApp.EventApi)

# Export to JSON
json_spec = AsyncApi.Export.to_string(MyApp.EventApi, :json)

# Export to YAML (requires yaml_elixir)
yaml_spec = AsyncApi.Export.to_string(MyApp.EventApi, :yaml)

# Save to file
AsyncApi.Export.to_file(MyApp.EventApi, "spec/event_api.json")
```

### Mix Tasks

```bash
# Generate JSON specification
mix async_api.gen MyApp.EventApi

# Generate YAML specification  
mix async_api.gen MyApp.EventApi --format yaml

# Generate both formats
mix async_api.gen MyApp.EventApi --format json,yaml

# Custom output directory
mix async_api.gen MyApp.EventApi --output priv/static/specs/
```

### Runtime Introspection

```elixir
# Get API information
AsyncApi.Info.info(MyApp.EventApi)

# List all operations
AsyncApi.Info.operations(MyApp.EventApi)

# Get specific components
AsyncApi.Info.component_schemas(MyApp.EventApi)
AsyncApi.Info.component_messages(MyApp.EventApi)

# Check for specific elements
AsyncApi.Info.has_channel?(MyApp.EventApi, "/user/{userId}/events")
AsyncApi.Info.has_operation?(MyApp.EventApi, :receiveUserEvents)
```

## AsyncAPI 3.0 Features

This DSL supports all AsyncAPI 3.0 features:

### Operations as First-Class Citizens
```elixir
operations do
  operation :publishUserUpdate do
    action :send
    channel "/user/{userId}"
    message :userUpdate
    
    reply do
      address "/user/{userId}/ack"
      message :acknowledgment
    end
  end
end
```

### Enhanced Security Schemes
```elixir
components do
  security_schemes do
    security_scheme :oauth2 do
      type :oauth2
      description "OAuth2 authentication"
      
      flows do
        authorization_code do
          authorization_url "https://example.com/oauth/authorize"
          token_url "https://example.com/oauth/token"
          
          scopes do
            scope "events:read", "Read event data"
            scope "events:write", "Write event data"
          end
        end
      end
    end
  end
end
```

### Protocol Bindings
```elixir
servers do
  server :kafka_cluster, "kafka.example.com:9092" do
    protocol :kafka
    bindings [
      kafka: [
        schema_registry_url: "https://schema-registry.example.com",
        schema_registry_vendor: "confluent"
      ]
    ]
  end
end
```

## Configuration

Configure AsyncAPI DSL in your `config/config.exs`:

```elixir
config :async_api_dsl,
  default_export_formats: [:json, :yaml],
  strict_validation: true,
  output_directory: "priv/static/api-specs",
  pretty_print: true
```

## Integration Examples

### Phoenix WebSocket Integration

```elixir
defmodule MyPhoenixApp.WebSocketAPI do
  use AsyncApi

  info do
    title "Phoenix WebSocket API"
    version "1.0.0"
  end

  # Define channels matching Phoenix channels
  channels do
    channel "room:lobby" do
      description "Lobby chat room"
    end
    
    channel "user:{userId}" do
      description "User-specific channel"
    end
  end

  operations do
    operation :joinRoom do
      action :send
      channel "room:lobby"
      message :joinMessage
    end
    
    operation :receiveMessage do
      action :receive  
      channel "room:lobby"
      message :chatMessage
    end
  end
end
```

### Kafka Event Streaming

```elixir
defmodule MyApp.KafkaStreams do
  use AsyncApi

  info do
    title "Kafka Event Streams"
    version "2.1.0"
  end

  servers do
    server :production, "kafka.prod.example.com:9092" do
      protocol :kafka
      description "Production Kafka cluster"
    end
  end

  channels do
    channel "user.events" do
      description "User activity events"
    end
  end

  operations do
    operation :publishUserEvent do
      action :send
      channel "user.events" 
      message :userActivity
    end
  end
end
```

## Documentation

- [Getting Started Guide](guides/getting_started.md)
- [API Reference](https://hexdocs.pm/async_api_dsl)
- [AsyncAPI 3.0 Features](https://www.asyncapi.com/docs/reference/specification/v3.0.0)
- [Spark DSL Framework](https://hexdocs.pm/spark)

## Comparison with Other Tools

| Feature | AsyncAPI DSL | Manual JSON/YAML | Code-First Tools |
|---------|--------------|-------------------|------------------|
| Type Safety | ✅ Compile-time | ❌ Runtime only | ⚠️ Limited |
| IDE Support | ✅ Full IntelliSense | ❌ Basic | ⚠️ Partial |
| Validation | ✅ Early + Runtime | ❌ Manual | ⚠️ Runtime only |
| Maintainability | ✅ High | ❌ Low | ⚠️ Medium |
| Elixir Integration | ✅ Native | ❌ External | ⚠️ Limited |

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests (`mix test`)
4. Run code quality checks (`mix credo && mix dialyzer`)
5. Commit your changes (`git commit -am 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Development

```bash
# Install dependencies
mix deps.get

# Run tests
mix test

# Run with coverage
mix test --cover

# Code quality
mix credo
mix dialyzer

# Generate documentation
mix docs
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built on the powerful [Spark DSL framework](https://hexdocs.pm/spark)
- Inspired by the [AsyncAPI specification](https://www.asyncapi.com/)
- Part of the broader Elixir ecosystem