defmodule ClaudeConfig.Dsl do
  @moduledoc """
  DSL extension for defining Claude Code .claude directory configurations.
  """

  # Project Information Entities
  defmodule Project do
    @moduledoc "Project information configuration"
    defstruct [:name, :description, :language, :framework, :version]
  end

  # Permission Entities
  defmodule AllowTool do
    @moduledoc "Tool permission to allow"
    defstruct [:pattern]
  end

  defmodule DenyTool do
    @moduledoc "Tool permission to deny"
    defstruct [:pattern]
  end

  defmodule AllowBash do
    @moduledoc "Bash command pattern to allow"
    defstruct [:command]
  end

  defmodule DenyBash do
    @moduledoc "Bash command pattern to deny"
    defstruct [:command]
  end

  defmodule Permissions do
    @moduledoc "Container for all permission settings"
    defstruct allow_tools: [], deny_tools: [], allow_bash: [], deny_bash: []
  end

  # Command Template Entity
  defmodule Command do
    @moduledoc "Command template definition"
    defstruct [:name, :description, :content, :usage, :examples]
  end

  # Entity Definitions
  @project %Spark.Dsl.Entity{
    name: :project,
    target: Project,
    describe: "Define project information for Claude Code configuration",
    schema: [
      name: [
        type: :string,
        required: true,
        doc: "The name of the project"
      ],
      description: [
        type: :string,
        required: true,
        doc: "A brief description of the project"
      ],
      language: [
        type: :string,
        required: true,
        doc: "Primary programming language"
      ],
      framework: [
        type: :string,
        doc: "Primary framework used (optional)"
      ],
      version: [
        type: :string,
        doc: "Current project version (optional)"
      ]
    ]
  }

  @allow_tool %Spark.Dsl.Entity{
    name: :allow_tool,
    target: AllowTool,
    describe: "Allow a specific tool with pattern matching",
    args: [:pattern],
    schema: [
      pattern: [
        type: :string,
        required: true,
        doc: "Tool permission pattern (e.g., 'Read(**/*)', 'Write(**/*.ex)')"
      ]
    ]
  }

  @deny_tool %Spark.Dsl.Entity{
    name: :deny_tool,
    target: DenyTool,
    describe: "Deny a specific tool with pattern matching",
    args: [:pattern],
    schema: [
      pattern: [
        type: :string,
        required: true,
        doc: "Tool permission pattern to deny"
      ]
    ]
  }

  @allow_bash %Spark.Dsl.Entity{
    name: :allow_bash,
    target: AllowBash,
    describe: "Allow bash command patterns",
    args: [:command],
    schema: [
      command: [
        type: :string,
        required: true,
        doc: "Bash command pattern to allow (e.g., 'mix *', 'git *')"
      ]
    ]
  }

  @deny_bash %Spark.Dsl.Entity{
    name: :deny_bash,
    target: DenyBash,
    describe: "Deny bash command patterns",
    args: [:command],
    schema: [
      command: [
        type: :string,
        required: true,
        doc: "Bash command pattern to deny (e.g., 'rm -rf *', 'sudo *')"
      ]
    ]
  }

  @command %Spark.Dsl.Entity{
    name: :command,
    target: Command,
    describe: "Define a reusable command template",
    args: [:name],
    schema: [
      name: [
        type: :string,
        required: true,
        doc: "Command name (used as filename)"
      ],
      description: [
        type: :string,
        doc: "Brief description of what the command does"
      ],
      content: [
        type: :string,
        required: true,
        doc: "Full markdown content for the command template"
      ],
      usage: [
        type: :string,
        doc: "Usage pattern for the command"
      ],
      examples: [
        type: {:list, :string},
        doc: "List of usage examples"
      ]
    ]
  }

  # Section Definitions
  @project_section %Spark.Dsl.Section{
    name: :project,
    top_level?: true,
    entities: [@project],
    describe: "Configure project information for Claude Code"
  }

  @permissions_section %Spark.Dsl.Section{
    name: :permissions,
    top_level?: true,
    entities: [@allow_tool, @deny_tool, @allow_bash, @deny_bash],
    describe: "Configure Claude Code permissions for tools and bash commands"
  }

  @commands_section %Spark.Dsl.Section{
    name: :commands,
    top_level?: true,
    entities: [@command],
    describe: "Define reusable command templates"
  }

  use Spark.Dsl.Extension,
    sections: [@project_section, @permissions_section, @commands_section],
    transformers: [ClaudeConfig.Transformers.ValidateConfig]
end