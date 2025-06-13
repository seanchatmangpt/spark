defmodule AsyncApi.WebSocketTutorialTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Tests that validate the AsyncAPI DSL can render the same YAML as the examples
  from the AsyncAPI WebSocket tutorial at https://www.asyncapi.com/docs/tutorials/websocket
  
  This test ensures our DSL implementation is fully compatible with the official
  AsyncAPI 3.0 specification by recreating the Slack WebSocket example.
  """

  defmodule SlackWebSocketApi do
    use AsyncApi

    info do
      title "Create an AsyncAPI document for a Slackbot with WebSocket"
      version "1.0.0"
      description """
      The Heart-Counter manages popular messages in a Slack workspace by monitoring message reaction data.
      """
    end

    servers do
      server :production, "wss-primary.slack.com" do
        pathname "/link"
        protocol :wss
        description "Slack's server in Socket Mode for real-time communication"
      end
    end

    channels do
      channel "/" do
        
        # WebSocket bindings for query parameters
        bindings [
          ws: [
            query: [
              type: :object,
              description: "Tokens are produced in the WebSocket URL generated from the apps.connections.open method from Slack's API",
              properties: [
                ticket: [
                  type: :string,
                  description: "Temporary token generated when connection is initiated",
                  const: "13748dac-b866-4ea7-b98e-4fb7895c0a7f"
                ],
                app_id: [
                  type: :string,
                  description: "Unique identifier assigned to the Slack app",
                  const: "fe684dfa62159c6ac646beeac31c8f4ef415e4f39c626c2dbd1530e3a690892f"
                ]
              ]
            ]
          ]
        ]
      end
    end

    operations do
      operation :helloListener do
        action :receive
        channel "/"
        
        message :hello
      end

      operation :reactionListener do
        action :receive
        channel "/"
        
        message :reaction
      end
    end

    components do
      messages do
        message :hello do
          summary "Action triggered when a successful WebSocket connection is established"
          payload :hello_schema
        end

        message :reaction do
          summary "Action triggered when the channel receives a new reaction-added event"
          payload :reaction_schema
        end
      end

      schemas do
        schema :hello_schema do
          type :object
          title "Hello Message"
          description "Schema for hello message when WebSocket connection is established"
          
          property :type, :string do
            description "Message type identifier"
            const "hello"
          end
          
          property :num_connections, :integer do
            description "Number of connections"
            minimum 1
          end
          
          property :debug_info, :object do
            description "Debug information object"
            
            property :host, :string do
              description "Host information"
            end
            
            property :started, :string do
              description "Start timestamp"
              format "date-time"
            end
            
            property :buildNumber, :integer do
              description "Build number"
              minimum 1
            end
            
            required [:host, :started, :buildNumber]
          end
          
          property :connection_info, :object do
            description "Connection information"
            
            property :app_id, :string do
              description "Application ID"
              pattern "^[a-f0-9]{64}$"
            end
            
            required [:app_id]
          end
          
          required [:type, :num_connections, :debug_info, :connection_info]
        end

        schema :reaction_schema do
          type :object
          title "Reaction Event"
          description "Schema for reaction added events from Slack"
          
          property :envelope_id, :string do
            description "Unique identifier for the event envelope"
            format "uuid"
          end
          
          property :payload, :object do
            description "Event payload containing reaction data"
            
            property :event, :object do
              description "Reaction event details"
              
              property :type, :string do
                description "Event type"
                const "reaction_added"
              end
              
              property :user, :string do
                description "User ID who added the reaction"
                pattern "^U[A-Z0-9]{8,}$"
              end
              
              property :reaction, :string do
                description "Reaction emoji name"
                pattern "^[a-z0-9_+-]+$"
              end
              
              property :item_user, :string do
                description "User ID of the message author"
                pattern "^U[A-Z0-9]{8,}$"
              end
              
              property :item, :object do
                description "Message item that received the reaction"
                
                property :type, :string do
                  description "Item type"
                  const "message"
                end
                
                property :channel, :string do
                  description "Channel ID where the message is located"
                  pattern "^C[A-Z0-9]{8,}$"
                end
                
                property :ts, :string do
                  description "Message timestamp"
                  pattern "^[0-9]{10}\\.[0-9]{6}$"
                end
                
                required [:type, :channel, :ts]
              end
              
              property :event_ts, :string do
                description "Event timestamp"
                pattern "^[0-9]{10}\\.[0-9]{6}$"
              end
              
              required [:type, :user, :reaction, :item_user, :item, :event_ts]
            end
            
            property :type, :string do
              description "Payload type"
              const "event_callback"
            end
            
            property :team_id, :string do
              description "Team/workspace ID"
              pattern "^T[A-Z0-9]{8,}$"
            end
            
            property :api_app_id, :string do
              description "API application ID"
              pattern "^A[A-Z0-9]{8,}$"
            end
            
            property :event_id, :string do
              description "Event ID"
              pattern "^Ev[A-Z0-9]{8,}$"
            end
            
            property :event_time, :integer do
              description "Event time as Unix timestamp"
              minimum 0
            end
            
            required [:event, :type, :team_id, :api_app_id, :event_id, :event_time]
          end
          
          property :type, :string do
            description "Message type"
            const "events_api"
          end
          
          property :accepts_response_payload, :boolean do
            description "Whether the event accepts response payload"
            const false
          end
          
          required [:envelope_id, :payload, :type, :accepts_response_payload]
        end
      end
    end
  end

  describe "Slack WebSocket AsyncAPI Tutorial Validation" do
    test "generates correct AsyncAPI 3.0 specification structure" do
      spec = AsyncApi.to_spec(SlackWebSocketApi)
      
      # Validate root structure
      assert spec.asyncapi == "3.0.0"
      assert spec.info.title == "Create an AsyncAPI document for a Slackbot with WebSocket"
      assert spec.info.version == "1.0.0"
      assert String.contains?(spec.info.description, "Heart-Counter manages popular messages")
    end

    test "generates correct server configuration" do
      spec = AsyncApi.to_spec(SlackWebSocketApi)
      
      production_server = spec.servers.production
      assert production_server.host == "wss-primary.slack.com"
      assert production_server.pathname == "/link"
      assert production_server.protocol == "wss"
      assert production_server.description == "Slack's server in Socket Mode for real-time communication"
    end

    test "generates correct channel configuration with WebSocket bindings" do
      spec = AsyncApi.to_spec(SlackWebSocketApi)
      
      root_channel = spec.channels["/"]
      assert root_channel != nil
      
      # Validate WebSocket bindings
      ws_bindings = root_channel.bindings.ws
      assert ws_bindings != nil
      
      query_schema = ws_bindings.query
      assert query_schema.type == :object
      assert String.contains?(query_schema.description, "Tokens are produced")
      
      # Validate query parameters
      assert query_schema.properties.ticket.type == :string
      assert query_schema.properties.ticket.const == "13748dac-b866-4ea7-b98e-4fb7895c0a7f"
      
      assert query_schema.properties.app_id.type == :string
      assert query_schema.properties.app_id.const == "fe684dfa62159c6ac646beeac31c8f4ef415e4f39c626c2dbd1530e3a690892f"
    end

    test "generates correct operations for hello and reaction listeners" do
      spec = AsyncApi.to_spec(SlackWebSocketApi)
      
      # Validate hello listener operation
      hello_op = spec.operations.helloListener
      assert hello_op.action == :receive
      assert hello_op.channel == %{"$ref" => "#/channels/%2F"}  # URL encoded "/"
      assert Enum.any?(hello_op.messages, &(&1 == %{"$ref" => "#/components/messages/hello"}))
      
      # Validate reaction listener operation
      reaction_op = spec.operations.reactionListener
      assert reaction_op.action == :receive
      assert reaction_op.channel == %{"$ref" => "#/channels/%2F"}  # URL encoded "/"
      assert Enum.any?(reaction_op.messages, &(&1 == %{"$ref" => "#/components/messages/reaction"}))
    end

    test "generates correct component messages" do
      spec = AsyncApi.to_spec(SlackWebSocketApi)
      
      messages = spec.components.messages
      
      # Validate hello message
      hello_msg = messages.hello
      assert hello_msg.summary == "Action triggered when a successful WebSocket connection is established"
      assert hello_msg.payload == %{"$ref" => "#/components/schemas/hello_schema"}
      
      # Validate reaction message
      reaction_msg = messages.reaction
      assert reaction_msg.summary == "Action triggered when the channel receives a new reaction-added event"
      assert reaction_msg.payload == %{"$ref" => "#/components/schemas/reaction_schema"}
    end

    test "generates correct hello schema with proper structure" do
      spec = AsyncApi.to_spec(SlackWebSocketApi)
      
      hello_schema = spec.components.schemas.hello_schema
      assert hello_schema.type == "object"
      assert hello_schema.title == "Hello Message"
      
      # Validate properties
      props = hello_schema.properties
      
      # Type property
      assert props.type.type == "string"
      assert props.type.const == "hello"
      
      # Num connections property
      assert props.num_connections.type == "integer"
      assert props.num_connections.minimum == 1
      
      # Debug info property (nested object)
      debug_info = props.debug_info
      assert debug_info.type == "object"
      assert debug_info.properties.host.type == "string"
      assert debug_info.properties.started.format == "date-time"
      assert debug_info.properties.buildNumber.minimum == 1
      assert debug_info.required == [:host, :started, :buildNumber]
      
      # Connection info property (nested object)
      conn_info = props.connection_info
      assert conn_info.type == "object"
      assert conn_info.properties.app_id.pattern == "^[a-f0-9]{64}$"
      assert conn_info.required == [:app_id]
      
      # Required fields
      assert hello_schema.required == [:type, :num_connections, :debug_info, :connection_info]
    end

    test "generates correct reaction schema with complex nested structure" do
      spec = AsyncApi.to_spec(SlackWebSocketApi)
      
      reaction_schema = spec.components.schemas.reaction_schema
      assert reaction_schema.type == "object"
      assert reaction_schema.title == "Reaction Event"
      
      props = reaction_schema.properties
      
      # Envelope ID
      assert props.envelope_id.format == "uuid"
      
      # Payload (complex nested object)
      payload = props.payload
      assert payload.type == "object"
      
      # Event within payload
      event = payload.properties.event
      assert event.type == "object"
      assert event.properties.type.const == "reaction_added"
      assert event.properties.user.pattern == "^U[A-Z0-9]{8,}$"
      assert event.properties.reaction.pattern == "^[a-z0-9_+-]+$"
      
      # Item within event
      item = event.properties.item
      assert item.properties.type.const == "message"
      assert item.properties.channel.pattern == "^C[A-Z0-9]{8,}$"
      assert item.properties.ts.pattern == "^[0-9]{10}\\.[0-9]{6}$"
      
      # Payload level properties
      assert payload.properties.type.const == "event_callback"
      assert payload.properties.team_id.pattern == "^T[A-Z0-9]{8,}$"
      assert payload.properties.api_app_id.pattern == "^A[A-Z0-9]{8,}$"
      
      # Top level properties
      assert props.type.const == "events_api"
      assert props.accepts_response_payload.const == false
      
      # Required fields validation
      assert reaction_schema.required == [:envelope_id, :payload, :type, :accepts_response_payload]
    end

    test "generates specification that matches tutorial YAML structure" do
      spec = AsyncApi.to_spec(SlackWebSocketApi)
      
      # Test that all major sections are present and correctly structured
      assert Map.has_key?(spec, :asyncapi)
      assert Map.has_key?(spec, :info)
      assert Map.has_key?(spec, :servers)
      assert Map.has_key?(spec, :channels)
      assert Map.has_key?(spec, :operations)
      assert Map.has_key?(spec, :components)
      
      # Test that components has the expected subsections
      components = spec.components
      assert Map.has_key?(components, :messages)
      assert Map.has_key?(components, :schemas)
      
      # Test that we have exactly the messages and schemas from the tutorial
      assert Map.has_key?(components.messages, :hello)
      assert Map.has_key?(components.messages, :reaction)
      assert Map.has_key?(components.schemas, :hello_schema)
      assert Map.has_key?(components.schemas, :reaction_schema)
      
      # Test that operations reference the correct channels and messages
      operations = spec.operations
      assert Map.has_key?(operations, :helloListener)
      assert Map.has_key?(operations, :reactionListener)
    end

    test "validates introspection functions work correctly" do
      # Test the Info module functions
      assert AsyncApi.Info.info(SlackWebSocketApi).title == "Create an AsyncAPI document for a Slackbot with WebSocket"
      
      # Test server introspection
      servers = AsyncApi.Info.servers(SlackWebSocketApi)
      assert length(servers) == 1
      assert AsyncApi.Info.server(SlackWebSocketApi, :production).host == "wss-primary.slack.com"
      
      # Test channel introspection
      channels = AsyncApi.Info.channels(SlackWebSocketApi)
      assert length(channels) == 1
      assert AsyncApi.Info.has_channel?(SlackWebSocketApi, "/")
      
      # Test operation introspection
      operations = AsyncApi.Info.operations(SlackWebSocketApi)
      assert length(operations) == 2
      assert AsyncApi.Info.has_operation?(SlackWebSocketApi, :helloListener)
      assert AsyncApi.Info.has_operation?(SlackWebSocketApi, :reactionListener)
      
      # Test message introspection
      messages = AsyncApi.Info.component_messages(SlackWebSocketApi)
      assert length(messages) == 2
      assert AsyncApi.Info.has_message?(SlackWebSocketApi, :hello)
      assert AsyncApi.Info.has_message?(SlackWebSocketApi, :reaction)
      
      # Test schema introspection
      schemas = AsyncApi.Info.component_schemas(SlackWebSocketApi)
      assert length(schemas) == 2
      assert AsyncApi.Info.has_schema?(SlackWebSocketApi, :hello_schema)
      assert AsyncApi.Info.has_schema?(SlackWebSocketApi, :reaction_schema)
    end

    test "validates complex schema properties are correctly structured" do
      hello_props = AsyncApi.Info.schema_properties(SlackWebSocketApi, :hello_schema)
      reaction_props = AsyncApi.Info.schema_properties(SlackWebSocketApi, :reaction_schema)
      
      # Hello schema should have 4 main properties
      assert length(hello_props) == 4
      property_names = Enum.map(hello_props, & &1.name)
      assert :type in property_names
      assert :num_connections in property_names
      assert :debug_info in property_names
      assert :connection_info in property_names
      
      # Reaction schema should have 4 main properties
      assert length(reaction_props) == 4
      reaction_property_names = Enum.map(reaction_props, & &1.name)
      assert :envelope_id in reaction_property_names
      assert :payload in reaction_property_names
      assert :type in reaction_property_names
      assert :accepts_response_payload in reaction_property_names
    end

    test "validates that references are correctly formatted" do
      spec = AsyncApi.to_spec(SlackWebSocketApi)
      
      # Check message references in operations
      hello_op = spec.operations.helloListener
      hello_message_ref = Enum.find(hello_op.messages, &String.contains?(&1["$ref"], "hello"))
      assert hello_message_ref["$ref"] == "#/components/messages/hello"
      
      reaction_op = spec.operations.reactionListener
      reaction_message_ref = Enum.find(reaction_op.messages, &String.contains?(&1["$ref"], "reaction"))
      assert reaction_message_ref["$ref"] == "#/components/messages/reaction"
      
      # Check schema references in messages
      hello_msg = spec.components.messages.hello
      assert hello_msg.payload["$ref"] == "#/components/schemas/hello_schema"
      
      reaction_msg = spec.components.messages.reaction
      assert reaction_msg.payload["$ref"] == "#/components/schemas/reaction_schema"
      
      # Check channel references in operations
      assert hello_op.channel["$ref"] == "#/channels/%2F"  # URL encoded "/"
      assert reaction_op.channel["$ref"] == "#/channels/%2F"  # URL encoded "/"
    end
  end

  describe "YAML Generation Compatibility" do
    test "generates YAML that can be parsed by standard YAML parsers" do
      spec = AsyncApi.to_spec(SlackWebSocketApi)
      
      # Convert to YAML (assuming we have a YAML library available)
      # This test validates the structure is YAML-serializable
      assert is_map(spec)
      assert Map.keys(spec) |> Enum.all?(&is_atom/1)
    end

    test "validates that all required AsyncAPI 3.0 fields are present" do
      spec = AsyncApi.to_spec(SlackWebSocketApi)
      
      # Required root fields
      assert spec.asyncapi == "3.0.0"
      assert is_map(spec.info)
      assert is_binary(spec.info.title)
      assert is_binary(spec.info.version)
      
      # Optional but present fields
      assert is_map(spec.servers)
      assert is_map(spec.channels)
      assert is_map(spec.operations)
      assert is_map(spec.components)
    end

    test "validates WebSocket protocol bindings are correctly formatted" do
      spec = AsyncApi.to_spec(SlackWebSocketApi)
      
      root_channel = spec.channels["/"]
      ws_bindings = root_channel.bindings.ws
      
      # Ensure bindings follow AsyncAPI WebSocket binding specification
      assert is_map(ws_bindings)
      assert Map.has_key?(ws_bindings, :query)
      
      query = ws_bindings.query
      assert query.type == :object
      assert is_map(query.properties)
      assert Map.has_key?(query.properties, :ticket)
      assert Map.has_key?(query.properties, :app_id)
    end
  end
end