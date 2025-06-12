defmodule AgiFactoryIntegrationTest do
  use ExUnit.Case, async: false
  
  alias AgiFactory.Core.{Orchestrator, QualityGate}
  alias AgiFactory.Domain.{DslProject, GenerationRequest}
  
  describe "Real Ash integration" do
    test "generates and compiles actual Ash resources" do
      project_attrs = %{
        name: "UserManagement",
        requirements: "Create user authentication with roles",
        framework: "ash"
      }
      
      # Test actual resource generation
      {:ok, project} = DslProject.create(project_attrs)
      {:ok, request} = GenerationRequest.create(%{
        dsl_project_id: project.id,
        strategy_type: :template,
        parameters: %{entities: ["User", "Role"]}
      })
      
      {:ok, result} = Orchestrator.execute_generation(request)
      
      # Verify generated code compiles
      assert {:ok, _compiled} = Code.compile_string(result.generated_code)
      
      # Verify Ash resource validity
      compiled_module = Module.concat(["Generated", "User"])
      assert function_exported?(compiled_module, :spark_dsl_config, 0)
      assert function_exported?(compiled_module, :spark_is, 1)
    end
    
    test "validates generated resources with Ash introspection" do
      code = """
      defmodule TestUser do
        use Ash.Resource,
          data_layer: Ash.DataLayer.Ets
          
        attributes do
          uuid_primary_key :id
          attribute :name, :string, allow_nil?: false
          attribute :email, :string
        end
        
        actions do
          defaults [:create, :read, :update, :destroy]
        end
      end
      """
      
      # Compile and test
      [{module, _}] = Code.compile_string(code)
      
      # Test Ash introspection
      attributes = Ash.Resource.Info.attributes(module)
      actions = Ash.Resource.Info.actions(module)
      
      assert length(attributes) == 3
      assert length(actions) == 4
      
      # Verify primary key
      pk = Ash.Resource.Info.primary_key(module)
      assert pk == [:id]
    end
  end
  
  describe "Cross-service integration" do
    test "integrates with requirements parser service" do
      requirements = "Build an e-commerce platform with user auth and product catalog"
      
      # Mock external service call
      parsed_requirements = %{
        entities: ["User", "Product", "Order"],
        features: [:authentication, :catalog, :checkout],
        complexity: 7.5
      }
      
      {:ok, project} = DslProject.create(%{
        name: "ECommerce",
        requirements: requirements,
        parsed_requirements: parsed_requirements
      })
      
      # Test generation with parsed requirements
      {:ok, request} = GenerationRequest.create(%{
        dsl_project_id: project.id,
        strategy_type: :hybrid,
        parameters: parsed_requirements
      })
      
      {:ok, result} = Orchestrator.execute_generation(request)
      
      assert result.success
      assert String.contains?(result.generated_code, "User")
      assert String.contains?(result.generated_code, "Product")
    end
  end
  
  describe "Quality gates" do
    test "enforces code quality thresholds" do
      poor_code = "defmodule Bad do\n# No content\nend"
      good_code = """
      defmodule GoodResource do
        use Ash.Resource
        
        attributes do
          uuid_primary_key :id
          attribute :name, :string, allow_nil?: false
        end
        
        actions do
          defaults [:create, :read]
        end
        
        validations do
          validate present(:name)
        end
      end
      """
      
      poor_result = QualityGate.assess(poor_code)
      good_result = QualityGate.assess(good_code)
      
      assert poor_result.score < 0.5
      assert good_result.score > 0.8
      
      # Test quality gate enforcement
      assert QualityGate.meets_threshold?(good_result, 0.7)
      refute QualityGate.meets_threshold?(poor_result, 0.7)
    end
  end
  
  describe "Performance benchmarks" do
    test "measures actual generation performance" do
      project_attrs = %{
        name: "PerformanceTest",
        requirements: "Create 10 related entities with complex relationships"
      }
      
      {:ok, project} = DslProject.create(project_attrs)
      
      entities = for i <- 1..10, do: "Entity#{i}"
      
      {time_microseconds, {:ok, result}} = :timer.tc(fn ->
        GenerationRequest.create(%{
          dsl_project_id: project.id,
          strategy_type: :template,
          parameters: %{entities: entities}
        })
        |> elem(1)
        |> Orchestrator.execute_generation()
      end)
      
      time_ms = time_microseconds / 1000
      
      assert time_ms < 5000  # Should complete in under 5 seconds
      assert result.success
      assert String.length(result.generated_code) > 1000
    end
    
    test "handles concurrent generation requests" do
      tasks = for i <- 1..5 do
        Task.async(fn ->
          {:ok, project} = DslProject.create(%{
            name: "Concurrent#{i}",
            requirements: "Test concurrent generation"
          })
          
          {:ok, request} = GenerationRequest.create(%{
            dsl_project_id: project.id,
            strategy_type: :template,
            parameters: %{entities: ["Entity#{i}"]}
          })
          
          Orchestrator.execute_generation(request)
        end)
      end
      
      results = Task.await_many(tasks, 10_000)
      
      assert length(results) == 5
      assert Enum.all?(results, fn {:ok, result} -> result.success end)
    end
  end
end