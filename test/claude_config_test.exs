defmodule ClaudeConfigTest do
  use ExUnit.Case

  defmodule TestClaudeConfig do
    use ClaudeConfig

    project do
      name "Test Project"
      description "A test project for ClaudeConfig DSL"
      language "Elixir"
      framework "Phoenix"
      version "1.0.0"
    end

    permissions do
      allow_tool "Read(**/*)"
      allow_tool "Write(**/*.ex)"
      allow_tool "Write(**/*.exs)"
      allow_bash "mix *"
      allow_bash "git *"
      deny_bash "rm -rf *"
      deny_bash "sudo *"
      deny_tool "Write(/etc/**/*)"
    end

    commands do
      command "test-runner" do
        description "Run comprehensive test suite"
        usage "/test-runner [suite] [options]"
        content """
        # Test Runner
        
        Runs the complete test suite with coverage reporting.
        
        ## Usage
        ```
        /test-runner [suite] [options]
        ```
        
        ## Examples
        - `/test-runner` - Run all tests
        - `/test-runner unit` - Run unit tests only
        """
        examples ["mix test", "mix test --cover"]
      end

      command "build-docs" do
        description "Generate documentation"
        content """
        # Documentation Builder
        
        Generates comprehensive documentation for the project.
        """
      end
    end
  end

  defmodule MinimalClaudeConfig do
    use ClaudeConfig

    permissions do
      allow_tool "Read(**/*)"
    end
  end

  describe "project configuration" do
    test "retrieves project information" do
      project = ClaudeConfig.Info.project_info(TestClaudeConfig)
      
      assert project.name == "Test Project"
      assert project.description == "A test project for ClaudeConfig DSL"
      assert project.language == "Elixir"
      assert project.framework == "Phoenix"
      assert project.version == "1.0.0"
    end

    test "handles missing project configuration" do
      project = ClaudeConfig.Info.project_info(MinimalClaudeConfig)
      assert project == nil
    end
  end

  describe "permissions configuration" do
    test "retrieves permissions correctly" do
      permissions = ClaudeConfig.Info.get_permissions(TestClaudeConfig)
      
      assert length(permissions.allow_tools) == 3
      assert length(permissions.allow_bash) == 2
      assert length(permissions.deny_bash) == 2
      assert length(permissions.deny_tools) == 1
      
      # Check specific permissions
      allow_patterns = Enum.map(permissions.allow_tools, & &1.pattern)
      assert "Read(**/*)" in allow_patterns
      assert "Write(**/*.ex)" in allow_patterns
      
      deny_patterns = Enum.map(permissions.deny_bash, & &1.command)
      assert "rm -rf *" in deny_patterns
      assert "sudo *" in deny_patterns
    end

    test "checks tool permissions" do
      assert ClaudeConfig.Info.tool_allowed?(TestClaudeConfig, "Read(lib/test.ex)")
      assert ClaudeConfig.Info.tool_allowed?(TestClaudeConfig, "Write(lib/new_file.ex)")
      refute ClaudeConfig.Info.tool_allowed?(TestClaudeConfig, "Write(/etc/hosts)")
      refute ClaudeConfig.Info.tool_allowed?(TestClaudeConfig, "Delete(lib/test.ex)")
    end

    test "checks bash permissions" do
      assert ClaudeConfig.Info.bash_allowed?(TestClaudeConfig, "mix test")
      assert ClaudeConfig.Info.bash_allowed?(TestClaudeConfig, "git status")
      refute ClaudeConfig.Info.bash_allowed?(TestClaudeConfig, "rm -rf /")
      refute ClaudeConfig.Info.bash_allowed?(TestClaudeConfig, "sudo apt update")
    end
  end

  describe "command templates" do
    test "retrieves all commands" do
      commands = ClaudeConfig.Info.get_commands(TestClaudeConfig)
      
      assert length(commands) == 2
      command_names = Enum.map(commands, & &1.name)
      assert "test-runner" in command_names
      assert "build-docs" in command_names
    end

    test "retrieves specific command" do
      command = ClaudeConfig.Info.command(TestClaudeConfig, "test-runner")
      
      assert command.name == "test-runner"
      assert command.description == "Run comprehensive test suite"
      assert command.usage == "/test-runner [suite] [options]"
      assert String.contains?(command.content, "Test Runner")
      assert "mix test" in command.examples
    end

    test "returns nil for non-existent command" do
      command = ClaudeConfig.Info.command(TestClaudeConfig, "non-existent")
      assert command == nil
    end

    test "gets command names" do
      names = ClaudeConfig.Info.command_names(TestClaudeConfig)
      assert names == ["test-runner", "build-docs"]
    end
  end

  describe ".claude directory generation" do
    test "generates config.json correctly" do
      # Use a temporary directory for testing
      temp_dir = System.tmp_dir!() 
      test_dir = Path.join(temp_dir, "claude_config_test_#{:rand.uniform(10000)}")
      
      try do
        result = ClaudeConfig.generate_claude_directory(TestClaudeConfig, test_dir)
        
        # Check that files were created
        assert File.exists?(result.config_file)
        assert File.exists?(result.commands_dir)
        assert length(result.command_files) == 2
        
        # Check config.json content
        config_content = File.read!(result.config_file)
        config = Jason.decode!(config_content)
        
        assert config["project_info"]["name"] == "Test Project"
        assert config["project_info"]["language"] == "Elixir"
        
        permissions = config["permissions"]
        assert "Read(**/*)" in permissions["allow"]
        assert "Bash(mix *)" in permissions["allow"]
        assert "Bash(rm -rf *)" in permissions["deny"]
        assert "Write(/etc/**/*)" in permissions["deny"]
        
        # Check command files
        test_runner_file = Path.join(result.commands_dir, "test-runner.md")
        assert File.exists?(test_runner_file)
        content = File.read!(test_runner_file)
        assert String.contains?(content, "Test Runner")
        assert String.contains?(content, "/test-runner [suite] [options]")
        
      after
        # Clean up
        if File.exists?(test_dir) do
          File.rm_rf!(test_dir)
        end
      end
    end

    test "generates minimal config without project info" do
      temp_dir = System.tmp_dir!()
      test_dir = Path.join(temp_dir, "claude_config_minimal_#{:rand.uniform(10000)}")
      
      try do
        result = ClaudeConfig.generate_claude_directory(MinimalClaudeConfig, test_dir)
        
        config_content = File.read!(result.config_file)
        config = Jason.decode!(config_content)
        
        # Should not have project_info section
        refute Map.has_key?(config, "project_info")
        
        # Should have permissions
        assert Map.has_key?(config, "permissions")
        assert "Read(**/*)" in config["permissions"]["allow"]
        
      after
        if File.exists?(test_dir) do
          File.rm_rf!(test_dir)
        end
      end
    end
  end
end