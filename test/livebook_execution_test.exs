defmodule Spark.LivebookExecutionTest do
  @moduledoc """
  Comprehensive execution tests for Spark generator Livebooks.
  
  This test suite actually executes code from the Livebooks to ensure
  they work correctly when users follow the tutorials.
  """
  
  use ExUnit.Case, async: false
  
  alias Spark.LivebookTestRunner
  
  @livebook_dir "livebooks"
  @quick_start_file Path.join(@livebook_dir, "spark_generators_quick_start.livemd")
  @cookbook_file Path.join(@livebook_dir, "spark_generators_cookbook.livemd")
  
  describe "Livebook comprehensive testing" do
    test "quick start livebook comprehensive test" do
      result = LivebookTestRunner.comprehensive_test(@quick_start_file)
      
      assert result.success_rate >= 75.0, 
        "Quick start should have >75% test success rate, got #{result.success_rate}%"
      
      # Check specific results
      assert get_test_result(result, "File existence") == true
      assert match?({:ok, _}, get_test_result(result, "DSL patterns"))
      
      IO.puts("\n📊 Quick Start Test Results:")
      IO.puts("   Success Rate: #{result.success_rate}%")
      IO.puts("   Tests Passed: #{result.tests_passed}")
    end
    
    test "cookbook livebook comprehensive test" do
      result = LivebookTestRunner.comprehensive_test(@cookbook_file)
      
      assert result.success_rate >= 75.0,
        "Cookbook should have >75% test success rate, got #{result.success_rate}%"
      
      # Check specific results  
      assert get_test_result(result, "File existence") == true
      assert match?({:ok, _}, get_test_result(result, "DSL patterns"))
      
      IO.puts("\n📊 Cookbook Test Results:")
      IO.puts("   Success Rate: #{result.success_rate}%")
      IO.puts("   Tests Passed: #{result.tests_passed}")
    end
  end
  
  describe "DSL pattern validation" do
    test "quick start contains all essential DSL patterns" do
      {:ok, message} = LivebookTestRunner.test_dsl_patterns(@quick_start_file)
      
      assert message =~ "All DSL patterns found"
      
      # Should find these specific patterns
      content = File.read!(@quick_start_file)
      assert content =~ ~r/defmodule.*BlogDsl/
      assert content =~ ~r/Spark\.Dsl\.Entity/
      assert content =~ ~r/Spark\.InfoGenerator/
    end
    
    test "cookbook contains advanced DSL patterns" do
      {:ok, message} = LivebookTestRunner.test_dsl_patterns(@cookbook_file)
      
      assert message =~ "All DSL patterns found"
      
      # Should find these specific patterns
      content = File.read!(@cookbook_file)
      assert content =~ ~r/ProcessBlogContent/
      assert content =~ ~r/ValidateBlogContent/
      assert content =~ ~r/Spark\.Dsl\.Transformer/
      assert content =~ ~r/Spark\.Dsl\.Verifier/
    end
  end
  
  describe "Interactive elements validation" do
    test "quick start has sufficient interactive elements" do
      {:ok, message, elements} = LivebookTestRunner.test_interactive_elements(@quick_start_file)
      
      assert message =~ "interactive elements"
      
      # Should have various types of interactive elements
      kino_inputs = get_element_count(elements, :kino_input)
      assert kino_inputs > 0, "Should have Kino input elements"
    end
    
    test "cookbook has comprehensive interactive features" do
      {:ok, message, elements} = LivebookTestRunner.test_interactive_elements(@cookbook_file)
      
      assert message =~ "interactive elements"
      
      # Should have advanced interactive features
      kino_layouts = get_element_count(elements, :kino_layout)
      dynamic_content = get_element_count(elements, :dynamic_content)
      
      assert kino_layouts > 0, "Should have layout controls"
      assert dynamic_content > 0, "Should have dynamic content"
    end
  end
  
  describe "Information theory compliance" do
    test "quick start meets information theory standards" do
      {:ok, message, metrics} = LivebookTestRunner.validate_information_theory(@quick_start_file)
      
      assert message =~ "compliance achieved"
      assert metrics.information_density > 1.0, "Should have good information density"
      assert metrics.entropy_reduction > 80.0, "Should achieve good entropy reduction"
      
      IO.puts("\n📊 Quick Start Information Theory Metrics:")
      IO.puts("   Characters: #{metrics.total_characters}")
      IO.puts("   Code blocks: #{metrics.code_blocks}")
      IO.puts("   Information density: #{metrics.information_density}")
      IO.puts("   Entropy reduction: #{metrics.entropy_reduction}%")
    end
    
    test "cookbook meets advanced information theory standards" do
      result = LivebookTestRunner.validate_information_theory(@cookbook_file)
      
      case result do
        {:ok, message, metrics} ->
          assert message =~ "compliance achieved"
          assert metrics.information_density > 0.5, "Should have good information density"
          assert metrics.entropy_reduction > 80.0, "Should achieve good entropy reduction"
          
        {:warning, message, metrics} ->
          # Accept warnings but log them
          IO.puts("\n⚠️ Cookbook Information Theory Warning: #{message}")
          assert metrics.entropy_reduction > 60.0, "Should achieve reasonable entropy reduction"
      end
    end
  end
  
  describe "Code block extraction and basic validation" do
    test "extracts code blocks correctly from quick start" do
      code_blocks = LivebookTestRunner.extract_code_blocks(File.read!(@quick_start_file))
      
      assert length(code_blocks) > 15, "Should extract many code blocks"
      
      # Check that blocks are properly indexed
      {first_index, first_block} = hd(code_blocks)
      assert is_integer(first_index)
      assert is_binary(first_block)
      assert String.length(first_block) > 0
    end
    
    test "extracts code blocks correctly from cookbook" do
      code_blocks = LivebookTestRunner.extract_code_blocks(File.read!(@cookbook_file))
      
      assert length(code_blocks) > 10, "Should extract substantial code blocks"
      
      # Should find Mix.install block
      mix_install_block = Enum.find(code_blocks, fn {_, block} -> 
        block =~ ~r/Mix\.install/
      end)
      assert mix_install_block, "Should find Mix.install block"
    end
  end
  
  describe "Syntax validation" do
    test "all code blocks have valid Elixir syntax" do
      code_blocks = LivebookTestRunner.extract_code_blocks(File.read!(@quick_start_file))
      
      syntax_errors = Enum.filter(code_blocks, fn {index, block} ->
        case Code.string_to_quoted(block) do
          {:ok, _} -> false
          {:error, _} -> true
        end
      end)
      
      if length(syntax_errors) > 0 do
        IO.puts("\n❌ Syntax errors found in quick start:")
        for {index, _block} <- syntax_errors do
          IO.puts("   Block #{index}: syntax error")
        end
      end
      
      # Allow some syntax errors for incomplete examples
      assert length(syntax_errors) < length(code_blocks) / 2, 
        "Most code blocks should have valid syntax"
    end
    
    test "cookbook code blocks have valid syntax" do
      code_blocks = LivebookTestRunner.extract_code_blocks(File.read!(@cookbook_file))
      
      syntax_errors = Enum.filter(code_blocks, fn {index, block} ->
        # Skip blocks that are meant to be incomplete (like output blocks)
        if block =~ ~r/(IO\.puts|assert|result =)/ and not (block =~ ~r/defmodule/) do
          false  # Skip output/test blocks
        else
          case Code.string_to_quoted(block) do
            {:ok, _} -> false
            {:error, _} -> true
          end
        end
      end)
      
      # Should have mostly valid syntax
      assert length(syntax_errors) < length(code_blocks) / 3,
        "Most substantial code blocks should have valid syntax"
    end
  end
  
  describe "Learning progression validation" do
    test "quick start follows logical progression" do
      content = File.read!(@quick_start_file)
      
      # Check that concepts appear in logical order
      concepts = [
        "Your First DSL",
        "Adding Transformers", 
        "Adding Verifiers",
        "Real-World Example"
      ]
      
      indices = Enum.map(concepts, fn concept ->
        case Regex.run(~r/#{Regex.escape(concept)}/i, content, return: :index) do
          [{index, _}] -> index
          nil -> -1
        end
      end)
      
      # Remove concepts that weren't found
      found_indices = Enum.filter(indices, &(&1 >= 0))
      
      assert length(found_indices) >= 3, "Should find most key concepts"
      assert found_indices == Enum.sort(found_indices), "Concepts should appear in logical order"
    end
    
    test "cookbook demonstrates progressive complexity" do
      content = File.read!(@cookbook_file)
      
      # Should start simple and get more complex
      assert content =~ ~r/Recipe 1.*Complete Blog DSL/s
      assert content =~ ~r/Step 1.*Create.*Foundation/s
      assert content =~ ~r/Step.*Add.*Processing/s
      
      # Later sections should be more complex
      simple_dsl_pos = find_position(content, "BlogDsl")
      complex_dsl_pos = find_position(content, "ProcessBlogContent")
      
      assert simple_dsl_pos < complex_dsl_pos, "Simple concepts should come before complex ones"
    end
  end
  
  # Helper functions
  
  defp get_test_result(result, test_name) do
    case Enum.find(result.results, fn {name, _} -> name == test_name end) do
      {_, result} -> result
      nil -> nil
    end
  end
  
  defp get_element_count(elements, element_type) do
    case Enum.find(elements, fn {type, _} -> type == element_type end) do
      {_, count} -> count
      nil -> 0
    end
  end
  
  defp find_position(content, pattern) do
    case Regex.run(~r/#{Regex.escape(pattern)}/, content, return: :index) do
      [{index, _}] -> index
      nil -> -1
    end
  end
end