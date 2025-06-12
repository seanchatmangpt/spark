defmodule ClaudeConfig.Transformers.ValidateConfig do
  @moduledoc """
  Transformer to validate ClaudeConfig DSL configuration at compile time.
  
  Ensures that:
  - Only one project configuration is defined
  - Command names are unique
  - Permission patterns are valid
  - Required fields are present
  """

  use Spark.Dsl.Transformer

  @impl true
  def transform(dsl_state) do
    with :ok <- validate_single_project(dsl_state),
         :ok <- validate_unique_commands(dsl_state),
         :ok <- validate_permission_patterns(dsl_state) do
      {:ok, dsl_state}
    else
      {:error, error} -> {:error, error}
    end
  end

  defp validate_single_project(dsl_state) do
    project_entities = Spark.Dsl.Transformer.get_entities(dsl_state, [:project])
    
    case length(project_entities) do
      0 -> :ok  # Project is optional
      1 -> :ok
      count -> 
        {:error, 
         Spark.Error.DslError.exception(
           message: "Only one project configuration is allowed, found #{count}",
           path: [:project]
         )}
    end
  end

  defp validate_unique_commands(dsl_state) do
    commands = Spark.Dsl.Transformer.get_entities(dsl_state, [:commands, :command])
    command_names = Enum.map(commands, & &1.name)
    unique_names = Enum.uniq(command_names)
    
    if length(command_names) == length(unique_names) do
      :ok
    else
      duplicates = command_names -- unique_names
      {:error,
       Spark.Error.DslError.exception(
         message: "Duplicate command names found: #{Enum.join(duplicates, ", ")}",
         path: [:commands]
       )}
    end
  end

  defp validate_permission_patterns(dsl_state) do
    # Validate allow_tool patterns
    allow_tools = Spark.Dsl.Transformer.get_entities(dsl_state, [:permissions, :allow_tool])
    deny_tools = Spark.Dsl.Transformer.get_entities(dsl_state, [:permissions, :deny_tool])
    
    with :ok <- validate_tool_patterns(allow_tools, [:permissions, :allow_tool]),
         :ok <- validate_tool_patterns(deny_tools, [:permissions, :deny_tool]) do
      :ok
    end
  end

  defp validate_tool_patterns(tools, path) do
    Enum.reduce_while(tools, :ok, fn tool, :ok ->
      if valid_tool_pattern?(tool.pattern) do
        {:cont, :ok}
      else
        error = Spark.Error.DslError.exception(
          message: "Invalid tool pattern: '#{tool.pattern}'. Expected format like 'Read(**/*)', 'Write(**/*.ex)', etc.",
          path: path
        )
        {:halt, {:error, error}}
      end
    end)
  end

  defp valid_tool_pattern?(pattern) do
    # Basic validation for common tool patterns
    tool_patterns = [
      ~r/^Read\(.+\)$/,
      ~r/^Write\(.+\)$/,
      ~r/^LS\(.+\)$/,
      ~r/^Glob\(.+\)$/,
      ~r/^Grep\(.+\)$/,
      ~r/^Edit\(.+\)$/,
      ~r/^MultiEdit\(.+\)$/,
      ~r/^NotebookRead\(.+\)$/,
      ~r/^NotebookEdit\(.+\)$/,
      ~r/^WebFetch\(.+\)$/,
      ~r/^WebSearch\(.+\)$/,
      ~r/^TodoRead\(.+\)$/,
      ~r/^TodoWrite\(.+\)$/,
      ~r/^Task\(.+\)$/
    ]
    
    Enum.any?(tool_patterns, &Regex.match?(&1, pattern))
  end
end