defmodule AsyncApi.Testing do
  @moduledoc """
  Contract testing framework for AsyncAPI specifications.
  
  Provides utilities for testing message contracts, operation flows,
  and API compliance. Integrates with ExUnit for seamless testing.
  
  ## Usage
  
      defmodule MyApp.EventApiTest do
        use ExUnit.Case
        use AsyncApi.Testing, api: MyApp.EventApi
        
        describe "user events" do
          test "user created message validates correctly" do
            payload = %{id: "123", name: "John", email: "john@example.com"}
            assert_valid_message(:userCreated, payload)
          end
          
          test "operation flow" do
            assert_operation_flow(:sendNotification, %{userId: "123"}) do
              # Test the actual operation implementation
              MyApp.EventBus.send_notification("123", "Hello!")
            end
          end
        end
      end
  """

  @doc """
  Use this module to import AsyncAPI testing utilities.
  
  ## Options
  
  - `:api` - The AsyncAPI module to test against (required)
  - `:validate_all` - Whether to validate all messages by default (default: true)
  - `:strict_mode` - Enable strict validation mode (default: false)
  """
  defmacro __using__(opts) do
    api_module = Keyword.fetch!(opts, :api)
    validate_all = Keyword.get(opts, :validate_all, true)
    strict_mode = Keyword.get(opts, :strict_mode, false)

    quote do
      import AsyncApi.Testing
      import AsyncApi.Testing.Assertions
      import AsyncApi.Testing.Generators

      @async_api_module unquote(api_module)
      @async_api_validate_all unquote(validate_all)
      @async_api_strict_mode unquote(strict_mode)

      setup do
        # Initialize testing context
        AsyncApi.Testing.setup_test_context(@async_api_module, %{
          validate_all: @async_api_validate_all,
          strict_mode: @async_api_strict_mode
        })
      end
    end
  end

  @doc """
  Setup test context for AsyncAPI testing.
  """
  def setup_test_context(api_module, opts \\ %{}) do
    context = %{
      api_module: api_module,
      spec: AsyncApi.to_spec(api_module),
      opts: opts,
      test_data: %{},
      generated_messages: []
    }

    Process.put(:async_api_test_context, context)
    {:ok, context}
  end

  @doc """
  Get the current test context.
  """
  def get_test_context do
    Process.get(:async_api_test_context) || raise("AsyncAPI test context not initialized. Make sure to use AsyncApi.Testing in your test module.")
  end

  @doc """
  Create a test message generator for a specific message type.
  
  Returns a function that generates valid test messages based on the schema.
  """
  def create_message_generator(message_name) do
    context = get_test_context()
    AsyncApi.Testing.Generators.create_generator(context.api_module, message_name)
  end

  @doc """
  Record a message for later validation or replay.
  """
  def record_message(message_name, payload, metadata \\ %{}) do
    context = get_test_context()
    
    recorded_message = %{
      name: message_name,
      payload: payload,
      metadata: metadata,
      timestamp: System.system_time(:millisecond)
    }

    updated_context = update_in(context.generated_messages, &[recorded_message | &1])
    Process.put(:async_api_test_context, updated_context)
    
    recorded_message
  end

  @doc """
  Get all recorded messages for analysis.
  """
  def get_recorded_messages do
    context = get_test_context()
    Enum.reverse(context.generated_messages)
  end

  @doc """
  Clear recorded messages.
  """
  def clear_recorded_messages do
    context = get_test_context()
    updated_context = %{context | generated_messages: []}
    Process.put(:async_api_test_context, updated_context)
    :ok
  end

  @doc """
  Create a contract test suite for an API module.
  
  Generates tests for all messages and operations automatically.
  """
  defmacro contract_test_suite(opts \\ []) do
    quote do
      describe "AsyncAPI Contract Tests" do
        setup do
          AsyncApi.Testing.setup_contract_tests(unquote(opts))
        end

        test "all messages have valid schemas" do
          AsyncApi.Testing.test_all_message_schemas(@async_api_module)
        end

        test "all operations are properly defined" do
          AsyncApi.Testing.test_all_operations(@async_api_module)
        end

        test "spec is valid AsyncAPI 3.0" do
          AsyncApi.Testing.test_spec_validity(@async_api_module)
        end
      end
    end
  end

  @doc """
  Setup contract tests with configuration.
  """
  def setup_contract_tests(opts) do
    context = get_test_context()
    
    contract_config = %{
      generate_examples: Keyword.get(opts, :generate_examples, true),
      validate_examples: Keyword.get(opts, :validate_examples, true),
      test_negative_cases: Keyword.get(opts, :test_negative_cases, false)
    }

    updated_context = put_in(context.opts.contract_config, contract_config)
    Process.put(:async_api_test_context, updated_context)
    
    {:ok, contract_config}
  end

  @doc """
  Test all message schemas are valid and examples validate.
  """
  def test_all_message_schemas(api_module) do
    messages = AsyncApi.Info.component_messages(api_module)
    
    Enum.each(messages, fn message ->
      # Test that message has a valid schema reference
      if message.payload == nil do
        raise "Message #{message.name} must have a payload defined"
      end
      
      # Generate and validate example data
      case AsyncApi.Testing.Generators.generate_example(api_module, message.name) do
        {:ok, example} ->
          case AsyncApi.Validator.validate_message(api_module, message.name, example) do
            :ok -> :ok
            {:error, errors} ->
              raise "Generated example for #{message.name} failed validation: #{inspect(errors)}"
          end
        
        {:error, reason} ->
          raise "Could not generate example for #{message.name}: #{reason}"
      end
    end)
    
    :ok
  end

  @doc """
  Test all operations are properly defined.
  """
  def test_all_operations(api_module) do
    operations = AsyncApi.Info.operations(api_module)
    channels = AsyncApi.Info.channels(api_module)
    messages = AsyncApi.Info.component_messages(api_module)
    
    channel_names = MapSet.new(channels, & &1.name)
    message_names = MapSet.new(messages, & &1.name)
    
    Enum.each(operations, fn operation ->
      # Test channel reference
      unless MapSet.member?(channel_names, operation.channel) do
        raise "Operation #{operation.name} references non-existent channel #{operation.channel}"
      end
      
      # Test message reference
      unless MapSet.member?(message_names, operation.message) do
        raise "Operation #{operation.name} references non-existent message #{operation.message}"
      end
        
      # Test operation has required fields
      unless operation.action in [:send, :receive] do
        raise "Operation #{operation.name} must have action of :send or :receive"
      end
    end)
    
    :ok
  end

  @doc """
  Test that the specification is valid AsyncAPI 3.0.
  """
  def test_spec_validity(api_module) do
    spec = AsyncApi.to_spec(api_module)
    
    # Test required root fields
    unless spec[:asyncapi] == "3.0.0" do
      raise "Spec must declare asyncapi version 3.0.0"
    end
    
    unless spec[:info] do
      raise "Spec must have info section"
    end
    
    unless spec[:info][:title] do
      raise "Spec must have info.title"
    end
    
    unless spec[:info][:version] do
      raise "Spec must have info.version"
    end
    
    # Test structure
    if spec[:channels] && !is_map(spec[:channels]) do
      raise "Channels must be a map"
    end
    
    if spec[:operations] && !is_map(spec[:operations]) do
      raise "Operations must be a map"
    end
    
    if spec[:components] && !is_map(spec[:components]) do
      raise "Components must be a map"
    end
    
    :ok
  end
end

defmodule AsyncApi.Testing.Assertions do
  @moduledoc """
  Test assertions for AsyncAPI specifications.
  """

  import ExUnit.Assertions

  @doc """
  Assert that a message payload is valid according to the schema.
  """
  defmacro assert_valid_message(message_name, payload) do
    quote do
      context = AsyncApi.Testing.get_test_context()
      
      case AsyncApi.Validator.validate_message(context.api_module, unquote(message_name), unquote(payload)) do
        :ok -> 
          AsyncApi.Testing.record_message(unquote(message_name), unquote(payload))
          :ok
        {:error, errors} ->
          flunk("Message validation failed for #{unquote(message_name)}: #{inspect(errors)}")
      end
    end
  end

  @doc """
  Assert that a message payload is invalid (for negative testing).
  """
  defmacro assert_invalid_message(message_name, payload, expected_errors \\ nil) do
    quote do
      context = AsyncApi.Testing.get_test_context()
      
      case AsyncApi.Validator.validate_message(context.api_module, unquote(message_name), unquote(payload)) do
        :ok -> 
          flunk("Expected message #{unquote(message_name)} to be invalid, but it passed validation")
        {:error, errors} ->
          if unquote(expected_errors) do
            expected = unquote(expected_errors)
            assert length(errors) >= length(expected), 
              "Expected at least #{length(expected)} errors, got #{length(errors)}"
          end
          :ok
      end
    end
  end

  @doc """
  Assert that operation parameters are valid.
  """
  defmacro assert_valid_operation_params(operation_name, params) do
    quote do
      context = AsyncApi.Testing.get_test_context()
      
      case AsyncApi.Validator.validate_operation_params(context.api_module, unquote(operation_name), unquote(params)) do
        :ok -> :ok
        {:error, errors} ->
          flunk("Operation parameter validation failed for #{unquote(operation_name)}: #{inspect(errors)}")
      end
    end
  end

  @doc """
  Assert that an operation flow completes successfully.
  
  Executes the given block and validates any messages produced.
  """
  defmacro assert_operation_flow(operation_name, params \\ %{}, do: block) do
    quote do
      context = AsyncApi.Testing.get_test_context()
      
      # Clear any previous messages
      AsyncApi.Testing.clear_recorded_messages()
      
      # Validate operation parameters first
      assert_valid_operation_params(unquote(operation_name), unquote(params))
      
      # Execute the operation
      result = unquote(block)
      
      # Validate any recorded messages
      recorded = AsyncApi.Testing.get_recorded_messages()
      
      if context.opts.validate_all do
        Enum.each(recorded, fn message ->
          case AsyncApi.Validator.validate_message(context.api_module, message.name, message.payload) do
            :ok -> :ok
            {:error, errors} ->
              flunk("Operation #{unquote(operation_name)} produced invalid message #{message.name}: #{inspect(errors)}")
          end
        end)
      end
      
      result
    end
  end

  @doc """
  Assert that the specification passes linting rules.
  """
  defmacro assert_spec_passes_linting(options \\ []) do
    quote do
      context = AsyncApi.Testing.get_test_context()
      
      case AsyncApi.Linter.lint(context.api_module) do
        {:ok, warnings} ->
          max_warnings = unquote(options)[:max_warnings] || 0
          if length(warnings) > max_warnings do
            flunk("Spec has #{length(warnings)} warnings, maximum allowed: #{max_warnings}. Warnings: #{inspect(warnings)}")
          end
          :ok
        {:error, errors} ->
          flunk("Spec failed linting: #{inspect(errors)}")
      end
    end
  end

  @doc """
  Assert that a batch of messages are all valid.
  """
  defmacro assert_valid_message_batch(message_name, payloads) do
    quote do
      context = AsyncApi.Testing.get_test_context()
      
      results = AsyncApi.Validator.validate_message_batch(context.api_module, unquote(message_name), unquote(payloads))
      
      failed_validations = Enum.filter(results, fn {_index, result} ->
        case result do
          :ok -> false
          {:error, _} -> true
        end
      end)
      
      if length(failed_validations) > 0 do
        failures = Enum.map(failed_validations, fn {index, {:error, errors}} ->
          "Index #{index}: #{inspect(errors)}"
        end)
        flunk("Message batch validation failed:\n#{Enum.join(failures, "\n")}")
      end
      
      # Record all valid messages
      Enum.each(unquote(payloads), fn payload ->
        AsyncApi.Testing.record_message(unquote(message_name), payload)
      end)
      
      :ok
    end
  end
end

defmodule AsyncApi.Testing.Generators do
  @moduledoc """
  Test data generators for AsyncAPI schemas.
  """

  alias AsyncApi.Info

  @doc """
  Generate example data for a message based on its schema.
  """
  def generate_example(api_module, message_name) do
    try do
      messages = Info.component_messages(api_module)
      
      case Enum.find(messages, fn msg -> msg.name == message_name end) do
        nil ->
          {:error, "Message '#{message_name}' not found"}
        
        message ->
          case get_message_schema(api_module, message) do
            nil ->
              {:error, "No schema found for message '#{message_name}'"}
            
            schema ->
              {:ok, generate_from_schema(schema)}
          end
      end
    rescue
      error ->
        {:error, "Generation error: #{Exception.message(error)}"}
    end
  end

  @doc """
  Create a generator function for a specific message type.
  """
  def create_generator(api_module, message_name) do
    case generate_example(api_module, message_name) do
      {:ok, example} ->
        fn -> example end
      {:error, reason} ->
        fn -> raise "Cannot generate example for #{message_name}: #{reason}" end
    end
  end

  @doc """
  Generate multiple examples for a message type.
  """
  def generate_examples(api_module, message_name, count \\ 5) do
    generator = create_generator(api_module, message_name)
    
    1..count
    |> Enum.map(fn _ -> 
      try do
        {:ok, generator.()}
      rescue
        error -> {:error, Exception.message(error)}
      end
    end)
  end

  @doc """
  Generate negative test cases (invalid data) for a message.
  """
  def generate_negative_examples(api_module, message_name) do
    messages = Info.component_messages(api_module)
    
    case Enum.find(messages, fn msg -> msg.name == message_name end) do
      nil ->
        []
      
      message ->
        case get_message_schema(api_module, message) do
          nil -> []
          schema -> generate_negative_cases(schema)
        end
    end
  end

  # Private helper functions

  defp get_message_schema(api_module, message) do
    schemas = Info.component_schemas(api_module)
    
    case message.payload do
      %{:"$ref" => ref} when is_binary(ref) ->
        schema_name = extract_schema_name_from_ref(ref)
        Enum.find(schemas, fn schema -> schema.name == schema_name end)
      
      schema_name when is_atom(schema_name) ->
        Enum.find(schemas, fn schema -> schema.name == schema_name end)
      
      _ -> nil
    end
  end

  defp extract_schema_name_from_ref(ref) do
    ref
    |> String.replace("#/components/schemas/", "")
    |> String.to_atom()
  end

  defp generate_from_schema(schema) do
    case schema.type do
      :object ->
        properties = schema.property || []
        required = schema.required || []
        
        Enum.reduce(properties, %{}, fn property, acc ->
          value = generate_property_value(property)
          Map.put(acc, property.name, value)
        end)
      
      :string ->
        generate_string_value(schema)
      
      :integer ->
        generate_integer_value(schema)
      
      :number ->
        generate_number_value(schema)
      
      :boolean ->
        true
      
      :array ->
        items_schema = schema.items || %{type: :string}
        [generate_from_schema(items_schema)]
      
      _ ->
        "example_value"
    end
  end

  defp generate_property_value(property) do
    case property.type do
      :string -> 
        cond do
          property.format == "email" -> "user@example.com"
          property.format == "uuid" -> "550e8400-e29b-41d4-a716-446655440000"
          property.format == "date-time" -> "2024-01-01T12:00:00Z"
          property.enum -> Enum.random(property.enum)
          true -> "example_#{property.name}"
        end
      
      :integer ->
        cond do
          property.minimum -> property.minimum + 1
          property.maximum -> property.maximum - 1
          true -> 42
        end
      
      :number ->
        cond do
          property.minimum -> property.minimum + 0.1
          property.maximum -> property.maximum - 0.1
          true -> 3.14
        end
      
      :boolean -> true
      
      :array -> ["example_item"]
      
      _ -> "example_value"
    end
  end

  defp generate_string_value(schema) do
    base = "example"
    
    cond do
      schema.format == "email" -> "user@example.com"
      schema.format == "uuid" -> "550e8400-e29b-41d4-a716-446655440000"
      schema.format == "date-time" -> "2024-01-01T12:00:00Z"
      schema.enum -> Enum.random(schema.enum)
      schema.min_length -> String.pad_trailing(base, schema.min_length, "x")
      true -> base
    end
  end

  defp generate_integer_value(schema) do
    cond do
      schema.minimum -> schema.minimum + 1
      schema.maximum -> schema.maximum - 1
      true -> 42
    end
  end

  defp generate_number_value(schema) do
    cond do
      schema.minimum -> schema.minimum + 0.1
      schema.maximum -> schema.maximum - 0.1
      true -> 3.14
    end
  end

  defp generate_negative_cases(schema) do
    base_cases = [
      # Wrong type
      %{case: "wrong_type_string", value: "string_instead_of_object"},
      %{case: "wrong_type_number", value: 123},
      %{case: "wrong_type_array", value: []},
      %{case: "null_value", value: nil}
    ]

    case schema.type do
      :object ->
        object_cases = [
          # Missing required fields
          %{case: "empty_object", value: %{}},
          # Extra unknown fields (if strict mode)
          %{case: "extra_fields", value: %{unknown_field: "value"}}
        ]
        base_cases ++ object_cases
      
      :string ->
        string_cases = []
        
        string_cases = if schema.min_length do
          short_string = String.duplicate("x", max(0, schema.min_length - 1))
          [%{case: "too_short", value: short_string} | string_cases]
        else
          string_cases
        end
        
        string_cases = if schema.max_length do
          long_string = String.duplicate("x", schema.max_length + 1)
          [%{case: "too_long", value: long_string} | string_cases]
        else
          string_cases
        end
        
        base_cases ++ string_cases
      
      _ ->
        base_cases
    end
  end
end

defmodule AsyncApi.Testing.Mocks do
  @moduledoc """
  Mock generators for AsyncAPI testing.
  
  Provides comprehensive mocking capabilities for API operations,
  message handlers, and transport layers.
  """

  @doc """
  Create a mock transport for testing clients.
  """
  def create_mock_transport(opts \\ []) do
    %{
      __struct__: AsyncApi.Testing.MockTransport,
      sent_messages: [],
      subscriptions: %{},
      responses: Keyword.get(opts, :responses, %{}),
      delays: Keyword.get(opts, :delays, %{}),
      failures: Keyword.get(opts, :failures, %{}),
      auto_ack: Keyword.get(opts, :auto_ack, true)
    }
  end

  @doc """
  Create a mock message handler for testing servers.
  """
  def create_mock_handler(operation_name, opts \\ []) do
    default_response = Keyword.get(opts, :default_response, {:ok, %{status: "processed"}})
    delay = Keyword.get(opts, :delay, 0)
    
    fn payload, metadata ->
      if delay > 0, do: Process.sleep(delay)
      
      # Record the call for later assertion
      record_handler_call(operation_name, payload, metadata)
      
      default_response
    end
  end

  @doc """
  Create a mock producer that records all published messages.
  """
  def create_mock_producer(opts \\ []) do
    %{
      __struct__: AsyncApi.Testing.MockProducer,
      published_messages: [],
      auto_confirm: Keyword.get(opts, :auto_confirm, true),
      confirm_delay: Keyword.get(opts, :confirm_delay, 0)
    }
  end

  @doc """
  Create a mock consumer that can simulate receiving messages.
  """
  def create_mock_consumer(opts \\ []) do
    %{
      __struct__: AsyncApi.Testing.MockConsumer,
      handlers: %{},
      received_messages: [],
      auto_process: Keyword.get(opts, :auto_process, true)
    }
  end

  @doc """
  Record a handler call for later verification.
  """
  def record_handler_call(operation_name, payload, metadata) do
    call = %{
      operation: operation_name,
      payload: payload,
      metadata: metadata,
      timestamp: System.system_time(:millisecond)
    }
    
    calls = Process.get(:mock_handler_calls, [])
    Process.put(:mock_handler_calls, [call | calls])
    call
  end

  @doc """
  Get all recorded handler calls.
  """
  def get_handler_calls do
    Process.get(:mock_handler_calls, [])
    |> Enum.reverse()
  end

  @doc """
  Clear recorded handler calls.
  """
  def clear_handler_calls do
    Process.put(:mock_handler_calls, [])
  end

  @doc """
  Simulate a message being received by a mock consumer.
  """
  def simulate_message(consumer, channel, message, payload) do
    received_message = %{
      channel: channel,
      message: message,
      payload: payload,
      timestamp: System.system_time(:millisecond)
    }
    
    updated_consumer = update_in(consumer.received_messages, &[received_message | &1])
    
    # Call handler if auto_process is enabled
    if consumer.auto_process do
      case Map.get(consumer.handlers, channel) do
        nil -> {:ok, updated_consumer}
        handler -> 
          try do
            handler.(payload, %{channel: channel, message: message})
            {:ok, updated_consumer}
          catch
            :error, reason -> {:error, reason, updated_consumer}
          end
      end
    else
      {:ok, updated_consumer}
    end
  end
end

defmodule AsyncApi.Testing.Contracts do
  @moduledoc """
  Advanced contract testing utilities.
  
  Provides comprehensive contract verification including:
  - Message schema evolution compatibility
  - Operation sequence validation
  - Cross-service contract testing
  - Performance contract verification
  """

  import ExUnit.Assertions

  @doc """
  Verify that a new API version is backward compatible.
  """
  def assert_backward_compatible(old_api_module, new_api_module, opts \\ []) do
    old_spec = AsyncApi.to_spec(old_api_module)
    new_spec = AsyncApi.to_spec(new_api_module)
    
    # Check that all old operations still exist
    old_operations = Map.keys(old_spec[:operations] || %{})
    new_operations = Map.keys(new_spec[:operations] || %{})
    
    missing_operations = old_operations -- new_operations
    unless Enum.empty?(missing_operations) do
      flunk("Breaking change: Operations removed: #{inspect(missing_operations)}")
    end
    
    # Check that all old message schemas are still compatible
    old_schemas = get_in(old_spec, [:components, :schemas]) || %{}
    new_schemas = get_in(new_spec, [:components, :schemas]) || %{}
    
    Enum.each(old_schemas, fn {schema_name, old_schema} ->
      case Map.get(new_schemas, schema_name) do
        nil ->
          if Keyword.get(opts, :allow_schema_removal, false) do
            :ok
          else
            flunk("Breaking change: Schema '#{schema_name}' was removed")
          end
        
        new_schema ->
          assert_schema_compatible(schema_name, old_schema, new_schema, opts)
      end
    end)
    
    :ok
  end

  @doc """
  Assert that two schemas are compatible.
  """
  def assert_schema_compatible(schema_name, old_schema, new_schema, opts \\ []) do
    # Check that required fields weren't added
    old_required = old_schema[:required] || []
    new_required = new_schema[:required] || []
    
    added_required = new_required -- old_required
    unless Enum.empty?(added_required) do
      flunk("Breaking change in schema '#{schema_name}': New required fields: #{inspect(added_required)}")
    end
    
    # Check that existing properties are still compatible
    old_properties = old_schema[:properties] || []
    new_properties = new_schema[:properties] || []
    
    old_prop_map = Enum.into(old_properties, %{})
    new_prop_map = Enum.into(new_properties, %{})
    
    Enum.each(old_prop_map, fn {prop_name, old_prop} ->
      case Map.get(new_prop_map, prop_name) do
        nil ->
          if Keyword.get(opts, :allow_property_removal, false) do
            :ok
          else
            flunk("Breaking change in schema '#{schema_name}': Property '#{prop_name}' was removed")
          end
        
        new_prop ->
          # Check type compatibility
          if old_prop[:type] != new_prop[:type] do
            flunk("Breaking change in schema '#{schema_name}': Property '#{prop_name}' type changed from #{old_prop[:type]} to #{new_prop[:type]}")
          end
      end
    end)
    
    :ok
  end

  @doc """
  Verify operation sequence contracts.
  
  Tests that a sequence of operations executes correctly and produces
  the expected message flow.
  """
  defmacro assert_operation_sequence(sequence, do: block) do
    quote do
      context = AsyncApi.Testing.get_test_context()
      
      # Clear any previous messages
      AsyncApi.Testing.clear_recorded_messages()
      AsyncApi.Testing.Mocks.clear_handler_calls()
      
      # Execute the sequence
      sequence_result = unquote(block)
      
      # Verify the sequence
      recorded_messages = AsyncApi.Testing.get_recorded_messages()
      handler_calls = AsyncApi.Testing.Mocks.get_handler_calls()
      
      # Check that we have the expected number of operations
      expected_count = length(unquote(sequence))
      actual_count = length(recorded_messages) + length(handler_calls)
      
      assert actual_count >= expected_count,
        "Expected at least #{expected_count} operations, but got #{actual_count}"
      
      # Verify each operation in sequence
      Enum.with_index(unquote(sequence))
      |> Enum.each(fn {expected_op, index} ->
        verify_operation_in_sequence(expected_op, index, recorded_messages, handler_calls)
      end)
      
      sequence_result
    end
  end

  @doc """
  Assert performance contracts are met.
  """
  defmacro assert_performance_contract(operation_name, constraints, do: block) do
    quote do
      start_time = System.monotonic_time(:millisecond)
      
      result = unquote(block)
      
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      
      constraints = unquote(constraints)
      
      # Check maximum duration
      if max_duration = constraints[:max_duration_ms] do
        assert duration <= max_duration,
          "Operation #{unquote(operation_name)} took #{duration}ms, max allowed: #{max_duration}ms"
      end
      
      # Check minimum throughput
      if min_throughput = constraints[:min_throughput_per_sec] do
        operations_count = constraints[:operations_count] || 1
        actual_throughput = operations_count * 1000 / duration
        
        assert actual_throughput >= min_throughput,
          "Operation #{unquote(operation_name)} throughput: #{actual_throughput}/sec, min required: #{min_throughput}/sec"
      end
      
      # Check memory usage if specified
      if max_memory_mb = constraints[:max_memory_mb] do
        memory_usage = :erlang.memory(:total) / (1024 * 1024)
        assert memory_usage <= max_memory_mb,
          "Memory usage #{memory_usage}MB exceeds limit: #{max_memory_mb}MB"
      end
      
      result
    end
  end

  # Private helper functions

  defp verify_operation_in_sequence(expected_op, index, recorded_messages, handler_calls) do
    # This is a simplified verification - could be more sophisticated
    case expected_op do
      {:send, operation_name, _payload} ->
        sent_message = Enum.find(recorded_messages, fn msg -> 
          msg.name == operation_name 
        end)
        assert sent_message != nil, "Expected message #{operation_name} was not sent"
      
      {:receive, operation_name} ->
        handler_call = Enum.find(handler_calls, fn call -> 
          call.operation == operation_name 
        end)
        assert handler_call != nil, "Expected operation #{operation_name} was not received"
      
      _ ->
        # Custom verification logic could be added here
        :ok
    end
  end
end

defmodule AsyncApi.Testing.MockTransport do
  @moduledoc """
  Mock transport implementation for testing.
  """
  
  defstruct [
    :sent_messages,
    :subscriptions,
    :responses,
    :delays,
    :failures,
    :auto_ack
  ]

  def send(transport, channel, message, options \\ []) do
    # Simulate network delay if configured
    if delay = Map.get(transport.delays, channel) do
      Process.sleep(delay)
    end
    
    # Simulate failure if configured
    if failure = Map.get(transport.failures, channel) do
      {:error, failure}
    else
      sent_message = %{
        channel: channel,
        message: message,
        options: options,
        timestamp: System.system_time(:millisecond)
      }
      
      updated_transport = update_in(transport.sent_messages, &[sent_message | &1])
      {:ok, updated_transport}
    end
  end

  def subscribe(transport, channel, callback, options \\ []) do
    subscription_id = "mock-sub-#{:rand.uniform(1000000)}"
    
    subscription = %{
      id: subscription_id,
      channel: channel,
      callback: callback,
      options: options
    }
    
    updated_transport = put_in(transport.subscriptions[subscription_id], subscription)
    {:ok, subscription_id, updated_transport}
  end

  def unsubscribe(transport, subscription_id) do
    updated_transport = update_in(transport.subscriptions, &Map.delete(&1, subscription_id))
    {:ok, updated_transport}
  end

  def get_sent_messages(transport, channel \\ nil) do
    messages = transport.sent_messages
    
    if channel do
      Enum.filter(messages, fn msg -> msg.channel == channel end)
    else
      messages
    end
    |> Enum.reverse()
  end
end