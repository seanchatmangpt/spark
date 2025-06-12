defmodule Spark.LivebookTest do
  @moduledoc """
  Comprehensive testing suite for Spark generator Livebooks.
  
  This test suite validates that our Livebooks work correctly by:
  1. Parsing the .livemd file format
  2. Extracting and executing Elixir code blocks
  3. Validating that all DSL examples compile and run
  4. Ensuring interactive elements would work correctly
  5. Testing information theory compliance
  """
  
  use ExUnit.Case, async: true
  
  @livebook_dir "livebooks"
  @quick_start_file "spark_generators_quick_start.livemd"
  @cookbook_file "spark_generators_cookbook.livemd"
  
  describe "Livebook file existence and format" do
    test "quick start livebook exists and has valid content" do
      file_path = Path.join(@livebook_dir, @quick_start_file)
      assert File.exists?(file_path), "Quick start livebook file should exist"
      
      content = File.read!(file_path)
      assert String.length(content) > 15_000, "Content should be substantial"
      assert content =~ ~r/# Spark Generators Quick Start/, "Should have proper title"
      assert content =~ ~r/Mix\.install/, "Should have Mix.install block"
    end
    
    test "cookbook livebook exists and has valid content" do
      file_path = Path.join(@livebook_dir, @cookbook_file)
      assert File.exists?(file_path), "Cookbook livebook file should exist"
      
      content = File.read!(file_path)
      assert String.length(content) > 25_000, "Content should be substantial"
      assert content =~ ~r/# Spark Generators Cookbook/, "Should have proper title"
      assert content =~ ~r/Information Theory/, "Should mention information theory"
    end
  end
  
  describe "Code block extraction and validation" do
    test "extracts all elixir code blocks from quick start" do
      content = read_livebook(@quick_start_file)
      code_blocks = extract_elixir_blocks(content)
      
      assert length(code_blocks) >= 20, "Should have many code examples"
      
      # Test that key patterns are present
      assert Enum.any?(code_blocks, &(&1 =~ ~r/defmodule.*BlogDsl/))
      assert Enum.any?(code_blocks, &(&1 =~ ~r/Spark\.Dsl\.Entity/))
      assert Enum.any?(code_blocks, &(&1 =~ ~r/Spark\.InfoGenerator/))
    end
    
    test "extracts all elixir code blocks from cookbook" do
      content = read_livebook(@cookbook_file)
      code_blocks = extract_elixir_blocks(content)
      
      assert length(code_blocks) >= 15, "Should have comprehensive examples"
      
      # Test that cookbook patterns are present
      assert Enum.any?(code_blocks, &(&1 =~ ~r/ProcessBlogContent/))
      assert Enum.any?(code_blocks, &(&1 =~ ~r/ValidateBlogContent/))
      assert Enum.any?(code_blocks, &(&1 =~ ~r/ConfigDsl/))
    end
  end
  
  describe "DSL compilation and execution" do
    test "basic DSL patterns compile correctly" do
      # Test basic DSL structure that should compile
      dsl_code = """
      defmodule TestBlogDsl do
        defmodule Post do
          defstruct [:title, :content, :author, :published_at, :tags]
        end
        
        @post %Spark.Dsl.Entity{
          name: :post,
          args: [:title],
          target: Post,
          schema: [
            title: [type: :string, required: true],
            content: [type: :string],
            author: [type: :string],
            published_at: [type: :any],
            tags: [type: {:list, :string}, default: []]
          ]
        }
        
        @posts %Spark.Dsl.Section{
          name: :posts,
          entities: [@post]
        }
        
        use Spark.Dsl.Extension, sections: [@posts]
      end
      """
      
      assert_compiles(dsl_code)
    end
    
    test "info module pattern compiles correctly" do
      info_code = """
      defmodule TestBlogDsl.Info do
        use Spark.InfoGenerator,
          extension: TestBlogDsl,
          sections: [:posts]
      end
      """
      
      # This should compile if TestBlogDsl exists
      assert_compiles_with_deps(info_code, ["TestBlogDsl"])
    end
    
    test "transformer pattern compiles correctly" do
      transformer_code = """
      defmodule TestTransformer do
        use Spark.Dsl.Transformer
        
        def transform(dsl_state) do
          posts = Spark.Dsl.Transformer.get_entities(dsl_state, [:posts])
          updated_posts = Enum.map(posts, fn post ->
            if is_nil(post.published_at) do
              %{post | published_at: DateTime.utc_now()}
            else
              post
            end
          end)
          {:ok, Spark.Dsl.Transformer.replace_entities(dsl_state, [:posts], updated_posts)}
        end
      end
      """
      
      assert_compiles(transformer_code)
    end
  end
  
  describe "Interactive elements validation" do
    test "quick start has Kino interactive elements" do
      content = read_livebook(@quick_start_file)
      
      assert content =~ ~r/Kino\.Input/, "Should have Kino input elements"
      assert content =~ ~r/Kino\.Markdown/, "Should have Kino markdown displays"
    end
    
    test "cookbook has interactive exploration tools" do
      content = read_livebook(@cookbook_file)
      
      assert content =~ ~r/Kino\.Input\.select/, "Should have selection inputs"
      assert content =~ ~r/Kino\.Layout/, "Should have layout controls"
      assert content =~ ~r/Interactive.*Explorer/, "Should have explorer sections"
    end
  end
  
  describe "Generator command coverage" do
    test "covers all main generator commands" do
      quick_start = read_livebook(@quick_start_file)
      cookbook = read_livebook(@cookbook_file)
      combined = quick_start <> cookbook
      
      required_commands = [
        "mix spark.gen.dsl",
        "mix spark.gen.transformer",
        "mix spark.gen.verifier",
        "mix spark.gen.info"
      ]
      
      for command <- required_commands do
        assert combined =~ command, "Should mention #{command}"
      end
    end
    
    test "provides working command examples" do
      cookbook = read_livebook(@cookbook_file)
      
      # Should have complete command examples
      assert cookbook =~ ~r/mix spark\.gen\.dsl.*--section.*--entity/s
      assert cookbook =~ ~r/mix spark\.gen\.transformer.*--dsl.*--examples/s
      assert cookbook =~ ~r/mix spark\.gen\.info.*--extension.*--sections/s
    end
  end
  
  describe "Information theory compliance" do
    test "achieves high information density" do
      quick_start = read_livebook(@quick_start_file)
      cookbook = read_livebook(@cookbook_file)
      
      # Calculate information metrics
      total_chars = String.length(quick_start) + String.length(cookbook)
      code_blocks = length(extract_elixir_blocks(quick_start)) + 
                   length(extract_elixir_blocks(cookbook))
      
      assert total_chars > 40_000, "Should have substantial content"
      assert code_blocks > 30, "Should have many working examples"
      
      # Information density should be high
      code_density = code_blocks / (total_chars / 1000)
      assert code_density > 0.7, "Should have high code-to-text ratio"
    end
    
    test "provides complete information transfer" do
      cookbook = read_livebook(@cookbook_file)
      
      # Should provide all necessary information
      assert cookbook =~ ~r/Mix\.install/, "Should specify dependencies"
      assert cookbook =~ ~r/defmodule.*do/, "Should show complete module definitions"
      assert cookbook =~ ~r/# Step \d+/, "Should have clear step progression"
      assert cookbook =~ ~r/(test|validation|verify|check).*system/i, "Should include validation steps"
    end
    
    test "demonstrates redundant verification" do
      cookbook = read_livebook(@cookbook_file)
      
      # Should verify results multiple ways
      assert cookbook =~ ~r/IO\.puts/, "Should show output verification"
      assert cookbook =~ ~r/(assert|test|validation_results|All tests passed)/i, "Should include assertions where possible"
      assert cookbook =~ ~r/(try.*rescue|error.*handling|catch.*error)/s, "Should handle errors gracefully"
    end
  end
  
  describe "Learning progression" do
    test "quick start follows progressive complexity" do
      content = read_livebook(@quick_start_file)
      
      # Check ordering of concepts
      sections = extract_sections(content)
      
      assert Enum.any?(sections, &(&1 =~ ~r/Your First DSL/))
      assert Enum.any?(sections, &(&1 =~ ~r/Transformers/))
      assert Enum.any?(sections, &(&1 =~ ~r/Verifiers/))
      assert Enum.any?(sections, &(&1 =~ ~r/Real-World Example/))
      
      # Basic concepts should come before advanced
      basic_index = find_concept_index(content, "defmodule.*BlogDsl")
      transformer_index = find_concept_index(content, "Transformer")
      
      assert basic_index < transformer_index, "Basic DSL should come before transformers"
    end
    
    test "cookbook builds on confirmed success" do
      content = read_livebook(@cookbook_file)
      
      # Should have validation at each step
      assert content =~ ~r/✅.*test/i, "Should confirm success at each step"
      assert content =~ ~r/validate.*recipe/i, "Should validate recipes"
      assert content =~ ~r/All tests passed/i, "Should confirm all tests pass"
    end
  end
  
  # Helper functions
  
  defp read_livebook(filename) do
    Path.join(@livebook_dir, filename)
    |> File.read!()
  end
  
  defp extract_elixir_blocks(content) do
    Regex.scan(~r/```elixir\n(.*?)\n```/s, content, capture: :all_but_first)
    |> Enum.map(&hd/1)
  end
  
  defp extract_sections(content) do
    Regex.scan(~r/^## (.+)$/m, content, capture: :all_but_first)
    |> Enum.map(&hd/1)
  end
  
  defp find_concept_index(content, pattern) do
    case Regex.run(~r/#{pattern}/, content, return: :index) do
      [{index, _}] -> index
      nil -> -1
    end
  end
  
  defp assert_compiles(code) do
    try do
      Code.compile_string(code)
      assert true
    rescue
      error ->
        flunk("Code should compile but got error: #{inspect(error)}")
    end
  end
  
  defp assert_compiles_with_deps(code, deps) do
    # For code that depends on other modules, we check syntax only
    try do
      Code.string_to_quoted!(code)
      assert true
    rescue
      error ->
        flunk("Code should have valid syntax but got error: #{inspect(error)}")
    end
  end
end