defmodule AsyncApi.Transformers.ValidateSchemas do
  @moduledoc """
  Transformer to validate schema definitions in AsyncAPI DSL.

  This transformer ensures that:
  - Schema names are unique within components
  - Schema types are valid JSON Schema types
  - Property types are valid
  - Required properties exist in the schema
  - Array schemas have valid item definitions
  """

  use Spark.Dsl.Transformer

  @valid_types [:string, :number, :integer, :boolean, :array, :object, :null]
  @valid_string_formats [
    "date-time", "time", "date", "duration", "email", "idn-email",
    "hostname", "idn-hostname", "ipv4", "ipv6", "uri", "uri-reference",
    "iri", "iri-reference", "uuid", "regex", "json-pointer",
    "relative-json-pointer", "binary", "byte", "password"
  ]

  @doc false
  def transform(dsl_state) do
    schemas = get_component_schemas(dsl_state)
    
    with :ok <- validate_unique_schema_names(schemas),
         :ok <- validate_schema_types(schemas),
         :ok <- validate_schema_properties(schemas),
         :ok <- validate_required_properties(schemas),
         :ok <- validate_array_items(schemas) do
      {:ok, dsl_state}
    end
  end

  defp get_component_schemas(dsl_state) do
    Spark.Dsl.Transformer.get_entities(dsl_state, [:components, :schemas])
  end

  defp validate_unique_schema_names(schemas) do
    names = Enum.map(schemas, & &1.name)
    duplicates = names -- Enum.uniq(names)
    
    case duplicates do
      [] -> :ok
      [name | _] -> 
        {:error, "Duplicate schema name found: #{name}. Schema names must be unique within components."}
    end
  end

  defp validate_schema_types(schemas) do
    Enum.reduce_while(schemas, :ok, fn schema, acc ->
      case validate_schema_type(schema) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_schema_type(schema) do
    cond do
      schema.type not in @valid_types ->
        {:error, "Schema '#{schema.name}' has invalid type: #{schema.type}. Valid types are: #{inspect(@valid_types)}"}
      
      schema.type == :string and schema.format and schema.format not in @valid_string_formats ->
        {:error, "Schema '#{schema.name}' has invalid string format: #{schema.format}. Valid formats are: #{inspect(@valid_string_formats)}"}
      
      true ->
        :ok
    end
  end

  defp validate_schema_properties(schemas) do
    Enum.reduce_while(schemas, :ok, fn schema, acc ->
      case validate_properties_for_schema(schema) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_properties_for_schema(schema) do
    properties = schema.properties || []
    
    # Validate that object schemas have properties
    cond do
      schema.type == :object and Enum.empty?(properties) ->
        {:error, "Schema '#{schema.name}' is of type 'object' but has no properties defined"}
      
      schema.type != :object and not Enum.empty?(properties) ->
        {:error, "Schema '#{schema.name}' is of type '#{schema.type}' but has properties defined. Only 'object' type schemas can have properties."}
      
      true ->
        validate_individual_properties(properties, schema.name)
    end
  end

  defp validate_individual_properties(properties, schema_name) do
    Enum.reduce_while(properties, :ok, fn property, acc ->
      case validate_property(property, schema_name) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_property(property, schema_name) do
    cond do
      property.type not in @valid_types ->
        {:error, "Property '#{property.name}' in schema '#{schema_name}' has invalid type: #{property.type}"}
      
      property.type == :string and property.format and property.format not in @valid_string_formats ->
        {:error, "Property '#{property.name}' in schema '#{schema_name}' has invalid string format: #{property.format}"}
      
      property.minimum and property.maximum and property.minimum > property.maximum ->
        {:error, "Property '#{property.name}' in schema '#{schema_name}' has minimum (#{property.minimum}) greater than maximum (#{property.maximum})"}
      
      property.min_length and property.max_length and property.min_length > property.max_length ->
        {:error, "Property '#{property.name}' in schema '#{schema_name}' has min_length (#{property.min_length}) greater than max_length (#{property.max_length})"}
      
      true ->
        :ok
    end
  end

  defp validate_required_properties(schemas) do
    Enum.reduce_while(schemas, :ok, fn schema, acc ->
      case validate_required_for_schema(schema) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_required_for_schema(schema) do
    required = schema.required || []
    property_names = Enum.map(schema.properties || [], & &1.name)
    
    missing_properties = required -- property_names
    
    case missing_properties do
      [] -> :ok
      props -> 
        {:error, "Schema '#{schema.name}' has required properties #{inspect(props)} that are not defined in properties"}
    end
  end

  defp validate_array_items(schemas) do
    Enum.reduce_while(schemas, :ok, fn schema, acc ->
      case validate_array_items_for_schema(schema) do
        :ok -> {:cont, acc}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_array_items_for_schema(schema) do
    cond do
      schema.type == :array and is_nil(schema.items) ->
        {:error, "Schema '#{schema.name}' is of type 'array' but has no items definition"}
      
      schema.type != :array and not is_nil(schema.items) ->
        {:error, "Schema '#{schema.name}' is of type '#{schema.type}' but has items defined. Only 'array' type schemas can have items."}
      
      schema.type == :array and is_map(schema.items) ->
        validate_items_schema(schema.items, schema.name)
      
      true ->
        :ok
    end
  end

  defp validate_items_schema(items_schema, schema_name) do
    cond do
      not is_map(items_schema) ->
        {:error, "Items definition for array schema '#{schema_name}' must be a schema object"}
      
      not Map.has_key?(items_schema, :type) ->
        {:error, "Items definition for array schema '#{schema_name}' must have a type"}
      
      items_schema.type not in @valid_types ->
        {:error, "Items definition for array schema '#{schema_name}' has invalid type: #{items_schema.type}"}
      
      true ->
        :ok
    end
  end
end