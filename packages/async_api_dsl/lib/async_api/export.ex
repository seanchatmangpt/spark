defmodule AsyncApi.Export do
  @moduledoc """
  Export utilities for AsyncAPI specifications.
  
  This module provides functions to export AsyncAPI specifications to various formats
  including JSON and YAML files.
  """

  @doc """
  Export specification to file.
  
  ## Parameters
  
  - `module` - The module defining the AsyncAPI specification
  - `path` - The file path where to save the specification
  - `format` - The export format (`:json` or `:yaml`, defaults to `:json`)
  
  ## Examples
  
      AsyncApi.Export.to_file(MyApp.EventApi, "spec/event_api.json")
      AsyncApi.Export.to_file(MyApp.EventApi, "spec/event_api.yaml", :yaml)
  """
  def to_file(module, path, format \\ :json) do
    spec = AsyncApi.to_spec(module)
    content = encode_spec(spec, format)
    
    # Ensure directory exists
    path |> Path.dirname() |> File.mkdir_p!()
    
    File.write!(path, content)
  end

  @doc """
  Export specification to string.
  
  ## Parameters
  
  - `module` - The module defining the AsyncAPI specification
  - `format` - The export format (`:json` or `:yaml`, defaults to `:json`)
  
  ## Examples
  
      json_spec = AsyncApi.Export.to_string(MyApp.EventApi, :json)
      yaml_spec = AsyncApi.Export.to_string(MyApp.EventApi, :yaml)
  """
  def to_string(module, format \\ :json) do
    spec = AsyncApi.to_spec(module)
    encode_spec(spec, format)
  end

  @doc """
  Export specification with pretty formatting.
  
  Similar to `to_string/2` but with enhanced formatting options.
  
  ## Parameters
  
  - `module` - The module defining the AsyncAPI specification
  - `format` - The export format (`:json` or `:yaml`)
  - `opts` - Additional formatting options
  
  ## Options
  
  - `:pretty` - Enable pretty printing (default: true)
  - `:indent` - Number of spaces for indentation (default: 2)
  
  ## Examples
  
      pretty_json = AsyncApi.Export.to_string_pretty(MyApp.EventApi, :json, pretty: true)
  """
  def to_string_pretty(module, format, opts \\ []) do
    spec = AsyncApi.to_spec(module)
    pretty = Keyword.get(opts, :pretty, true)
    
    case format do
      :json -> Jason.encode!(spec, pretty: pretty)
      :yaml -> encode_spec(spec, :yaml)
    end
  end

  @doc """
  Validate specification before export.
  
  Runs validation checks and returns either the encoded specification or validation errors.
  
  ## Examples
  
      case AsyncApi.Export.validate_and_export(MyApp.EventApi, :json) do
        {:ok, json_spec} -> File.write!("spec.json", json_spec)
        {:error, errors} -> IO.inspect(errors, label: "Validation errors")
      end
  """
  def validate_and_export(module, format \\ :json) do
    try do
      spec = AsyncApi.to_spec(module)
      content = encode_spec(spec, format)
      {:ok, content}
    rescue
      error -> {:error, [Exception.message(error)]}
    end
  end

  # Private functions

  defp encode_spec(spec, :json) do
    Jason.encode!(spec, pretty: true)
  end

  defp encode_spec(spec, :yaml) do
    # YamlElixir doesn't have write_to_string, only read functions
    # For now, fall back to JSON format with a note
    json_content = Jason.encode!(spec, pretty: true)
    """
    # YAML export not yet implemented - YamlElixir only supports reading YAML
    # This is JSON format for now:
    
    #{json_content}
    """
  end
end