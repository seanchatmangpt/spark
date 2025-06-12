defmodule ClaudeConfig.Info do
  @moduledoc """
  Introspection functions for ClaudeConfig DSL.
  
  Provides access to the configured project information, permissions,
  and command templates.
  """

  use Spark.InfoGenerator,
    extension: ClaudeConfig.Dsl,
    sections: [:project, :permissions, :commands]

  @doc "Get project information (only one allowed per module)"
  def project_info(resource) do
    case project(resource) do
      [project] -> project
      [] -> nil
      multiple -> raise "Only one project configuration is allowed, got: #{length(multiple)}"
    end
  end

  @doc "Get permissions configuration"
  def get_permissions(resource) do
    # The 'permissions' function returns all entities from the permissions section
    # We need to group them by entity type
    all_permissions = permissions(resource)
    
    allow_tools = Enum.filter(all_permissions, &(&1.__struct__ == ClaudeConfig.Dsl.AllowTool))
    deny_tools = Enum.filter(all_permissions, &(&1.__struct__ == ClaudeConfig.Dsl.DenyTool))
    allow_bash = Enum.filter(all_permissions, &(&1.__struct__ == ClaudeConfig.Dsl.AllowBash))
    deny_bash = Enum.filter(all_permissions, &(&1.__struct__ == ClaudeConfig.Dsl.DenyBash))

    %ClaudeConfig.Dsl.Permissions{
      allow_tools: allow_tools,
      deny_tools: deny_tools,
      allow_bash: allow_bash,
      deny_bash: deny_bash
    }
  end

  @doc "Get all command templates"
  def get_commands(resource) do
    # The 'commands' function returns all command entities from the commands section
    commands(resource)
  end

  @doc "Get a specific command template by name"
  def command(resource, name) do
    get_commands(resource)
    |> Enum.find(&(&1.name == name))
  end

  @doc "Get all command names"
  def command_names(resource) do
    get_commands(resource)
    |> Enum.map(& &1.name)
  end

  @doc "Check if a tool pattern is allowed"
  def tool_allowed?(resource, pattern) do
    perms = get_permissions(resource)
    
    # Check if explicitly denied first
    denied = Enum.any?(perms.deny_tools, &match_pattern?(&1.pattern, pattern))
    
    if denied do
      false
    else
      # Check if explicitly allowed
      Enum.any?(perms.allow_tools, &match_pattern?(&1.pattern, pattern))
    end
  end

  @doc "Check if a bash command is allowed"
  def bash_allowed?(resource, command) do
    perms = get_permissions(resource)
    
    # Check if explicitly denied first
    denied = Enum.any?(perms.deny_bash, &match_pattern?(&1.command, command))
    
    if denied do
      false
    else
      # Check if explicitly allowed
      Enum.any?(perms.allow_bash, &match_pattern?(&1.command, command))
    end
  end

  # Simple pattern matching - can be enhanced for more complex patterns
  defp match_pattern?(pattern, value) do
    # Convert glob-like patterns to regex
    regex_pattern = 
      pattern
      |> String.replace("**", ".*")
      |> String.replace("*", "[^/]*")
      |> then(&"^#{&1}$")
    
    case Regex.compile(regex_pattern) do
      {:ok, regex} -> Regex.match?(regex, value)
      {:error, _} -> pattern == value
    end
  end
end