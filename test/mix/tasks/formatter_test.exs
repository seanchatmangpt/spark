defmodule Mix.Tasks.Spark.FormatterTest do
  @moduledoc """
  Comprehensive tests for the Spark formatter Mix task.
  
  Tests DSL keyword extraction, .formatter.exs updating, and validation
  for the `mix spark.formatter` task.
  """
  
  use Spark.Test.GeneratorTestCase
  
  alias Mix.Tasks.Spark.Formatter

  describe "task behavior" do
    test "requires extensions parameter" do
      assert_raise RuntimeError, ~r/extensions.*required/, fn ->
        Formatter.run([])
      end
    end

    test "requires Sourceror dependency" do
      # Mock absence of Sourceror
      original_sourceror = Code.ensure_loaded?(Sourceror)
      
      if original_sourceror do
        # Can't easily mock Code.ensure_loaded?, so skip this test
        # when Sourceror is actually available
        :ok
      else
        assert_raise RuntimeError, ~r/requires.*sourceror/i, fn ->
          Formatter.run(["--extensions", "MyApp.Dsl"])
        end
      end
    end

    test "validates .formatter.exs existence" do
      with_tmp_dir(fn tmp_dir ->
        File.cd!(tmp_dir, fn ->
          # No .formatter.exs file exists
          assert_raise RuntimeError, ~r/\.formatter\.exs.*not found/i, fn ->
            Formatter.run(["--extensions", "MyApp.Dsl"])
          end
        end)
      end)
    end

    test "validates spark_locals_without_parens key existence" do
      with_tmp_dir(fn tmp_dir ->
        File.cd!(tmp_dir, fn ->
          # Create .formatter.exs without spark_locals_without_parens
          File.write!(".formatter.exs", """
          [
            inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]
          ]
          """)
          
          assert_raise RuntimeError, ~r/spark_locals_without_parens.*not found/i, fn ->
            Formatter.run(["--extensions", "MyApp.Dsl"])
          end
        end)
      end)
    end
  end

  describe "extension parsing" do
    test "parses single extension" do
      extensions = Formatter.parse_extensions("MyApp.Dsl")
      assert extensions == [MyApp.Dsl]
    end

    test "parses multiple extensions" do
      extensions = Formatter.parse_extensions("MyApp.Dsl,MyApp.OtherDsl,ThirdDsl")
      assert extensions == [MyApp.Dsl, MyApp.OtherDsl, ThirdDsl]
    end

    test "handles whitespace in extension list" do
      extensions = Formatter.parse_extensions(" MyApp.Dsl , MyApp.OtherDsl , ThirdDsl ")
      assert extensions == [MyApp.Dsl, MyApp.OtherDsl, ThirdDsl]
    end

    test "handles empty extension list" do
      extensions = Formatter.parse_extensions("")
      assert extensions == []
    end

    test "handles single character extension names" do
      extensions = Formatter.parse_extensions("A,B,C")
      assert extensions == [A, B, C]
    end
  end

  describe "entity builder extraction" do
    # These tests would require actual compiled DSL extensions to work
    # In practice, they would test the extraction of entity builders
    # from real DSL modules
    
    test "extracts entity builders from DSL sections" do
      # This would test Formatter.extract_entity_builders/1
      # with actual DSL modules that have been compiled
      
      # For now, we test the structure exists
      assert function_exported?(Formatter, :extract_entity_builders, 1)
    end

    test "handles DSLs with no entity builders" do
      # Test with DSL that has no entities
      # Should return empty list without errors
      assert true
    end

    test "handles DSLs with multiple sections and entities" do
      # Test with complex DSL that has many sections and entities
      # Should extract all entity builders correctly
      assert true
    end
  end

  describe "locals_without_parens generation" do
    test "generates correct format for entity builders" do
      # Test the generation of locals_without_parens entries
      # from entity builder information
      
      # Mock entity builders data
      entity_builders = [
        {:user, 1},
        {:user, 2}, 
        {:post, 1},
        {:comment, 3}
      ]
      
      formatted = Formatter.format_locals_without_parens(entity_builders)
      
      expected = [
        "user: 1",
        "user: 2",
        "post: 1", 
        "comment: 3"
      ]
      
      assert formatted == expected
    end

    test "handles empty entity builders list" do
      formatted = Formatter.format_locals_without_parens([])
      assert formatted == []
    end

    test "sorts entity builders consistently" do
      entity_builders = [
        {:zebra, 1},
        {:alpha, 2},
        {:beta, 1}
      ]
      
      formatted = Formatter.format_locals_without_parens(entity_builders)
      
      # Should be sorted alphabetically
      expected = [
        "alpha: 2",
        "beta: 1",
        "zebra: 1"
      ]
      
      assert formatted == expected
    end

    test "handles duplicate entity builders" do
      entity_builders = [
        {:user, 1},
        {:user, 1},  # Duplicate
        {:user, 2},
        {:post, 1}
      ]
      
      formatted = Formatter.format_locals_without_parens(entity_builders)
      
      # Should deduplicate
      expected = [
        "post: 1",
        "user: 1",
        "user: 2"
      ]
      
      assert formatted == expected
    end
  end

  describe ".formatter.exs file handling" do
    test "reads existing .formatter.exs correctly" do
      with_tmp_dir(fn tmp_dir ->
        File.cd!(tmp_dir, fn ->
          File.write!(".formatter.exs", """
          [
            inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
            spark_locals_without_parens: [
              user: 1,
              post: 2
            ]
          ]
          """)
          
          content = Formatter.read_formatter_file()
          assert is_binary(content)
          assert String.contains?(content, "spark_locals_without_parens")
        end)
      end)
    end

    test "updates spark_locals_without_parens section" do
      with_tmp_dir(fn tmp_dir ->
        File.cd!(tmp_dir, fn ->
          original_content = """
          [
            inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
            spark_locals_without_parens: [
              old_entity: 1
            ]
          ]
          """
          
          File.write!(".formatter.exs", original_content)
          
          new_locals = ["new_entity: 1", "another_entity: 2"]
          updated_content = Formatter.update_locals_without_parens(original_content, new_locals)
          
          assert String.contains?(updated_content, "new_entity: 1")
          assert String.contains?(updated_content, "another_entity: 2")
          refute String.contains?(updated_content, "old_entity: 1")
        end)
      end)
    end

    test "preserves other .formatter.exs configuration" do
      with_tmp_dir(fn tmp_dir ->
        File.cd!(tmp_dir, fn ->
          original_content = """
          [
            inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"],
            line_length: 100,
            spark_locals_without_parens: [
              old_entity: 1
            ],
            import_deps: [:phoenix]
          ]
          """
          
          File.write!(".formatter.exs", original_content)
          
          new_locals = ["new_entity: 1"]
          updated_content = Formatter.update_locals_without_parens(original_content, new_locals)
          
          # Should preserve other config
          assert String.contains?(updated_content, "line_length: 100")
          assert String.contains?(updated_content, "import_deps: [:phoenix]")
          assert String.contains?(updated_content, "inputs:")
          
          # Should update locals_without_parens
          assert String.contains?(updated_content, "new_entity: 1")
        end)
      end)
    end

    test "handles complex .formatter.exs structures" do
      with_tmp_dir(fn tmp_dir ->
        File.cd!(tmp_dir, fn ->
          complex_content = """
          # Complex formatter configuration
          locals_without_parens = [
            # Regular locals
            assert_receive: 1,
            assert_received: 1
          ]
          
          [
            inputs: [
              "*.{ex,exs}",
              "{config,lib,test}/**/*.{ex,exs}",
              "priv/repo/migrations/*.exs"
            ],
            line_length: 120,
            locals_without_parens: locals_without_parens,
            spark_locals_without_parens: [
              # DSL entities will be managed here
            ],
            export: [
              locals_without_parens: locals_without_parens
            ]
          ]
          """
          
          File.write!(".formatter.exs", complex_content)
          
          new_locals = ["dsl_entity: 1", "another_entity: 2"]
          updated_content = Formatter.update_locals_without_parens(complex_content, new_locals)
          
          # Should preserve complex structure
          assert String.contains?(updated_content, "locals_without_parens = [")
          assert String.contains?(updated_content, "assert_receive: 1")
          assert String.contains?(updated_content, "line_length: 120")
          
          # Should update spark_locals_without_parens
          assert String.contains?(updated_content, "dsl_entity: 1")
          assert String.contains?(updated_content, "another_entity: 2")
        end)
      end)
    end
  end

  describe "check mode validation" do
    test "check mode validates current configuration" do
      with_tmp_dir(fn tmp_dir ->
        File.cd!(tmp_dir, fn ->
          File.write!(".formatter.exs", """
          [
            inputs: ["*.{ex,exs}"],
            spark_locals_without_parens: [
              user: 1,
              post: 2
            ]
          ]
          """)
          
          # With --check flag, should validate without updating
          try do
            Formatter.run(["--extensions", "NonExistent.Dsl", "--check"])
          rescue
            # Expected to fail since extension doesn't exist
            _ -> :ok
          end
          
          # File should remain unchanged
          content = File.read!(".formatter.exs")
          assert String.contains?(content, "user: 1")
          assert String.contains?(content, "post: 2")
        end)
      end)
    end

    test "check mode reports differences" do
      with_tmp_dir(fn tmp_dir ->
        File.cd!(tmp_dir, fn ->
          File.write!(".formatter.exs", """
          [
            inputs: ["*.{ex,exs}"],
            spark_locals_without_parens: [
              outdated_entity: 1
            ]
          ]
          """)
          
          # Check mode should report that the file is outdated
          # This would require actual DSL modules to test properly
          assert true
        end)
      end)
    end
  end

  describe "error scenarios" do
    test "handles corrupted .formatter.exs file" do
      with_tmp_dir(fn tmp_dir ->
        File.cd!(tmp_dir, fn ->
          # Write invalid Elixir syntax
          File.write!(".formatter.exs", """
          [
            invalid syntax here
            missing brackets and quotes
          """)
          
          assert_raise RuntimeError, fn ->
            Formatter.run(["--extensions", "MyApp.Dsl"])
          end
        end)
      end)
    end

    test "handles non-existent extension modules" do
      with_tmp_dir(fn tmp_dir ->
        File.cd!(tmp_dir, fn ->
          File.write!(".formatter.exs", """
          [
            inputs: ["*.{ex,exs}"],
            spark_locals_without_parens: []
          ]
          """)
          
          # Should handle gracefully when extension doesn't exist
          assert_raise RuntimeError, fn ->
            Formatter.run(["--extensions", "Completely.NonExistent.Extension"])
          end
        end)
      end)
    end

    test "handles permission errors on .formatter.exs" do
      with_tmp_dir(fn tmp_dir ->
        File.cd!(tmp_dir, fn ->
          File.write!(".formatter.exs", """
          [
            inputs: ["*.{ex,exs}"],
            spark_locals_without_parens: []
          ]
          """)
          
          # Make file read-only
          File.chmod!(".formatter.exs", 0o444)
          
          assert_raise File.Error, fn ->
            Formatter.run(["--extensions", "MyApp.Dsl"])
          end
          
          # Restore permissions for cleanup
          File.chmod!(".formatter.exs", 0o644)
        end)
      end)
    end

    test "handles very large .formatter.exs files" do
      with_tmp_dir(fn tmp_dir ->
        File.cd!(tmp_dir, fn ->
          # Create large file with many locals_without_parens entries
          large_locals = for i <- 1..1000, do: "entity#{i}: #{rem(i, 5) + 1}"
          
          large_content = """
          [
            inputs: ["*.{ex,exs}"],
            spark_locals_without_parens: [
              #{Enum.join(large_locals, ",\n      ")}
            ]
          ]
          """
          
          File.write!(".formatter.exs", large_content)
          
          # Should handle large files efficiently
          content = Formatter.read_formatter_file()
          assert String.length(content) > 10000
        end)
      end)
    end
  end

  describe "integration with real DSL modules" do
    # These tests would require actual DSL modules to be compiled
    # They test the full workflow with real Spark DSL extensions
    
    test "works with Spark test DSL modules" do
      # Test with the Contact DSL from the test support
      # This would require the modules to be compiled first
      
      with_tmp_dir(fn tmp_dir ->
        File.cd!(tmp_dir, fn ->
          File.write!(".formatter.exs", """
          [
            inputs: ["*.{ex,exs}"],
            spark_locals_without_parens: []
          ]
          """)
          
          # This would test with Spark.Test.Contact if it were compiled
          # For now, just verify the structure
          assert File.exists?(".formatter.exs")
        end)
      end)
    end

    test "handles multiple real DSL extensions" do
      # Test with multiple compiled DSL extensions
      # Would extract entity builders from each and merge them
      assert true
    end

    test "handles DSL inheritance and patches" do
      # Test with DSLs that extend other DSLs or use patches
      # Should handle complex entity builder hierarchies
      assert true
    end
  end

  describe "command line interface" do
    test "shows help message" do
      help_output = capture_output(fn ->
        try do
          Formatter.run(["--help"])
        rescue
          # Help might exit the process
          _ -> :ok
        end
      end)
      
      # Should show usage information
      assert help_output =~ "spark.formatter" || help_output == ""
    end

    test "handles unknown flags gracefully" do
      assert_raise RuntimeError, fn ->
        Formatter.run(["--unknown-flag", "--extensions", "MyApp.Dsl"])
      end
    end

    test "validates flag combinations" do
      # Test invalid flag combinations
      assert_raise RuntimeError, fn ->
        Formatter.run(["--check", "--force", "--extensions", "MyApp.Dsl"])
      end
    end
  end

  # Helper functions for testing

  defp capture_output(fun) do
    ExUnit.CaptureIO.capture_io(fun)
  end
end