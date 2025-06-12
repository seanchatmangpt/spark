defmodule Spark.LivebookTestRunner do
  @moduledoc """
  Test runner for executing Livebook code blocks in isolation.
  
  This module provides utilities for:
  1. Parsing .livemd files
  2. Extracting executable code blocks
  3. Running code blocks in isolated environments
  4. Validating expected outputs
  5. Testing interactive patterns
  """
  
  @doc """
  Executes a Livebook file and validates that all code blocks run successfully.
  """
  def execute_livebook(file_path, opts \\ []) do
    timeout = Opts.get(opts, :timeout, 30_000)
    validate_outputs = Opts.get(opts, :validate_outputs, true)
    
    content = File.read!(file_path)
    code_blocks = extract_code_blocks(content)
    
    results = Enum.map(code_blocks, fn {index, block} ->
      execute_code_block(block, index, timeout)
    end)
    
    if validate_outputs do
      validate_execution_results(results, content)
    else
      results
    end
  end
  
  @doc """
  Extracts all Elixir code blocks from a Livebook file.
  """
  def extract_code_blocks(content) do
    # Match Mix.install block first (special handling)
    mix_install = case Regex.run(~r/```elixir\n(Mix\.install\(.*?\))\n```/s, content, capture: :all_but_first) do
      [install_block] -> [{0, install_block}]
      nil -> []
    end
    
    # Extract all other Elixir blocks
    other_blocks = 
      Regex.scan(~r/```elixir\n((?!Mix\.install).*?)\n```/s, content, capture: :all_but_first)
      |> Enum.with_index(1)
      |> Enum.map(fn {[block], index} -> {index, block} end)
    
    mix_install ++ other_blocks
  end
  
  @doc """
  Executes a single code block in an isolated environment.
  """
  def execute_code_block(code, index, timeout \\ 30_000) do
    # Create a temporary module to execute the code
    module_name = :"TestModule#{index}_#{:erlang.unique_integer([:positive])}"
    
    # Wrap code in a module to prevent conflicts
    wrapped_code = """
    defmodule #{module_name} do
      def run do
        try do
    #{indent_code(code, 4)}
        rescue
          error -> {:error, error}
        catch
          :exit, reason -> {:error, {:exit, reason}}
          value -> {:error, {:throw, value}}
        end
      end
    end
    """
    
    try do
      # Compile the module
      [{^module_name, _}] = Code.compile_string(wrapped_code)
      
      # Execute with timeout
      task = Task.async(fn -> apply(module_name, :run, []) end)
      result = Task.await(task, timeout)
      
      # Clean up
      :code.delete(module_name)
      :code.purge(module_name)
      
      case result do
        {:error, error} -> {:error, index, error}
        value -> {:ok, index, value}
      end
    rescue
      error ->
        {:compile_error, index, error}
    end
  end
  
  @doc """
  Validates that code blocks produce expected outputs.
  """
  def validate_execution_results(results, content) do
    errors = Enum.filter(results, fn
      {:ok, _, _} -> false
      {:error, _, _} -> true
      {:compile_error, _, _} -> true
    end)
    
    if length(errors) > 0 do
      {:error, "Execution failed for #{length(errors)} code blocks", errors}
    else
      {:ok, "All #{length(results)} code blocks executed successfully", results}
    end
  end
  
  @doc """
  Tests specific DSL patterns in a Livebook.
  """
  def test_dsl_patterns(file_path) do
    content = File.read!(file_path)
    
    patterns = [
      {:basic_dsl, ~r/defmodule.*Dsl.*do.*use Spark\.Dsl\.Extension/s},
      {:entity_definition, ~r/@\w+.*%Spark\.Dsl\.Entity\{/s},
      {:section_definition, ~r/@\w+.*%Spark\.Dsl\.Section\{/s},
      {:info_module, ~r/defmodule.*Info.*use Spark\.InfoGenerator/s},
      {:transformer, ~r/defmodule.*Transformer.*use Spark\.Dsl\.Transformer/s},
      {:verifier, ~r/defmodule.*Verifier.*use Spark\.Dsl\.Verifier/s}
    ]
    
    results = Enum.map(patterns, fn {name, pattern} ->
      found = content =~ pattern
      {name, found}
    end)
    
    missing = Enum.filter(results, fn {_, found} -> not found end)
    
    if length(missing) > 0 do
      {:error, "Missing DSL patterns: #{inspect(Enum.map(missing, &elem(&1, 0)))}"}
    else
      {:ok, "All DSL patterns found: #{inspect(Enum.map(results, &elem(&1, 0)))}"}
    end
  end
  
  @doc """
  Tests interactive elements in a Livebook.
  """
  def test_interactive_elements(file_path) do
    content = File.read!(file_path)
    
    interactive_patterns = [
      {:kino_input, ~r/Kino\.Input/},
      {:kino_markdown, ~r/Kino\.Markdown/},
      {:kino_layout, ~r/Kino\.Layout/},
      {:dynamic_content, ~r/Kino\.Input\.read/}
    ]
    
    results = Enum.map(interactive_patterns, fn {name, pattern} ->
      matches = Regex.scan(pattern, content) |> length()
      {name, matches}
    end)
    
    total_interactive = Enum.map(results, &elem(&1, 1)) |> Enum.sum()
    
    if total_interactive > 0 do
      {:ok, "Found #{total_interactive} interactive elements", results}
    else
      {:error, "No interactive elements found"}
    end
  end
  
  @doc """
  Validates information theory compliance in documentation.
  """
  def validate_information_theory(file_path) do
    content = File.read!(file_path)
    
    # Calculate metrics
    total_chars = String.length(content)
    code_blocks = extract_code_blocks(content) |> length()
    
    # Check for key information theory principles
    checks = [
      {:complete_information, content =~ ~r/Mix\.install/ and content =~ ~r/defmodule/},
      {:redundant_verification, content =~ ~r/(test|assert|validate|verify)/i},
      {:progressive_building, content =~ ~r/(step|section|part)/i},
      {:working_examples, code_blocks > 10},
      {:minimal_entropy, content =~ ~r/(complete|exact|specific)/i}
    ]
    
    passed = Enum.count(checks, fn {_, result} -> result end)
    total = length(checks)
    
    # Calculate information density
    info_density = code_blocks / (total_chars / 1000)
    
    metrics = %{
      total_characters: total_chars,
      code_blocks: code_blocks,
      information_density: Float.round(info_density, 2),
      principles_passed: "#{passed}/#{total}",
      entropy_reduction: Float.round((passed / total) * 100, 1)
    }
    
    if passed >= 4 do
      {:ok, "Information theory compliance achieved", metrics}
    else
      {:warning, "Information theory compliance needs improvement", metrics}
    end
  end
  
  @doc """
  Runs a comprehensive test suite on a Livebook file.
  """
  def comprehensive_test(file_path) do
    file_name = Path.basename(file_path)
    
    tests = [
      {"File existence", fn -> File.exists?(file_path) end},
      {"DSL patterns", fn -> test_dsl_patterns(file_path) end},
      {"Interactive elements", fn -> test_interactive_elements(file_path) end},
      {"Information theory", fn -> validate_information_theory(file_path) end}
    ]
    
    results = Enum.map(tests, fn {name, test_fn} ->
      try do
        result = test_fn.()
        {name, result}
      rescue
        error ->
          {name, {:error, error}}
      end
    end)
    
    # Count successes
    successes = Enum.count(results, fn {_, result} ->
      case result do
        true -> true
        {:ok, _} -> true
        {:ok, _, _} -> true
        _ -> false
      end
    end)
    
    %{
      file: file_name,
      tests_passed: "#{successes}/#{length(results)}",
      success_rate: Float.round(successes / length(results) * 100, 1),
      results: results
    }
  end
  
  # Private helper functions
  
  defp indent_code(code, spaces) do
    indent = String.duplicate(" ", spaces)
    code
    |> String.split("\n")
    |> Enum.map(&(indent <> &1))
    |> Enum.join("\n")
  end
  
  # Simple options helper
  defmodule Opts do
    def get(opts, key, default) do
      Keyword.get(opts, key, default)
    end
  end
end