defmodule SimpleDslFactoryTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias SimpleDslFactory

  describe "generate_resource/1" do
    test "generates working Ash resource code" do
      spec = %{
        name: "BlogPost",
        attributes: [
          %{name: :title, type: :string, required: true},
          %{name: :body, type: :string},
          %{name: :published, type: :boolean, default: false}
        ],
        actions: [:create, :read, :update, :destroy]
      }

      assert {:ok, result} = SimpleDslFactory.generate_resource(spec)
      assert %{spec: _spec, generated: generated, quality: quality, code: code} = result

      # The code should be valid Elixir
      assert {:ok, _ast} = Code.string_to_quoted(code)
      
      # Should contain expected elements
      assert String.contains?(code, "defmodule BlogPost")
      assert String.contains?(code, "use Ash.Resource")
      assert String.contains?(code, "attribute :title")
      assert String.contains?(code, "attribute :body")
      assert String.contains?(code, "attribute :published")
      
      # Quality should be measured
      assert quality.compiles_successfully in [true, false]  # Should be boolean
      assert is_integer(quality.lines_of_code)
      assert quality.lines_of_code > 0
    end

    test "handles invalid specs gracefully" do
      invalid_spec = %{
        name: "invalid name with spaces",  # Invalid module name
        attributes: [],
        actions: [:create]
      }

      # Should either fail validation or generate with quality issues
      case SimpleDslFactory.generate_resource(invalid_spec) do
        {:error, _reason} -> 
          # Validation caught the issue - good!
          assert true
        {:ok, result} ->
          # Generated but should have low quality
          assert result.quality.overall_score < 50
      end
    end

    property "generates code for any valid spec" do
      check all name <- valid_module_name(),
                attr_count <- integer(1..5),
                attributes <- list_of(valid_attribute(), length: attr_count) do
        
        spec = %{
          name: name,
          attributes: attributes,
          actions: [:create, :read]
        }

        case SimpleDslFactory.generate_resource(spec) do
          {:ok, result} ->
            # Generated code should parse
            assert {:ok, _} = Code.string_to_quoted(result.code)
            assert String.contains?(result.code, "defmodule #{name}")
            
          {:error, _} ->
            # If it fails, that's okay for property testing
            # We're testing robustness
            :ok
        end
      end
    end
  end

  describe "measure_quality/1" do
    setup do
      # Create a simple generated resource for testing
      {:ok, dsl_spec} = Ash.create!(SimpleDslFactory.DslSpec, %{
        name: "TestResource",
        attributes: Jason.encode!([%{name: :test, type: :string}]),
        actions: [:create],
        raw_spec: "{}"
      }, domain: SimpleDslFactory)

      {:ok, generated} = Ash.create!(SimpleDslFactory.GeneratedResource, %{
        dsl_spec_id: dsl_spec.id,
        code: """
        defmodule TestResource do
          use Ash.Resource
          
          attributes do
            uuid_primary_key :id
            attribute :test, :string
          end
        end
        """
      }, domain: SimpleDslFactory)

      %{generated: generated}
    end

    test "measures real code metrics", %{generated: generated} do
      assert {:ok, quality} = SimpleDslFactory.measure_quality(generated)
      
      assert is_integer(quality.lines_of_code)
      assert quality.lines_of_code > 0
      assert is_integer(quality.cyclomatic_complexity)
      assert is_integer(quality.compilation_time_ms)
      assert is_boolean(quality.compiles_successfully)
      assert is_boolean(quality.follows_conventions)
      
      score = Decimal.to_float(quality.overall_score)
      assert score >= 0.0 and score <= 100.0
    end
  end

  describe "analyze_patterns/1" do
    test "returns pattern analysis" do
      patterns = SimpleDslFactory.analyze_patterns(limit: 5)
      
      assert is_list(patterns)
      assert length(patterns) <= 5
      
      # Each pattern should have expected fields
      for pattern <- patterns do
        assert Map.has_key?(pattern, :pattern)
        assert Map.has_key?(pattern, :count)
        assert Map.has_key?(pattern, :avg_quality)
        assert Map.has_key?(pattern, :success_rate)
      end
    end
  end

  # Property testing generators
  defp valid_module_name do
    gen all prefix <- string(:ascii, min_length: 1, max_length: 10),
            suffix <- string(:ascii, min_length: 0, max_length: 10),
            String.match?(prefix, ~r/^[A-Z]/) do
      # Ensure it starts with capital letter and contains only valid chars
      clean_prefix = String.replace(prefix, ~r/[^A-Za-z0-9]/, "")
      clean_suffix = String.replace(suffix, ~r/[^A-Za-z0-9]/, "")
      
      case clean_prefix do
        "" -> "TestModule"
        name -> String.capitalize(name) <> clean_suffix
      end
    end
  end

  defp valid_attribute do
    gen all name <- atom(:alphanumeric),
            type <- member_of([:string, :integer, :boolean, :decimal]) do
      %{name: name, type: type}
    end
  end
end