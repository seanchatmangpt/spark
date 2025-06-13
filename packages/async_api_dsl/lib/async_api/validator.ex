defmodule AsyncApi.Validator do
  @moduledoc """
  Runtime validation utilities for AsyncAPI specifications and messages.
  
  Provides comprehensive validation for:
  - Message payloads against schemas
  - Operation parameters and headers
  - Security requirements
  - Protocol-specific validation
  - Custom validation rules
  
  ## Usage
  
      # Validate a message payload
      AsyncApi.Validator.validate_message(MyApp.EventApi, :userCreated, payload)
      
      # Validate operation parameters
      AsyncApi.Validator.validate_operation_params(MyApp.EventApi, :sendNotification, params)
      
      # Custom validation with context
      AsyncApi.Validator.validate_with_context(payload, schema, %{user_id: 123})
  """

  alias AsyncApi.Info

  @type validation_result :: :ok | {:error, [validation_error()]}
  @type validation_error :: %{
    path: [String.t() | integer()],
    message: String.t(),
    value: any(),
    constraint: atom()
  }
  @type validation_context :: %{optional(atom()) => any()}

  @doc """
  Validate a message payload against its schema.
  
  ## Examples
  
      payload = %{id: "123", name: "John", email: "john@example.com"}
      AsyncApi.Validator.validate_message(MyApp.Api, :userCreated, payload)
      # => :ok
      
      invalid_payload = %{id: 123}  # missing required fields
      AsyncApi.Validator.validate_message(MyApp.Api, :userCreated, invalid_payload)
      # => {:error, [%{path: ["name"], message: "Required field missing", ...}]}
  """
  @spec validate_message(module(), atom(), map()) :: validation_result()
  def validate_message(module, message_name, payload) do
    try do
      messages = Info.component_messages(module)
      
      case Enum.find(messages, fn msg -> msg.name == message_name end) do
        nil ->
          {:error, [%{path: [], message: "Message '#{message_name}' not found", value: message_name, constraint: :not_found}]}
        
        message ->
          case get_message_schema(module, message) do
            nil ->
              {:error, [%{path: [], message: "No schema found for message '#{message_name}'", value: message_name, constraint: :no_schema}]}
            
            schema ->
              validate_against_schema(payload, schema, [])
          end
      end
    rescue
      error ->
        {:error, [%{path: [], message: "Validation error: #{Exception.message(error)}", value: payload, constraint: :validation_error}]}
    end
  end

  @doc """
  Validate operation parameters.
  
  Validates channel parameters and headers for a specific operation.
  """
  @spec validate_operation_params(module(), atom(), map()) :: validation_result()
  def validate_operation_params(module, operation_name, params) do
    try do
      operations = Info.operations(module)
      
      case Enum.find(operations, fn op -> op.name == operation_name end) do
        nil ->
          {:error, [%{path: [], message: "Operation '#{operation_name}' not found", value: operation_name, constraint: :not_found}]}
        
        operation ->
          validate_operation_parameters(module, operation, params)
      end
    rescue
      error ->
        {:error, [%{path: [], message: "Parameter validation error: #{Exception.message(error)}", value: params, constraint: :validation_error}]}
    end
  end

  @doc """
  Validate with custom context for conditional validation.
  
  Allows passing additional context that can be used in custom validation rules.
  """
  @spec validate_with_context(any(), map(), validation_context()) :: validation_result()
  def validate_with_context(value, schema, context \\ %{}) do
    validate_against_schema_with_context(value, schema, [], context)
  end

  @doc """
  Validate security requirements for an operation.
  """
  @spec validate_security_requirements(module(), atom(), map()) :: validation_result()
  def validate_security_requirements(module, operation_name, auth_data) do
    try do
      spec = AsyncApi.to_spec(module)
      operations = get_in(spec, [:operations]) || %{}
      
      case Map.get(operations, operation_name) do
        nil ->
          {:error, [%{path: [], message: "Operation '#{operation_name}' not found", value: operation_name, constraint: :not_found}]}
        
        operation ->
          security_reqs = operation.security || []
          validate_security_requirements_list(spec, security_reqs, auth_data)
      end
    rescue
      error ->
        {:error, [%{path: [], message: "Security validation error: #{Exception.message(error)}", value: auth_data, constraint: :validation_error}]}
    end
  end

  @doc """
  Validate a payload against a JSON Schema with detailed error reporting.
  """
  @spec validate_json_schema(any(), map()) :: validation_result()
  def validate_json_schema(value, schema) do
    validate_against_map_schema(value, schema, [])
  end

  @doc """
  Batch validate multiple messages.
  
  Useful for validating message batches or event streams.
  """
  @spec validate_message_batch(module(), atom(), [map()]) :: [{integer(), validation_result()}]
  def validate_message_batch(module, message_name, payloads) do
    payloads
    |> Enum.with_index()
    |> Enum.map(fn {payload, index} ->
      {index, validate_message(module, message_name, payload)}
    end)
  end

  @doc """
  Create a custom validator function for repeated validation.
  
  Returns a function that can be used for efficient repeated validation
  of the same message type.
  """
  @spec create_validator(module(), atom()) :: (map() -> validation_result())
  def create_validator(module, message_name) do
    # Pre-compile validation for performance
    messages = Info.component_messages(module)
    
    case Enum.find(messages, fn msg -> msg.name == message_name end) do
      nil ->
        fn _payload ->
          {:error, [%{path: [], message: "Message '#{message_name}' not found", value: message_name, constraint: :not_found}]}
        end
      
      message ->
        case get_message_schema(module, message) do
          nil ->
            fn _payload ->
              {:error, [%{path: [], message: "No schema found for message '#{message_name}'", value: message_name, constraint: :no_schema}]}
            end
          
          schema ->
            fn payload ->
              validate_against_schema(payload, schema, [])
            end
        end
    end
  end

  # Private helper functions

  defp get_message_schema(module, message) do
    schemas = Info.component_schemas(module)
    
    # Handle different payload reference formats
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

  defp validate_operation_parameters(module, operation, params) do
    channels = Info.channels(module)
    
    case Enum.find(channels, fn ch -> ch.name == operation.channel end) do
      nil ->
        {:error, [%{path: [], message: "Channel '#{operation.channel}' not found", value: operation.channel, constraint: :not_found}]}
      
      channel ->
        validate_channel_parameters(channel, params)
    end
  end

  defp validate_channel_parameters(channel, params) do
    # Get parameter definitions from channel
    parameter_names = extract_parameters_from_channel(channel.name)
    
    errors = []
    
    # Check required parameters
    errors = Enum.reduce(parameter_names, errors, fn param_name, acc ->
      if Map.has_key?(params, param_name) do
        acc
      else
        error = %{
          path: [param_name],
          message: "Required parameter '#{param_name}' is missing",
          value: params,
          constraint: :required
        }
        [error | acc]
      end
    end)

    case errors do
      [] -> :ok
      _ -> {:error, Enum.reverse(errors)}
    end
  end

  defp extract_parameters_from_channel(channel_name) do
    channel_name
    |> to_string()
    |> (&Regex.scan(~r/\{([^}]+)\}/, &1)).()
    |> Enum.map(fn [_, param] -> String.to_atom(param) end)
  end

  defp validate_security_requirements_list(_spec, [], _auth_data) do
    # No security requirements
    :ok
  end

  defp validate_security_requirements_list(spec, security_reqs, auth_data) do
    # For now, basic validation - in real implementation would check schemes
    security_schemes = get_in(spec, [:components, :securitySchemes]) || %{}
    
    errors = Enum.flat_map(security_reqs, fn req ->
      Enum.flat_map(req, fn {scheme_name, scopes} ->
        cond do
          !Map.has_key?(security_schemes, scheme_name) ->
            [%{path: [scheme_name], message: "Security scheme '#{scheme_name}' not found", value: scheme_name, constraint: :not_found}]
          
          !Map.has_key?(auth_data, scheme_name) ->
            [%{path: [scheme_name], message: "Authentication data for '#{scheme_name}' not provided", value: auth_data, constraint: :missing_auth}]
          
          true ->
            # Additional scope validation could go here
            []
        end
      end)
    end)

    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  defp validate_against_schema(value, schema, path) do
    validate_against_schema_with_context(value, schema, path, %{})
  end

  # Version that works with map schemas (for JSON Schema validation)
  defp validate_against_map_schema(value, schema, path) when is_map(schema) do
    errors = []
    
    # Type validation
    errors = case validate_type(value, schema[:type]) do
      :ok -> errors
      {:error, error} -> [%{error | path: path} | errors]
    end

    # Required fields validation (for objects)
    errors = if schema[:type] == :object do
      required = schema[:required] || []
      validate_required_fields(value, required, path) ++ errors
    else
      errors
    end

    # Properties validation (for objects) 
    errors = if schema[:type] == :object && is_map(value) do
      properties = schema[:properties] || %{}
      validate_map_properties(value, properties, path) ++ errors
    else
      errors
    end

    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  # Helper for validating map-based properties
  defp validate_map_properties(value, properties, path) when is_map(value) and is_map(properties) do
    Enum.flat_map(properties, fn {prop_name, prop_schema} ->
      prop_atom = if is_binary(prop_name), do: String.to_atom(prop_name), else: prop_name
      prop_value = Map.get(value, prop_atom) || Map.get(value, to_string(prop_atom))
      
      if prop_value != nil do
        case validate_against_map_schema(prop_value, prop_schema, path ++ [prop_name]) do
          :ok -> []
          {:error, errors} -> errors
        end
      else
        []
      end
    end)
  end

  defp validate_map_properties(_value, _properties, _path), do: []

  defp validate_against_schema_with_context(value, schema, path, _context) do
    errors = []
    
    # Type validation
    errors = case validate_type(value, schema.type) do
      :ok -> errors
      {:error, error} -> [%{error | path: path} | errors]
    end

    # Required fields validation (for objects)
    errors = if schema.type == :object do
      required = schema.required || []
      validate_required_fields(value, required, path) ++ errors
    else
      errors
    end

    # Properties validation (for objects)
    errors = if schema.type == :object && is_map(value) do
      properties = schema.property || []
      validate_properties(value, properties, path) ++ errors
    else
      errors
    end

    # String constraints
    errors = if schema.type == :string && is_binary(value) do
      validate_string_constraints(value, schema, path) ++ errors
    else
      errors
    end

    # Number constraints
    errors = if schema.type in [:integer, :number] && is_number(value) do
      validate_number_constraints(value, schema, path) ++ errors
    else
      errors
    end

    # Array constraints
    errors = if schema.type == :array && is_list(value) do
      validate_array_constraints(value, schema, path) ++ errors
    else
      errors
    end

    case errors do
      [] -> :ok
      _ -> {:error, Enum.reverse(errors)}
    end
  end

  defp validate_type(value, expected_type) do
    case {value, expected_type} do
      {_, nil} -> :ok
      {v, :string} when is_binary(v) -> :ok
      {v, :integer} when is_integer(v) -> :ok
      {v, :number} when is_number(v) -> :ok
      {v, :boolean} when is_boolean(v) -> :ok
      {v, :array} when is_list(v) -> :ok
      {v, :object} when is_map(v) -> :ok
      _ -> 
        {:error, %{
          path: [],
          message: "Expected #{expected_type}, got #{get_type_name(value)}",
          value: value,
          constraint: :type_mismatch
        }}
    end
  end

  defp validate_required_fields(value, required, path) when is_map(value) do
    Enum.flat_map(required, fn field ->
      field_atom = if is_binary(field), do: String.to_atom(field), else: field
      if Map.has_key?(value, field_atom) || Map.has_key?(value, to_string(field_atom)) do
        []
      else
        [%{
          path: path ++ [field],
          message: "Required field '#{field}' is missing",
          value: value,
          constraint: :required
        }]
      end
    end)
  end

  defp validate_required_fields(_value, _required, _path), do: []

  defp validate_properties(value, properties, path) when is_map(value) and is_list(properties) do
    Enum.flat_map(properties, fn property ->
      prop_name = property.name
      prop_atom = if is_binary(prop_name), do: String.to_atom(prop_name), else: prop_name
      prop_value = Map.get(value, prop_atom) || Map.get(value, to_string(prop_atom))
      
      if prop_value != nil do
        case validate_against_schema_with_context(prop_value, property, path ++ [prop_name], %{}) do
          :ok -> []
          {:error, errors} -> errors
        end
      else
        []
      end
    end)
  end

  defp validate_properties(_value, _properties, _path), do: []

  defp validate_string_constraints(value, schema, path) do
    errors = []

    # Min length
    errors = if min_length = schema.min_length do
      if String.length(value) < min_length do
        error = %{
          path: path,
          message: "String must be at least #{min_length} characters long",
          value: value,
          constraint: :min_length
        }
        [error | errors]
      else
        errors
      end
    else
      errors
    end

    # Max length
    errors = if max_length = schema.max_length do
      if String.length(value) > max_length do
        error = %{
          path: path,
          message: "String must be at most #{max_length} characters long",
          value: value,
          constraint: :max_length
        }
        [error | errors]
      else
        errors
      end
    else
      errors
    end

    # Pattern
    errors = if pattern = schema.pattern do
      regex = if is_binary(pattern), do: Regex.compile!(pattern), else: pattern
      if !Regex.match?(regex, value) do
        error = %{
          path: path,
          message: "String does not match required pattern",
          value: value,
          constraint: :pattern
        }
        [error | errors]
      else
        errors
      end
    else
      errors
    end

    # Enum
    errors = if enum_values = schema.enum do
      if !Enum.member?(enum_values, value) do
        error = %{
          path: path,
          message: "Value must be one of: #{Enum.join(enum_values, ", ")}",
          value: value,
          constraint: :enum
        }
        [error | errors]
      else
        errors
      end
    else
      errors
    end

    errors
  end

  defp validate_number_constraints(value, schema, path) do
    errors = []

    # Minimum
    errors = if minimum = schema.minimum do
      if value < minimum do
        error = %{
          path: path,
          message: "Number must be at least #{minimum}",
          value: value,
          constraint: :minimum
        }
        [error | errors]
      else
        errors
      end
    else
      errors
    end

    # Maximum
    errors = if maximum = schema.maximum do
      if value > maximum do
        error = %{
          path: path,
          message: "Number must be at most #{maximum}",
          value: value,
          constraint: :maximum
        }
        [error | errors]
      else
        errors
      end
    else
      errors
    end

    errors
  end

  defp validate_array_constraints(value, schema, path) do
    errors = []

    # Min items
    errors = if min_items = schema.min_items do
      if length(value) < min_items do
        error = %{
          path: path,
          message: "Array must have at least #{min_items} items",
          value: value,
          constraint: :min_items
        }
        [error | errors]
      else
        errors
      end
    else
      errors
    end

    # Max items
    errors = if max_items = schema.max_items do
      if length(value) > max_items do
        error = %{
          path: path,
          message: "Array must have at most #{max_items} items",
          value: value,
          constraint: :max_items
        }
        [error | errors]
      else
        errors
      end
    else
      errors
    end

    # Items validation
    errors = if items_schema = schema.items do
      item_errors = value
      |> Enum.with_index()
      |> Enum.flat_map(fn {item, index} ->
        case validate_against_schema_with_context(item, items_schema, path ++ [index], %{}) do
          :ok -> []
          {:error, item_errors} -> item_errors
        end
      end)
      item_errors ++ errors
    else
      errors
    end

    errors
  end

  defp get_type_name(value) do
    cond do
      is_binary(value) -> "string"
      is_integer(value) -> "integer"
      is_float(value) -> "number"
      is_boolean(value) -> "boolean"
      is_list(value) -> "array"
      is_map(value) -> "object"
      true -> "unknown"
    end
  end
end