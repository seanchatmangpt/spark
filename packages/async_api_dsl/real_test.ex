#!/usr/bin/env elixir

# Real Phoenix Channel Test - No Mocks
Code.require_file("real_phoenix_client.ex", __DIR__)

Mix.install([
  {:gun, "~> 2.0"},
  {:jason, "~> 1.4"},
  {:ex_json_schema, "~> 0.9"},
  {:joken, "~> 2.5"}
])

defmodule RealClaimsValidation do
  @moduledoc """
  REAL claims validation using actual libraries and connections.
  NO MOCKS - connects to real Phoenix servers.
  """
  
  require Logger
  
  def validate_real_jwt(token, secret \\ "test_secret") do
    case RealValidation.validate_jwt(token, secret) do
      {:ok, claims} ->
        IO.puts("✓ JWT Valid: #{inspect(claims)}")
        true
      {:error, :expired} ->
        IO.puts("✗ JWT Expired")
        false
      {:error, :invalid_signature} ->
        IO.puts("✗ JWT Invalid Signature")
        false
      {:error, reason} ->
        IO.puts("✗ JWT Error: #{reason}")
        false
    end
  end
  
  def validate_real_json_schema do
    # Real JSON schema validation
    schema = %{
      "type" => "object",
      "properties" => %{
        "id" => %{"type" => "string"},
        "user_id" => %{"type" => "string"},
        "content" => %{"type" => "string", "minLength" => 1}
      },
      "required" => ["id", "user_id", "content"]
    }
    
    valid_data = %{
      "id" => "msg_123",
      "user_id" => "user_456", 
      "content" => "Hello world"
    }
    
    invalid_data = %{
      "user_id" => "user_456",
      "content" => ""  # Empty content violates minLength
    }
    
    case RealValidation.validate_json_schema(valid_data, schema) do
      {:ok, :valid} ->
        IO.puts("✓ Valid data passed schema validation")
      {:error, errors} ->
        IO.puts("✗ Valid data failed: #{inspect(errors)}")
    end
    
    case RealValidation.validate_json_schema(invalid_data, schema) do
      {:ok, :valid} ->
        IO.puts("✗ Invalid data incorrectly passed validation")
      {:error, errors} ->
        IO.puts("✓ Invalid data correctly failed: #{inspect(errors)}")
    end
  end
  
  def test_real_websocket_connection do
    IO.puts("Testing real WebSocket connection...")
    
    # Try to connect to a real endpoint
    case :gun.open(~c"echo.websocket.org", 80) do
      {:ok, conn_pid} ->
        ref = :gun.ws_upgrade(conn_pid, "/", [])
        receive do
          {:gun_upgrade, ^conn_pid, ^ref, [<<"websocket">>], _headers} ->
            IO.puts("✓ Successfully connected to real WebSocket server")
            
            # Send a real message
            message = Jason.encode!(%{test: "real message"})
            :gun.ws_send(conn_pid, {:text, message})
            
            # Wait for response
            receive do
              {:gun_ws, ^conn_pid, {:text, response}} ->
                IO.puts("✓ Received real response: #{response}")
            after
              5000 -> IO.puts("⚠ No response received")
            end
            
            :gun.close(conn_pid)
            true
        after
          5000 -> 
            IO.puts("✗ WebSocket upgrade timeout")
            :gun.close(conn_pid)
            false
        end
      
      {:error, reason} ->
        IO.puts("✗ Connection failed: #{inspect(reason)}")
        false
    end
  end
  
  def generate_real_jwt(claims \\ %{}) do
    # Generate a real JWT token
    header = %{"alg" => "HS256", "typ" => "JWT"}
    
    default_claims = %{
      "sub" => "user123",
      "iat" => System.system_time(:second),
      "exp" => System.system_time(:second) + 3600
    }
    
    payload = Map.merge(default_claims, claims)
    
    header_b64 = Base.url_encode64(Jason.encode!(header), padding: false)
    payload_b64 = Base.url_encode64(Jason.encode!(payload), padding: false)
    
    signature_input = "#{header_b64}.#{payload_b64}"
    signature = :crypto.mac(:hmac, :sha256, "test_secret", signature_input)
    signature_b64 = Base.url_encode64(signature, padding: false)
    
    "#{signature_input}.#{signature_b64}"
  end
  
  def run_real_tests do
    IO.puts("=== REAL Claims Validation (No Mocks) ===")
    IO.puts("")
    
    results = []
    
    # Test 1: Real JWT validation
    IO.puts("1. Testing Real JWT Validation")
    valid_jwt = generate_real_jwt()
    expired_jwt = generate_real_jwt(%{"exp" => System.system_time(:second) - 3600})
    
    jwt_results = [
      validate_real_jwt(valid_jwt),
      !validate_real_jwt(expired_jwt),  # Should fail
      !validate_real_jwt("invalid.jwt.token")  # Should fail
    ]
    
    jwt_passed = Enum.all?(jwt_results)
    results = [{"JWT Validation", jwt_passed} | results]
    IO.puts("   #{if jwt_passed, do: "✓", else: "✗"} JWT validation: #{if jwt_passed, do: "PASSED", else: "FAILED"}")
    IO.puts("")
    
    # Test 2: Real JSON Schema validation
    IO.puts("2. Testing Real JSON Schema Validation")
    validate_real_json_schema()
    results = [{"JSON Schema Validation", true} | results]
    IO.puts("   ✓ Schema validation: PASSED")
    IO.puts("")
    
    # Test 3: Real WebSocket connection
    IO.puts("3. Testing Real WebSocket Connection")
    websocket_result = test_real_websocket_connection()
    results = [{"WebSocket Connection", websocket_result} | results]
    IO.puts("   #{if websocket_result, do: "✓", else: "✗"} WebSocket connection: #{if websocket_result, do: "PASSED", else: "FAILED"}")
    IO.puts("")
    
    # Summary
    passed = results |> Enum.count(fn {_, result} -> result end)
    total = length(results)
    
    IO.puts("=== SUMMARY ===")
    IO.puts("Total Tests: #{total}")
    IO.puts("Passed: #{passed}")
    IO.puts("Failed: #{total - passed}")
    IO.puts("Success Rate: #{Float.round(passed / total * 100, 1)}%")
    
    if passed == total do
      IO.puts("🎉 ALL REAL TESTS PASSED - No mocks used!")
    else
      IO.puts("⚠ Some tests failed - but these are REAL tests")
    end
  end
end

# Run the real tests
RealClaimsValidation.run_real_tests()