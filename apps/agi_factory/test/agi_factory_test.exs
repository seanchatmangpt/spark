defmodule AgiFactoryTest do
  use ExUnit.Case, async: false
  use AgiFactory.DataCase

  import Mox
  setup :verify_on_exit!

  alias AgiFactory.{Repo, Resources.DslProject, Resources.GenerationRequest}
  alias AgiFactory.Workflows.DslGeneration

  describe "AgiFactory domain operations" do
    test "creates domain with proper resource configuration" do
      assert AgiFactory.__domain__()
      
      resources = AgiFactory.Info.resources()
      assert length(resources) == 4
      
      resource_names = Enum.map(resources, & &1.resource)
      assert AgiFactory.Resources.DslProject in resource_names
      assert AgiFactory.Resources.GenerationRequest in resource_names
      assert AgiFactory.Resources.QualityAssessment in resource_names
      assert AgiFactory.Resources.EvolutionCycle in resource_names
    end

    test "has proper authorization configuration" do
      config = AgiFactory.Info.authorization()
      assert config.authorize == :by_default
      refute config.require_actor?
    end

    test "validates all resources are accessible" do
      for resource <- AgiFactory.Info.resources() do
        assert Code.ensure_loaded?(resource.resource)
        assert function_exported?(resource.resource, :spark_dsl_config, 0)
      end
    end
  end

  describe "Repo configuration" do
    test "has correct OTP app configuration" do
      assert AgiFactory.Repo.__adapter__() == Ecto.Adapters.Postgres
    end

    test "has required extensions installed" do
      extensions = AgiFactory.Repo.installed_extensions()
      assert "uuid-ossp" in extensions
      assert "citext" in extensions
    end

    test "can connect to database" do
      assert {:ok, _} = Repo.query("SELECT 1")
    end
  end

  describe "DslProject resource operations" do
    test "creates project with valid attributes" do
      attrs = %{
        name: "Test Project",
        requirements: "Create a user authentication system with OAuth2 support",
        status: :draft
      }

      assert {:ok, project} = 
        DslProject
        |> Ash.Changeset.for_create(:create, attrs)
        |> AgiFactory.create()

      assert project.name == "Test Project"
      assert project.status == :draft
      assert project.metadata == %{}
      assert is_binary(project.id)
    end

    test "validates required attributes" do
      attrs = %{name: "Test"}

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        DslProject
        |> Ash.Changeset.for_create(:create, attrs)
        |> AgiFactory.create()

      assert Enum.any?(errors, fn error ->
        error.field == :requirements && error.message =~ "required"
      end)
    end

    test "generate_from_requirements action processes correctly" do
      RequirementsParserMock
      |> expect(:parse_requirements, fn requirements ->
        %{
          entities: ["User", "Session"],
          actions: ["login", "logout", "register"],
          complexity: 7.5
        }
      end)

      attrs = %{
        name: "Auth System",
        requirements: "Build OAuth2 authentication with user management"
      }

      assert {:ok, project} =
        DslProject
        |> Ash.Changeset.for_create(:generate_from_requirements, attrs)
        |> AgiFactory.create()

      assert project.status == :generating
      assert project.specification != nil
    end

    test "complete_generation updates project correctly" do
      project = create_test_project(%{status: :generating})

      update_attrs = %{
        generated_code: "defmodule MyAuth do\n  # Generated code\nend",
        quality_score: Decimal.new("85.5")
      }

      assert {:ok, updated_project} =
        project
        |> Ash.Changeset.for_update(:complete_generation, update_attrs)
        |> AgiFactory.update()

      assert updated_project.status == :testing
      assert updated_project.generated_code == update_attrs.generated_code
      assert Decimal.equal?(updated_project.quality_score, update_attrs.quality_score)
    end

    test "calculates health_score correctly" do
      project = create_test_project(%{
        status: :deployed,
        quality_score: Decimal.new("90"),
        metadata: %{test_coverage: 95, performance_score: 88}
      })

      assert {:ok, [project_with_calc]} =
        DslProject
        |> Ash.Query.load(:health_score)
        |> Ash.Query.filter(id == ^project.id)
        |> AgiFactory.read()

      assert Decimal.gt?(project_with_calc.health_score, Decimal.new("80"))
    end

    test "calculates evolution_potential accurately" do
      project = create_test_project(%{
        status: :deployed,
        metadata: %{
          usage_patterns: [%{frequency: "high", complexity: "medium"}],
          user_feedback: %{satisfaction: 8.5, improvement_requests: 3}
        }
      })

      assert {:ok, [project_with_calc]} =
        DslProject
        |> Ash.Query.load(:evolution_potential)
        |> Ash.Query.filter(id == ^project.id)
        |> AgiFactory.read()

      assert Decimal.gte?(project_with_calc.evolution_potential, Decimal.new("0"))
      assert Decimal.lte?(project_with_calc.evolution_potential, Decimal.new("100"))
    end

    test "handles invalid status transitions" do
      project = create_test_project(%{status: :failed})

      attrs = %{status: :deployed}

      assert {:error, %Ash.Error.Invalid{}} =
        project
        |> Ash.Changeset.for_update(:update, attrs)
        |> AgiFactory.update()
    end
  end

  describe "GenerationRequest resource operations" do
    test "creates generation request with proper defaults" do
      project = create_test_project()

      attrs = %{
        strategy_type: :template,
        parameters: %{template_id: "auth_basic"},
        priority: 2
      }

      assert {:ok, request} =
        GenerationRequest
        |> Ash.Changeset.for_create(:queue_generation, attrs)
        |> Ash.Changeset.set_argument(:dsl_project_id, project.id)
        |> AgiFactory.create()

      assert request.strategy_type == :template
      assert request.status == :pending
      assert request.priority == 2
      assert request.dsl_project_id == project.id
    end

    test "processes generation request lifecycle" do
      project = create_test_project()
      request = create_generation_request(project)

      # Start processing
      assert {:ok, processing_request} =
        request
        |> Ash.Changeset.for_update(:start_processing)
        |> AgiFactory.update()

      assert processing_request.status == :processing
      assert processing_request.started_at != nil

      # Complete processing
      result = %{
        generated_dsl: "user { name :string }",
        strategy_used: :template,
        confidence: 0.95
      }

      assert {:ok, completed_request} =
        processing_request
        |> Ash.Changeset.for_update(:complete_processing, %{result: result})
        |> AgiFactory.update()

      assert completed_request.status == :completed
      assert completed_request.result == result
      assert completed_request.completed_at != nil
    end

    test "marks request as failed with error message" do
      project = create_test_project()
      request = create_generation_request(project, %{status: :processing})

      error_message = "Template not found for strategy: :advanced_ml"

      assert {:ok, failed_request} =
        request
        |> Ash.Changeset.for_update(:mark_failed, %{error_message: error_message})
        |> AgiFactory.update()

      assert failed_request.status == :failed
      assert failed_request.error_message == error_message
      assert failed_request.completed_at != nil
    end

    test "calculates request duration correctly" do
      project = create_test_project()
      
      started_at = DateTime.utc_now() |> DateTime.add(-300, :second)
      completed_at = DateTime.utc_now()

      request = create_generation_request(project, %{
        status: :completed,
        started_at: started_at,
        completed_at: completed_at
      })

      assert {:ok, [request_with_calc]} =
        GenerationRequest
        |> Ash.Query.load(:duration)
        |> Ash.Query.filter(id == ^request.id)
        |> AgiFactory.read()

      assert request_with_calc.duration >= 295
      assert request_with_calc.duration <= 305
    end

    test "detects overdue requests" do
      project = create_test_project()
      
      old_started_at = DateTime.utc_now() |> DateTime.add(-900, :second) # 15 min ago

      request = create_generation_request(project, %{
        status: :processing,
        started_at: old_started_at
      })

      assert {:ok, [request_with_calc]} =
        GenerationRequest
        |> Ash.Query.load(:is_overdue)
        |> Ash.Query.filter(id == ^request.id)
        |> AgiFactory.read()

      assert request_with_calc.is_overdue == true
    end

    test "validates strategy_type constraints" do
      project = create_test_project()

      attrs = %{
        strategy_type: :invalid_strategy,
        parameters: %{}
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        GenerationRequest
        |> Ash.Changeset.for_create(:queue_generation, attrs)
        |> Ash.Changeset.set_argument(:dsl_project_id, project.id)
        |> AgiFactory.create()

      assert Enum.any?(errors, fn error ->
        error.field == :strategy_type && error.message =~ "one_of"
      end)
    end
  end

  describe "DslGeneration workflow" do
    setup do
      project = create_test_project(%{
        requirements: "Create user management system with authentication",
        status: :generating
      })

      options = %{
        strategy_count: 3,
        quality_criteria: %{min_score: 80, prefer_patterns: true},
        mode: :production
      }

      %{project: project, options: options}
    end

    test "executes complete workflow successfully", %{project: project, options: options} do
      # Mock all external service calls
      setup_workflow_mocks()

      input = %{
        dsl_project_id: project.id,
        options: options
      }

      assert {:ok, result} = Reactor.run(DslGeneration, input, %{}, async?: false)
      
      assert result.status == :completed
      assert result.generated_code != nil
      assert Decimal.gt?(result.quality_score, Decimal.new("80"))
    end

    test "handles requirements parsing failure gracefully", %{project: project, options: options} do
      RequirementsParserMock
      |> expect(:parse_project_requirements, fn _project ->
        {:error, "Invalid requirements format"}
      end)

      input = %{dsl_project_id: project.id, options: options}

      assert {:error, _reason} = Reactor.run(DslGeneration, input, %{}, async?: false)

      # Verify compensation was triggered
      updated_project = AgiFactory.get!(DslProject, project.id)
      assert updated_project.status == :failed
    end

    test "retries generation strategies on failure", %{project: project, options: options} do
      call_count = Agent.start_link(fn -> 0 end)

      DslSynthesizerMock
      |> expect(:generate_multiple_strategies, 3, fn _spec, _patterns, _count ->
        Agent.update(call_count, &(&1 + 1))
        current_count = Agent.get(call_count, & &1)
        
        if current_count < 3 do
          {:error, "Generation service temporarily unavailable"}
        else
          {:ok, [
            %{id: 1, strategy: :template, confidence: 0.9},
            %{id: 2, strategy: :pattern_based, confidence: 0.85}
          ]}
        end
      end)

      setup_other_workflow_mocks()

      input = %{dsl_project_id: project.id, options: options}

      assert {:ok, _result} = Reactor.run(DslGeneration, input, %{}, async?: false)
      
      # Verify it was retried 3 times
      assert Agent.get(call_count, & &1) == 3
    end

    test "runs async steps concurrently", %{project: project, options: options} do
      start_time = System.monotonic_time()
      
      # Mock services with delays to test concurrency
      RequirementsParserMock
      |> expect(:parse_project_requirements, fn _project ->
        Process.sleep(100)
        {:ok, %{entities: ["User"], complexity: 5}}
      end)

      UsageAnalyzerMock
      |> expect(:analyze_for_generation, fn _spec ->
        Process.sleep(100)
        {:ok, %{patterns: ["crud", "auth"], frequency: "high"}}
      end)

      setup_remaining_workflow_mocks()

      input = %{dsl_project_id: project.id, options: options}

      assert {:ok, _result} = Reactor.run(DslGeneration, input, %{}, async?: true)
      
      end_time = System.monotonic_time()
      duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)
      
      # Should complete in ~150ms if running concurrently, 200ms+ if sequential
      assert duration < 180
    end

    test "compensates properly on workflow failure", %{project: project} do
      # Force failure in final step
      setup_workflow_mocks_with_final_failure()

      input = %{dsl_project_id: project.id, options: %{}}

      assert {:error, _reason} = Reactor.run(DslGeneration, input, %{}, async?: false)

      # Verify all compensations ran
      updated_project = AgiFactory.get!(DslProject, project.id)
      assert updated_project.status == :failed
      
      # Verify artifacts were cleaned
      cleanup_artifacts = Agent.get(:cleanup_called, & &1)
      assert cleanup_artifacts == true
    end
  end

  describe "Integration with other umbrella apps" do
    test "successfully calls RequirementsParser service" do
      RequirementsParserMock
      |> expect(:parse_project_requirements, fn project ->
        assert project.requirements != nil
        {:ok, %{entities: ["User", "Session"], complexity: 6.5}}
      end)

      project = create_test_project(%{
        requirements: "User authentication with sessions"
      })

      input = %{dsl_project_id: project.id, options: %{}}

      # This should not fail on the requirements parsing step
      assert {:ok, _} = Reactor.run(DslGeneration, input, %{}, async?: false)
    end

    test "integrates with DslSynthesizer for code generation" do
      DslSynthesizerMock
      |> expect(:generate_multiple_strategies, fn spec, patterns, count ->
        assert spec != nil
        assert patterns != nil
        assert count > 0

        {:ok, [
          %{id: 1, strategy: :template, confidence: 0.92, code: "user { name :string }"},
          %{id: 2, strategy: :ai_assisted, confidence: 0.88, code: "user { name :string, email :string }"}
        ]}
      end)

      DslSynthesizerMock
      |> expect(:generate_final_code, fn strategy, mode ->
        assert strategy.confidence > 0.8
        assert mode == :production

        {:ok, "defmodule UserDsl do\n  user do\n    name :string\n  end\nend"}
      end)

      setup_other_workflow_mocks()

      project = create_test_project()
      input = %{dsl_project_id: project.id, options: %{mode: :production}}

      assert {:ok, result} = Reactor.run(DslGeneration, input, %{}, async?: false)
      assert result.generated_code =~ "defmodule UserDsl"
    end

    test "uses UsageAnalyzer for pattern detection" do
      UsageAnalyzerMock
      |> expect(:analyze_for_generation, fn specification ->
        assert specification.entities != nil

        {:ok, %{
          patterns: ["crud_operations", "authentication", "validation"],
          frequency: "very_high",
          suggested_optimizations: ["index_optimization", "caching"]
        }}
      end)

      setup_other_workflow_mocks()

      project = create_test_project()
      input = %{dsl_project_id: project.id, options: %{}}

      assert {:ok, _result} = Reactor.run(DslGeneration, input, %{}, async?: false)
    end
  end

  describe "Error handling and edge cases" do
    test "handles database connection failures gracefully" do
      # Simulate DB failure
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(AgiFactory.Repo)
      :ok = Ecto.Adapters.SQL.Sandbox.mode(AgiFactory.Repo, :manual)
      
      GenServer.stop(AgiFactory.Repo)

      attrs = %{name: "Test", requirements: "Test requirements"}

      assert {:error, _} =
        DslProject
        |> Ash.Changeset.for_create(:create, attrs)
        |> AgiFactory.create()

      # Restart repo for other tests
      start_supervised!(AgiFactory.Repo)
    end

    test "validates complex metadata structures" do
      complex_metadata = %{
        deployment: %{
          environment: "production",
          version: "1.0.0",
          features: ["auth", "crud", "validation"]
        },
        performance: %{
          response_time_ms: 45,
          throughput_rps: 1200,
          memory_usage_mb: 128
        },
        analytics: %{
          user_interactions: [
            %{action: "create_user", count: 1500, success_rate: 0.98},
            %{action: "login", count: 5000, success_rate: 0.995}
          ]
        }
      }

      project = create_test_project(%{metadata: complex_metadata})

      assert project.metadata["deployment"]["environment"] == "production"
      assert length(project.metadata["analytics"]["user_interactions"]) == 2
    end

    test "handles concurrent generation requests safely" do
      project = create_test_project()

      # Create multiple concurrent requests
      tasks = 
        1..5
        |> Enum.map(fn i ->
          Task.async(fn ->
            attrs = %{
              strategy_type: :template,
              parameters: %{template_id: "template_#{i}"},
              priority: i
            }

            GenerationRequest
            |> Ash.Changeset.for_create(:queue_generation, attrs)
            |> Ash.Changeset.set_argument(:dsl_project_id, project.id)
            |> AgiFactory.create()
          end)
        end)

      results = Task.await_many(tasks, 5000)

      # All should succeed
      assert Enum.all?(results, fn
        {:ok, _} -> true
        _ -> false
      end)

      # All should be linked to the same project
      created_requests = 
        GenerationRequest
        |> Ash.Query.filter(dsl_project_id == ^project.id)
        |> AgiFactory.read!()

      assert length(created_requests) == 5
    end
  end

  # Helper functions
  defp create_test_project(attrs \\ %{}) do
    default_attrs = %{
      name: "Test Project #{System.unique_integer()}",
      requirements: "Create a test DSL for demonstration purposes",
      status: :draft
    }

    attrs = Map.merge(default_attrs, attrs)

    DslProject
    |> Ash.Changeset.for_create(:create, attrs)
    |> AgiFactory.create!()
  end

  defp create_generation_request(project, attrs \\ %{}) do
    default_attrs = %{
      strategy_type: :template,
      parameters: %{template_id: "basic"},
      priority: 1
    }

    attrs = Map.merge(default_attrs, attrs)

    GenerationRequest
    |> Ash.Changeset.for_create(:queue_generation, attrs)
    |> Ash.Changeset.set_argument(:dsl_project_id, project.id)
    |> AgiFactory.create!()
  end

  defp setup_workflow_mocks do
    RequirementsParserMock
    |> expect(:parse_project_requirements, fn _project ->
      {:ok, %{
        entities: ["User", "Session", "Permission"],
        actions: ["authenticate", "authorize", "logout"],
        complexity: 8.2,
        estimated_effort: "medium"
      }}
    end)

    UsageAnalyzerMock
    |> expect(:analyze_for_generation, fn _spec ->
      {:ok, %{
        patterns: ["authentication", "crud_operations", "validation"],
        frequency: "high",
        performance_characteristics: %{avg_response_time: 50}
      }}
    end)

    DslSynthesizerMock
    |> expect(:generate_multiple_strategies, fn _spec, _patterns, _count ->
      {:ok, [
        %{id: 1, strategy: :template, confidence: 0.92, complexity: 7.8},
        %{id: 2, strategy: :pattern_based, confidence: 0.87, complexity: 8.1},
        %{id: 3, strategy: :ai_assisted, confidence: 0.95, complexity: 8.5}
      ]}
    end)

    DslSynthesizerMock
    |> expect(:generate_final_code, fn _strategy, _mode ->
      {:ok, """
      defmodule AuthenticationDsl do
        use Spark.Dsl

        user do
          name :string, required: true
          email :string, required: true
          password_hash :string
        end

        session do
          token :string, required: true
          expires_at :datetime
        end
      end
      """}
    end)

    setup_quality_mocks()
  end

  defp setup_other_workflow_mocks do
    RequirementsParserMock
    |> stub(:parse_project_requirements, fn _project ->
      {:ok, %{entities: ["User"], complexity: 5}}
    end)

    UsageAnalyzerMock
    |> stub(:analyze_for_generation, fn _spec ->
      {:ok, %{patterns: ["basic"], frequency: "medium"}}
    end)

    setup_quality_mocks()
  end

  defp setup_remaining_workflow_mocks do
    DslSynthesizerMock
    |> expect(:generate_multiple_strategies, fn _spec, _patterns, _count ->
      {:ok, [%{id: 1, strategy: :template, confidence: 0.9}]}
    end)

    DslSynthesizerMock
    |> expect(:generate_final_code, fn _strategy, _mode ->
      {:ok, "defmodule TestDsl do\nend"}
    end)

    setup_quality_mocks()
  end

  defp setup_quality_mocks do
    AgiFactoryQualityAssuranceMock
    |> stub(:evaluate_all, fn _strategies, _criteria ->
      {:ok, %{
        evaluations: [
          %{strategy_id: 1, score: 92.5, strengths: ["clean", "efficient"]},
          %{strategy_id: 2, score: 87.0, strengths: ["flexible"]},
          %{strategy_id: 3, score: 95.0, strengths: ["innovative", "scalable"]}
        ],
        best_score: 95.0,
        average_score: 91.5
      }}
    end)

    AgiFactorySelectionMock
    |> stub(:choose_best, fn _strategies, _evaluations ->
      {:ok, %{id: 3, strategy: :ai_assisted, confidence: 0.95, score: 95.0}}
    end)
  end

  defp setup_workflow_mocks_with_final_failure do
    setup_other_workflow_mocks()

    Agent.start_link(fn -> false end, name: :cleanup_called)

    DslSynthesizerMock
    |> expect(:generate_final_code, fn _strategy, _mode ->
      {:error, "Code generation service unavailable"}
    end)

    AgiFactoryCleanupMock
    |> expect(:remove_generation_artifacts, fn ->
      Agent.update(:cleanup_called, fn _ -> true end)
      :ok
    end)
  end
end