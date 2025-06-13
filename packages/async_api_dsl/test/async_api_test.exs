defmodule AsyncApiTest do
  use ExUnit.Case, async: true

  defmodule TestEventApi do
    use AsyncApi

    info do
      title "Test Event API"
      version "1.0.0"
      description "A test AsyncAPI specification"
    end

    servers do
      server :production, "wss://api.example.com" do
        protocol :websockets
        description "Production WebSocket server"
      end

      server :staging, "wss://staging.example.com" do
        protocol :websockets
        description "Staging WebSocket server"
      end
    end

    channels do
      channel "/user/{userId}/notifications" do
        description "User-specific notifications"
        
        parameter :userId do
          schema :string
          description "The user ID"
        end
        
      end

      channel "/system/events" do
        description "System-wide events"
      end
    end

    operations do
      operation :receive_notification do
        action :receive
        channel "/user/{userId}/notifications"
        summary "Receive notifications"
        description "Subscribe to receive user notifications"
        
        message :notification_message
      end

      operation :publish_event do
        action :send
        channel "/system/events"
        summary "Publish system event"
        
        message :system_event_message
      end
    end

    components do
      messages do
        message :notification_message do
          content_type "application/json"
          payload :notification_schema
          description "A user notification message"
        end

        message :system_event_message do
          content_type "application/json"
          payload :system_event_schema
          description "A system event message"
        end
      end
      
      schemas do
        schema :notification_schema do
          type :object
          description "Schema for user notifications"
          
          property :id, :string
          property :message, :string
          property :timestamp, :string, format: "date-time"
          property :priority, :integer
          
          required [:id, :message, :timestamp]
        end

        schema :system_event_schema do
          type :object
          description "Schema for system events"
          
          property :event_type, :string
          property :data, :object
          property :timestamp, :string, format: "date-time"
          
          required [:event_type, :timestamp]
        end
      end
    end
  end

  describe "AsyncAPI DSL" do
    test "defines info section correctly" do
      info = AsyncApi.Info.info(TestEventApi)
      
      assert info.title == "Test Event API"
      assert info.version == "1.0.0"
      assert info.description == "A test AsyncAPI specification"
    end

    test "defines servers correctly" do
      servers = AsyncApi.Info.servers(TestEventApi)
      
      assert length(servers) == 2
      
      production_server = AsyncApi.Info.server(TestEventApi, :production)
      assert production_server.name == :production
      assert production_server.host == "wss://api.example.com"
      assert production_server.protocol == :websockets
      
      staging_server = AsyncApi.Info.server(TestEventApi, :staging)
      assert staging_server.name == :staging
      assert staging_server.host == "wss://staging.example.com"
    end

    test "defines channels correctly" do
      channels = AsyncApi.Info.channels(TestEventApi)
      
      assert length(channels) == 2
      
      notifications_channel = AsyncApi.Info.channel(TestEventApi, "/user/{userId}/notifications")
      assert notifications_channel.address == "/user/{userId}/notifications"
      assert notifications_channel.description == "User-specific notifications"
      
      system_channel = AsyncApi.Info.channel(TestEventApi, "/system/events")
      assert system_channel.address == "/system/events"
      assert system_channel.description == "System-wide events"
    end

    test "defines channel parameters correctly" do
      parameters = AsyncApi.Info.channel_parameters(TestEventApi, "/user/{userId}/notifications")
      
      assert length(parameters) == 1
      
      user_id_param = Enum.find(parameters, &(&1.name == :userId))
      assert user_id_param.schema == :string
      assert user_id_param.description == "The user ID"
    end

    test "defines channel operations correctly" do
      operations = AsyncApi.Info.channel_operations(TestEventApi, "/user/{userId}/notifications")
      
      assert length(operations) == 1
      
      receive_op = Enum.find(operations, &(&1.operation_id == :receive_notification))
      assert receive_op.action == :receive
      assert receive_op.summary == "Receive notifications"
      assert receive_op.messages == [:notification_message]
    end

    test "defines component messages correctly" do
      messages = AsyncApi.Info.component_messages(TestEventApi)
      
      assert length(messages) == 2
      
      notification_msg = AsyncApi.Info.component_message(TestEventApi, :notification_message)
      assert notification_msg.content_type == "application/json"
      assert notification_msg.payload == :notification_schema
      
      system_msg = AsyncApi.Info.component_message(TestEventApi, :system_event_message)
      assert system_msg.payload == :system_event_schema
    end

    test "defines component schemas correctly" do
      schemas = AsyncApi.Info.component_schemas(TestEventApi)
      
      assert length(schemas) == 2
      
      notification_schema = AsyncApi.Info.component_schema(TestEventApi, :notification_schema)
      assert notification_schema.type == :object
      assert notification_schema.required == [:id, :message, :timestamp]
      
      system_schema = AsyncApi.Info.component_schema(TestEventApi, :system_event_schema)
      assert system_schema.type == :object
      assert system_schema.required == [:event_type, :timestamp]
    end

    test "defines schema properties correctly" do
      properties = AsyncApi.Info.schema_properties(TestEventApi, :notification_schema)
      
      assert length(properties) == 4
      
      id_prop = Enum.find(properties, &(&1.name == :id))
      assert id_prop.type == :string
      
      timestamp_prop = Enum.find(properties, &(&1.name == :timestamp))
      assert timestamp_prop.type == :string
      assert timestamp_prop.format == "date-time"
      
      priority_prop = Enum.find(properties, &(&1.name == :priority))
      assert priority_prop.type == :integer
    end

    test "generates complete AsyncAPI specification" do
      spec = AsyncApi.to_spec(TestEventApi)
      
      assert spec.asyncapi == "3.0.0"
      assert spec.info.title == "Test Event API"
      assert spec.info.version == "1.0.0"
      
      assert Map.has_key?(spec.servers, :production)
      assert Map.has_key?(spec.servers, :staging)
      
      assert Map.has_key?(spec.channels, "/user/{userId}/notifications")
      assert Map.has_key?(spec.channels, "/system/events")
      
      assert Map.has_key?(spec.components.messages, :notification_message)
      assert Map.has_key?(spec.components.schemas, :notification_schema)
    end

    test "introspection helper functions work correctly" do
      assert AsyncApi.Info.has_channel?(TestEventApi, "/user/{userId}/notifications")
      assert not AsyncApi.Info.has_channel?(TestEventApi, "/nonexistent")
      
      assert AsyncApi.Info.has_server?(TestEventApi, :production)
      assert not AsyncApi.Info.has_server?(TestEventApi, :nonexistent)
      
      assert AsyncApi.Info.has_message?(TestEventApi, :notification_message)
      assert not AsyncApi.Info.has_message?(TestEventApi, :nonexistent)
      
      assert AsyncApi.Info.has_schema?(TestEventApi, :notification_schema)
      assert not AsyncApi.Info.has_schema?(TestEventApi, :nonexistent)
      
      channel_addresses = AsyncApi.Info.channel_addresses(TestEventApi)
      assert "/user/{userId}/notifications" in channel_addresses
      assert "/system/events" in channel_addresses
      
      server_names = AsyncApi.Info.server_names(TestEventApi)
      assert :production in server_names
      assert :staging in server_names
      
      message_names = AsyncApi.Info.message_names(TestEventApi)
      assert :notification_message in message_names
      assert :system_event_message in message_names
      
      schema_names = AsyncApi.Info.schema_names(TestEventApi)
      assert :notification_schema in schema_names
      assert :system_event_schema in schema_names
    end
  end
end