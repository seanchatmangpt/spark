defmodule AsyncApi.Errors do
  @moduledoc """
  Enhanced error reporting and diagnostics for AsyncAPI specifications.
  
  Provides detailed error messages, suggestions for fixes, and context-aware
  diagnostics to improve developer experience when working with AsyncAPI DSL.
  
  ## Features
  
  - Contextual error messages with line numbers
  - Suggestions for common fixes
  - Error categorization and severity levels
  - Integration with IDEs and editors
  - Helpful documentation links
  - Error recovery suggestions
  
  ## Usage
  
      case AsyncApi.Errors.validate_with_diagnostics(MyApp.EventApi) do
        {:ok, _spec} -> 
          IO.puts("✅ Specification is valid")
        {:error, diagnostics} ->
          AsyncApi.Errors.print_diagnostics(diagnostics)
      end
  """

  @type severity :: :error | :warning | :info | :hint
  @type error_code :: atom()
  @type diagnostic :: %{
    severity: severity(),
    code: error_code(),
    message: String.t(),
    file: String.t() | nil,
    line: integer() | nil,
    column: integer() | nil,
    source: String.t() | nil,
    suggestions: [String.t()],
    help_url: String.t() | nil,
    related_info: [diagnostic()] | nil
  }

  @doc """
  Validate a specification with enhanced diagnostics.
  
  Returns detailed diagnostic information including suggestions
  and help for resolving issues.
  """
  @spec validate_with_diagnostics(module()) :: {:ok, map()} | {:error, [diagnostic()]}
  def validate_with_diagnostics(api_module) do
    try do
      spec = AsyncApi.to_spec(api_module)
      
      # Collect all diagnostics
      diagnostics = []
      |> collect_compilation_diagnostics(api_module)
      |> collect_validation_diagnostics(spec, api_module)
      |> collect_linting_diagnostics(spec, api_module)
      |> collect_performance_diagnostics(spec, api_module)
      |> collect_security_diagnostics(spec, api_module)
      
      errors = Enum.filter(diagnostics, &(&1.severity == :error))
      
      case errors do
        [] -> {:ok, spec}
        _ -> {:error, diagnostics}
      end
    rescue
      error ->
        diagnostic = create_compilation_error_diagnostic(error, api_module)
        {:error, [diagnostic]}
    end
  end

  @doc """
  Print diagnostics in a human-readable format.
  
  Supports different output formats for various contexts.
  """
  @spec print_diagnostics([diagnostic()], keyword()) :: :ok
  def print_diagnostics(diagnostics, opts \\ []) do
    format = Keyword.get(opts, :format, :terminal)
    show_suggestions = Keyword.get(opts, :show_suggestions, true)
    show_help_urls = Keyword.get(opts, :show_help_urls, true)
    
    case format do
      :terminal -> print_terminal_diagnostics(diagnostics, show_suggestions, show_help_urls)
      :json -> print_json_diagnostics(diagnostics)
      :junit -> print_junit_diagnostics(diagnostics)
      :github -> print_github_actions_diagnostics(diagnostics)
      _ -> {:error, "Unsupported format: #{format}"}
    end
  end

  @doc """
  Get suggestions for fixing a specific error.
  """
  @spec get_suggestions(error_code()) :: [String.t()]
  def get_suggestions(error_code) do
    case error_code do
      :missing_required_field ->
        [
          "Add the required field to your specification",
          "Check the AsyncAPI 3.0 specification for required fields",
          "Use `mix async_api.validate` to see all missing fields"
        ]
      
      :invalid_operation_reference ->
        [
          "Ensure the operation references an existing channel",
          "Check that the channel name matches exactly (case-sensitive)",
          "Verify the channel is defined in the channels section"
        ]
      
      :schema_validation_failed ->
        [
          "Check that all required properties are present",
          "Verify property types match the schema definition",
          "Use the testing framework to generate valid examples"
        ]
      
      :naming_convention_violation ->
        [
          "Use camelCase for operation and message names",
          "Use lowercase with slashes for channel names",
          "Avoid special characters except hyphens and underscores"
        ]
      
      :security_scheme_missing ->
        [
          "Define security schemes in the components section",
          "Add authentication requirements to operations",
          "Consider using OAuth2 or API key authentication"
        ]
      
      :performance_concern ->
        [
          "Consider breaking large schemas into smaller components",
          "Use pagination for operations that return large datasets",
          "Implement proper error handling and timeouts"
        ]
      
      _ ->
        [
          "Check the AsyncAPI 3.0 specification documentation",
          "Use the linter to identify common issues",
          "Consult the AsyncAPI DSL documentation"
        ]
    end
  end

  @doc """
  Get documentation URL for a specific error code.
  """
  @spec get_help_url(error_code()) :: String.t() | nil
  def get_help_url(error_code) do
    base_url = "https://hexdocs.pm/async_api_dsl/troubleshooting.html"
    
    case error_code do
      :missing_required_field -> "#{base_url}#missing-required-fields"
      :invalid_operation_reference -> "#{base_url}#operation-references"
      :schema_validation_failed -> "#{base_url}#schema-validation"
      :naming_convention_violation -> "#{base_url}#naming-conventions"
      :security_scheme_missing -> "#{base_url}#security-configuration"
      :performance_concern -> "#{base_url}#performance-optimization"
      _ -> base_url
    end
  end

  @doc """
  Create a diagnostic from a validation error.
  """
  @spec create_diagnostic(severity(), error_code(), String.t(), keyword()) :: diagnostic()
  def create_diagnostic(severity, code, message, opts \\ []) do
    %{
      severity: severity,
      code: code,
      message: message,
      file: Keyword.get(opts, :file),
      line: Keyword.get(opts, :line),
      column: Keyword.get(opts, :column),
      source: Keyword.get(opts, :source),
      suggestions: Keyword.get(opts, :suggestions, get_suggestions(code)),
      help_url: Keyword.get(opts, :help_url, get_help_url(code)),
      related_info: Keyword.get(opts, :related_info)
    }
  end

  @doc """
  Enhanced error context for better debugging.
  """
  @spec enhance_error_context(any(), module()) :: map()
  def enhance_error_context(error, api_module) do
    %{
      error: error,
      api_module: api_module,
      spec_info: get_spec_info(api_module),
      elixir_version: System.version(),
      async_api_dsl_version: get_package_version(),
      timestamp: DateTime.utc_now(),
      environment: %{
        mix_env: Mix.env(),
        otp_version: System.otp_release(),
        compile_time: DateTime.utc_now()
      }
    }
  end

  # Private helper functions

  defp collect_compilation_diagnostics(diagnostics, api_module) do
    try do
      # Try to compile and check for any compilation issues
      AsyncApi.to_spec(api_module)
      diagnostics
    rescue
      error ->
        diagnostic = create_compilation_error_diagnostic(error, api_module)
        [diagnostic | diagnostics]
    end
  end

  defp collect_validation_diagnostics(diagnostics, spec, api_module) do
    # Use the validator to check for issues
    case AsyncApi.Validator.validate_json_schema(spec, get_asyncapi_schema()) do
      :ok -> diagnostics
      {:error, errors} ->
        validation_diagnostics = Enum.map(errors, fn error ->
          create_diagnostic(
            :error,
            :schema_validation_failed,
            "Schema validation failed: #{error.message}",
            file: get_module_file(api_module),
            source: "AsyncAPI Validator"
          )
        end)
        
        validation_diagnostics ++ diagnostics
    end
  end

  defp collect_linting_diagnostics(diagnostics, spec, api_module) do
    case AsyncApi.Linter.lint(api_module) do
      {:ok, warnings} ->
        warning_diagnostics = Enum.map(warnings, fn warning ->
          create_diagnostic(
            :warning,
            :linting_warning,
            warning,
            file: get_module_file(api_module),
            source: "AsyncAPI Linter"
          )
        end)
        
        warning_diagnostics ++ diagnostics
      
      {:error, errors} ->
        error_diagnostics = Enum.map(errors, fn error ->
          create_diagnostic(
            :error,
            :linting_error,
            error,
            file: get_module_file(api_module),
            source: "AsyncAPI Linter"
          )
        end)
        
        error_diagnostics ++ diagnostics
    end
  end

  defp collect_performance_diagnostics(diagnostics, spec, _api_module) do
    # Check for performance issues
    performance_issues = []
    
    # Large schemas
    schemas = get_in(spec, [:components, :schemas]) || %{}
    large_schemas = Enum.filter(schemas, fn {_name, schema} ->
      properties = schema[:properties] || %{}
      map_size(properties) > 50
    end)
    
    performance_issues = if length(large_schemas) > 0 do
      large_schema_names = Enum.map(large_schemas, fn {name, _} -> to_string(name) end)
      
      diagnostic = create_diagnostic(
        :warning,
        :performance_concern,
        "Large schemas detected: #{Enum.join(large_schema_names, ", ")}. Consider breaking into smaller components.",
        source: "Performance Analyzer"
      )
      
      [diagnostic | performance_issues]
    else
      performance_issues
    end
    
    # Deep channel nesting
    channels = spec[:channels] || %{}
    deep_channels = Enum.filter(channels, fn {name, _} ->
      depth = name |> to_string() |> String.split("/") |> length()
      depth > 6
    end)
    
    performance_issues = if length(deep_channels) > 0 do
      deep_channel_names = Enum.map(deep_channels, fn {name, _} -> to_string(name) end)
      
      diagnostic = create_diagnostic(
        :warning,
        :performance_concern,
        "Deep channel nesting detected: #{Enum.join(deep_channel_names, ", ")}. Consider flattening the structure.",
        source: "Performance Analyzer"
      )
      
      [diagnostic | performance_issues]
    else
      performance_issues
    end
    
    performance_issues ++ diagnostics
  end

  defp collect_security_diagnostics(diagnostics, spec, _api_module) do
    security_schemes = get_in(spec, [:components, :securitySchemes]) || %{}
    
    security_issues = []
    
    # No security schemes defined
    security_issues = if Enum.empty?(security_schemes) do
      diagnostic = create_diagnostic(
        :warning,
        :security_scheme_missing,
        "No security schemes defined. Consider adding authentication for production APIs.",
        source: "Security Analyzer"
      )
      
      [diagnostic | security_issues]
    else
      security_issues
    end
    
    # Insecure configurations
    insecure_schemes = Enum.filter(security_schemes, fn {_name, scheme} ->
      scheme[:type] == "http" && scheme[:scheme] == "basic"
    end)
    
    security_issues = if length(insecure_schemes) > 0 do
      scheme_names = Enum.map(insecure_schemes, fn {name, _} -> to_string(name) end)
      
      diagnostic = create_diagnostic(
        :warning,
        :security_concern,
        "Insecure authentication schemes detected: #{Enum.join(scheme_names, ", ")}. Consider using stronger authentication.",
        source: "Security Analyzer"
      )
      
      [diagnostic | security_issues]
    else
      security_issues
    end
    
    security_issues ++ diagnostics
  end

  defp create_compilation_error_diagnostic(error, api_module) do
    create_diagnostic(
      :error,
      :compilation_error,
      "Compilation failed: #{Exception.message(error)}",
      file: get_module_file(api_module),
      source: "Elixir Compiler",
      suggestions: [
        "Check for syntax errors in your AsyncAPI DSL",
        "Ensure all required fields are properly defined",
        "Verify that referenced components exist"
      ]
    )
  end

  defp print_terminal_diagnostics(diagnostics, show_suggestions, show_help_urls) do
    # Group by severity
    errors = Enum.filter(diagnostics, &(&1.severity == :error))
    warnings = Enum.filter(diagnostics, &(&1.severity == :warning))
    infos = Enum.filter(diagnostics, &(&1.severity in [:info, :hint]))
    
    # Print summary
    IO.puts("\n📊 AsyncAPI Diagnostics Summary:")
    IO.puts("   #{length(errors)} errors, #{length(warnings)} warnings, #{length(infos)} info")
    
    # Print errors
    if length(errors) > 0 do
      IO.puts("\n❌ Errors:")
      Enum.each(errors, fn diagnostic ->
        print_diagnostic(diagnostic, show_suggestions, show_help_urls)
      end)
    end
    
    # Print warnings
    if length(warnings) > 0 do
      IO.puts("\n⚠️  Warnings:")
      Enum.each(warnings, fn diagnostic ->
        print_diagnostic(diagnostic, show_suggestions, show_help_urls)
      end)
    end
    
    # Print info
    if length(infos) > 0 do
      IO.puts("\n💡 Info:")
      Enum.each(infos, fn diagnostic ->
        print_diagnostic(diagnostic, show_suggestions, show_help_urls)
      end)
    end
    
    :ok
  end

  defp print_diagnostic(diagnostic, show_suggestions, show_help_urls) do
    # Print main message
    location = format_location(diagnostic)
    IO.puts("   #{location}#{diagnostic.message}")
    
    if diagnostic.source do
      IO.puts("      Source: #{diagnostic.source}")
    end
    
    # Print suggestions
    if show_suggestions && length(diagnostic.suggestions) > 0 do
      IO.puts("      Suggestions:")
      Enum.each(diagnostic.suggestions, fn suggestion ->
        IO.puts("        • #{suggestion}")
      end)
    end
    
    # Print help URL
    if show_help_urls && diagnostic.help_url do
      IO.puts("      Help: #{diagnostic.help_url}")
    end
    
    IO.puts("")
  end

  defp format_location(diagnostic) do
    cond do
      diagnostic.file && diagnostic.line ->
        "#{diagnostic.file}:#{diagnostic.line}: "
      diagnostic.file ->
        "#{diagnostic.file}: "
      true ->
        ""
    end
  end

  defp print_json_diagnostics(diagnostics) do
    json_output = Jason.encode!(diagnostics, pretty: true)
    IO.puts(json_output)
    :ok
  end

  defp print_junit_diagnostics(diagnostics) do
    errors = Enum.filter(diagnostics, &(&1.severity == :error))
    failures = Enum.filter(diagnostics, &(&1.severity == :warning))
    
    junit_xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <testsuite name="AsyncAPI Validation" tests="1" failures="#{length(failures)}" errors="#{length(errors)}">
      <testcase name="AsyncAPI Specification Validation">
        #{generate_junit_failures(failures)}
        #{generate_junit_errors(errors)}
      </testcase>
    </testsuite>
    """
    
    IO.puts(junit_xml)
    :ok
  end

  defp print_github_actions_diagnostics(diagnostics) do
    Enum.each(diagnostics, fn diagnostic ->
      level = case diagnostic.severity do
        :error -> "error"
        :warning -> "warning"
        _ -> "notice"
      end
      
      file = diagnostic.file || ""
      line = diagnostic.line || ""
      
      IO.puts("::#{level} file=#{file},line=#{line}::#{diagnostic.message}")
    end)
    
    :ok
  end

  defp generate_junit_failures(failures) do
    Enum.map(failures, fn diagnostic ->
      """
        <failure message="#{escape_xml(diagnostic.message)}" type="#{diagnostic.code}">
          #{escape_xml(Enum.join(diagnostic.suggestions, "\n"))}
        </failure>
      """
    end)
    |> Enum.join("")
  end

  defp generate_junit_errors(errors) do
    Enum.map(errors, fn diagnostic ->
      """
        <error message="#{escape_xml(diagnostic.message)}" type="#{diagnostic.code}">
          #{escape_xml(Enum.join(diagnostic.suggestions, "\n"))}
        </error>
      """
    end)
    |> Enum.join("")
  end

  defp escape_xml(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp get_module_file(api_module) do
    try do
      api_module.module_info(:compile)[:source]
      |> to_string()
    rescue
      _ -> nil
    end
  end

  defp get_spec_info(api_module) do
    try do
      spec = AsyncApi.to_spec(api_module)
      info = spec[:info] || %{}
      
      %{
        title: info[:title],
        version: info[:version],
        asyncapi_version: spec[:asyncapi],
        channels: map_size(spec[:channels] || %{}),
        operations: map_size(spec[:operations] || %{}),
        components: map_size(spec[:components] || %{})
      }
    rescue
      _ -> %{}
    end
  end

  defp get_package_version do
    try do
      Application.spec(:async_api_dsl, :vsn)
      |> to_string()
    rescue
      _ -> "unknown"
    end
  end

  defp get_asyncapi_schema do
    # This would contain the AsyncAPI 3.0 JSON Schema
    # For now, return a minimal schema
    %{
      type: :object,
      required: [:asyncapi, :info],
      properties: %{
        asyncapi: %{type: :string},
        info: %{
          type: :object,
          required: [:title, :version],
          properties: %{
            title: %{type: :string},
            version: %{type: :string}
          }
        }
      }
    }
  end
end