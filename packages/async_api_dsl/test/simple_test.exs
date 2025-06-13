defmodule AsyncApi.SimpleTest do
  @moduledoc """
  Simple smoke tests for core AsyncAPI DSL functionality.
  """
  
  use ExUnit.Case, async: true
  
  defmodule TestApi do
    use AsyncApi
    
    info do
      title "Test API"
      version "1.0.0"
    end
    
    channels do
      channel "events" do
        description "Event channel"
      end
    end
    
    components do
      messages do
        message :test_event do
          content_type "application/json"
          payload :test_event_schema
        end
      end
      
      schemas do
        schema :test_event_schema do
          type :object
          
          property :id, :string
          
          required [:id]
        end
      end
    end
    
    operations do
      operation :send_event do
        action :send
        channel "events"
        message :test_event
      end
    end
  end
  
  test "generates basic specification" do
    spec = AsyncApi.to_spec(TestApi)
    assert spec.info.title == "Test API"
    assert Map.has_key?(spec.channels, "events")
    assert Map.has_key?(spec.operations, :send_event)
  end
  
  test "core modules exist and have basic functionality" do
    # Test that basic DSL functionality works
    spec = AsyncApi.to_spec(TestApi)
    assert is_map(spec)
    assert spec.asyncapi == "3.0.0"
    assert spec.info.title == "Test API"
    
    # Test basic validation works
    assert :ok = AsyncApi.Validator.validate_message(TestApi, :test_event, %{id: "test-123"})
    
    # Test basic code generation works  
    assert {:ok, code} = AsyncApi.Codegen.generate_client(TestApi, :elixir)
    assert String.contains?(code, "defmodule")
  end
  
  test "basic linting works" do
    result = AsyncApi.Linter.lint(TestApi)
    assert {:ok, _} = result
  end
  
  test "basic validation works" do
    valid_payload = %{id: "test-123"}
    result = AsyncApi.Validator.validate_message(TestApi, :test_event, valid_payload)
    assert result == :ok
  end
  
  test "basic code generation works" do
    result = AsyncApi.Codegen.generate_client(TestApi, :elixir)
    assert {:ok, code} = result
    assert String.contains?(code, "defmodule")
  end
  
  test "basic error handling works" do
    result = AsyncApi.Errors.validate_with_diagnostics(TestApi)
    # Should return errors due to missing security schemes
    assert {:error, diagnostics} = result
    assert is_list(diagnostics)
    assert length(diagnostics) > 0
  end
  
  test "export functionality works" do
    json_output = AsyncApi.Export.to_string(TestApi, :json)
    assert String.contains?(json_output, "Test API")
    
    yaml_output = AsyncApi.Export.to_string(TestApi, :yaml)
    assert String.contains?(yaml_output, "Test API")
  end
end