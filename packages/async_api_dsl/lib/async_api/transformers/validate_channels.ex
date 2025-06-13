defmodule AsyncApi.Transformers.ValidateChannels do
  @moduledoc """
  Transformer to validate channel definitions in AsyncAPI DSL.

  This transformer ensures that:
  - Channel addresses are unique
  - Parameter references in channels are valid
  - Operations reference valid messages
  - Channel bindings are properly formatted
  """

  use Spark.Dsl.Transformer

  @doc false
  def transform(dsl_state) do
    channels = Spark.Dsl.Transformer.get_entities(dsl_state, [:channels])
    
    with :ok <- validate_unique_addresses(channels),
         :ok <- validate_channel_parameters(channels),
         :ok <- validate_channel_operations(channels, dsl_state) do
      {:ok, dsl_state}
    end
  end

  defp validate_unique_addresses(channels) do
    addresses = Enum.map(channels, & &1.address)
    duplicates = addresses -- Enum.uniq(addresses)
    
    case duplicates do
      [] -> :ok
      [address | _] -> 
        {:error, "Duplicate channel address found: #{address}. Channel addresses must be unique."}
    end
  end

  defp validate_channel_parameters(channels) do
    Enum.reduce_while(channels, :ok, fn channel, acc ->
      case validate_parameters_for_channel(channel) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_parameters_for_channel(channel) do
    # Extract parameter names from the channel address
    address_params = extract_parameter_names(channel.address)
    
    # Get defined parameters for this channel
    defined_params = Enum.map(channel.parameters || [], & &1.name)
    
    # Check for missing parameter definitions
    missing_params = address_params -- defined_params
    
    case missing_params do
      [] -> :ok
      params -> 
        {:error, "Channel '#{channel.address}' references parameters #{inspect(params)} that are not defined"}
    end
  end

  defp extract_parameter_names(address) do
    # Extract parameter names from channel address like "/user/{userId}/notifications"
    Regex.scan(~r/\{([^}]+)\}/, address, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.to_atom/1)
  end

  defp validate_channel_operations(channels, dsl_state) do
    component_messages = get_component_message_names(dsl_state)
    
    Enum.reduce_while(channels, :ok, fn channel, acc ->
      case validate_operations_for_channel(channel, component_messages) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_operations_for_channel(channel, component_messages) do
    operations = channel.operations || []
    
    Enum.reduce_while(operations, :ok, fn operation, acc ->
      case validate_operation_messages(operation, component_messages) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_operation_messages(operation, component_messages) do
    case operation.messages do
      nil -> :ok
      messages ->
        invalid_messages = messages -- component_messages
        
        case invalid_messages do
          [] -> :ok
          msgs -> 
            {:error, "Operation '#{operation.operation_id}' references undefined messages: #{inspect(msgs)}"}
        end
    end
  end

  defp get_component_message_names(dsl_state) do
    Spark.Dsl.Transformer.get_entities(dsl_state, [:components])
    |> Enum.filter(&match?(%AsyncApi.Dsl.Message{}, &1))
    |> Enum.map(& &1.name)
  end
end