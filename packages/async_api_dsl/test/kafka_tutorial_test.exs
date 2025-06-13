defmodule AsyncApi.KafkaTutorialTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Tests validating the AsyncAPI DSL can generate the same YAML as the official Kafka tutorial.
  Based on: https://www.asyncapi.com/docs/tutorials/kafka
  """

  defmodule UserSignupApi do
    use AsyncApi

    info do
      title "User Signup API"
      version "1.0.0"
      description "The API notifies you whenever a new user signs up in the application."
    end

    servers do
      server :centralKafkaServer, "central.mykafkacluster.org:8092" do
        protocol :kafka
        description "Kafka broker running in a central warehouse"
      end

      server :westKafkaServer, "west.mykafkacluster.org:8092" do
        protocol :kafka
        description "Kafka broker running in the west warehouse"
      end

      server :eastKafkaServer, "east.mykafkacluster.org:8092" do
        protocol :kafka
        description "Kafka broker running in the east warehouse"
      end
    end

    channels do
      channel "user_signedup" do
        description "This channel contains a message per each user who signs up in our application."
      end
    end

    operations do
      operation :onUserSignedUp do
        action :receive
        channel "user_signedup"
        
        message :userSignedUp
      end
    end

    components do
      messages do
        message :userSignedUp do
          title "User Signed Up"
          payload :userSignedUpPayload
        end
      end

      schemas do
        schema :userSignedUpPayload do
          type :object
          
          property :userId, :integer do
            description "This property describes the id of the user"
          end
          
          property :userEmail, :string do
            description "This property describes the email of the user"
          end
        end
      end
    end
  end

  describe "Kafka Tutorial Compatibility" do
    test "DSL compiles successfully with Kafka configuration" do
      assert UserSignupApi.spark_dsl_config() != nil
    end

    test "generates correct AsyncAPI version" do
      spec = AsyncApi.to_spec(UserSignupApi)
      assert spec.asyncapi == "3.0.0"
    end

    test "generates correct API information" do
      spec = AsyncApi.to_spec(UserSignupApi)
      
      assert spec.info.title == "User Signup API"
      assert spec.info.version == "1.0.0"
      assert spec.info.description == "The API notifies you whenever a new user signs up in the application."
    end

    test "generates correct Kafka server configurations" do
      spec = AsyncApi.to_spec(UserSignupApi)
      
      assert Map.has_key?(spec.servers, :centralKafkaServer)
      assert Map.has_key?(spec.servers, :westKafkaServer)
      assert Map.has_key?(spec.servers, :eastKafkaServer)
      
      central_server = spec.servers[:centralKafkaServer]
      assert central_server.host == "central.mykafkacluster.org:8092"
      assert central_server.protocol == "kafka"
      assert central_server.description == "Kafka broker running in a central warehouse"
      
      west_server = spec.servers[:westKafkaServer]
      assert west_server.host == "west.mykafkacluster.org:8092"
      assert west_server.protocol == "kafka"
      assert west_server.description == "Kafka broker running in the west warehouse"
      
      east_server = spec.servers[:eastKafkaServer]
      assert east_server.host == "east.mykafkacluster.org:8092"
      assert east_server.protocol == "kafka"
      assert east_server.description == "Kafka broker running in the east warehouse"
    end

    test "generates correct channel configuration" do
      spec = AsyncApi.to_spec(UserSignupApi)
      
      assert Map.has_key?(spec.channels, "user_signedup")
      
      channel = spec.channels["user_signedup"]
      assert channel.description == "This channel contains a message per each user who signs up in our application."
    end

    test "generates correct operation configuration" do
      spec = AsyncApi.to_spec(UserSignupApi)
      
      assert Map.has_key?(spec.operations, :onUserSignedUp)
      
      operation = spec.operations[:onUserSignedUp]
      assert operation.action == :receive
      assert operation.channel == %{"$ref" => "#/channels/user_signedup"}
    end

    test "generates correct message schemas" do
      spec = AsyncApi.to_spec(UserSignupApi)
      
      assert Map.has_key?(spec.components.messages, :userSignedUp)
      
      message = spec.components.messages[:userSignedUp]
      assert message.payload == %{"$ref" => "#/components/schemas/userSignedUpPayload"}
    end

    test "generates correct payload schema" do
      spec = AsyncApi.to_spec(UserSignupApi)
      
      assert Map.has_key?(spec.components.schemas, :userSignedUpPayload)
      
      schema = spec.components.schemas[:userSignedUpPayload]
      assert schema.type == "object"
      
      assert Map.has_key?(schema.properties, :userId)
      assert Map.has_key?(schema.properties, :userEmail)
      
      user_id_prop = schema.properties[:userId]
      assert user_id_prop.type == "integer"
      assert user_id_prop.description == "This property describes the id of the user"
      
      user_email_prop = schema.properties[:userEmail]
      assert user_email_prop.type == "string"
      assert user_email_prop.description == "This property describes the email of the user"
    end

    test "can access Kafka servers through introspection" do
      servers = AsyncApi.Info.servers(UserSignupApi)
      
      assert length(servers) == 3
      
      server_names = Enum.map(servers, & &1.name)
      assert :centralKafkaServer in server_names
      assert :westKafkaServer in server_names
      assert :eastKafkaServer in server_names
      
      # Test specific server access
      central_server = AsyncApi.Info.server(UserSignupApi, :centralKafkaServer)
      assert central_server.host == "central.mykafkacluster.org:8092"
      assert central_server.protocol == :kafka
    end

    test "can access channels through introspection" do
      channels = AsyncApi.Info.channels(UserSignupApi)
      
      assert length(channels) == 1
      
      channel = hd(channels)
      assert channel.address == "user_signedup"
      assert channel.description == "This channel contains a message per each user who signs up in our application."
    end

    test "can access operations through introspection" do
      operations = AsyncApi.Info.operations(UserSignupApi)
      
      assert length(operations) == 1
      
      operation = hd(operations)
      assert operation.operation_id == :onUserSignedUp
      assert operation.action == :receive
    end

    test "can access component messages through introspection" do
      messages = AsyncApi.Info.component_messages(UserSignupApi)
      
      assert length(messages) == 1
      
      message = hd(messages)
      assert message.name == :userSignedUp
      assert message.payload == :userSignedUpPayload
    end

    test "can access component schemas through introspection" do
      schemas = AsyncApi.Info.component_schemas(UserSignupApi)
      
      assert length(schemas) == 1
      
      schema = hd(schemas)
      assert schema.name == :userSignedUpPayload
      assert schema.type == :object
    end

    test "validates Kafka protocol support" do
      # Ensure all servers use Kafka protocol
      servers = AsyncApi.Info.servers(UserSignupApi)
      
      for server <- servers do
        assert server.protocol == :kafka
      end
    end

    test "validates receive operation pattern" do
      # Kafka typically uses receive operations for consuming messages
      operations = AsyncApi.Info.operations_by_action(UserSignupApi, :receive)
      
      assert length(operations) == 1
      
      operation = hd(operations)
      assert operation.action == :receive
      assert operation.operation_id == :onUserSignedUp
    end

    test "full specification structure matches Kafka tutorial pattern" do
      spec = AsyncApi.to_spec(UserSignupApi)
      
      # Verify it follows the expected Kafka tutorial structure
      assert spec.asyncapi == "3.0.0"
      assert is_map(spec.info)
      assert is_map(spec.servers)
      assert is_map(spec.channels)
      assert is_map(spec.operations)
      assert is_map(spec.components)
      
      # Verify Kafka-specific patterns
      assert Map.has_key?(spec.channels, "user_signedup")
      assert Map.has_key?(spec.operations, :onUserSignedUp)
      assert spec.operations[:onUserSignedUp].action == :receive
      
      # Verify all servers are Kafka
      for {_name, server} <- spec.servers do
        assert server.protocol == "kafka"
      end
    end
  end

  describe "JSON Serialization" do
    test "can serialize full specification to JSON" do
      spec = AsyncApi.to_spec(UserSignupApi)
      
      # Should be able to encode to JSON without errors
      json_result = Jason.encode(spec)
      assert {:ok, _json_string} = json_result
    end

    test "serialized JSON contains expected Kafka tutorial elements" do
      spec = AsyncApi.to_spec(UserSignupApi)
      {:ok, json_string} = Jason.encode(spec)
      {:ok, parsed} = Jason.decode(json_string)
      
      # Verify key elements are present in serialized form
      assert parsed["asyncapi"] == "3.0.0"
      assert parsed["info"]["title"] == "User Signup API"
      assert Map.has_key?(parsed["servers"], "centralKafkaServer")
      assert Map.has_key?(parsed["channels"], "user_signedup")
      assert Map.has_key?(parsed["operations"], "onUserSignedUp")
      assert parsed["operations"]["onUserSignedUp"]["action"] == "receive"
    end
  end
end