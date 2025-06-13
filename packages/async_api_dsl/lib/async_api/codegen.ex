defmodule AsyncApi.Codegen do
  @moduledoc """
  Code generation utilities for AsyncAPI specifications.
  
  Generates client code, server stubs, message validation functions,
  and other utilities from AsyncAPI specifications.
  
  ## Supported Languages
  
  - Elixir (full support)
  - Go (basic support)
  - TypeScript/JavaScript (basic support)
  - Python (basic support)
  
  ## Usage
  
      # Generate Elixir client
      {:ok, client_code} = AsyncApi.Codegen.generate_client(MyApp.EventApi, :elixir)
      File.write!("lib/my_app/event_client.ex", client_code)
      
      # Generate TypeScript types
      {:ok, types} = AsyncApi.Codegen.generate_types(MyApp.EventApi, :typescript)
      File.write!("src/types/events.ts", types)
      
      # Generate validation functions
      {:ok, validators} = AsyncApi.Codegen.generate_validators(MyApp.EventApi, :elixir)
      
      # Generate server stubs
      {:ok, server_code} = AsyncApi.Codegen.generate_server(MyApp.EventApi, :elixir)
  """

  alias AsyncApi.Info

  @type language :: :elixir | :go | :typescript | :javascript | :python | :rust | :java
  @type generation_target :: :client | :server | :types | :validators | :mocks | :tests

  @doc """
  Generate client code for a specific language.
  
  Creates a complete client with methods for all operations.
  """
  @spec generate_client(module(), language(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_client(api_module, language, opts \\ []) do
    try do
      spec = AsyncApi.to_spec(api_module)
      
      case language do
        :elixir -> {:ok, generate_elixir_client(spec, api_module, opts)}
        :go -> {:ok, generate_go_client(spec, api_module, opts)}
        :typescript -> {:ok, generate_typescript_client(spec, api_module, opts)}
        :javascript -> {:ok, generate_javascript_client(spec, api_module, opts)}
        :python -> {:ok, generate_python_client(spec, api_module, opts)}
        _ -> {:error, "Unsupported language: #{language}"}
      end
    rescue
      error -> {:error, "Code generation failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Generate server stub code for a specific language.
  
  Creates server stubs with handler placeholders for all operations.
  """
  @spec generate_server(module(), language(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_server(api_module, language, opts \\ []) do
    try do
      spec = AsyncApi.to_spec(api_module)
      
      case language do
        :elixir -> {:ok, generate_elixir_server(spec, api_module, opts)}
        :go -> {:ok, generate_go_server(spec, api_module, opts)}
        :typescript -> {:ok, generate_typescript_server(spec, api_module, opts)}
        :python -> {:ok, generate_python_server(spec, api_module, opts)}
        _ -> {:error, "Unsupported language: #{language}"}
      end
    rescue
      error -> {:error, "Code generation failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Generate type definitions for a specific language.
  
  Creates type/interface definitions for all messages and schemas.
  """
  @spec generate_types(module(), language(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_types(api_module, language, opts \\ []) do
    try do
      spec = AsyncApi.to_spec(api_module)
      
      case language do
        :elixir -> {:ok, generate_elixir_types(spec, api_module, opts)}
        :typescript -> {:ok, generate_typescript_types(spec, api_module, opts)}
        :go -> {:ok, generate_go_types(spec, api_module, opts)}
        :python -> {:ok, generate_python_types(spec, api_module, opts)}
        _ -> {:error, "Unsupported language: #{language}"}
      end
    rescue
      error -> {:error, "Type generation failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Generate validation functions for message payloads.
  
  Creates validation functions that can be used at runtime.
  """
  @spec generate_validators(module(), language(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_validators(api_module, language, opts \\ []) do
    try do
      spec = AsyncApi.to_spec(api_module)
      
      case language do
        :elixir -> {:ok, generate_elixir_validators(spec, api_module, opts)}
        :typescript -> {:ok, generate_typescript_validators(spec, api_module, opts)}
        :go -> {:ok, generate_go_validators(spec, api_module, opts)}
        :python -> {:ok, generate_python_validators(spec, api_module, opts)}
        _ -> {:error, "Unsupported language: #{language}"}
      end
    rescue
      error -> {:error, "Validator generation failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Generate mock implementations for testing.
  """
  @spec generate_mocks(module(), language(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_mocks(api_module, language, opts \\ []) do
    try do
      spec = AsyncApi.to_spec(api_module)
      
      case language do
        :elixir -> {:ok, generate_elixir_mocks(spec, api_module, opts)}
        :typescript -> {:ok, generate_typescript_mocks(spec, api_module, opts)}
        :go -> {:ok, generate_go_mocks(spec, api_module, opts)}
        :python -> {:ok, generate_python_mocks(spec, api_module, opts)}
        _ -> {:error, "Unsupported language: #{language}"}
      end
    rescue
      error -> {:error, "Mock generation failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Generate test files for the API.
  """
  @spec generate_tests(module(), language(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_tests(api_module, language, opts \\ []) do
    try do
      spec = AsyncApi.to_spec(api_module)
      
      case language do
        :elixir -> {:ok, generate_elixir_tests(spec, api_module, opts)}
        :typescript -> {:ok, generate_typescript_tests(spec, api_module, opts)}
        :go -> {:ok, generate_go_tests(spec, api_module, opts)}
        :python -> {:ok, generate_python_tests(spec, api_module, opts)}
        _ -> {:error, "Unsupported language: #{language}"}
      end
    rescue
      error -> {:error, "Test generation failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Generate all code artifacts for a specific language.
  
  Creates client, server, types, validators, mocks, and tests.
  """
  @spec generate_all(module(), language(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def generate_all(api_module, language, opts \\ []) do
    try do
      results = %{}
      
      with {:ok, client} <- generate_client(api_module, language, opts),
           {:ok, server} <- generate_server(api_module, language, opts),
           {:ok, types} <- generate_types(api_module, language, opts),
           {:ok, validators} <- generate_validators(api_module, language, opts),
           {:ok, mocks} <- generate_mocks(api_module, language, opts),
           {:ok, tests} <- generate_tests(api_module, language, opts) do
        
        {:ok, %{
          client: client,
          server: server,
          types: types,
          validators: validators,
          mocks: mocks,
          tests: tests
        }}
      else
        {:error, reason} -> {:error, reason}
      end
    rescue
      error -> {:error, "Full generation failed: #{Exception.message(error)}"}
    end
  end

  # Elixir code generation

  defp generate_elixir_client(spec, api_module, opts) do
    module_name = Keyword.get(opts, :module_name, "#{api_module}.Client")
    operations = spec[:operations] || %{}
    
    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Generated client for #{api_module}.
      
      This module provides functions to interact with the #{spec[:info][:title]} API.
      \"\"\"
      
      #{generate_elixir_client_functions(operations, spec)}
      
      # Helper functions
      
      defp encode_message(payload) when is_map(payload) do
        Jason.encode!(payload)
      end
      
      defp encode_message(payload), do: payload
      
      defp decode_message(data) when is_binary(data) do
        case Jason.decode(data) do
          {:ok, decoded} -> decoded
          {:error, _} -> data
        end
      end
      
      defp decode_message(data), do: data
      
      defp validate_message(message_name, payload) do
        case AsyncApi.Validator.validate_message(#{api_module}, message_name, payload) do
          :ok -> {:ok, payload}
          {:error, errors} -> {:error, {:validation_failed, errors}}
        end
      end
    end
    """
  end

  defp generate_elixir_client_functions(operations, spec) do
    operations
    |> Enum.map(fn {operation_name, operation} ->
      generate_elixir_client_function(operation_name, operation, spec)
    end)
    |> Enum.join("\n\n  ")
  end

  defp generate_elixir_client_function(operation_name, operation, spec) do
    function_name = Macro.underscore(to_string(operation_name))
    # Extract channel reference - it might be a map with $ref
    channel = case operation[:channel] do
      %{"$ref" => ref} -> String.replace(ref, "#/channels/", "")
      channel_name when is_binary(channel_name) -> channel_name
      channel_name when is_atom(channel_name) -> to_string(channel_name)
    end
    message = operation[:message]
    action = operation[:action]
    
    case action do
      :send ->
        summary = operation[:summary] || ("Send " <> to_string(operation_name) <> " message")
        description = operation[:description] || ""
        "@doc \"\"\"\n" <> summary <> "\n\n" <> description <> "\n\"\"\"\ndef " <> function_name <> "(payload, opts \\\\ []) do\n  with {:ok, validated} <- validate_message(:" <> to_string(message) <> ", payload) do\n    channel = \"" <> channel <> "\"\n    encoded_payload = encode_message(validated)\n    \n    # TODO: Implement actual message sending based on protocol\n    # This is a placeholder - replace with actual transport implementation\n    {:ok, %{\n      channel: channel,\n      message: :" <> to_string(message) <> ",\n      payload: encoded_payload,\n      metadata: Keyword.get(opts, :metadata, %{})\n    }}\n  end\nend"
      
      :receive ->
        summary = operation[:summary] || ("Subscribe to " <> to_string(operation_name) <> " messages")
        description = operation[:description] || ""
        "@doc \"\"\"\n" <> summary <> "\n\n" <> description <> "\n\"\"\"\ndef subscribe_" <> function_name <> "(callback, opts \\\\ []) when is_function(callback, 1) do\n  channel = \"" <> channel <> "\"\n  \n  # TODO: Implement actual subscription based on protocol\n  # This is a placeholder - replace with actual transport implementation\n  {:ok, %{\n    channel: channel,\n    message: :" <> to_string(message) <> ",\n    callback: callback,\n    options: opts\n  }}\nend"
    end
  end

  defp generate_elixir_server(spec, api_module, opts) do
    module_name = Keyword.get(opts, :module_name, "#{api_module}.Server")
    operations = spec[:operations] || %{}
    
    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Generated server stub for #{api_module}.
      
      This module provides a GenServer-based server implementation for handling
      #{spec[:info][:title]} API operations.
      \"\"\"
      
      use GenServer
      require Logger
      
      # Client API
      
      def start_link(opts \\\\ []) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end
      
      #{generate_elixir_server_handlers(operations, spec)}
      
      # GenServer callbacks
      
      def init(opts) do
        state = %{
          operations: #{inspect(Map.keys(operations))},
          handlers: %{},
          options: opts
        }
        
        {:ok, state}
      end
      
      def handle_call({:register_handler, operation, handler}, _from, state) do
        updated_state = put_in(state.handlers[operation], handler)
        {:reply, :ok, updated_state}
      end
      
      def handle_call({:handle_operation, operation, payload, metadata}, _from, state) do
        case Map.get(state.handlers, operation) do
          nil ->
            Logger.warning("No handler registered for operation: \#{operation}")
            {:reply, {:error, :no_handler}, state}
          
          handler when is_function(handler, 2) ->
            try do
              result = handler.(payload, metadata)
              {:reply, {:ok, result}, state}
            rescue
              error ->
                Logger.error("Handler error for \#{operation}: \#{Exception.message(error)}")
                {:reply, {:error, {:handler_error, Exception.message(error)}}, state}
            end
          
          handler when is_function(handler, 1) ->
            try do
              result = handler.(payload)
              {:reply, {:ok, result}, state}
            rescue
              error ->
                Logger.error("Handler error for \#{operation}: \#{Exception.message(error)}")
                {:reply, {:error, {:handler_error, Exception.message(error)}}, state}
            end
        end
      end
      
      def handle_info(msg, state) do
        Logger.debug("Received unexpected message: \#{inspect(msg)}")
        {:noreply, state}
      end
    end
    """
  end

  defp generate_elixir_server_handlers(operations, _spec) do
    operations
    |> Enum.map(fn {operation_name, operation} ->
      generate_elixir_server_handler(operation_name, operation)
    end)
    |> Enum.join("\n\n  ")
  end

  defp generate_elixir_server_handler(operation_name, operation) do
    function_name = "register_#{Macro.underscore(to_string(operation_name))}_handler"
    
    """
    @doc \"\"\"
    Register a handler for #{operation_name} operation.
    
    #{operation[:summary] || ""}
    #{operation[:description] || ""}
    
    ## Examples
    
        #{function_name}(fn payload, metadata ->
          # Handle the #{operation_name} operation
          {:ok, "processed"}
        end)
    \"\"\"
    def #{function_name}(handler) when is_function(handler) do
      GenServer.call(__MODULE__, {:register_handler, :#{operation_name}, handler})
    end
    
    @doc \"\"\"
    Handle #{operation_name} operation directly.
    \"\"\"
    def handle_#{Macro.underscore(to_string(operation_name))}(payload, metadata \\\\ %{}) do
      GenServer.call(__MODULE__, {:handle_operation, :#{operation_name}, payload, metadata})
    end
    """
  end

  defp generate_elixir_types(spec, api_module, opts) do
    schemas = get_in(spec, [:components, :schemas]) || %{}
    module_name = Keyword.get(opts, :module_name, "#{api_module}.Types")
    
    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Type definitions for #{api_module}.
      
      This module contains struct definitions for all message schemas
      defined in the #{spec[:info][:title]} API.
      \"\"\"
      
      #{generate_elixir_type_definitions(schemas)}
    end
    """
  end

  defp generate_elixir_type_definitions(schemas) do
    schemas
    |> Enum.map(fn {schema_name, schema} ->
      generate_elixir_type_definition(schema_name, schema)
    end)
    |> Enum.join("\n\n  ")
  end

  defp generate_elixir_type_definition(schema_name, schema) do
    struct_name = Macro.camelize(to_string(schema_name))
    properties = schema[:properties] || []
    required = schema[:required] || []
    schema_description = schema[:description] || ("Schema for " <> to_string(schema_name))
    
    field_definitions = properties
    |> Enum.map(fn prop ->
      generate_elixir_field_definition(prop, required)
    end)
    |> Enum.join(",\n    ")
    
    "@type t_" <> to_string(schema_name) <> " :: %__MODULE__." <> struct_name <> "{\n  " <> field_definitions <> "\n}\n\ndefmodule " <> struct_name <> " do\n  @moduledoc \"\"\"\n  " <> schema_description <> "\n  \"\"\"\n  \n  defstruct [\n    " <> field_definitions <> "\n  ]\n  \n  @type t :: %__MODULE__{\n    " <> field_definitions <> "\n  }\nend"
  end

  defp generate_elixir_field_definition({prop_name, prop_schema}, required) do
    field_name = to_string(prop_name)
    field_type = convert_schema_type_to_elixir(prop_schema[:type])
    
    default_value = if Enum.member?(required, prop_name), do: "", else: " | nil"
    
    "#{field_name}: #{field_type}#{default_value}"
  end

  defp convert_schema_type_to_elixir(type) do
    case type do
      :string -> "String.t()"
      :integer -> "integer()"
      :number -> "float()"
      :boolean -> "boolean()"
      :array -> "list()"
      :object -> "map()"
      _ -> "any()"
    end
  end

  defp generate_elixir_validators(spec, api_module, opts) do
    messages = get_in(spec, [:components, :messages]) || %{}
    module_name = Keyword.get(opts, :module_name, "#{api_module}.Validators")
    
    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Message validators for #{api_module}.
      
      This module provides optimized validation functions for all message types
      defined in the #{spec[:info][:title]} API.
      \"\"\"
      
      alias AsyncApi.Validator
      
      #{generate_elixir_validator_functions(messages, api_module)}
      
      @doc \"\"\"
      Validate any message by name.
      \"\"\"
      def validate_message(message_name, payload) do
        Validator.validate_message(#{api_module}, message_name, payload)
      end
      
      @doc \"\"\"
      Get a pre-compiled validator function for a message type.
      \"\"\"
      def get_validator(message_name) do
        Validator.create_validator(#{api_module}, message_name)
      end
    end
    """
  end

  defp generate_elixir_validator_functions(messages, api_module) do
    messages
    |> Enum.map(fn {message_name, _message} ->
      function_name = "validate_#{Macro.underscore(to_string(message_name))}"
      
      """
      @doc \"\"\"
      Validate #{message_name} message payload.
      \"\"\"
      def #{function_name}(payload) do
        validate_message(:#{message_name}, payload)
      end
      """
    end)
    |> Enum.join("\n\n  ")
  end

  defp generate_elixir_mocks(spec, api_module, opts) do
    operations = spec[:operations] || %{}
    module_name = Keyword.get(opts, :module_name, "#{api_module}.Mocks")
    
    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Mock implementations for #{api_module}.
      
      This module provides mock implementations for testing purposes.
      \"\"\"
      
      use GenServer
      
      def start_link(opts \\\\ []) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end
      
      #{generate_elixir_mock_functions(operations)}
      
      def init(_opts) do
        {:ok, %{recorded_calls: []}}
      end
      
      def handle_call({:record_call, operation, payload}, _from, state) do
        call = %{
          operation: operation,
          payload: payload,
          timestamp: System.system_time(:millisecond)
        }
        
        updated_state = %{state | recorded_calls: [call | state.recorded_calls]}
        {:reply, :ok, updated_state}
      end
      
      def handle_call(:get_recorded_calls, _from, state) do
        {:reply, Enum.reverse(state.recorded_calls), state}
      end
      
      def handle_call(:clear_recorded_calls, _from, state) do
        {:reply, :ok, %{state | recorded_calls: []}}
      end
    end
    """
  end

  defp generate_elixir_mock_functions(operations) do
    operations
    |> Enum.map(fn {operation_name, operation} ->
      generate_elixir_mock_function(operation_name, operation)
    end)
    |> Enum.join("\n\n  ")
  end

  defp generate_elixir_mock_function(operation_name, operation) do
    function_name = Macro.underscore(to_string(operation_name))
    
    case operation[:action] do
      :send ->
        """
        def #{function_name}(payload, opts \\\\ []) do
          GenServer.call(__MODULE__, {:record_call, :#{operation_name}, payload})
          
          # Return a mock successful response
          {:ok, %{
            operation: :#{operation_name},
            payload: payload,
            message_id: "mock-#{:rand.uniform(1000000)}",
            timestamp: System.system_time(:millisecond)
          }}
        end
        """
      
      :receive ->
        """
        def subscribe_#{function_name}(callback, opts \\\\ []) do
          GenServer.call(__MODULE__, {:record_call, :subscribe_#{operation_name}, %{callback: callback, opts: opts}})
          
          # Return a mock subscription
          {:ok, %{
            subscription_id: "mock-sub-#{:rand.uniform(1000000)}",
            operation: :#{operation_name}
          }}
        end
        """
    end
  end

  defp generate_elixir_tests(spec, api_module, opts) do
    operations = spec[:operations] || %{}
    module_name = Keyword.get(opts, :module_name, "#{api_module}Test")
    
    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Generated tests for #{api_module}.
      \"\"\"
      
      use ExUnit.Case, async: true
      use AsyncApi.Testing, api: #{api_module}
      
      alias #{api_module}.Client
      alias #{api_module}.Mocks
      
      setup do
        {:ok, _} = Mocks.start_link()
        :ok
      end
      
      #{generate_elixir_test_functions(operations)}
      
      describe "message validation" do
        #{generate_elixir_validation_tests(spec)}
      end
      
      describe "contract compliance" do
        test "API spec is valid" do
          assert_spec_passes_linting()
        end
        
        test "all operations are properly defined" do
          operations = AsyncApi.Info.operations(#{api_module})
          assert length(operations) > 0
          
          Enum.each(operations, fn operation ->
            assert operation.name != nil
            assert operation.action in [:send, :receive]
            assert operation.channel != nil
            assert operation.message != nil
          end)
        end
      end
    end
    """
  end

  defp generate_elixir_test_functions(operations) do
    operations
    |> Enum.map(fn {operation_name, operation} ->
      generate_elixir_test_function(operation_name, operation)
    end)
    |> Enum.join("\n\n    ")
  end

  defp generate_elixir_test_function(operation_name, operation) do
    test_name = "test #{Macro.underscore(to_string(operation_name))}"
    function_name = Macro.underscore(to_string(operation_name))
    
    case operation[:action] do
      :send ->
        """
        #{test_name} do
          # Generate valid test payload
          {:ok, payload} = AsyncApi.Testing.Generators.generate_example(@async_api_module, :#{operation[:message]})
          
          # Test the operation
          assert {:ok, result} = Client.#{function_name}(payload)
          assert result.operation == :#{operation_name}
          assert result.payload == payload
        end
        """
      
      :receive ->
        """
        #{test_name} do
          callback = fn message ->
            assert_valid_message(:#{operation[:message]}, message.payload)
            :ok
          end
          
          assert {:ok, subscription} = Client.subscribe_#{function_name}(callback)
          assert subscription.operation == :#{operation_name}
        end
        """
    end
  end

  defp generate_elixir_validation_tests(spec) do
    messages = get_in(spec, [:components, :messages]) || %{}
    
    messages
    |> Enum.map(fn {message_name, _message} ->
      """
      test "#{message_name} message validation" do
        # Test valid message
        {:ok, valid_payload} = AsyncApi.Testing.Generators.generate_example(@async_api_module, :#{message_name})
        assert_valid_message(:#{message_name}, valid_payload)
        
        # Test invalid message (if negative examples available)
        negative_examples = AsyncApi.Testing.Generators.generate_negative_examples(@async_api_module, :#{message_name})
        
        Enum.each(negative_examples, fn example ->
          assert_invalid_message(:#{message_name}, example.value)
        end)
      end
      """
    end)
    |> Enum.join("\n\n    ")
  end

  # Placeholder implementations for other languages

  defp generate_go_client(_spec, _api_module, _opts) do
    "// Go client generation not yet implemented"
  end

  defp generate_go_server(_spec, _api_module, _opts) do
    "// Go server generation not yet implemented"
  end

  defp generate_go_types(_spec, _api_module, _opts) do
    "// Go types generation not yet implemented"
  end

  defp generate_go_validators(_spec, _api_module, _opts) do
    "// Go validators generation not yet implemented"
  end

  defp generate_go_mocks(_spec, _api_module, _opts) do
    "// Go mocks generation not yet implemented"
  end

  defp generate_go_tests(_spec, _api_module, _opts) do
    "// Go tests generation not yet implemented"
  end

  defp generate_typescript_client(spec, api_module, opts) do
    class_name = Keyword.get(opts, :class_name, "#{api_module |> to_string() |> String.split(".") |> List.last()}Client")
    operations = spec[:operations] || %{}
    
    """
    /**
     * Generated TypeScript client for #{api_module}
     * 
     * #{spec[:info][:description] || "AsyncAPI client"}
     */
    
    #{generate_typescript_types_inline(spec)}
    
    export interface ClientOptions {
      transport?: Transport;
      validator?: MessageValidator;
      timeout?: number;
      retries?: number;
    }
    
    export interface Transport {
      send(channel: string, message: any, options?: any): Promise<void>;
      subscribe(channel: string, callback: (message: any) => void, options?: any): Promise<Subscription>;
    }
    
    export interface Subscription {
      unsubscribe(): Promise<void>;
    }
    
    export interface MessageValidator {
      validate(messageType: string, payload: any): ValidationResult;
    }
    
    export interface ValidationResult {
      valid: boolean;
      errors?: string[];
    }
    
    export class #{class_name} {
      private transport: Transport;
      private validator?: MessageValidator;
      private options: ClientOptions;
      
      constructor(options: ClientOptions) {
        if (!options.transport) {
          throw new Error('Transport is required');
        }
        
        this.transport = options.transport;
        this.validator = options.validator;
        this.options = {
          timeout: 5000,
          retries: 3,
          ...options
        };
      }
      
      #{generate_typescript_client_methods(operations)}
      
      private validateMessage(messageType: string, payload: any): void {
        if (!this.validator) return;
        
        const result = this.validator.validate(messageType, payload);
        if (!result.valid) {
          throw new Error(`Validation failed for ${messageType}: ${result.errors?.join(', ')}`);
        }
      }
      
      private async withRetry<T>(operation: () => Promise<T>): Promise<T> {
        let lastError: Error | undefined;
        
        for (let i = 0; i <= this.options.retries!; i++) {
          try {
            return await operation();
          } catch (error) {
            lastError = error as Error;
            if (i < this.options.retries!) {
              await this.delay(Math.pow(2, i) * 1000); // Exponential backoff
            }
          }
        }
        
        throw lastError;
      }
      
      private delay(ms: number): Promise<void> {
        return new Promise(resolve => setTimeout(resolve, ms));
      }
    }
    """
  end

  defp generate_typescript_server(_spec, _api_module, _opts) do
    "// TypeScript server generation not yet implemented"
  end

  defp generate_typescript_types(spec, api_module, opts) do
    module_name = Keyword.get(opts, :module_name, "#{api_module |> to_string() |> String.split(".") |> List.last()}Types")
    
    """
    /**
     * Generated TypeScript types for #{api_module}
     * 
     * #{spec[:info][:description] || "AsyncAPI types"}
     */
    
    #{generate_typescript_types_inline(spec)}
    
    // Message type union
    export type MessageType = #{generate_message_type_union(spec)};
    
    // Operation types
    #{generate_operation_types(spec)}
    
    // Channel types
    #{generate_channel_types(spec)}
    """
  end

  defp generate_typescript_validators(spec, api_module, opts) do
    messages = get_in(spec, [:components, :messages]) || %{}
    
    """
    /**
     * Generated TypeScript validators for #{api_module}
     */
    
    import { z } from 'zod';
    
    #{generate_zod_schemas(spec)}
    
    export class MessageValidator {
      private schemas = {
        #{generate_schema_registry(messages)}
      };
      
      validate(messageType: string, payload: any): ValidationResult {
        const schema = this.schemas[messageType];
        if (!schema) {
          return {
            valid: false,
            errors: [`Unknown message type: ${messageType}`]
          };
        }
        
        try {
          schema.parse(payload);
          return { valid: true };
        } catch (error) {
          return {
            valid: false,
            errors: error.errors?.map((e: any) => e.message) || [error.message]
          };
        }
      }
      
      #{generate_typed_validator_methods(messages)}
    }
    
    export interface ValidationResult {
      valid: boolean;
      errors?: string[];
    }
    """
  end

  defp generate_typescript_mocks(_spec, _api_module, _opts) do
    "// TypeScript mocks generation not yet implemented"
  end

  defp generate_typescript_tests(_spec, _api_module, _opts) do
    "// TypeScript tests generation not yet implemented"
  end

  defp generate_javascript_client(_spec, _api_module, _opts) do
    "// JavaScript client generation not yet implemented"
  end

  defp generate_python_client(_spec, _api_module, _opts) do
    "# Python client generation not yet implemented"
  end

  defp generate_python_server(_spec, _api_module, _opts) do
    "# Python server generation not yet implemented"
  end

  defp generate_python_types(_spec, _api_module, _opts) do
    "# Python types generation not yet implemented"
  end

  defp generate_python_validators(_spec, _api_module, _opts) do
    "# Python validators generation not yet implemented"
  end

  defp generate_python_mocks(_spec, _api_module, _opts) do
    "# Python mocks generation not yet implemented"
  end

  defp generate_python_tests(_spec, _api_module, _opts) do
    "# Python tests generation not yet implemented"
  end

  # TypeScript helper functions

  defp generate_typescript_types_inline(spec) do
    schemas = get_in(spec, [:components, :schemas]) || %{}
    
    schemas
    |> Enum.map(fn {schema_name, schema} ->
      generate_typescript_interface(schema_name, schema)
    end)
    |> Enum.join("\n\n")
  end

  defp generate_typescript_interface(schema_name, schema) do
    interface_name = Macro.camelize(to_string(schema_name))
    properties = schema[:properties] || []
    required = schema[:required] || []
    
    property_definitions = properties
    |> Enum.map(fn {prop_name, prop_schema} ->
      prop_type = convert_schema_type_to_typescript(prop_schema[:type])
      is_required = Enum.member?(required, prop_name)
      optional_marker = if is_required, do: "", else: "?"
      
      "  #{prop_name}#{optional_marker}: #{prop_type};"
    end)
    |> Enum.join("\n")
    
    "export interface " <> interface_name <> " {\n" <> property_definitions <> "\n}"
  end

  defp convert_schema_type_to_typescript(type) do
    case type do
      :string -> "string"
      :integer -> "number"
      :number -> "number"
      :boolean -> "boolean"
      :array -> "any[]"
      :object -> "Record<string, any>"
      _ -> "any"
    end
  end

  defp generate_typescript_client_methods(operations) do
    operations
    |> Enum.map(fn {operation_name, operation} ->
      generate_typescript_client_method(operation_name, operation)
    end)
    |> Enum.join("\n\n  ")
  end

  defp generate_typescript_client_method(operation_name, operation) do
    method_name = Macro.underscore(to_string(operation_name))
    channel = extract_channel_name(operation)
    message_type = operation[:message]
    
    case operation[:action] do
      :send ->
        summary = operation[:summary] || ("Send " <> to_string(operation_name) <> " message")
        description = operation[:description] || ""
        "/**\n * " <> summary <> "\n * " <> description <>
        "\n */\nasync " <> method_name <> "(payload: any, options?: any): Promise<void> {\n" <>
        "  this.validateMessage('" <> to_string(message_type) <> "', payload);\n" <>
        "  \n" <>
        "  return await this.withRetry(async () => {\n" <>
        "    await this.transport.send('" <> channel <> "', payload, options);\n" <>
        "  });\n" <>
        "}"
      
      :receive ->
        summary = operation[:summary] || ("Subscribe to " <> to_string(operation_name) <> " messages")
        description = operation[:description] || ""
        "/**\n * " <> summary <> "\n * " <> description <>
        "\n */\nasync subscribe" <> Macro.camelize(to_string(operation_name)) <>
        "(\n  callback: (message: any) => void,\n  options?: any\n): Promise<Subscription> {\n" <>
        "  return await this.transport.subscribe('" <> channel <> "', (message) => {\n" <>
        "    try {\n" <>
        "      this.validateMessage('" <> to_string(message_type) <> "', message);\n" <>
        "      callback(message);\n" <>
        "    } catch (error) {\n" <>
        "      console.error('Message validation failed:', error);\n" <>
        "    }\n" <>
        "  }, options);\n" <>
        "}"
    end
  end

  defp extract_channel_name(operation) do
    case operation[:channel] do
      %{"$ref" => ref} -> String.replace(ref, "#/channels/", "")
      channel_name when is_binary(channel_name) -> channel_name
      channel_name when is_atom(channel_name) -> to_string(channel_name)
    end
  end

  # Additional TypeScript helper functions

  defp generate_message_type_union(spec) do
    messages = get_in(spec, [:components, :messages]) || %{}
    
    message_names = messages
    |> Map.keys()
    |> Enum.map(&"'#{&1}'")
    |> Enum.join(" | ")
    
    if message_names == "", do: "string", else: message_names
  end

  defp generate_operation_types(spec) do
    operations = spec[:operations] || %{}
    
    operations
    |> Enum.map(fn {operation_name, operation} ->
      interface_name = Macro.camelize(to_string(operation_name))
      action = operation[:action]
      channel = extract_channel_name(operation)
      message = operation[:message]
      
      "export interface " <> interface_name <> "Operation {\n" <>
      "  action: '" <> to_string(action) <> "';\n" <>
      "  channel: '" <> channel <> "';\n" <>
      "  message: '" <> to_string(message) <> "';\n" <>
      "}"
    end)
    |> Enum.join("\n\n")
  end

  defp generate_channel_types(spec) do
    channels = spec[:channels] || %{}
    
    channel_names = channels
    |> Map.keys()
    |> Enum.map(&"'#{&1}'")
    |> Enum.join(" | ")
    
    channel_type = if channel_names == "", do: "string", else: channel_names
    
    "export type ChannelName = " <> channel_type <> ";\n\n" <>
    "export interface ChannelInfo {\n" <>
    "  name: ChannelName;\n" <>
    "  description?: string;\n" <>
    "}"
  end

  defp generate_zod_schemas(spec) do
    schemas = get_in(spec, [:components, :schemas]) || %{}
    
    schemas
    |> Enum.map(fn {schema_name, schema} ->
      generate_zod_schema(schema_name, schema)
    end)
    |> Enum.join("\n\n")
  end

  defp generate_zod_schema(schema_name, schema) do
    schema_var = Macro.underscore(to_string(schema_name))
    properties = generate_zod_properties(schema[:properties] || [], schema[:required] || [])
    
    "const " <> schema_var <> "Schema = z.object({\n" <>
    "  " <> properties <> "\n" <>
    "});"
  end

  defp generate_zod_properties(properties, required) do
    properties
    |> Enum.map(fn {prop_name, prop_schema} ->
      prop_type = convert_schema_type_to_zod(prop_schema[:type])
      is_required = Enum.member?(required, prop_name)
      
      zod_type = if is_required, do: prop_type, else: "#{prop_type}.optional()"
      
      "  #{prop_name}: #{zod_type}"
    end)
    |> Enum.join(",\n")
  end

  defp convert_schema_type_to_zod(type) do
    case type do
      :string -> "z.string()"
      :integer -> "z.number().int()"
      :number -> "z.number()"
      :boolean -> "z.boolean()"
      :array -> "z.array(z.any())"
      :object -> "z.record(z.any())"
      _ -> "z.any()"
    end
  end

  defp generate_schema_registry(messages) do
    messages
    |> Enum.map(fn {message_name, _message} ->
      schema_var = Macro.underscore(to_string(message_name))
      "'#{message_name}': #{schema_var}Schema"
    end)
    |> Enum.join(",\n    ")
  end

  defp generate_typed_validator_methods(messages) do
    messages
    |> Enum.map(fn {message_name, _message} ->
      method_name = "validate#{Macro.camelize(to_string(message_name))}"
      
      method_name <> "(payload: any): ValidationResult {\n" <>
      "  return this.validate('" <> to_string(message_name) <> "', payload);\n" <>
      "}"
    end)
    |> Enum.join("\n  ")
  end
end