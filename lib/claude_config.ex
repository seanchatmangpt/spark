defmodule ClaudeConfig do
  @moduledoc """
  DSL for managing Claude Code .claude directory configurations.
  
  Provides a declarative way to define Claude Code project settings, permissions,
  and command templates through a structured DSL that generates proper .claude
  directory structures.

  ## Example

      defmodule MyProject.ClaudeConfig do
        use ClaudeConfig

        project do
          name "My Elixir Project"
          description "A sample Elixir application"
          language "Elixir"
          framework "Phoenix"
          version "1.0.0"
        end

        permissions do
          allow_tool "Read(**/*)"
          allow_tool "Write(**/*.ex)"
          allow_bash "mix *"
          deny_bash "rm -rf *"
        end

        command "test-runner" do
          description "Run comprehensive test suite"
          content '''
          # Test Runner
          
          Runs the complete test suite with coverage reporting.
          
          ## Usage
          ```
          /test-runner [suite] [options]
          ```
          '''
        end
      end

  The DSL generates:
  - `.claude/config.json` with project info and permissions
  - `.claude/commands/*.md` files for each defined command
  """

  use Spark.Dsl,
    default_extensions: [
      extensions: [ClaudeConfig.Dsl]
    ]

  @doc """
  Generates the .claude directory structure based on DSL configuration.
  """
  def generate_claude_directory(module, base_path \\ ".") do
    claude_dir = Path.join(base_path, ".claude")
    commands_dir = Path.join(claude_dir, "commands")

    # Ensure directories exist
    File.mkdir_p!(commands_dir)

    # Generate config.json
    config_content = generate_config_json(module)
    config_path = Path.join(claude_dir, "config.json")
    File.write!(config_path, config_content)

    # Generate command files
    commands = ClaudeConfig.Info.get_commands(module)
    Enum.each(commands, fn command ->
      command_file = Path.join(commands_dir, "#{command.name}.md")
      File.write!(command_file, command.content)
    end)

    # Return generated file paths
    %{
      config_file: config_path,
      commands_dir: commands_dir,
      command_files: Enum.map(commands, &Path.join(commands_dir, "#{&1.name}.md"))
    }
  end

  defp generate_config_json(module) do
    project = ClaudeConfig.Info.project_info(module)
    permissions = ClaudeConfig.Info.get_permissions(module)

    config = %{
      permissions: %{
        allow: Enum.map(permissions.allow_tools, & &1.pattern) ++
               Enum.map(permissions.allow_bash, &"Bash(#{&1.command})"),
        deny: Enum.map(permissions.deny_tools, & &1.pattern) ++
              Enum.map(permissions.deny_bash, &"Bash(#{&1.command})")
      }
    }

    config = if project do
      Map.put(config, :project_info, %{
        name: project.name,
        description: project.description,
        language: project.language,
        framework: project.framework,
        version: project.version
      })
    else
      config
    end

    Jason.encode!(config, pretty: true)
  end
end