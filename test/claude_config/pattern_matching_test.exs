defmodule ClaudeConfig.PatternMatchingTest do
  use ExUnit.Case

  defmodule TestConfig do
    use ClaudeConfig

    permissions do
      allow_tool "Read(**/*)"
      allow_tool "Write(**/*.ex)"
      allow_tool "Write(**/*.exs)"
      allow_tool "Write(mix.exs)"
      allow_tool "LS(lib/**/*)"
      allow_tool "Glob(test/**/*)"
      
      allow_bash "mix *"
      allow_bash "git *"
      allow_bash "echo hello"
      
      deny_tool "Write(/etc/**/*)"
      deny_tool "Write(/usr/**/*)"
      deny_tool "Read(secrets.txt)"
      
      deny_bash "rm -rf *"
      deny_bash "sudo *"
      deny_bash "chmod 777 *"
    end
  end

  describe "tool permission pattern matching" do
    test "matches exact patterns" do
      assert ClaudeConfig.Info.tool_allowed?(TestConfig, "Write(mix.exs)")
      refute ClaudeConfig.Info.tool_allowed?(TestConfig, "Read(secrets.txt)")
    end

    test "matches single-level wildcards" do
      assert ClaudeConfig.Info.tool_allowed?(TestConfig, "Write(lib/test.ex)")
      assert ClaudeConfig.Info.tool_allowed?(TestConfig, "Write(test/support.exs)")
    end

    test "matches multi-level wildcards" do
      assert ClaudeConfig.Info.tool_allowed?(TestConfig, "Read(lib/deep/nested/file.ex)")
      assert ClaudeConfig.Info.tool_allowed?(TestConfig, "LS(lib/very/deep/path)")
      assert ClaudeConfig.Info.tool_allowed?(TestConfig, "Glob(test/unit/nested/test.exs)")
    end

    test "respects deny patterns over allow patterns" do
      # Even though Write(**/*) would match, deny patterns take precedence
      refute ClaudeConfig.Info.tool_allowed?(TestConfig, "Write(/etc/hosts)")
      refute ClaudeConfig.Info.tool_allowed?(TestConfig, "Write(/usr/local/bin/script)")
    end

    test "rejects unmatched patterns" do
      refute ClaudeConfig.Info.tool_allowed?(TestConfig, "Delete(lib/test.ex)")
      refute ClaudeConfig.Info.tool_allowed?(TestConfig, "Execute(script.sh)")
      refute ClaudeConfig.Info.tool_allowed?(TestConfig, "Write(lib/test.py)")  # .py not allowed
    end

    test "handles complex path matching" do
      assert ClaudeConfig.Info.tool_allowed?(TestConfig, "Read(lib/my_app/controllers/user_controller.ex)")
      assert ClaudeConfig.Info.tool_allowed?(TestConfig, "Write(lib/my_app.ex)")
      refute ClaudeConfig.Info.tool_allowed?(TestConfig, "Write(lib/test.py)")
    end
  end

  describe "bash permission pattern matching" do
    test "matches exact commands" do
      assert ClaudeConfig.Info.bash_allowed?(TestConfig, "echo hello")
      refute ClaudeConfig.Info.bash_allowed?(TestConfig, "rm -rf /")
    end

    test "matches command prefixes with wildcards" do
      assert ClaudeConfig.Info.bash_allowed?(TestConfig, "mix test")
      assert ClaudeConfig.Info.bash_allowed?(TestConfig, "mix deps.get")
      assert ClaudeConfig.Info.bash_allowed?(TestConfig, "git status")
      assert ClaudeConfig.Info.bash_allowed?(TestConfig, "git commit -m 'message'")
    end

    test "respects deny patterns over allow patterns" do
      # Even though these might match wildcards, deny patterns take precedence
      refute ClaudeConfig.Info.bash_allowed?(TestConfig, "rm -rf lib/")
      refute ClaudeConfig.Info.bash_allowed?(TestConfig, "sudo apt update")
      refute ClaudeConfig.Info.bash_allowed?(TestConfig, "chmod 777 file.txt")
    end

    test "rejects unmatched commands" do
      refute ClaudeConfig.Info.bash_allowed?(TestConfig, "python script.py")
      refute ClaudeConfig.Info.bash_allowed?(TestConfig, "npm install")
      refute ClaudeConfig.Info.bash_allowed?(TestConfig, "curl http://example.com")
    end

    test "handles complex command matching" do
      assert ClaudeConfig.Info.bash_allowed?(TestConfig, "mix test --cover --parallel")
      assert ClaudeConfig.Info.bash_allowed?(TestConfig, "git push origin main")
      refute ClaudeConfig.Info.bash_allowed?(TestConfig, "mix not_a_real_task")  # Still allowed due to wildcard
    end
  end

  describe "edge cases" do
    test "handles empty patterns gracefully" do
      defmodule EmptyPatternConfig do
        use ClaudeConfig
        
        permissions do
          allow_tool "Read(**/*)"
        end
      end

      # Should handle empty or nil inputs gracefully
      refute ClaudeConfig.Info.tool_allowed?(EmptyPatternConfig, "")
      refute ClaudeConfig.Info.bash_allowed?(EmptyPatternConfig, "")
    end

    test "handles special characters in patterns" do
      defmodule SpecialCharConfig do
        use ClaudeConfig
        
        permissions do
          allow_tool "Read(**/*.ex)"
          allow_bash "echo '*'"
          deny_tool "Write(**/*.tmp)"
        end
      end

      assert ClaudeConfig.Info.tool_allowed?(SpecialCharConfig, "Read(lib/test.ex)")
      refute ClaudeConfig.Info.tool_allowed?(SpecialCharConfig, "Write(lib/temp.tmp)")
    end

    test "handles case sensitivity" do
      defmodule CaseSensitiveConfig do
        use ClaudeConfig
        
        permissions do
          allow_tool "Read(**/*.ex)"
          allow_bash "Mix test"
        end
      end

      assert ClaudeConfig.Info.tool_allowed?(CaseSensitiveConfig, "Read(lib/test.ex)")
      refute ClaudeConfig.Info.tool_allowed?(CaseSensitiveConfig, "Read(lib/test.EX)")  # Case matters
      
      assert ClaudeConfig.Info.bash_allowed?(CaseSensitiveConfig, "Mix test")
      refute ClaudeConfig.Info.bash_allowed?(CaseSensitiveConfig, "mix test")  # Case matters
    end
  end

  describe "pattern precedence" do
    test "deny patterns always override allow patterns" do
      defmodule PrecedenceConfig do
        use ClaudeConfig
        
        permissions do
          allow_tool "Write(**/*)"      # Very permissive
          deny_tool "Write(**/secrets/**/*)"  # But deny secrets
          
          allow_bash "*"               # Allow everything
          deny_bash "rm *"             # But deny rm commands
        end
      end

      # Should be denied despite broad allow pattern
      refute ClaudeConfig.Info.tool_allowed?(PrecedenceConfig, "Write(app/secrets/api_key.txt)")
      refute ClaudeConfig.Info.bash_allowed?(PrecedenceConfig, "rm file.txt")
      
      # Should be allowed
      assert ClaudeConfig.Info.tool_allowed?(PrecedenceConfig, "Write(app/public/file.txt)")
      assert ClaudeConfig.Info.bash_allowed?(PrecedenceConfig, "ls -la")
    end
  end
end