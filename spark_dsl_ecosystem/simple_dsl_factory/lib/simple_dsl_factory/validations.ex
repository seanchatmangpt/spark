defmodule SimpleDslFactory.Validations do
  @moduledoc """
  Real validations that actually check the data.
  
  No phantom dependencies - these functions exist and work.
  """

  defmodule ValidAttributesJson do
    @moduledoc """
    Validates that attributes field contains valid JSON representing a list of attribute specs.
    """
    
    use Ash.Resource.Validation

    @impl true
    def init(opts) do
      if is_atom(opts[:attribute]) do
        {:ok, opts}
      else
        {:error, "attribute option is required and must be an atom"}
      end
    end

    @impl true
    def validate(changeset, opts, _context) do
      attribute = opts[:attribute]
      
      case Ash.Changeset.get_attribute(changeset, attribute) do
        nil -> :ok
        value when is_binary(value) ->
          case Jason.decode(value) do
            {:ok, attrs} when is_list(attrs) ->
              validate_attributes(attrs)
            {:ok, _} ->
              {:error, field: attribute, message: "must be a JSON array"}
            {:error, _} ->
              {:error, field: attribute, message: "must be valid JSON"}
          end
        _ ->
          {:error, field: attribute, message: "must be a string"}
      end
    end

    defp validate_attributes(attrs) do
      case Enum.find(attrs, &(!valid_attribute?(&1))) do
        nil -> :ok
        invalid_attr -> 
          {:error, message: "invalid attribute: #{inspect(invalid_attr)}"}
      end
    end

    defp valid_attribute?(attr) when is_map(attr) do
      has_name? = Map.has_key?(attr, :name) or Map.has_key?(attr, "name")
      has_type? = Map.has_key?(attr, :type) or Map.has_key?(attr, "type")
      has_name? and has_type?
    end
    defp valid_attribute?(_), do: false
  end

  defmodule ValidElixirCode do
    @moduledoc """
    Validates that code field contains parseable Elixir code.
    """
    
    use Ash.Resource.Validation

    @impl true
    def init(opts) do
      if is_atom(opts[:attribute]) do
        {:ok, opts}
      else
        {:error, "attribute option is required and must be an atom"}
      end
    end

    @impl true
    def validate(changeset, opts, _context) do
      attribute = opts[:attribute]
      
      case Ash.Changeset.get_attribute(changeset, attribute) do
        nil -> :ok
        value when is_binary(value) ->
          case Code.string_to_quoted(value) do
            {:ok, _ast} -> :ok
            {:error, {_line, error, _token}} ->
              {:error, field: attribute, message: "invalid Elixir code: #{error}"}
          end
        _ ->
          {:error, field: attribute, message: "must be a string"}
      end
    end
  end
end