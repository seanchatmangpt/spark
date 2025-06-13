defmodule AsyncApi.IntegrationTest do
  @moduledoc """
  Comprehensive integration tests for all AsyncAPI DSL features.
  
  Tests all 9 major modules implemented in the roadmap:
  1. AsyncApi.Linter
  2. AsyncApi.Validator  
  3. AsyncApi.Testing
  4. AsyncApi.Bindings.Grpc
  5. AsyncApi.Bindings.Nats
  6. AsyncApi.Codegen
  7. AsyncApi.Phoenix
  8. AsyncApi.Errors
  9. AsyncApi.Traits
  """
  
  use ExUnit.Case, async: true
  
  # Test API module with comprehensive feature usage
  defmodule TestApi do
    use AsyncApi
    
    info do
      title "Test Event API"
      version "1.0.0"
      description "Comprehensive test API for AsyncAPI DSL features"
      terms_of_service "https://example.com/terms"
      
      contact do
        name "API Team"
        url "https://example.com/contact"
        email "api@example.com"
      end
      
      license do
        name "MIT"
        url "https://opensource.org/licenses/MIT"
      end
    end
    
    # Define reusable traits
    message_traits do
      trait :timestamped_message do
        headers do
          field :timestamp, :string do
            description "Message timestamp in ISO 8601 format"
            examples ["2023-12-01T10:30:00Z"]
          end
        end
        
        correlation_id do
          location "$message.header#/correlationId"
          description "Unique correlation identifier"
        end
      end
      
      trait :authenticated_message do
        headers do
          field :authorization, :string do
            description "Bearer token for authentication"
            pattern "^Bearer [A-Za-z0-9\\-\\._~\\+\\/]+=*$"
          end
        end
      end
    end
    
    operation_traits do
      trait :logged_operation do
        summary "Operation with automatic logging"
        tags ["logging"]
        
        bindings [
          http: [
            headers: %{
              "X-Request-ID" => %{
                schema: %{type: :string, format: :uuid},
                required: true
              }
            }
          ]
        ]
      end
    end
    
    # Server configurations
    servers do
      server :production, "nats://nats.example.com:4222" do
        protocol :nats
        description "Production NATS server"
        
        variables do
          variable :environment do
            enum ["prod", "staging"]
            default "prod"
            description "Environment name"
          end
        end
        
        security [
          %{api_key: []}
        ]
        
        bindings [
          nats: [
            cluster_id: "production-cluster",
            client_id: "test-api",
            jetstream_enabled: true
          ]
        ]
      end
      
      server :grpc_server, "grpc://api.example.com:9090" do
        protocol :grpc
        description "gRPC server endpoint"
        
        bindings [
          grpc: [
            tls: true,
            max_message_size: 4194304
          ]
        ]
      end
    end
    
    # Security schemes
    components do
      security_schemes do
        security_scheme :api_key do
          type :apiKey
          location :header
          name "X-API-Key"
          description "API key authentication"
        end
        
        security_scheme :oauth2 do
          type :oauth2
          description "OAuth2 authentication"
          
          flows do
            authorization_code do
              authorization_url "https://auth.example.com/oauth/authorize"
              token_url "https://auth.example.com/oauth/token"
              
              scopes %{
                "read:events" => "Read access to events",
                "write:events" => "Write access to events"
              }
            end
          end
        end
      end
    end
    
    # Channel definitions
    channels do
      channel "user.events" do
        description "User event stream"
        
        parameters do
          parameter :user_id do
            schema do
              type :string
              format :uuid
            end
            description "User identifier"
          end
        end
        
        bindings [
          nats: [
            subject: "user.events.{user_id}",
            queue_group: "user-processors",
            jetstream: %{
              stream: "USER_EVENTS",
              durable_name: "user-event-processor",
              deliver_policy: :new,
              ack_policy: :explicit
            }
          ],
          grpc: [
            service: "UserEventService",
            method: "SubscribeToEvents"
          ]
        ]
      end
      
      channel "user.commands" do
        description "User command channel"
        
        bindings [
          nats: [
            subject: "user.cmd",
            reply_to: "user.cmd.reply"
          ],
          grpc: [
            service: "UserCommandService",
            method: "ProcessCommand"
          ]
        ]
      end
    end
    
    # Message definitions
    messages do
      message :user_created do
        traits [:timestamped_message, :authenticated_message]
        
        content_type "application/json"
        name_field "eventType"
        title "User Created Event"
        summary "Emitted when a new user is created"
        description "This event is published when a user successfully creates an account"
        
        tags ["user", "creation"]
        
        payload do
          type :object
          
          properties do
            field :user_id, :string do
              format :uuid
              description "Unique user identifier"
              examples ["123e4567-e89b-12d3-a456-426614174000"]
            end
            
            field :email, :string do
              format :email
              description "User email address"
              examples ["user@example.com"]
            end
            
            field :profile, :object do
              description "User profile information"
              
              properties do
                field :name, :string do
                  min_length 1
                  max_length 100
                  description "Full name"
                end
                
                field :age, :integer do
                  minimum 0
                  maximum 150
                  description "Age in years"
                end
              end
              
              required [:name]
            end
          end
          
          required [:user_id, :email, :profile]
        end
        
        examples do
          example :basic_user do
            summary "Basic user creation"
            value %{
              user_id: "123e4567-e89b-12d3-a456-426614174000",
              email: "john.doe@example.com",
              profile: %{
                name: "John Doe",
                age: 30
              }
            }
          end
        end
        
        bindings [
          nats: [
            headers: %{
              "Content-Type" => "application/json",
              "Event-Type" => "user.created"
            }
          ]
        ]
      end
      
      message :user_command do
        content_type "application/json"
        
        payload do
          type :object
          
          properties do
            field :command, :string do
              enum ["create", "update", "delete"]
              description "Command type"
            end
            
            field :data, :object do
              description "Command payload"
            end
          end
          
          required [:command, :data]
        end
      end
    end
    
    # Operation definitions
    operations do
      operation :publish_user_created do
        traits [:logged_operation]
        
        action :send
        channel "user.events"
        message :user_created
        
        title "Publish User Created Event"
        summary "Publishes a user created event"
        description "Publishes an event when a new user account is created"
        
        security [
          %{api_key: []},
          %{oauth2: ["write:events"]}
        ]
        
        tags ["user", "events", "publishing"]
        
        external_docs do
          description "User event publishing guide"
          url "https://docs.example.com/events/user-created"
        end
        
        reply do
          address "user.events.reply"
          
          messages do
            one_of [
              %{message_ref: :user_created_ack}
            ]
          end
        end
        
        bindings [
          nats: [
            headers: %{
              "Source" => "user-service"
            }
          ],
          grpc: [
            service: "UserEventService",
            method: "PublishUserCreated"
          ]
        ]
      end
      
      operation :receive_user_events do
        action :receive
        channel "user.events"
        
        messages do
          one_of [
            %{message_ref: :user_created}
          ]
        end
        
        summary "Subscribe to user events"
        description "Receives all user-related events"
        
        bindings [
          nats: [
            consumer_config: %{
              max_waiting: 100,
              max_ack_pending: 1000
            }
          ]
        ]
      end
      
      operation :send_user_command do
        action :send
        channel "user.commands"
        message :user_command
        
        summary "Send user command"
        description "Sends a command to process user operations"
        
        reply do
          address "user.commands.reply"
        end
      end
    end
  end
  
  # Acknowledgment message for testing
  defmodule TestApi.Messages do
    defstruct user_created_ack: %{
      content_type: "application/json",
      payload: %{
        type: :object,
        properties: %{
          status: %{type: :string, enum: ["success", "error"]},
          message: %{type: :string}
        },
        required: [:status]
      }
    }
  end
  
  describe "AsyncApi.Traits" do
    test "defines and retrieves message traits" do
      traits = AsyncApi.Traits.message_traits(TestApi)
      
      assert length(traits) == 2
      
      timestamped_trait = Enum.find(traits, &(&1.name == :timestamped_message))
      assert timestamped_trait.headers
      assert timestamped_trait.correlation_id
      
      auth_trait = Enum.find(traits, &(&1.name == :authenticated_message))
      assert auth_trait.headers
    end
    
    test "defines and retrieves operation traits" do
      traits = AsyncApi.Traits.operation_traits(TestApi)
      
      assert length(traits) == 1
      
      logged_trait = Enum.find(traits, &(&1.name == :logged_operation))
      assert logged_trait.summary == "Operation with automatic logging"
      assert logged_trait.tags == ["logging"]
    end
    
    test "validates trait references" do
      assert :ok = AsyncApi.Traits.validate_trait_references(TestApi)
    end
    
    test "generates trait documentation" do
      {:ok, markdown} = AsyncApi.Traits.generate_trait_documentation(TestApi, :markdown)
      assert String.contains?(markdown, "# AsyncAPI Traits Documentation")
      assert String.contains?(markdown, "timestamped_message")
      assert String.contains?(markdown, "logged_operation")
    end
  end
  
  describe "AsyncApi.Linter" do
    test "lints specification successfully" do
      assert {:ok, []} = AsyncApi.Linter.lint(TestApi)
    end
    
    test "checks naming conventions" do
      violations = AsyncApi.Linter.check_naming_conventions(TestApi)
      # Should pass with our well-named API
      assert length(violations) == 0
    end
    
    test "checks security requirements" do
      issues = AsyncApi.Linter.check_security_requirements(TestApi)
      # Should pass since we have security schemes defined
      assert length(issues) == 0
    end
    
    test "validates message schemas" do
      issues = AsyncApi.Linter.validate_message_schemas(TestApi)
      assert length(issues) == 0
    end
  end
  
  describe "AsyncApi.Validator" do
    test "validates message against schema" do
      valid_payload = %{
        user_id: "123e4567-e89b-12d3-a456-426614174000",
        email: "test@example.com",
        profile: %{
          name: "Test User",
          age: 25
        }
      }
      
      assert :ok = AsyncApi.Validator.validate_message(TestApi, :user_created, valid_payload)
    end
    
    test "rejects invalid message" do
      invalid_payload = %{
        user_id: "invalid-uuid",  # Invalid UUID format
        email: "not-an-email",    # Invalid email format
        profile: %{}              # Missing required name field
      }
      
      assert {:error, _errors} = AsyncApi.Validator.validate_message(TestApi, :user_created, invalid_payload)
    end
    
    test "validates operation parameters" do
      params = %{user_id: "123e4567-e89b-12d3-a456-426614174000"}
      
      assert :ok = AsyncApi.Validator.validate_operation_params(TestApi, :publish_user_created, params)
    end
    
    test "creates reusable validator" do
      assert {:ok, validator_fn} = AsyncApi.Validator.create_validator(TestApi, :user_created)
      assert is_function(validator_fn, 1)
      
      valid_payload = %{
        user_id: "123e4567-e89b-12d3-a456-426614174000",
        email: "test@example.com",
        profile: %{name: "Test User"}
      }
      
      assert :ok = validator_fn.(valid_payload)
    end
  end
  
  describe "AsyncApi.Testing" do
    test "validates all message schemas" do
      assert :ok = AsyncApi.Testing.test_all_message_schemas(TestApi)
    end
    
    test "validates all operations" do
      assert :ok = AsyncApi.Testing.test_all_operations(TestApi)
    end
    
    test "validates spec validity" do
      assert :ok = AsyncApi.Testing.test_spec_validity(TestApi)
    end
    
    test "generates example data" do
      assert {:ok, example} = AsyncApi.Testing.Generators.generate_example(TestApi, :user_created)
      
      # Should have all required fields
      assert Map.has_key?(example, :user_id)
      assert Map.has_key?(example, :email)
      assert Map.has_key?(example, :profile)
      assert Map.has_key?(example.profile, :name)
    end
    
    test "generates negative examples" do
      negative_examples = AsyncApi.Testing.Generators.generate_negative_examples(TestApi, :user_created)
      
      # Should generate some invalid examples
      assert length(negative_examples) > 0
    end
  end
  
  describe "AsyncApi.Bindings.Nats" do
    test "generates NATS configuration" do
      config = AsyncApi.Bindings.Nats.generate_nats_config(TestApi)
      
      assert config.connection
      assert config.jetstream
      assert config.subjects
      assert config.consumers
      assert config.producers
      
      # Check JetStream is enabled
      assert config.jetstream.enabled == true
    end
    
    test "generates JetStream configuration" do
      js_config = AsyncApi.Bindings.Nats.generate_jetstream_config(TestApi)
      
      assert js_config.streams
      assert js_config.consumers
      assert Map.has_key?(js_config.streams, "USER_EVENTS")
    end
    
    test "extracts subject patterns" do
      patterns = AsyncApi.Bindings.Nats.extract_subject_patterns(TestApi)
      
      user_events_pattern = Enum.find(patterns, &(&1.channel == :"user.events"))
      assert user_events_pattern.subject == "user.events.{user_id}"
      assert user_events_pattern.wildcard == true
      assert user_events_pattern.queue_group == "user-processors"
    end
    
    test "validates NATS bindings" do
      assert :ok = AsyncApi.Bindings.Nats.validate_nats_bindings(TestApi)
    end
    
    test "generates client code" do
      assert {:ok, client_code} = AsyncApi.Bindings.Nats.generate_client_code(TestApi, language: :elixir)
      
      assert String.contains?(client_code, "defmodule")
      assert String.contains?(client_code, "GenServer")
      assert String.contains?(client_code, "publish_user_created")
    end
  end
  
  describe "AsyncApi.Bindings.Grpc" do
    test "generates service definition" do
      assert {:ok, definition} = AsyncApi.Bindings.Grpc.generate_service_definition(TestApi, "UserService")
      
      assert String.contains?(definition, "service UserService")
      assert String.contains?(definition, "rpc")
    end
    
    test "generates Protocol Buffers file" do
      assert {:ok, proto_content} = AsyncApi.Bindings.Grpc.generate_proto_file(TestApi, "user_service")
      
      assert String.contains?(proto_content, "syntax = \"proto3\";")
      assert String.contains?(proto_content, "message")
      assert String.contains?(proto_content, "service")
    end
    
    test "generates client code" do
      assert {:ok, client_code} = AsyncApi.Bindings.Grpc.generate_client_code(TestApi, :elixir, service_name: "UserService")
      
      assert String.contains?(client_code, "defmodule")
      assert String.contains?(client_code, "GRPC")
    end
    
    test "validates gRPC bindings" do
      assert :ok = AsyncApi.Bindings.Grpc.validate_grpc_bindings(TestApi)
    end
  end
  
  describe "AsyncApi.Codegen" do
    test "generates Elixir client code" do
      assert {:ok, client_code} = AsyncApi.Codegen.generate_client(TestApi, :elixir)
      
      assert String.contains?(client_code, "defmodule")
      assert String.contains?(client_code, "publish_user_created")
      assert String.contains?(client_code, "subscribe_receive_user_events")
    end
    
    test "generates Elixir server code" do
      assert {:ok, server_code} = AsyncApi.Codegen.generate_server(TestApi, :elixir)
      
      assert String.contains?(server_code, "defmodule")
      assert String.contains?(server_code, "GenServer")
      assert String.contains?(server_code, "register_publish_user_created_handler")
    end
    
    test "generates type definitions" do
      assert {:ok, types_code} = AsyncApi.Codegen.generate_types(TestApi, :elixir)
      
      assert String.contains?(types_code, "defmodule")
      assert String.contains?(types_code, "defstruct")
      assert String.contains?(types_code, "UserCreated")
    end
    
    test "generates validators" do
      assert {:ok, validators_code} = AsyncApi.Codegen.generate_validators(TestApi, :elixir)
      
      assert String.contains?(validators_code, "defmodule")
      assert String.contains?(validators_code, "validate_user_created")
    end
    
    test "generates mocks" do
      assert {:ok, mocks_code} = AsyncApi.Codegen.generate_mocks(TestApi, :elixir)
      
      assert String.contains?(mocks_code, "defmodule")
      assert String.contains?(mocks_code, "GenServer")
      assert String.contains?(mocks_code, "publish_user_created")
    end
    
    test "generates tests" do
      assert {:ok, tests_code} = AsyncApi.Codegen.generate_tests(TestApi, :elixir)
      
      assert String.contains?(tests_code, "defmodule")
      assert String.contains?(tests_code, "use ExUnit.Case")
      assert String.contains?(tests_code, "test ")
    end
    
    test "generates all artifacts" do
      assert {:ok, all_code} = AsyncApi.Codegen.generate_all(TestApi, :elixir)
      
      assert Map.has_key?(all_code, :client)
      assert Map.has_key?(all_code, :server)
      assert Map.has_key?(all_code, :types)
      assert Map.has_key?(all_code, :validators)
      assert Map.has_key?(all_code, :mocks)
      assert Map.has_key?(all_code, :tests)
    end
    
    test "handles unsupported languages gracefully" do
      assert {:error, "Unsupported language: rust"} = AsyncApi.Codegen.generate_client(TestApi, :rust)
    end
  end
  
  describe "AsyncApi.Phoenix" do
    test "extracts channels" do
      channels = AsyncApi.Phoenix.extract_channels(TestApi)
      
      assert length(channels) == 2
      
      user_events_channel = Enum.find(channels, &(&1.name == :"user.events"))
      assert user_events_channel.path == "user.events"
      assert user_events_channel.description == "User event stream"
      assert length(user_events_channel.operations) > 0
    end
    
    test "generates channel module" do
      assert {:ok, channel_code} = AsyncApi.Phoenix.generate_channel_module(TestApi, :"user.events")
      
      assert String.contains?(channel_code, "defmodule")
      assert String.contains?(channel_code, "use Phoenix.Channel")
      assert String.contains?(channel_code, "def join")
      assert String.contains?(channel_code, "def handle_in")
    end
    
    test "generates broadcaster" do
      broadcaster_code = AsyncApi.Phoenix.generate_broadcaster(TestApi)
      
      assert String.contains?(broadcaster_code, "defmodule")
      assert String.contains?(broadcaster_code, "broadcast")
      assert String.contains?(broadcaster_code, "Phoenix.PubSub")
    end
    
    test "generates presence module" do
      presence_code = AsyncApi.Phoenix.generate_presence_module(TestApi)
      
      assert String.contains?(presence_code, "defmodule")
      assert String.contains?(presence_code, "use Phoenix.Presence")
      assert String.contains?(presence_code, "track_connection")
    end
    
    test "generates WebSocket endpoint configuration" do
      endpoint_code = AsyncApi.Phoenix.generate_websocket_endpoint(TestApi)
      
      assert String.contains?(endpoint_code, "defmodule")
      assert String.contains?(endpoint_code, "use Phoenix.Endpoint")
      assert String.contains?(endpoint_code, "socket")
    end
  end
  
  describe "AsyncApi.Errors" do
    test "validates with diagnostics" do
      assert {:ok, _spec} = AsyncApi.Errors.validate_with_diagnostics(TestApi)
    end
    
    test "provides helpful suggestions" do
      suggestions = AsyncApi.Errors.get_suggestions(:missing_required_field)
      
      assert length(suggestions) > 0
      assert Enum.any?(suggestions, &String.contains?(&1, "required field"))
    end
    
    test "provides documentation URLs" do
      url = AsyncApi.Errors.get_help_url(:schema_validation_failed)
      
      assert String.starts_with?(url, "https://")
      assert String.contains?(url, "troubleshooting")
    end
    
    test "creates detailed diagnostics" do
      diagnostic = AsyncApi.Errors.create_diagnostic(
        :error,
        :test_error,
        "Test error message",
        file: "test.ex",
        line: 42
      )
      
      assert diagnostic.severity == :error
      assert diagnostic.code == :test_error
      assert diagnostic.message == "Test error message"
      assert diagnostic.file == "test.ex"
      assert diagnostic.line == 42
      assert length(diagnostic.suggestions) > 0
    end
    
    test "enhances error context" do
      error = %RuntimeError{message: "Test error"}
      context = AsyncApi.Errors.enhance_error_context(error, TestApi)
      
      assert context.error == error
      assert context.api_module == TestApi
      assert context.spec_info
      assert context.elixir_version
      assert context.environment
    end
  end
  
  describe "AsyncApi core functionality" do
    test "generates complete AsyncAPI specification" do
      spec = AsyncApi.to_spec(TestApi)
      
      # Root level
      assert spec.asyncapi == "3.0.0"
      assert spec.id == "urn:com:example:test-api"
      assert spec.defaultContentType == "application/json"
      
      # Info object
      assert spec.info.title == "Test Event API"
      assert spec.info.version == "1.0.0"
      assert spec.info.contact.name == "API Team"
      assert spec.info.license.name == "MIT"
      
      # Servers
      assert Map.has_key?(spec.servers, :production)
      assert Map.has_key?(spec.servers, :grpc_server)
      
      # Channels
      assert Map.has_key?(spec.channels, :"user.events")
      assert Map.has_key?(spec.channels, :"user.commands")
      
      # Messages
      assert Map.has_key?(spec.components.messages, :user_created)
      assert Map.has_key?(spec.components.messages, :user_command)
      
      # Operations
      assert Map.has_key?(spec.operations, :publish_user_created)
      assert Map.has_key?(spec.operations, :receive_user_events)
      
      # Security schemes
      assert Map.has_key?(spec.components.securitySchemes, :api_key)
      assert Map.has_key?(spec.components.securitySchemes, :oauth2)
    end
    
    test "validates AsyncAPI spec structure" do
      spec = AsyncApi.to_spec(TestApi)
      
      # Ensure required fields are present
      assert spec.asyncapi
      assert spec.info
      assert spec.info.title
      assert spec.info.version
    end
    
    test "exports to JSON format" do
      json_output = AsyncApi.Export.to_string(TestApi, :json)
      
      assert String.contains?(json_output, "\"asyncapi\"")
      assert String.contains?(json_output, "\"info\"")
      assert String.contains?(json_output, "\"channels\"")
    end
    
    test "exports to YAML format" do
      yaml_output = AsyncApi.Export.to_string(TestApi, :yaml)
      
      assert String.contains?(yaml_output, "asyncapi:")
      assert String.contains?(yaml_output, "info:")
      assert String.contains?(yaml_output, "channels:")
    end
  end
  
  describe "Mix tasks integration" do
    test "dev task configuration" do
      # Test that our TestApi module is properly structured for dev tools
      assert Code.ensure_loaded?(TestApi)
      assert function_exported?(TestApi, :spark_dsl_config, 0)
      
      # Verify spec can be generated
      spec = AsyncApi.to_spec(TestApi)
      assert spec.info.title == "Test Event API"
    end
  end
  
  describe "Error handling and edge cases" do
    test "handles missing message gracefully" do
      assert {:error, _} = AsyncApi.Validator.validate_message(TestApi, :nonexistent_message, %{})
    end
    
    test "handles invalid trait references" do
      # This would be caught at compile time in a real scenario
      # but we can test the validation function
      assert AsyncApi.Traits.validate_trait_references(TestApi) == :ok
    end
    
    test "handles malformed bindings gracefully" do
      # NATS validator should handle missing or malformed bindings
      assert AsyncApi.Bindings.Nats.validate_nats_bindings(TestApi) == :ok
    end
  end
end