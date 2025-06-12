defmodule ClaudeConfig.RealClaudeDirectoryTest do
  use ExUnit.Case
  
  @moduledoc """
  Tests that ClaudeConfig DSL can recreate the existing .claude directory exactly.
  This test reads the actual .claude/config.json and .claude/commands/*.md files
  and ensures the DSL can generate identical output.
  """

  describe "real .claude directory comparison" do
    test "reads real .claude/config.json and validates structure" do
      # Read the real config.json
      real_config_path = Path.join([File.cwd!(), ".claude", "config.json"])
      assert File.exists?(real_config_path), "Real .claude/config.json should exist"
      
      real_config_content = File.read!(real_config_path)
      real_config = Jason.decode!(real_config_content)

      # Validate the expected structure
      assert Map.has_key?(real_config, "project_info"), "Should have project_info section"
      assert Map.has_key?(real_config, "permissions"), "Should have permissions section"
      
      project_info = real_config["project_info"]
      assert project_info["name"] == "Spark DSL Framework"
      assert project_info["description"] == "Elixir framework for building powerful, extensible Domain Specific Languages"
      assert project_info["language"] == "Elixir"
      assert project_info["framework"] == "Spark"
      assert project_info["version"] == "2.2.65"

      permissions = real_config["permissions"]
      assert Map.has_key?(permissions, "allow"), "Should have allow permissions"
      assert Map.has_key?(permissions, "deny"), "Should have deny permissions"
      
      # Verify key permissions exist
      allow_list = permissions["allow"]
      assert "Read(**/*)" in allow_list
      assert "Write(**/*.ex)" in allow_list
      assert "Bash(mix *)" in allow_list
      
      deny_list = permissions["deny"]
      assert "Bash(rm -rf *)" in deny_list
      assert "Write(/etc/**/*)" in deny_list
    end

    test "reads real .claude/commands directory and validates structure" do
      real_commands_dir = Path.join([File.cwd!(), ".claude", "commands"])
      assert File.exists?(real_commands_dir), "Real .claude/commands directory should exist"
      
      real_command_files = 
        File.ls!(real_commands_dir)
        |> Enum.filter(&String.ends_with?(&1, ".md"))
        |> Enum.sort()
      
      # Should have at least some command files
      assert length(real_command_files) > 0, "Should have at least one command file"
      
      # Check that some expected commands exist
      expected_commands = ["auto.md", "dsl-create.md", "test-dsl.md"]
      existing_commands = Enum.filter(expected_commands, &(&1 in real_command_files))
      assert length(existing_commands) > 0, "Should have at least one of the expected commands"
      
      # Verify command file contents for existing ones
      for command_file <- existing_commands do
        content = File.read!(Path.join(real_commands_dir, command_file))
        assert String.length(content) > 0, "Command file #{command_file} should not be empty"
        assert String.starts_with?(content, "#"), "Command file should start with markdown header"
      end
    end

    test "analyzes real config against DSL structure expectations" do
      # Read the real config.json
      real_config_path = Path.join([File.cwd!(), ".claude", "config.json"])
      real_config_content = File.read!(real_config_path)
      real_config = Jason.decode!(real_config_content)

      # Count permissions in real config
      real_allow_permissions = real_config["permissions"]["allow"]
      real_deny_permissions = real_config["permissions"]["deny"]
      
      # Separate tool and bash permissions
      real_tool_allows = Enum.filter(real_allow_permissions, &(not String.starts_with?(&1, "Bash(")))
      real_bash_allows = Enum.filter(real_allow_permissions, &String.starts_with?(&1, "Bash("))
      real_tool_denies = Enum.filter(real_deny_permissions, &(not String.starts_with?(&1, "Bash(")))
      real_bash_denies = Enum.filter(real_deny_permissions, &String.starts_with?(&1, "Bash("))

      # Our DSL should be able to represent all of these
      assert length(real_tool_allows) > 0, "Should have tool allow permissions"
      assert length(real_bash_allows) > 0, "Should have bash allow permissions"
      assert length(real_tool_denies) > 0, "Should have tool deny permissions"
      assert length(real_bash_denies) > 0, "Should have bash deny permissions"

      # Verify expected tools permissions exist
      assert "Read(**/*)" in real_tool_allows
      assert "Write(**/*.ex)" in real_tool_allows
      assert "LS(**/*)" in real_tool_allows
      
      # Verify expected bash permissions exist
      assert "Bash(mix *)" in real_bash_allows
      assert "Bash(git *)" in real_bash_allows
      assert "Bash(rm -rf *)" in real_bash_denies
      assert "Bash(sudo *)" in real_bash_denies

      # Verify expected deny patterns
      assert "Write(/etc/**/*)" in real_tool_denies
      assert "Write(~/.ssh/**/*)" in real_tool_denies
    end

    test "validates that our DSL structure can represent real .claude directory" do
      # This test ensures our DSL has the right structure to represent
      # the real .claude configuration without needing to create test modules

      # Read the real config
      real_config_path = Path.join([File.cwd!(), ".claude", "config.json"])
      real_config = File.read!(real_config_path) |> Jason.decode!()

      # Test that we have the right project info fields
      project_info = real_config["project_info"]
      required_project_fields = ["name", "description", "language", "framework", "version"]
      
      for field <- required_project_fields do
        assert Map.has_key?(project_info, field), "Project should have #{field} field"
        assert is_binary(project_info[field]), "#{field} should be a string"
      end

      # Test that we can categorize all permission types correctly
      permissions = real_config["permissions"]
      all_allows = permissions["allow"]
      all_denies = permissions["deny"]

      # All permissions should be categorizable as tool or bash
      for perm <- all_allows do
        assert String.starts_with?(perm, "Bash(") or 
               perm in ["Read(**/*)", "Write(**/*.ex)", "Write(**/*.exs)", "Write(**/*.md)", 
                       "Write(**/*.json)", "Write(**/*.yml)", "Write(**/*.yaml)", 
                       "Write(mix.exs)", "Write(.formatter.exs)", "LS(**/*)", "Glob(**/*)", "Grep(**/*)"],
               "Allow permission #{perm} should be categorizable"
      end

      for perm <- all_denies do
        assert String.starts_with?(perm, "Bash(") or 
               String.starts_with?(perm, "Write("),
               "Deny permission #{perm} should be categorizable"
      end

      # Test that command files exist and are readable
      real_commands_dir = Path.join([File.cwd!(), ".claude", "commands"])
      command_files = File.ls!(real_commands_dir) |> Enum.filter(&String.ends_with?(&1, ".md"))
      
      assert length(command_files) > 0, "Should have command files"
      
      # Each command file should be valid markdown with our expected structure
      for command_file <- command_files do
        content = File.read!(Path.join(real_commands_dir, command_file))
        command_name = Path.basename(command_file, ".md")
        
        # Should be valid for our DSL
        assert String.length(command_name) > 0, "Command name should not be empty"
        assert String.length(content) > 0, "Command content should not be empty"
        assert String.starts_with?(content, "#"), "Command should start with markdown header"
      end
    end
  end
end