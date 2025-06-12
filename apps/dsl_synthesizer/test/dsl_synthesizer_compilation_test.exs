defmodule DslSynthesizerCompilationTest do
  use ExUnit.Case, async: false
  
  alias DslSynthesizer.{CodeGenerator, TemplateEngine, QualityAnalyzer}
  
  describe "Real code compilation testing" do
    test "generates and compiles Phoenix LiveView components" do
      specification = %{
        framework: :phoenix_live_view,
        components: [
          %{
            name: "UserList",
            type: :live_component,
            props: [:users, :filter],
            events: ["filter_changed", "user_selected"]
          },
          %{
            name: "UserForm",
            type: :live_component,
            props: [:user, :changeset],
            events: ["save", "cancel"]
          }
        ]
      }
      
      {:ok, generated_code} = CodeGenerator.generate(specification, :template)
      
      # Test compilation
      assert {:ok, modules} = Code.compile_string(generated_code)
      assert length(modules) >= 2
      
      # Verify LiveView component structure
      for {module, _bytecode} <- modules do
        if String.contains?(to_string(module), "Component") do
          assert function_exported?(module, :render, 1)
          assert function_exported?(module, :handle_event, 3)
        end
      end
    end
    
    test "generates compilable Ash resources with complex relationships" do
      specification = %{
        framework: :ash,
        resources: [
          %{
            name: "User",
            attributes: [
              %{name: :id, type: :uuid_primary_key},
              %{name: :email, type: :string, constraints: [%{unique: true}]},
              %{name: :name, type: :string}
            ],
            relationships: [
              %{name: :posts, type: :has_many, destination: "Post"},
              %{name: :profile, type: :has_one, destination: "Profile"}
            ],
            actions: [:create, :read, :update, :destroy],
            validations: [%{type: :present, attribute: :email}]
          },
          %{
            name: "Post",
            attributes: [
              %{name: :id, type: :uuid_primary_key},
              %{name: :title, type: :string},
              %{name: :content, type: :string},
              %{name: :published, type: :boolean, default: false}
            ],
            relationships: [
              %{name: :author, type: :belongs_to, destination: "User"}
            ],
            actions: [:create, :read, :update, :destroy, :publish]
          }
        ]
      }
      
      {:ok, generated_code} = CodeGenerator.generate(specification, :template)
      
      # Compile the generated code
      [{user_module, _}, {post_module, _}] = Code.compile_string(generated_code)
      
      # Test Ash resource functionality
      user_attributes = Ash.Resource.Info.attributes(user_module)
      post_attributes = Ash.Resource.Info.attributes(post_module)
      
      assert length(user_attributes) == 3
      assert length(post_attributes) == 4
      
      # Test relationships
      user_relationships = Ash.Resource.Info.relationships(user_module)
      post_relationships = Ash.Resource.Info.relationships(post_module)
      
      assert length(user_relationships) == 2
      assert length(post_relationships) == 1
      
      # Test actions
      user_actions = Ash.Resource.Info.actions(user_module)
      assert length(user_actions) >= 4
    end
    
    test "validates generated code meets quality standards" do
      specification = %{
        framework: :ash,
        resources: [
          %{
            name: "QualityTest",
            attributes: [
              %{name: :id, type: :uuid_primary_key},
              %{name: :data, type: :map}
            ]
          }
        ]
      }
      
      {:ok, code} = CodeGenerator.generate(specification, :template)
      quality_report = QualityAnalyzer.analyze(code)
      
      # Quality checks
      assert quality_report.syntax_valid
      assert quality_report.compilation_successful
      assert quality_report.ash_resource_valid
      assert quality_report.quality_score > 0.8
      
      # Style checks
      assert quality_report.follows_conventions
      assert quality_report.has_documentation
      assert length(quality_report.warnings) < 3
    end
  end
  
  describe "Code generation strategies comparison" do
    test "compares template vs AI-assisted generation quality" do
      specification = %{
        domain: :e_commerce,
        entities: ["Product", "Category", "Order"],
        features: [:catalog, :cart, :checkout]
      }
      
      # Generate with different strategies
      {:ok, template_code} = CodeGenerator.generate(specification, :template)
      {:ok, ai_code} = CodeGenerator.generate(specification, :ai_assisted)
      {:ok, hybrid_code} = CodeGenerator.generate(specification, :hybrid)
      
      # Compile all versions
      template_compilation = compile_and_analyze(template_code)
      ai_compilation = compile_and_analyze(ai_code)
      hybrid_compilation = compile_and_analyze(hybrid_code)
      
      # Compare results
      assert template_compilation.compiles
      assert ai_compilation.compiles
      assert hybrid_compilation.compiles
      
      # Quality comparison
      qualities = [
        {:template, template_compilation.quality_score},
        {:ai, ai_compilation.quality_score},
        {:hybrid, hybrid_compilation.quality_score}
      ]
      
      sorted_qualities = Enum.sort_by(qualities, fn {_, score} -> score end, :desc)
      best_strategy = elem(hd(sorted_qualities), 0)
      
      # Log results for analysis
      IO.inspect({:best_strategy, best_strategy, sorted_qualities})
      
      # All should meet minimum quality threshold
      for {_strategy, score} <- qualities do
        assert score > 0.7
      end
    end
  end
  
  describe "Performance and optimization" do
    test "measures code generation performance across strategies" do
      large_specification = %{
        framework: :ash,
        resources: for i <- 1..20 do
          %{
            name: "Entity#{i}",
            attributes: [
              %{name: :id, type: :uuid_primary_key},
              %{name: :name, type: :string},
              %{name: :data, type: :map}
            ],
            relationships: if i > 1, do: [%{name: :parent, type: :belongs_to, destination: "Entity#{i-1}"}], else: []
          }
        end
      }
      
      strategies = [:template, :pattern_based, :ai_assisted, :hybrid]
      
      performance_results = for strategy <- strategies do
        {time_microseconds, {:ok, code}} = :timer.tc(fn ->
          CodeGenerator.generate(large_specification, strategy)
        end)
        
        time_ms = time_microseconds / 1000
        code_size = String.length(code)
        
        # Verify compilation
        compilation_result = compile_and_analyze(code)
        
        {
          strategy,
          %{
            generation_time_ms: time_ms,
            code_size_bytes: code_size,
            compiles: compilation_result.compiles,
            quality_score: compilation_result.quality_score
          }
        }
      end
      
      # Performance assertions
      for {strategy, metrics} <- performance_results do
        assert metrics.generation_time_ms < 30_000, "#{strategy} took too long: #{metrics.generation_time_ms}ms"
        assert metrics.compiles, "#{strategy} generated code that doesn't compile"
        assert metrics.quality_score > 0.6, "#{strategy} quality too low: #{metrics.quality_score}"
      end
      
      # Log performance comparison
      IO.inspect({:performance_comparison, performance_results})
    end
    
    test "handles memory efficiently with large codebases" do
      # Monitor memory usage during generation
      initial_memory = :erlang.memory(:total)
      
      massive_specification = %{
        framework: :ash,
        resources: for i <- 1..100 do
          %{
            name: "MassiveEntity#{i}",
            attributes: for j <- 1..10, do: %{name: "field_#{j}", type: :string},
            relationships: for k <- 1..3, do: %{name: "rel_#{k}", type: :has_many, destination: "Other#{k}"}
          }
        end
      }
      
      {:ok, _massive_code} = CodeGenerator.generate(massive_specification, :template)
      
      final_memory = :erlang.memory(:total)
      memory_increase = final_memory - initial_memory
      
      # Memory increase should be reasonable (less than 100MB)
      assert memory_increase < 100_000_000
    end
  end
  
  describe "Error handling and edge cases" do
    test "handles malformed specifications gracefully" do
      malformed_specs = [
        %{},  # Empty spec
        %{framework: :unknown},  # Unknown framework
        %{resources: "invalid"},  # Invalid resources
        %{resources: [%{name: ""}]},  # Empty resource name
        %{resources: [%{attributes: "not_a_list"}]}  # Invalid attributes
      ]
      
      for spec <- malformed_specs do
        case CodeGenerator.generate(spec, :template) do
          {:ok, code} ->
            # If generation succeeds, code should still be valid
            compilation = compile_and_analyze(code)
            assert compilation.compiles or compilation.has_fallback
            
          {:error, reason} ->
            # Error should be descriptive
            assert is_atom(reason) or is_binary(reason)
        end
      end
    end
    
    test "recovers from compilation failures" do
      # Intentionally create problematic specification
      problematic_spec = %{
        framework: :ash,
        resources: [
          %{
            name: "ProblematicResource",
            attributes: [
              %{name: :id, type: :invalid_type},  # Invalid type
              %{name: :duplicate, type: :string},
              %{name: :duplicate, type: :string}   # Duplicate attribute
            ]
          }
        ]
      }
      
      result = CodeGenerator.generate_with_recovery(problematic_spec, :template)
      
      case result do
        {:ok, code, warnings} ->
          assert is_binary(code)
          assert is_list(warnings)
          assert length(warnings) > 0
          
        {:error, :unrecoverable, details} ->
          assert is_map(details)
          assert Map.has_key?(details, :attempted_fixes)
      end
    end
  end
  
  # Helper functions
  defp compile_and_analyze(code) do
    compilation_result = case Code.compile_string(code) do
      modules when is_list(modules) ->
        %{compiles: true, modules: modules}
      {:error, errors} ->
        %{compiles: false, errors: errors}
    end
    
    quality_score = if compilation_result.compiles do
      QualityAnalyzer.calculate_score(code)
    else
      0.0
    end
    
    Map.merge(compilation_result, %{
      quality_score: quality_score,
      has_fallback: String.contains?(code, "# Fallback")
    })
  end
end