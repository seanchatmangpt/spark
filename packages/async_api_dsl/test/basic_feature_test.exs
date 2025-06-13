defmodule AsyncApi.BasicFeatureTest do
  @moduledoc """
  Basic functionality tests for AsyncAPI DSL features.
  Tests core functionality without external dependencies.
  """
  
  use ExUnit.Case, async: true
  
  # Simple test API
  defmodule SimpleTestApi do
    use AsyncApi
    
    info do
      title "Simple Test API"
      version "1.0.0"
      description "Simple test for basic functionality"
    end
    
    channels do
      channel "test.events" do
        description "Test event channel"
      end
    end
    
    components do
      messages do
        message :test_event do
          content_type "application/json"
          
          payload do
            type :object
            
            properties do
              field :id, :string, required: true
              field :data, :string
            end
          end
        end
      end
    end
    
    operations do
      operation :send_test_event do
        action :send
        channel "test.events"
        message :test_event
        summary "Send a test event"
      end
    end
  end
  
  # Test API with traits
  defmodule TraitTestApi do
    use AsyncApi
    
    info do
      title "Trait Test API"
      version "1.0.0"
    end
    
    message_traits do
      trait :timestamped do
        headers do
          field :timestamp, :string do
            description "Message timestamp"
          end
        end
      end
    end
    
    messages do
      message :user_event do
        traits [:timestamped]
        
        payload do
          type :object
          properties do
            field :user_id, :string, required: true
          end
        end
      end
    end
  end
  
  describe "Core AsyncAPI functionality" do
    test "generates basic specification" do
      spec = AsyncApi.to_spec(SimpleTestApi)
      
      assert spec.info.title == "Simple Test API"
      assert spec.info.version == "1.0.0"
      assert Map.has_key?(spec.channels, :"test.events")
      assert Map.has_key?(spec.components.messages, :test_event)
      assert Map.has_key?(spec.operations, :send_test_event)
    end
    
    test "handles export to JSON" do
      json_output = AsyncApi.Export.to_string(SimpleTestApi, :json)
      
      assert is_binary(json_output)
      assert String.contains?(json_output, "\"title\"")
      assert String.contains?(json_output, "Simple Test API")
    end
    
    test "handles export to YAML" do
      yaml_output = AsyncApi.Export.to_string(SimpleTestApi, :yaml)
      
      assert is_binary(yaml_output)
      assert String.contains?(yaml_output, "title:")
      assert String.contains?(yaml_output, "Simple Test API")
    end
  end
  
  describe "AsyncApi.Traits" do
    test "defines message traits" do
      traits = AsyncApi.Traits.message_traits(TraitTestApi)
      
      assert length(traits) == 1
      trait = List.first(traits)
      assert trait.name == :timestamped
      assert trait.headers != nil
    end
    
    test "validates trait references" do
      result = AsyncApi.Traits.validate_trait_references(TraitTestApi)
      assert result == :ok
    end
  end
  
  describe "AsyncApi.Linter" do
    test "basic linting functionality" do
      result = AsyncApi.Linter.lint(SimpleTestApi)
      assert {:ok, _} = result
    end
    
    test "checks naming conventions" do
      violations = AsyncApi.Linter.check_naming_conventions(SimpleTestApi)
      assert is_list(violations)
    end
  end
  
  describe "AsyncApi.Validator" do
    test "validates valid message payload" do
      valid_payload = %{
        id: "test-123",
        data: "test data"
      }
      
      result = AsyncApi.Validator.validate_message(SimpleTestApi, :test_event, valid_payload)
      assert result == :ok
    end
    
    test "rejects invalid message payload" do
      invalid_payload = %{
        data: "test data"
        # missing required 'id' field
      }
      
      result = AsyncApi.Validator.validate_message(SimpleTestApi, :test_event, invalid_payload)
      assert {:error, _} = result
    end
  end
  
  describe "AsyncApi.Testing" do
    test "validates message schemas" do
      result = AsyncApi.Testing.test_all_message_schemas(SimpleTestApi)
      assert result == :ok
    end
    
    test "validates operations" do
      result = AsyncApi.Testing.test_all_operations(SimpleTestApi)
      assert result == :ok
    end
    
    test "validates spec validity" do
      result = AsyncApi.Testing.test_spec_validity(SimpleTestApi)
      assert result == :ok
    end
  end
  
  describe "AsyncApi.Errors" do
    test "validates with diagnostics" do
      result = AsyncApi.Errors.validate_with_diagnostics(SimpleTestApi)
      assert {:ok, _} = result
    end
    
    test "provides suggestions for error codes" do
      suggestions = AsyncApi.Errors.get_suggestions(:missing_required_field)
      assert is_list(suggestions)
      assert length(suggestions) > 0
    end
    
    test "provides help URLs" do
      url = AsyncApi.Errors.get_help_url(:schema_validation_failed)
      assert is_binary(url)
      assert String.contains?(url, "https://")
    end
  end
  
  describe "AsyncApi.Codegen" do
    test "generates Elixir client code" do
      result = AsyncApi.Codegen.generate_client(SimpleTestApi, :elixir)
      assert {:ok, code} = result
      assert String.contains?(code, "defmodule")
      assert String.contains?(code, "send_test_event")
    end
    
    test "generates Elixir server code" do
      result = AsyncApi.Codegen.generate_server(SimpleTestApi, :elixir)
      assert {:ok, code} = result
      assert String.contains?(code, "defmodule")
      assert String.contains?(code, "GenServer")
    end
    
    test "generates type definitions" do
      result = AsyncApi.Codegen.generate_types(SimpleTestApi, :elixir)
      assert {:ok, code} = result
      assert String.contains?(code, "defmodule")
    end
    
    test "handles unsupported languages" do
      result = AsyncApi.Codegen.generate_client(SimpleTestApi, :rust)
      assert {:error, msg} = result
      assert String.contains?(msg, "Unsupported language")
    end
  end
  
  describe "AsyncApi.Phoenix" do
    test "extracts channels" do
      channels = AsyncApi.Phoenix.extract_channels(SimpleTestApi)
      assert is_list(channels)
      assert length(channels) == 1
      
      channel = List.first(channels)
      assert channel.name == :"test.events"
      assert channel.path == "test.events"
    end
    
    test "generates channel module code" do
      result = AsyncApi.Phoenix.generate_channel_module(SimpleTestApi, :"test.events")
      assert {:ok, code} = result
      assert String.contains?(code, "defmodule")
      assert String.contains?(code, "use Phoenix.Channel")
    end
    
    test "generates broadcaster code" do
      code = AsyncApi.Phoenix.generate_broadcaster(SimpleTestApi)
      assert String.contains?(code, "defmodule")
      assert String.contains?(code, "broadcast")
    end
  end
  
  describe "AsyncApi.Bindings.Nats" do
    test "generates NATS configuration" do
      config = AsyncApi.Bindings.Nats.generate_nats_config(SimpleTestApi)
      
      assert is_map(config)
      assert Map.has_key?(config, :connection)
      assert Map.has_key?(config, :jetstream)
      assert Map.has_key?(config, :subjects)
    end
    
    test "extracts subject patterns" do
      patterns = AsyncApi.Bindings.Nats.extract_subject_patterns(SimpleTestApi)
      assert is_list(patterns)
    end
    
    test "validates NATS bindings" do
      result = AsyncApi.Bindings.Nats.validate_nats_bindings(SimpleTestApi)
      assert result == :ok
    end
  end
  
  describe "AsyncApi.Bindings.Grpc" do
    test "generates service definition" do
      result = AsyncApi.Bindings.Grpc.generate_service_definition(SimpleTestApi, "TestService")
      assert {:ok, code} = result
      assert String.contains?(code, "service TestService")
    end
    
    test "generates proto file" do
      result = AsyncApi.Bindings.Grpc.generate_proto_file(SimpleTestApi, "test_service")
      assert {:ok, code} = result
      assert String.contains?(code, "syntax = \"proto3\";")
    end
    
    test "validates gRPC bindings" do
      result = AsyncApi.Bindings.Grpc.validate_grpc_bindings(SimpleTestApi)
      assert result == :ok
    end
  end
end