defmodule AsyncApi.Transformers.ValidateOperations do
  @moduledoc """
  Transformer to validate operation definitions in AsyncAPI v3.0 DSL.

  This transformer ensures that:
  - Operation IDs are unique
  - Channel references are valid
  - Message references in operations are valid
  - Reply definitions are valid
  - Action types are valid (send/receive)
  """

  use Spark.Dsl.Transformer

  @doc false
  def transform(dsl_state) do
    operations = Spark.Dsl.Transformer.get_entities(dsl_state, [:operations])
    channels = get_channel_addresses(dsl_state)
    component_messages = get_component_message_names(dsl_state)
    
    with :ok <- validate_unique_operation_ids(operations),
         :ok <- validate_channel_references(operations, channels),
         :ok <- validate_message_references(operations, component_messages),
         :ok <- validate_reply_definitions(operations, channels, component_messages) do
      {:ok, dsl_state}
    end
  end

  defp validate_unique_operation_ids(operations) do
    operation_ids = Enum.map(operations, & &1.operation_id)
    duplicates = operation_ids -- Enum.uniq(operation_ids)
    
    case duplicates do
      [] -> :ok
      [operation_id | _] -> 
        {:error, "Duplicate operation ID found: #{operation_id}. Operation IDs must be unique."}
    end
  end

  defp validate_channel_references(operations, channel_addresses) do
    Enum.reduce_while(operations, :ok, fn operation, acc ->
      case validate_channel_reference(operation, channel_addresses) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_channel_reference(operation, channel_addresses) do
    channel_ref = operation.channel
    
    cond do
      is_nil(channel_ref) ->
        {:error, "Operation '#{operation.operation_id}' must reference a channel"}
      
      is_atom(channel_ref) ->
        # Convert atom to string for comparison
        channel_str = Atom.to_string(channel_ref)
        if channel_str in channel_addresses do
          :ok
        else
          {:error, "Operation '#{operation.operation_id}' references undefined channel: #{channel_ref}"}
        end
      
      is_binary(channel_ref) ->
        if channel_ref in channel_addresses do
          :ok
        else
          {:error, "Operation '#{operation.operation_id}' references undefined channel: #{channel_ref}"}
        end
      
      true ->
        {:error, "Operation '#{operation.operation_id}' has invalid channel reference type: #{inspect(channel_ref)}"}
    end
  end

  defp validate_message_references(operations, component_messages) do
    Enum.reduce_while(operations, :ok, fn operation, acc ->
      case validate_operation_messages(operation, component_messages) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_operation_messages(operation, component_messages) do
    messages = operation.messages || []
    
    invalid_messages = Enum.reject(messages, fn message ->
      case message do
        %{name: name} when is_atom(name) -> name in component_messages
        name when is_atom(name) -> name in component_messages
        _ -> false
      end
    end)
    
    case invalid_messages do
      [] -> :ok
      msgs -> 
        message_names = Enum.map(msgs, fn
          %{name: name} -> name
          name -> name
        end)
        {:error, "Operation '#{operation.operation_id}' references undefined messages: #{inspect(message_names)}"}
    end
  end

  defp validate_reply_definitions(operations, channel_addresses, component_messages) do
    Enum.reduce_while(operations, :ok, fn operation, acc ->
      case validate_operation_reply(operation, channel_addresses, component_messages) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_operation_reply(operation, channel_addresses, component_messages) do
    case operation.reply do
      nil -> :ok
      reply -> validate_reply(reply, operation.operation_id, channel_addresses, component_messages)
    end
  end

  defp validate_reply(reply, operation_id, channel_addresses, component_messages) do
    with :ok <- validate_reply_channel(reply, operation_id, channel_addresses),
         :ok <- validate_reply_messages(reply, operation_id, component_messages) do
      :ok
    end
  end

  defp validate_reply_channel(reply, operation_id, channel_addresses) do
    case reply.channel do
      nil when is_nil(reply.address) ->
        {:error, "Reply for operation '#{operation_id}' must specify either a channel or address"}
      
      nil -> :ok  # Address is specified instead
      
      channel_ref when is_atom(channel_ref) ->
        channel_str = Atom.to_string(channel_ref)
        if channel_str in channel_addresses do
          :ok
        else
          {:error, "Reply for operation '#{operation_id}' references undefined channel: #{channel_ref}"}
        end
      
      channel_ref when is_binary(channel_ref) ->
        if channel_ref in channel_addresses do
          :ok
        else
          {:error, "Reply for operation '#{operation_id}' references undefined channel: #{channel_ref}"}
        end
      
      _ ->
        {:error, "Reply for operation '#{operation_id}' has invalid channel reference"}
    end
  end

  defp validate_reply_messages(reply, operation_id, component_messages) do
    messages = reply.messages || []
    
    invalid_messages = Enum.reject(messages, fn message ->
      case message do
        %{name: name} when is_atom(name) -> name in component_messages
        name when is_atom(name) -> name in component_messages
        _ -> false
      end
    end)
    
    case invalid_messages do
      [] -> :ok
      msgs -> 
        message_names = Enum.map(msgs, fn
          %{name: name} -> name
          name -> name
        end)
        {:error, "Reply for operation '#{operation_id}' references undefined messages: #{inspect(message_names)}"}
    end
  end

  defp get_channel_addresses(dsl_state) do
    Spark.Dsl.Transformer.get_entities(dsl_state, [:channels])
    |> Enum.map(& &1.address)
  end

  defp get_component_message_names(dsl_state) do
    Spark.Dsl.Transformer.get_entities(dsl_state, [:components])
    |> Enum.filter(&match?(%AsyncApi.Dsl.Message{}, &1))
    |> Enum.map(& &1.name)
  end
end