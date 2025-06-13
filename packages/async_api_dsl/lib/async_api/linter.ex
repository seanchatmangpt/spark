defmodule AsyncApi.Linter do
  @moduledoc """
  Spec linting utilities for AsyncAPI specifications.
  
  Provides comprehensive linting rules to ensure best practices,
  consistency, and quality in AsyncAPI specifications.
  
  ## Usage
  
      # Lint a specification module
      case AsyncApi.Linter.lint(MyApp.EventApi) do
        {:ok, []} -> 
          IO.puts("No linting issues found")
        {:ok, warnings} -> 
          Enum.each(warnings, fn warning -> IO.puts("Warning: " <> warning) end)
        {:error, errors} -> 
          Enum.each(errors, fn error -> IO.puts("Error: " <> error) end)
      end
      
      # Run specific linting rules
      AsyncApi.Linter.check_naming_conventions(MyApp.EventApi)
      AsyncApi.Linter.check_security_requirements(MyApp.EventApi)
  """

  alias AsyncApi.Info

  @type lint_result :: {:ok, [String.t()]} | {:error, [String.t()]}
  @type lint_level :: :error | :warning | :info

  @doc """
  Lint an AsyncAPI specification module.
  
  Returns {:ok, warnings} for successful linting with potential warnings,
  or {:error, errors} for critical linting failures.
  """
  @spec lint(module()) :: lint_result()
  def lint(module) do
    try do
      # Test spec generation first
      spec = AsyncApi.to_spec(module)
      
      # Validate spec has required structure
      unless is_map(spec) and Map.has_key?(spec, :info) do
        raise "Invalid specification structure generated"
      end
      
      issues = []
      |> run_rule(&check_info_completeness/2, spec, module)
      |> run_rule(&check_naming_conventions/2, spec, module)
      |> run_rule(&check_security_requirements/2, spec, module)
      |> run_rule(&check_operation_consistency/2, spec, module)
      |> run_rule(&check_message_schemas/2, spec, module)
      |> run_rule(&check_channel_parameters/2, spec, module)
      |> run_rule(&check_version_format/2, spec, module)
      |> run_rule(&check_description_quality/2, spec, module)
      |> run_rule(&check_deprecated_usage/2, spec, module)
      |> run_rule(&check_performance_considerations/2, spec, module)
      
      {errors, warnings} = Enum.split_with(issues, fn {level, _} -> level == :error end)
      
      case errors do
        [] -> {:ok, Enum.map(warnings, fn {_, message} -> message end)}
        _ -> {:error, Enum.map(errors, fn {_, message} -> message end)}
      end
    rescue
      error -> {:error, ["Failed to lint specification: #{Exception.message(error)}"]}
    end
  end

  @doc """
  Check naming conventions across the specification.
  """
  def check_naming_conventions(module) do
    spec = AsyncApi.to_spec(module)
    check_naming_conventions(spec, module)
  end

  @doc """
  Check security requirements and configurations.
  """
  def check_security_requirements(module) do
    spec = AsyncApi.to_spec(module)
    check_security_requirements(spec, module)
  end

  @doc """
  Check operation consistency and best practices.
  """
  def check_operation_consistency(module) do
    spec = AsyncApi.to_spec(module)
    check_operation_consistency(spec, module)
  end

  # Private helper functions

  defp run_rule(issues, rule_func, spec, module) do
    case rule_func.(spec, module) do
      [] -> issues
      new_issues when is_list(new_issues) -> issues ++ new_issues
      issue -> issues ++ [issue]
    end
  end

  defp check_info_completeness(spec, _module) do
    info = spec[:info] || %{}
    issues = []

    issues = if !info[:title] || String.trim(info[:title]) == "", 
      do: [{:error, "Info section must have a non-empty title"}] ++ issues, 
      else: issues

    issues = if !info[:version] || String.trim(info[:version]) == "", 
      do: [{:error, "Info section must have a non-empty version"}] ++ issues, 
      else: issues

    issues = if !info[:description] || String.length(String.trim(info[:description])) < 10, 
      do: [{:warning, "Info description should be at least 10 characters long"}] ++ issues, 
      else: issues

    issues = if !info[:contact], 
      do: [{:warning, "Consider adding contact information for API support"}] ++ issues, 
      else: issues

    issues = if !info[:license], 
      do: [{:warning, "Consider adding license information"}] ++ issues, 
      else: issues

    issues
  end

  defp check_naming_conventions(spec, _module) do
    issues = []

    # Check channel naming
    channels = get_in(spec, [:channels]) || %{}
    issues = Enum.reduce(channels, issues, fn {channel_name, _}, acc ->
      cond do
        !String.match?(to_string(channel_name), ~r/^[a-z0-9\/\{\}\-_\.]+$/) ->
          [{:warning, "Channel '#{channel_name}' should use lowercase, numbers, forward slashes, hyphens, underscores, dots, and parameter braces only"} | acc]
        String.contains?(to_string(channel_name), "//") ->
          [{:error, "Channel '#{channel_name}' contains double slashes which is invalid"} | acc]
        true -> acc
      end
    end)

    # Check operation naming
    operations = get_in(spec, [:operations]) || %{}
    issues = Enum.reduce(operations, issues, fn {op_name, _}, acc ->
      if !String.match?(to_string(op_name), ~r/^[a-zA-Z][a-zA-Z0-9]*$/) do
        [{:warning, "Operation '#{op_name}' should use camelCase naming convention"} | acc]
      else
        acc
      end
    end)

    # Check message naming
    messages = get_in(spec, [:components, :messages]) || %{}
    issues = Enum.reduce(messages, issues, fn {msg_name, _}, acc ->
      if !String.match?(to_string(msg_name), ~r/^[a-zA-Z][a-zA-Z0-9]*$/) do
        [{:warning, "Message '#{msg_name}' should use camelCase naming convention"} | acc]
      else
        acc
      end
    end)

    # Check schema naming  
    schemas = get_in(spec, [:components, :schemas]) || %{}
    issues = Enum.reduce(schemas, issues, fn {schema_name, _}, acc ->
      if !String.match?(to_string(schema_name), ~r/^[a-zA-Z][a-zA-Z0-9]*$/) do
        [{:warning, "Schema '#{schema_name}' should use camelCase naming convention"} | acc]
      else
        acc
      end
    end)

    issues
  end

  defp check_security_requirements(spec, _module) do
    issues = []
    
    # Check if any security schemes are defined
    security_schemes = get_in(spec, [:components, :securitySchemes]) || %{}
    issues = if Enum.empty?(security_schemes) do
      [{:warning, "No security schemes defined. Consider adding authentication for production APIs"} | issues]
    else
      issues
    end

    # Check for insecure configurations
    issues = Enum.reduce(security_schemes, issues, fn {scheme_name, scheme}, acc ->
      cond do
        scheme[:type] == "http" && scheme[:scheme] == "basic" ->
          [{:warning, "Security scheme '#{scheme_name}' uses HTTP Basic auth which may not be secure for production"} | acc]
        scheme[:type] == "apiKey" && scheme[:in] == "query" ->
          [{:warning, "Security scheme '#{scheme_name}' passes API key in query parameter which may be logged"} | acc]
        true -> acc
      end
    end)

    # Check servers for secure protocols
    servers = spec[:servers] || %{}
    issues = Enum.reduce(servers, issues, fn {server_name, server}, acc ->
      url = server[:url] || ""
      cond do
        String.starts_with?(url, "ws://") ->
          [{:warning, "Server '#{server_name}' uses insecure WebSocket protocol (ws://). Consider using wss://"} | acc]
        String.starts_with?(url, "http://") ->
          [{:warning, "Server '#{server_name}' uses insecure HTTP protocol. Consider using HTTPS"} | acc]
        true -> acc
      end
    end)

    issues
  end

  defp check_operation_consistency(spec, _module) do
    issues = []
    operations = get_in(spec, [:operations]) || %{}
    channels = get_in(spec, [:channels]) || %{}

    # Check that all operation channels exist
    issues = Enum.reduce(operations, issues, fn {op_name, operation}, acc ->
      channel_ref = operation[:channel]
      if channel_ref && !Map.has_key?(channels, String.to_atom(channel_ref)) do
        [{:error, "Operation '#{op_name}' references non-existent channel '#{channel_ref}'"} | acc]
      else
        acc
      end
    end)

    # Check for operations without descriptions
    issues = Enum.reduce(operations, issues, fn {op_name, operation}, acc ->
      if !operation[:summary] && !operation[:description] do
        [{:warning, "Operation '#{op_name}' lacks summary or description"} | acc]
      else
        acc
      end
    end)

    # Check for channels without operations
    used_channels = operations |> Map.values() |> Enum.map(& &1[:channel]) |> MapSet.new()
    issues = Enum.reduce(channels, issues, fn {channel_name, _}, acc ->
      if !MapSet.member?(used_channels, to_string(channel_name)) do
        [{:warning, "Channel '#{channel_name}' is defined but not used by any operations"} | acc]
      else
        acc
      end
    end)

    issues
  end

  defp check_message_schemas(spec, _module) do
    issues = []
    messages = get_in(spec, [:components, :messages]) || %{}
    schemas = get_in(spec, [:components, :schemas]) || %{}

    # Check that message payloads reference valid schemas
    issues = Enum.reduce(messages, issues, fn {msg_name, message}, acc ->
      payload = message[:payload]
      cond do
        is_map(payload) && payload[:"$ref"] ->
          ref_path = payload[:"$ref"]
          if String.starts_with?(ref_path, "#/components/schemas/") do
            schema_name = ref_path |> String.replace("#/components/schemas/", "") |> String.to_atom()
            if !Map.has_key?(schemas, schema_name) do
              [{:error, "Message '#{msg_name}' references non-existent schema '#{schema_name}'"} | acc]
            else
              acc
            end
          else
            acc
          end
        !payload ->
          [{:warning, "Message '#{msg_name}' has no payload defined"} | acc]
        true -> acc
      end
    end)

    issues
  end

  defp check_channel_parameters(spec, _module) do
    issues = []
    channels = get_in(spec, [:channels]) || %{}

    issues = Enum.reduce(channels, issues, fn {channel_name, channel}, acc ->
      channel_str = to_string(channel_name)
      parameters = channel[:parameters] || %{}
      
      # Extract parameter names from channel path
      param_matches = Regex.scan(~r/\{([^}]+)\}/, channel_str)
      path_params = Enum.map(param_matches, fn [_, param] -> param end)
      defined_params = Map.keys(parameters) |> Enum.map(&to_string/1)

      # Check for undefined parameters
      missing_params = path_params -- defined_params
      extra_params = defined_params -- path_params

      acc = Enum.reduce(missing_params, acc, fn param, inner_acc ->
        [{:error, "Channel '#{channel_name}' uses parameter '{#{param}}' but doesn't define it"} | inner_acc]
      end)

      Enum.reduce(extra_params, acc, fn param, inner_acc ->
        [{:warning, "Channel '#{channel_name}' defines parameter '#{param}' but doesn't use it in the path"} | inner_acc]
      end)
    end)

    issues
  end

  defp check_version_format(spec, _module) do
    version = get_in(spec, [:info, :version])
    if version && !String.match?(version, ~r/^\d+\.\d+\.\d+/) do
      [{:warning, "Version '#{version}' should follow semantic versioning format (e.g., 1.0.0)"}]
    else
      []
    end
  end

  defp check_description_quality(spec, _module) do
    issues = []
    
    # Check info description
    info_desc = get_in(spec, [:info, :description])
    issues = if info_desc && String.length(String.trim(info_desc)) < 20 do
      [{:warning, "Info description is quite short. Consider providing more detail about the API's purpose"} | issues]
    else
      issues
    end

    # Check operation descriptions
    operations = get_in(spec, [:operations]) || %{}
    issues = Enum.reduce(operations, issues, fn {op_name, operation}, acc ->
      summary = operation[:summary]
      description = operation[:description]
      
      cond do
        !summary && !description ->
          [{:warning, "Operation '#{op_name}' has no summary or description"} | acc]
        summary && String.length(String.trim(summary)) < 5 ->
          [{:warning, "Operation '#{op_name}' summary is very brief"} | acc]
        true -> acc
      end
    end)

    issues
  end

  defp check_deprecated_usage(spec, _module) do
    issues = []
    
    # Check for deprecated operations
    operations = get_in(spec, [:operations]) || %{}
    deprecated_ops = Enum.filter(operations, fn {_, op} -> op[:deprecated] end)
    
    issues = if length(deprecated_ops) > 0 do
      names = deprecated_ops |> Enum.map(fn {name, _} -> to_string(name) end) |> Enum.join(", ")
      [{:info, "Found deprecated operations: #{names}. Consider migration timeline documentation"} | issues]
    else
      issues
    end

    issues
  end

  defp check_performance_considerations(spec, _module) do
    issues = []
    
    # Check for very large schemas that might impact performance
    schemas = get_in(spec, [:components, :schemas]) || %{}
    issues = Enum.reduce(schemas, issues, fn {schema_name, schema}, acc ->
      properties = schema[:properties] || %{}
      if map_size(properties) > 50 do
        [{:warning, "Schema '#{schema_name}' has #{map_size(properties)} properties. Consider breaking into smaller schemas for better performance"} | acc]
      else
        acc
      end
    end)

    # Check for deeply nested channel paths
    channels = get_in(spec, [:channels]) || %{}
    issues = Enum.reduce(channels, issues, fn {channel_name, _}, acc ->
      depth = channel_name |> to_string() |> String.split("/") |> length()
      if depth > 6 do
        [{:warning, "Channel '#{channel_name}' has #{depth} path segments. Deep nesting may impact routing performance"} | acc]
      else
        acc
      end
    end)

    issues
  end
end