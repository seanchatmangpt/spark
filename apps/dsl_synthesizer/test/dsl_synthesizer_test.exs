defmodule DslSynthesizerTest do
  use ExUnit.Case, async: false
  use DslSynthesizer.DataCase

  import Mox
  setup :verify_on_exit!

  alias DslSynthesizer.{
    Repo,
    Resources.GenerationStrategy,
    Resources.CodeCandidate,
    Workflows.MultiStrategyGeneration
  }

  describe "DslSynthesizer domain operations" do
    test "creates domain with proper resource configuration" do
      assert DslSynthesizer.__domain__()
      
      resources = DslSynthesizer.Info.resources()
      assert length(resources) == 4
      
      resource_names = Enum.map(resources, & &1.resource)
      assert DslSynthesizer.Resources.GenerationStrategy in resource_names
      assert DslSynthesizer.Resources.CodeCandidate in resource_names
      assert DslSynthesizer.Resources.QualityMetrics in resource_names
      assert DslSynthesizer.Resources.TemplateEngine in resource_names
    end

    test "has proper authorization configuration" do
      config = DslSynthesizer.Info.authorization()
      assert config.authorize == :by_default
      refute config.require_actor?
    end

    test "validates all resources are accessible" do
      for resource <- DslSynthesizer.Info.resources() do
        assert Code.ensure_loaded?(resource.resource)
        assert function_exported?(resource.resource, :spark_dsl_config, 0)
      end
    end
  end

  describe "Repo configuration" do
    test "has correct OTP app configuration" do
      assert DslSynthesizer.Repo.__adapter__() == Ecto.Adapters.Postgres
    end

    test "has required extensions installed" do
      extensions = DslSynthesizer.Repo.installed_extensions()
      assert "uuid-ossp" in extensions
      assert "citext" in extensions
    end

    test "can connect to database" do
      assert {:ok, _} = Repo.query("SELECT 1")
    end
  end

  describe "GenerationStrategy resource operations" do
    test "creates strategy with valid attributes" do
      attrs = %{
        name: :template_auth,
        description: "Template-based authentication DSL generation",
        strategy_type: :template,
        configuration: %{
          template_path: "auth/basic",
          variables: ["user_model", "session_model"],
          customizations: %{security_level: "high"}
        },
        priority: 1
      }

      assert {:ok, strategy} = 
        GenerationStrategy
        |> Ash.Changeset.for_create(:create, attrs)
        |> DslSynthesizer.create()

      assert strategy.name == :template_auth
      assert strategy.strategy_type == :template
      assert strategy.active == true
      assert strategy.success_rate == 0.0
      assert strategy.version == "1.0.0"
      assert is_binary(strategy.id)
    end

    test "validates required name attribute" do
      attrs = %{strategy_type: :template}

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        GenerationStrategy
        |> Ash.Changeset.for_create(:create, attrs)
        |> DslSynthesizer.create()

      assert Enum.any?(errors, fn error ->
        error.field == :name && error.message =~ "required"
      end)
    end

    test "validates strategy_type constraints" do
      attrs = %{
        name: :test_strategy,
        strategy_type: :invalid_type
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        GenerationStrategy
        |> Ash.Changeset.for_create(:create, attrs)
        |> DslSynthesizer.create()

      assert Enum.any?(errors, fn error ->
        error.field == :strategy_type && error.message =~ "one_of"
      end)
    end

    test "validates success_rate constraints" do
      attrs = %{
        name: :test_strategy,
        strategy_type: :template,
        success_rate: Decimal.new("1.5")
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        GenerationStrategy
        |> Ash.Changeset.for_create(:create, attrs)
        |> DslSynthesizer.create()

      assert Enum.any?(errors, fn error ->
        error.field == :success_rate && error.message =~ "max"
      end)
    end

    test "generate_code action processes specification correctly" do
      setup_strategy_mocks()

      specification = %{
        entities: [
          %{name: "User", type: "model", fields: ["name", "email", "password_hash"]},
          %{name: "Session", type: "model", fields: ["token", "expires_at"]}
        ],
        features: [:authentication, :crud],
        complexity: "moderate"
      }

      patterns = [
        %{type: "auth_pattern", confidence: 0.9},
        %{type: "crud_pattern", confidence: 0.85}
      ]

      context = %{framework: "ash", database: "postgres"}

      attrs = %{
        name: :dynamic_auth,
        strategy_type: :ai_assisted,
        configuration: %{model_type: "gpt-4", temperature: 0.3}
      }

      assert {:ok, strategy} =
        GenerationStrategy
        |> Ash.Changeset.for_create(:generate_code, attrs)
        |> Ash.Changeset.set_argument(:specification, specification)
        |> Ash.Changeset.set_argument(:patterns, patterns)
        |> Ash.Changeset.set_argument(:context, context)
        |> DslSynthesizer.create()

      assert strategy.name == :dynamic_auth
      assert strategy.configuration["model_type"] == "gpt-4"
    end

    test "optimize_strategy updates configuration and metrics" do
      strategy = create_test_strategy()

      optimizations = %{
        configuration: %{
          template_caching: true,
          parallel_generation: true,
          optimization_level: "aggressive"
        },
        performance_metrics: %{
          avg_generation_time: 2.5,
          success_rate: 0.92,
          code_quality_score: 0.88
        }
      }

      assert {:ok, optimized_strategy} =
        strategy
        |> Ash.Changeset.for_update(:optimize_strategy, optimizations)
        |> DslSynthesizer.update()

      assert optimized_strategy.configuration["template_caching"] == true
      assert optimized_strategy.performance_metrics["success_rate"] == 0.92
    end

    test "activate and deactivate actions work correctly" do
      strategy = create_test_strategy(%{active: false})

      # Activate
      assert {:ok, activated_strategy} =
        strategy
        |> Ash.Changeset.for_update(:activate)
        |> DslSynthesizer.update()

      assert activated_strategy.active == true

      # Deactivate
      assert {:ok, deactivated_strategy} =
        activated_strategy
        |> Ash.Changeset.for_update(:deactivate)
        |> DslSynthesizer.update()

      assert deactivated_strategy.active == false
    end

    test "calculates efficiency_score correctly" do
      strategy = create_test_strategy(%{
        success_rate: Decimal.new("0.90"),
        performance_metrics: %{
          avg_generation_time: 1.5,
          memory_usage: 64,
          cpu_efficiency: 0.85
        }
      })

      assert {:ok, [strategy_with_calc]} =
        GenerationStrategy
        |> Ash.Query.load(:efficiency_score)
        |> Ash.Query.filter(id == ^strategy.id)
        |> DslSynthesizer.read()

      assert Decimal.gte?(strategy_with_calc.efficiency_score, Decimal.new("0.0"))
      assert Decimal.lte?(strategy_with_calc.efficiency_score, Decimal.new("1.0"))
      assert Decimal.gt?(strategy_with_calc.efficiency_score, Decimal.new("0.7"))
    end

    test "calculates recent_performance accurately" do
      strategy = create_test_strategy(%{
        performance_metrics: %{
          recent_runs: [
            %{timestamp: DateTime.utc_now(), success: true, duration: 1.2},
            %{timestamp: DateTime.utc_now(), success: true, duration: 1.8},
            %{timestamp: DateTime.utc_now(), success: false, duration: 3.5}
          ]
        }
      })

      assert {:ok, [strategy_with_calc]} =
        GenerationStrategy
        |> Ash.Query.load(:recent_performance)
        |> Ash.Query.filter(id == ^strategy.id)
        |> DslSynthesizer.read()

      assert Decimal.gte?(strategy_with_calc.recent_performance, Decimal.new("0.0"))
      assert Decimal.lte?(strategy_with_calc.recent_performance, Decimal.new("1.0"))
    end

    test "determines complexity_handling capability" do
      simple_strategy = create_test_strategy(%{
        configuration: %{max_entities: 5, max_relationships: 3}
      })

      complex_strategy = create_test_strategy(%{
        configuration: %{max_entities: 50, max_relationships: 100, ai_assistance: true}
      })

      assert {:ok, [simple_with_calc]} =
        GenerationStrategy
        |> Ash.Query.load(:complexity_handling)
        |> Ash.Query.filter(id == ^simple_strategy.id)
        |> DslSynthesizer.read()

      assert {:ok, [complex_with_calc]} =
        GenerationStrategy
        |> Ash.Query.load(:complexity_handling)
        |> Ash.Query.filter(id == ^complex_strategy.id)
        |> DslSynthesizer.read()

      assert simple_with_calc.complexity_handling in [:low, :medium]
      assert complex_with_calc.complexity_handling in [:high, :expert]
    end
  end

  describe "CodeCandidate resource operations" do
    test "creates code candidate with valid attributes" do
      strategy = create_test_strategy()

      attrs = %{
        generated_code: """
        defmodule UserAuth do
          use Ash.Resource

          attributes do
            uuid_primary_key :id
            attribute :email, :string, allow_nil?: false
            attribute :password_hash, :string
          end

          actions do
            defaults [:create, :read, :update, :destroy]
          end
        end
        """,
        language: :elixir,
        metadata: %{
          generation_time: 2.3,
          template_used: "ash_resource_basic",
          optimizations_applied: ["syntax_formatting", "validation_enhancement"]
        }
      }

      assert {:ok, candidate} =
        CodeCandidate
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.Changeset.manage_relationship(:generation_strategy, strategy, type: :replace)
        |> DslSynthesizer.create()

      assert candidate.generated_code =~ "defmodule UserAuth"
      assert candidate.language == :elixir
      assert candidate.generation_strategy_id == strategy.id
      assert candidate.test_results == %{}
      assert candidate.performance_metrics == %{}
      assert is_binary(candidate.id)
    end

    test "validates required generated_code attribute" do
      strategy = create_test_strategy()

      attrs = %{language: :elixir}

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        CodeCandidate
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.Changeset.manage_relationship(:generation_strategy, strategy, type: :replace)
        |> DslSynthesizer.create()

      assert Enum.any?(errors, fn error ->
        error.field == :generated_code && error.message =~ "required"
      end)
    end

    test "validates quality_score constraints" do
      strategy = create_test_strategy()

      attrs = %{
        generated_code: "defmodule Test do\nend",
        quality_score: Decimal.new("1.5")
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        CodeCandidate
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.Changeset.manage_relationship(:generation_strategy, strategy, type: :replace)
        |> DslSynthesizer.create()

      assert Enum.any?(errors, fn error ->
        error.field == :quality_score && error.message =~ "max"
      end)
    end

    test "generate_from_strategy action validates and compiles code" do
      setup_code_validation_mocks()
      
      strategy = create_test_strategy()

      specification = %{
        entities: [%{name: "User", type: "model"}],
        requirements: "Simple user model"
      }

      valid_code = """
      defmodule User do
        use Ash.Resource

        attributes do
          uuid_primary_key :id
          attribute :name, :string
        end
      end
      """

      attrs = %{
        generated_code: valid_code,
        language: :elixir,
        metadata: %{generation_method: "template"}
      }

      assert {:ok, candidate} =
        CodeCandidate
        |> Ash.Changeset.for_create(:generate_from_strategy, attrs)
        |> Ash.Changeset.set_argument(:strategy_id, strategy.id)
        |> Ash.Changeset.set_argument(:specification, specification)
        |> DslSynthesizer.create()

      assert candidate.syntax_valid == true
      assert candidate.compilation_status == :success
      assert candidate.quality_score != nil
    end

    test "handles compilation failures gracefully" do
      setup_code_validation_mocks_with_failure()
      
      strategy = create_test_strategy()

      specification = %{entities: [%{name: "Invalid"}]}

      invalid_code = """
      defmodule Invalid
        # Missing 'do' keyword
        use Ash.Resource
      """

      attrs = %{
        generated_code: invalid_code,
        language: :elixir
      }

      assert {:ok, candidate} =
        CodeCandidate
        |> Ash.Changeset.for_create(:generate_from_strategy, attrs)
        |> Ash.Changeset.set_argument(:strategy_id, strategy.id)
        |> Ash.Changeset.set_argument(:specification, specification)
        |> DslSynthesizer.create()

      assert candidate.syntax_valid == false
      assert candidate.compilation_status == :failed
      assert candidate.quality_score == Decimal.new("0.0")
    end

    test "run_tests action executes and updates test results" do
      strategy = create_test_strategy()
      candidate = create_test_candidate(strategy, %{
        generated_code: valid_ash_resource_code(),
        syntax_valid: true,
        compilation_status: :success
      })

      setup_test_execution_mocks()

      assert {:ok, tested_candidate} =
        candidate
        |> Ash.Changeset.for_update(:run_tests)
        |> DslSynthesizer.update()

      assert tested_candidate.test_results["total"] == 5
      assert tested_candidate.test_results["passed"] == 4
      assert tested_candidate.test_results["failed"] == 1
      assert tested_candidate.test_results["coverage"] == 0.85
    end

    test "calculates readiness_score comprehensively" do
      strategy = create_test_strategy()
      candidate = create_test_candidate(strategy, %{
        syntax_valid: true,
        compilation_status: :success,
        quality_score: Decimal.new("0.88"),
        test_results: %{
          total: 10,
          passed: 9,
          failed: 1,
          coverage: 0.92
        },
        performance_metrics: %{
          execution_time: 0.05,
          memory_usage: 12,
          complexity_score: 6.5
        }
      })

      assert {:ok, [candidate_with_calc]} =
        CodeCandidate
        |> Ash.Query.load(:readiness_score)
        |> Ash.Query.filter(id == ^candidate.id)
        |> DslSynthesizer.read()

      assert Decimal.gte?(candidate_with_calc.readiness_score, Decimal.new("0.0"))
      assert Decimal.lte?(candidate_with_calc.readiness_score, Decimal.new("1.0"))
      assert Decimal.gt?(candidate_with_calc.readiness_score, Decimal.new("0.8"))
    end
  end

  describe "MultiStrategyGeneration workflow" do
    setup do
      specification = %{
        entities: [
          %{name: "User", type: "model", fields: ["name", "email", "password_hash"]},
          %{name: "Session", type: "model", fields: ["token", "user_id", "expires_at"]},
          %{name: "Permission", type: "model", fields: ["name", "resource"]}
        ],
        features: [:authentication, :authorization, :crud],
        complexity: "high",
        requirements: "Enterprise authentication system with role-based access control"
      }

      %{specification: specification}
    end

    test "executes complete multi-strategy workflow successfully", %{specification: specification} do
      setup_workflow_mocks()

      input = %{
        specification: specification,
        strategy_count: 3,
        parallel_limit: 2
      }

      assert {:ok, result} = Reactor.run(MultiStrategyGeneration, input, %{}, async?: false)
      
      assert result.selected_strategy != nil
      assert result.evaluation_score > 0.8
      assert length(result.final_candidates) == 3
    end

    test "creates strategies concurrently with proper types", %{specification: specification} do
      setup_strategy_creation_mocks()

      input = %{specification: specification, strategy_count: 5}

      start_time = System.monotonic_time()
      assert {:ok, result} = Reactor.run(MultiStrategyGeneration, input, %{}, async?: true)
      end_time = System.monotonic_time()

      duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Should complete faster due to concurrent strategy creation
      assert duration < 1000

      # Verify all strategy types were created
      created_strategies = [
        result.template_strategy,
        result.pattern_strategy,
        result.ai_strategy,
        result.hybrid_strategy,
        result.example_strategy
      ]

      strategy_types = Enum.map(created_strategies, & &1.strategy_type)
      assert :template in strategy_types
      assert :pattern_based in strategy_types
      assert :ai_assisted in strategy_types
      assert :hybrid in strategy_types
      assert :example_driven in strategy_types
    end

    test "evaluates and selects optimal strategy", %{specification: specification} do
      setup_evaluation_mocks()

      input = %{specification: specification}

      assert {:ok, result} = Reactor.run(MultiStrategyGeneration, input, %{}, async?: false)

      # Should select AI-assisted strategy as best based on mocked scores
      assert result.selected_strategy.strategy_type == :ai_assisted
      assert result.selected_strategy.evaluation_score == 0.95
      assert result.selection_reason == "highest_overall_score"
    end

    test "handles strategy creation failures gracefully", %{specification: specification} do
      # Mock one strategy to fail, others to succeed
      DslSynthesizerMock
      |> expect(:create!, 5, fn resource, attrs ->
        case attrs.strategy_type do
          :template -> {:error, "Template service unavailable"}
          _ -> create_mock_strategy(attrs.strategy_type)
        end
      end)

      setup_evaluation_mocks()

      input = %{specification: specification}

      # Should still succeed with remaining strategies
      assert {:ok, result} = Reactor.run(MultiStrategyGeneration, input, %{}, async?: false)
      assert result.selected_strategy != nil
    end

    test "scales to large specifications efficiently", %{specification: _spec} do
      large_specification = %{
        entities: generate_large_entity_list(50),
        features: [:authentication, :authorization, :crud, :search, :analytics, :reporting, :notifications],
        complexity: "expert",
        requirements: "Large enterprise system with 50+ entities and complex relationships"
      }

      setup_scalability_mocks()

      input = %{specification: large_specification, strategy_count: 5}

      start_time = System.monotonic_time()
      assert {:ok, result} = Reactor.run(MultiStrategyGeneration, input, %{}, async?: false)
      end_time = System.monotonic_time()

      duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Should handle large specs within reasonable time
      assert duration < 5000
      assert result.selected_strategy != nil
      assert result.complexity_handled == "expert"
    end

    test "generates multiple final candidates with diversity", %{specification: specification} do
      setup_candidate_generation_mocks()

      input = %{specification: specification, strategy_count: 4}

      assert {:ok, result} = Reactor.run(MultiStrategyGeneration, input, %{}, async?: false)

      candidates = result.final_candidates
      assert length(candidates) == 4

      # Verify diversity in generated code
      code_variations = Enum.map(candidates, & &1.generated_code)
      unique_approaches = Enum.uniq_by(code_variations, fn code ->
        cond do
          String.contains?(code, "use GenServer") -> :genserver_approach
          String.contains?(code, "use Agent") -> :agent_approach
          String.contains?(code, "use Ash.Resource") -> :ash_approach
          true -> :custom_approach
        end
      end)

      assert length(unique_approaches) >= 2
    end
  end

  describe "Advanced DSL generation scenarios" do
    test "generates Phoenix LiveView DSL" do
      specification = %{
        entities: [
          %{name: "UserLive", type: "liveview", events: ["user_created", "user_updated"]},
          %{name: "UserForm", type: "component", props: ["user", "changeset"]}
        ],
        features: [:real_time, :forms, :validation],
        framework: "phoenix_live_view"
      }

      setup_phoenix_mocks()

      attrs = %{
        name: :phoenix_live_generation,
        strategy_type: :template,
        configuration: %{framework: "phoenix_live_view"}
      }

      assert {:ok, strategy} =
        GenerationStrategy
        |> Ash.Changeset.for_create(:generate_code, attrs)
        |> Ash.Changeset.set_argument(:specification, specification)
        |> DslSynthesizer.create()

      # Verify Phoenix LiveView specific generation
      assert strategy.configuration["framework"] == "phoenix_live_view"
    end

    test "generates Ash DSL with complex relationships" do
      specification = %{
        entities: [
          %{
            name: "User",
            type: "model",
            fields: ["name", "email"],
            relationships: [
              %{type: "has_many", target: "Post", name: "posts"},
              %{type: "belongs_to", target: "Organization", name: "organization"}
            ]
          },
          %{
            name: "Post",
            type: "model",
            fields: ["title", "content", "published"],
            relationships: [
              %{type: "belongs_to", target: "User", name: "author"}
            ]
          }
        ],
        features: [:crud, :validation, :authorization],
        framework: "ash"
      }

      setup_ash_mocks()

      input = %{specification: specification}

      assert {:ok, result} = Reactor.run(MultiStrategyGeneration, input, %{}, async?: false)

      final_code = hd(result.final_candidates).generated_code
      assert final_code =~ "has_many :posts"
      assert final_code =~ "belongs_to :organization"
      assert final_code =~ "belongs_to :author"
    end

    test "handles custom DSL patterns" do
      specification = %{
        entities: [
          %{name: "CustomWorkflow", type: "workflow", steps: ["validate", "process", "notify"]}
        ],
        features: [:custom_dsl, :workflow_engine],
        patterns: [
          %{name: "step_pattern", template: "step :{{name}} do\n  {{body}}\nend"}
        ]
      }

      setup_custom_dsl_mocks()

      attrs = %{
        name: :custom_workflow_generation,
        strategy_type: :pattern_based,
        configuration: %{custom_patterns: true}
      }

      assert {:ok, strategy} =
        GenerationStrategy
        |> Ash.Changeset.for_create(:generate_code, attrs)
        |> Ash.Changeset.set_argument(:specification, specification)
        |> DslSynthesizer.create()

      assert strategy.configuration["custom_patterns"] == true
    end
  end

  describe "Error handling and edge cases" do
    test "handles invalid code generation gracefully" do
      strategy = create_test_strategy()

      invalid_specification = %{
        entities: [%{invalid_field: "bad_data"}],
        malformed: true
      }

      attrs = %{
        generated_code: "invalid elixir syntax here",
        language: :elixir
      }

      # Should create candidate but mark as failed
      assert {:ok, candidate} =
        CodeCandidate
        |> Ash.Changeset.for_create(:generate_from_strategy, attrs)
        |> Ash.Changeset.set_argument(:strategy_id, strategy.id)
        |> Ash.Changeset.set_argument(:specification, invalid_specification)
        |> DslSynthesizer.create()

      assert candidate.syntax_valid == false
      assert candidate.compilation_status == :failed
    end

    test "handles database connection failures gracefully" do
      # Simulate DB failure
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(DslSynthesizer.Repo)
      :ok = Ecto.Adapters.SQL.Sandbox.mode(DslSynthesizer.Repo, :manual)
      
      GenServer.stop(DslSynthesizer.Repo)

      attrs = %{name: :test_strategy, strategy_type: :template}

      assert {:error, _} =
        GenerationStrategy
        |> Ash.Changeset.for_create(:create, attrs)
        |> DslSynthesizer.create()

      # Restart repo for other tests
      start_supervised!(DslSynthesizer.Repo)
    end

    test "handles concurrent strategy generation safely" do
      specification = %{entities: [%{name: "Test"}], features: [:basic]}

      tasks = 
        1..5
        |> Enum.map(fn i ->
          Task.async(fn ->
            attrs = %{
              name: :"concurrent_strategy_#{i}",
              strategy_type: :template,
              priority: i
            }

            GenerationStrategy
            |> Ash.Changeset.for_create(:generate_code, attrs)
            |> Ash.Changeset.set_argument(:specification, specification)
            |> DslSynthesizer.create()
          end)
        end)

      results = Task.await_many(tasks, 10000)

      # All should succeed
      assert Enum.all?(results, fn
        {:ok, _} -> true
        _ -> false
      end)

      # All should have unique names
      strategy_names = Enum.map(results, fn {:ok, strategy} -> strategy.name end)
      assert length(Enum.uniq(strategy_names)) == length(strategy_names)
    end

    test "handles memory pressure during large generation" do
      # Create a specification that would generate large amounts of code
      massive_specification = %{
        entities: generate_large_entity_list(100),
        features: [:crud, :validation, :authorization, :search, :analytics],
        complexity: "expert"
      }

      setup_memory_pressure_mocks()

      input = %{
        specification: massive_specification,
        strategy_count: 5,
        parallel_limit: 1  # Limit parallelism to reduce memory pressure
      }

      # Should handle gracefully without running out of memory
      assert {:ok, result} = Reactor.run(MultiStrategyGeneration, input, %{}, async?: false)
      assert result.selected_strategy != nil
    end
  end

  # Helper functions
  defp create_test_strategy(attrs \\ %{}) do
    default_attrs = %{
      name: :"test_strategy_#{System.unique_integer()}",
      description: "Test strategy for unit testing",
      strategy_type: :template,
      configuration: %{template_path: "test/basic"},
      priority: 1
    }

    attrs = Map.merge(default_attrs, attrs)

    GenerationStrategy
    |> Ash.Changeset.for_create(:create, attrs)
    |> DslSynthesizer.create!()
  end

  defp create_test_candidate(strategy, attrs \\ %{}) do
    default_attrs = %{
      generated_code: "defmodule Test do\nend",
      language: :elixir,
      syntax_valid: true,
      compilation_status: :success
    }

    attrs = Map.merge(default_attrs, attrs)

    CodeCandidate
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.Changeset.manage_relationship(:generation_strategy, strategy, type: :replace)
    |> DslSynthesizer.create!()
  end

  defp valid_ash_resource_code do
    """
    defmodule TestResource do
      use Ash.Resource

      attributes do
        uuid_primary_key :id
        attribute :name, :string, allow_nil?: false
        attribute :email, :string
      end

      actions do
        defaults [:create, :read, :update, :destroy]
      end

      validations do
        validate present(:name)
        validate present(:email)
      end
    end
    """
  end

  defp generate_large_entity_list(count) do
    1..count
    |> Enum.map(fn i ->
      %{
        name: "Entity#{i}",
        type: "model",
        fields: ["field1_#{i}", "field2_#{i}", "field3_#{i}"],
        relationships: [
          %{type: "has_many", target: "Entity#{i+1}", name: "related_#{i}"}
        ]
      }
    end)
  end

  defp create_mock_strategy(strategy_type) do
    %{
      id: Ash.UUID.generate(),
      name: :"mock_#{strategy_type}",
      strategy_type: strategy_type,
      configuration: %{},
      success_rate: 0.8
    }
  end

  # Mock setup functions
  defp setup_strategy_mocks do
    DslSynthesizerChangesMock
    |> stub(:validate_specification, fn changeset -> changeset end)
    |> stub(:apply_strategy, fn changeset -> changeset end)
    |> stub(:optimize_generated, fn changeset -> changeset end)
    |> stub(:validate_output, fn changeset -> changeset end)
  end

  defp setup_code_validation_mocks do
    DslSynthesizerChangesMock
    |> stub(:validate_syntax, fn changeset ->
      Ash.Changeset.change_attribute(changeset, :syntax_valid, true)
    end)
    |> stub(:compile_code, fn changeset ->
      Ash.Changeset.change_attribute(changeset, :compilation_status, :success)
    end)
    |> stub(:calculate_quality, fn changeset ->
      Ash.Changeset.change_attribute(changeset, :quality_score, Decimal.new("0.85"))
    end)
  end

  defp setup_code_validation_mocks_with_failure do
    DslSynthesizerChangesMock
    |> stub(:validate_syntax, fn changeset ->
      Ash.Changeset.change_attribute(changeset, :syntax_valid, false)
    end)
    |> stub(:compile_code, fn changeset ->
      Ash.Changeset.change_attribute(changeset, :compilation_status, :failed)
    end)
    |> stub(:calculate_quality, fn changeset ->
      Ash.Changeset.change_attribute(changeset, :quality_score, Decimal.new("0.0"))
    end)
  end

  defp setup_test_execution_mocks do
    DslSynthesizerChangesMock
    |> stub(:execute_tests, fn changeset ->
      test_results = %{
        total: 5,
        passed: 4,
        failed: 1,
        coverage: 0.85,
        duration: 0.15
      }
      Ash.Changeset.change_attribute(changeset, :test_results, test_results)
    end)
    |> stub(:update_test_results, fn changeset -> changeset end)
  end

  defp setup_workflow_mocks do
    DslSynthesizerMock
    |> stub(:create!, fn _resource, attrs ->
      create_mock_strategy(attrs.strategy_type)
    end)

    DslSynthesizerEvaluationMock
    |> stub(:compare_strategies, fn strategies ->
      {:ok, %{
        evaluations: Enum.map(strategies, fn strategy ->
          %{
            strategy_id: strategy.id,
            score: :rand.uniform() * 0.4 + 0.6,  # Random score between 0.6-1.0
            strengths: ["performance", "readability"],
            weaknesses: ["complexity"]
          }
        end),
        best_score: 0.95
      }}
    end)

    DslSynthesizerSelectionMock
    |> stub(:choose_optimal, fn evaluations ->
      best_eval = Enum.max_by(evaluations.evaluations, & &1.score)
      {:ok, %{
        strategy_type: :ai_assisted,
        evaluation_score: best_eval.score,
        selection_reason: "highest_overall_score"
      }}
    end)

    DslSynthesizerGenerationMock
    |> stub(:create_candidates, fn _strategy, count ->
      candidates = 1..count
      |> Enum.map(fn i ->
        %{
          id: Ash.UUID.generate(),
          generated_code: "defmodule Generated#{i} do\n  # Generated code\nend",
          quality_score: 0.8 + (i * 0.05),
          compilation_status: :success
        }
      end)

      {:ok, candidates}
    end)
  end

  defp setup_strategy_creation_mocks do
    setup_workflow_mocks()
  end

  defp setup_evaluation_mocks do
    setup_workflow_mocks()
  end

  defp setup_scalability_mocks do
    setup_workflow_mocks()

    DslSynthesizerMock
    |> stub(:create!, fn _resource, attrs ->
      strategy = create_mock_strategy(attrs.strategy_type)
      Map.put(strategy, :complexity_handled, "expert")
    end)
  end

  defp setup_candidate_generation_mocks do
    setup_workflow_mocks()

    DslSynthesizerGenerationMock
    |> stub(:create_candidates, fn _strategy, count ->
      candidates = [
        %{
          generated_code: "defmodule GenServerApproach do\n  use GenServer\nend",
          approach: :genserver_approach
        },
        %{
          generated_code: "defmodule AgentApproach do\n  use Agent\nend",
          approach: :agent_approach
        },
        %{
          generated_code: "defmodule AshApproach do\n  use Ash.Resource\nend",
          approach: :ash_approach
        },
        %{
          generated_code: "defmodule CustomApproach do\n  # Custom implementation\nend",
          approach: :custom_approach
        }
      ]
      |> Enum.take(count)

      {:ok, candidates}
    end)
  end

  defp setup_phoenix_mocks do
    setup_strategy_mocks()
  end

  defp setup_ash_mocks do
    setup_strategy_mocks()
  end

  defp setup_custom_dsl_mocks do
    setup_strategy_mocks()
  end

  defp setup_memory_pressure_mocks do
    DslSynthesizerMock
    |> stub(:create!, fn _resource, attrs ->
      # Simulate memory-conscious generation
      :timer.sleep(10)  # Small delay to simulate processing
      create_mock_strategy(attrs.strategy_type)
    end)

    DslSynthesizerEvaluationMock
    |> stub(:compare_strategies, fn _strategies ->
      {:ok, %{
        evaluations: [%{strategy_id: "test", score: 0.8}],
        best_score: 0.8,
        memory_usage: "within_limits"
      }}
    end)

    DslSynthesizerSelectionMock
    |> stub(:choose_optimal, fn _evaluations ->
      {:ok, %{strategy_type: :template, evaluation_score: 0.8}}
    end)

    DslSynthesizerGenerationMock
    |> stub(:create_candidates, fn _strategy, count ->
      # Generate smaller, simpler candidates to reduce memory usage
      candidates = 1..count
      |> Enum.map(fn i ->
        %{
          id: Ash.UUID.generate(),
          generated_code: "defmodule Simple#{i} do\nend",
          memory_efficient: true
        }
      end)

      {:ok, candidates}
    end)
  end
end