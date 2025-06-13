defmodule AsyncApi.Transformers.ValidateMessages do
  @moduledoc """
  Transformer to validate message definitions in AsyncAPI DSL.

  This transformer ensures that:
  - Message names are unique within components
  - Payload references point to valid schemas
  - Header references point to valid schemas
  - Content types are valid
  """

  use Spark.Dsl.Transformer

  @valid_content_types [
    "application/json",
    "application/xml",
    "text/plain",
    "text/html",
    "application/octet-stream",
    "application/x-www-form-urlencoded",
    "multipart/form-data",
    "application/avro",
    "application/protobuf"
  ]

  @doc false
  def transform(dsl_state) do
    messages = get_component_messages(dsl_state)
    schemas = get_component_schema_names(dsl_state)
    
    with :ok <- validate_unique_message_names(messages),
         :ok <- validate_message_payloads(messages, schemas),
         :ok <- validate_message_headers(messages, schemas),
         :ok <- validate_content_types(messages) do
      {:ok, dsl_state}
    end
  end

  defp get_component_messages(dsl_state) do
    Spark.Dsl.Transformer.get_entities(dsl_state, [:components, :messages])
  end

  defp get_component_schema_names(dsl_state) do
    Spark.Dsl.Transformer.get_entities(dsl_state, [:components, :schemas])
    |> Enum.map(& &1.name)
  end

  defp validate_unique_message_names(messages) do
    names = Enum.map(messages, & &1.name)
    duplicates = names -- Enum.uniq(names)
    
    case duplicates do
      [] -> :ok
      [name | _] -> 
        {:error, "Duplicate message name found: #{name}. Message names must be unique within components."}
    end
  end

  defp validate_message_payloads(messages, schema_names) do
    Enum.reduce_while(messages, :ok, fn message, acc ->
      case validate_payload_reference(message, schema_names) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_payload_reference(message, schema_names) do
    case message.payload do
      nil -> 
        {:error, "Message '#{message.name}' must have a payload defined"}
      
      payload when is_atom(payload) ->
        if payload in schema_names do
          :ok
        else
          {:error, "Message '#{message.name}' references undefined payload schema: #{payload}"}
        end
      
      payload when is_map(payload) ->
        # Inline schema definition - validate basic structure
        validate_inline_schema(payload, "payload for message '#{message.name}'")
      
      _ ->
        {:error, "Message '#{message.name}' has invalid payload type. Must be atom reference or inline schema."}
    end
  end

  defp validate_message_headers(messages, schema_names) do
    Enum.reduce_while(messages, :ok, fn message, acc ->
      case validate_header_reference(message, schema_names) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_header_reference(message, schema_names) do
    case message.headers do
      nil -> :ok  # Headers are optional
      
      headers when is_atom(headers) ->
        if headers in schema_names do
          :ok
        else
          {:error, "Message '#{message.name}' references undefined headers schema: #{headers}"}
        end
      
      headers when is_map(headers) ->
        # Inline schema definition - validate basic structure
        validate_inline_schema(headers, "headers for message '#{message.name}'")
      
      _ ->
        {:error, "Message '#{message.name}' has invalid headers type. Must be atom reference or inline schema."}
    end
  end

  defp validate_content_types(messages) do
    Enum.reduce_while(messages, :ok, fn message, acc ->
      case validate_content_type(message) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_content_type(message) do
    case message.content_type do
      nil -> :ok  # Content type is optional
      
      content_type when is_binary(content_type) ->
        if content_type in @valid_content_types or String.contains?(content_type, "/") do
          :ok
        else
          {:error, "Message '#{message.name}' has invalid content type: #{content_type}"}
        end
      
      _ ->
        {:error, "Message '#{message.name}' content type must be a string"}
    end
  end

  defp validate_inline_schema(schema, context) do
    cond do
      not is_map(schema) ->
        {:error, "Invalid inline schema for #{context}: must be a map"}
      
      not Map.has_key?(schema, :type) ->
        {:error, "Invalid inline schema for #{context}: must have a 'type' field"}
      
      true ->
        :ok
    end
  end
end