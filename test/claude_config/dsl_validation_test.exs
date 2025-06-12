defmodule ClaudeConfig.DslValidationTest do
  use ExUnit.Case

  describe "project validation" do
    test "allows single project configuration" do
      # This should compile without errors
      defmodule SingleProjectConfig do
        use ClaudeConfig

        project do
          name "Test"
          description "Test project"
          language "Elixir"
        end
      end

      project = ClaudeConfig.Info.project_info(SingleProjectConfig)
      assert project.name == "Test"
    end

    test "rejects multiple project configurations" do
      assert_raise Spark.Error.DslError, ~r/Only one project configuration is allowed/, fn ->
        defmodule MultipleProjectConfig do
          use ClaudeConfig

          project do
            name "Test 1"
            description "First project"
            language "Elixir"
          end

          project do
            name "Test 2"
            description "Second project"
            language "Elixir"
          end
        end
      end
    end
  end

  describe "command validation" do
    test "allows unique command names" do
      defmodule UniqueCommandsConfig do
        use ClaudeConfig

        commands do
          command "test" do
            content "Test command"
          end

          command "build" do
            content "Build command"
          end
        end
      end

      commands = ClaudeConfig.Info.get_commands(UniqueCommandsConfig)
      assert length(commands) == 2
    end

    test "rejects duplicate command names" do
      assert_raise Spark.Error.DslError, ~r/Duplicate command names found: duplicate/, fn ->
        defmodule DuplicateCommandsConfig do
          use ClaudeConfig

          commands do
            command "duplicate" do
              content "First command"
            end

            command "unique" do
              content "Unique command"
            end

            command "duplicate" do
              content "Second command with same name"
            end
          end
        end
      end
    end
  end

  describe "permission pattern validation" do
    test "accepts valid tool patterns" do
      defmodule ValidPatternsConfig do
        use ClaudeConfig

        permissions do
          allow_tool "Read(**/*)"
          allow_tool "Write(**/*.ex)"
          allow_tool "LS(lib/**/*)"
          allow_tool "Glob(**/*.exs)"
          deny_tool "Write(/etc/**/*)"
        end
      end

      permissions = ClaudeConfig.Info.get_permissions(ValidPatternsConfig)
      assert length(permissions.allow_tools) == 4
      assert length(permissions.deny_tools) == 1
    end

    test "rejects invalid tool patterns" do
      assert_raise Spark.Error.DslError, ~r/Invalid tool pattern/, fn ->
        defmodule InvalidPatternsConfig do
          use ClaudeConfig

          permissions do
            allow_tool "InvalidTool(**/*)"
          end
        end
      end
    end

    test "accepts any bash command patterns" do
      defmodule BashPatternsConfig do
        use ClaudeConfig

        permissions do
          allow_bash "mix *"
          allow_bash "git status"
          allow_bash "echo 'hello'"
          deny_bash "rm -rf *"
          deny_bash "sudo *"
        end
      end

      permissions = ClaudeConfig.Info.get_permissions(BashPatternsConfig)
      assert length(permissions.allow_bash) == 3
      assert length(permissions.deny_bash) == 2
    end
  end

  describe "required field validation" do
    test "requires name for project" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule MissingProjectNameConfig do
          use ClaudeConfig

          project do
            description "Missing name"
            language "Elixir"
          end
        end
      end
    end

    test "requires description for project" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule MissingProjectDescConfig do
          use ClaudeConfig

          project do
            name "Test"
            language "Elixir"
          end
        end
      end
    end

    test "requires language for project" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule MissingProjectLangConfig do
          use ClaudeConfig

          project do
            name "Test"
            description "Missing language"
          end
        end
      end
    end

    test "requires content for command" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule MissingCommandContentConfig do
          use ClaudeConfig

          commands do
            command "test" do
              description "Missing content"
            end
          end
        end
      end
    end

    test "requires pattern for tool permissions" do
      assert_raise Spark.Error.DslError, fn ->
        defmodule MissingToolPatternConfig do
          use ClaudeConfig

          permissions do
            allow_tool()
          end
        end
      end
    end
  end

  describe "optional fields" do
    test "allows optional project fields to be omitted" do
      defmodule OptionalProjectFieldsConfig do
        use ClaudeConfig

        project do
          name "Minimal Project"
          description "Has only required fields"
          language "Elixir"
          # framework and version are optional
        end
      end

      project = ClaudeConfig.Info.project_info(OptionalProjectFieldsConfig)
      assert project.name == "Minimal Project"
      assert project.framework == nil
      assert project.version == nil
    end

    test "allows optional command fields to be omitted" do
      defmodule OptionalCommandFieldsConfig do
        use ClaudeConfig

        commands do
          command "minimal" do
            content "Just the required content"
            # description, usage, examples are optional
          end
        end
      end

      command = ClaudeConfig.Info.command(OptionalCommandFieldsConfig, "minimal")
      assert command.content == "Just the required content"
      assert command.description == nil
      assert command.usage == nil
      assert command.examples == nil
    end
  end
end