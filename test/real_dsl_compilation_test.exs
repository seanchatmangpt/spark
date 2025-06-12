defmodule RealDslCompilationTest do
  use ExUnit.Case, async: false
  
  @moduledoc """
  Zach Daniel: REAL Spark DSL compilation testing with actual transformers,
  verifiers, and macro expansion. This tests the actual DSL compilation pipeline.
  """
  
  # Zach: Real Spark DSL definition for testing
  defmodule TestDsl do
    @moduledoc """
    A real Spark DSL that tests actual compilation, transformation, and verification.
    """
    
    use Spark.Dsl,
      default_extensions: [
        extensions: [TestDsl.Extension]
      ]
    
    defmodule Extension do
      use Spark.Dsl.Extension,
        sections: [TestDsl.Dsl],
        transformers: [TestDsl.Transformers.AddDefaultActions],
        verifiers: [TestDsl.Verifiers.ValidateActions]
    end
    
    defmodule Dsl do
      use Spark.Dsl.Section,
        name: :test_dsl,
        top_level?: true,
        schema: [
          name: [type: :string, required: true, doc: "The name of the test resource"],
          description: [type: :string, doc: "Description of the resource"]
        ]
      
      defmodule Actions do
        use Spark.Dsl.Section,
          name: :actions,
          entities: [Actions.Action],
          top_level?: false
        
        defmodule Action do
          use Spark.Dsl.Entity,
            name: :action,
            target: TestDsl.Action,
            args: [:name],
            schema: [
              name: [type: :atom, required: true],
              type: [type: {:one_of, [:create, :read, :update, :delete]}, required: true],
              enabled: [type: :boolean, default: true],
              timeout: [type: :pos_integer, default: 5000]
            ]
        end
      end
      
      defmodule Attributes do
        use Spark.Dsl.Section,
          name: :attributes,
          entities: [Attributes.Attribute],
          top_level?: false
        
        defmodule Attribute do
          use Spark.Dsl.Entity,
            name: :attribute,
            target: TestDsl.Attribute,
            args: [:name, :type],
            schema: [
              name: [type: :atom, required: true],
              type: [type: {:one_of, [:string, :integer, :boolean, :map]}, required: true],
              required: [type: :boolean, default: false],
              default: [type: :any]
            ]
        end
      end
      
      use Spark.Dsl.Section,
        name: :test_dsl,
        sections: [Actions, Attributes],
        top_level?: true
    end
    
    # Zach: Real Spark transformer that modifies the DSL at compile time
    defmodule Transformers.AddDefaultActions do
      use Spark.Dsl.Transformer
      
      def transform(dsl_state) do
        # Get existing actions
        existing_actions = Spark.Dsl.Extension.get_entities(dsl_state, [:test_dsl, :actions])
        action_names = Enum.map(existing_actions, & &1.name)
        
        # Add default CRUD actions if they don't exist
        default_actions = [
          %TestDsl.Action{name: :create, type: :create, enabled: true, timeout: 5000},
          %TestDsl.Action{name: :read, type: :read, enabled: true, timeout: 3000},
          %TestDsl.Action{name: :update, type: :update, enabled: true, timeout: 5000},
          %TestDsl.Action{name: :delete, type: :delete, enabled: true, timeout: 5000}
        ]
        
        new_actions = Enum.reject(default_actions, fn action ->
          action.name in action_names
        end)
        
        # Add new actions to DSL state
        Enum.reduce(new_actions, {:ok, dsl_state}, fn action, {:ok, state} ->
          Spark.Dsl.Extension.add_entity(state, [:test_dsl, :actions], action)
        end)
      end
    end
    
    # Zach: Real Spark verifier that validates the compiled DSL
    defmodule Verifiers.ValidateActions do
      use Spark.Dsl.Verifier
      
      def verify(dsl_state) do
        actions = Spark.Dsl.Extension.get_entities(dsl_state, [:test_dsl, :actions])
        attributes = Spark.Dsl.Extension.get_entities(dsl_state, [:test_dsl, :attributes])
        
        errors = []
        
        # Verify each action has required attributes for its type
        errors = Enum.reduce(actions, errors, fn action, acc ->
          case validate_action_requirements(action, attributes) do
            :ok -> acc
            {:error, error} -> [error | acc]
          end
        end)
        
        # Verify no duplicate action names
        action_names = Enum.map(actions, & &1.name)
        duplicate_names = action_names -- Enum.uniq(action_names)
        
        errors = if length(duplicate_names) > 0 do
          [{:error, "Duplicate action names: #{inspect(duplicate_names)}"} | errors]
        else
          errors
        end
        
        case errors do
          [] -> :ok
          _ -> {:error, errors}
        end
      end
      
      defp validate_action_requirements(action, attributes) do
        case action.type do
          :create ->
            # Create actions need at least one attribute
            if length(attributes) > 0 do
              :ok
            else
              {:error, "Create action #{action.name} requires at least one attribute"}
            end
          
          :update ->
            # Update actions need an identifier attribute
            has_id = Enum.any?(attributes, fn attr ->
              attr.name in [:id, :uuid, :primary_key]
            end)
            
            if has_id do
              :ok
            else
              {:error, "Update action #{action.name} requires an identifier attribute"}
            end
          
          _ -> :ok
        end
      end
    end
  end
  
  # Zach: Data structures for compiled DSL entities
  defmodule Action do
    defstruct [:name, :type, :enabled, :timeout]
  end
  
  defmodule Attribute do
    defstruct [:name, :type, :required, :default]
  end
  
  # Zach: Test resource using the real DSL
  defmodule TestResource do
    use TestDsl
    
    test_dsl do
      name "TestResource"
      description "A test resource for DSL compilation testing"
    end
    
    attributes do
      attribute :id, :integer
      attribute :name, :string, required: true
      attribute :email, :string
      attribute :metadata, :map
    end
    
    actions do
      action :custom_action, :create, timeout: 10_000
      action :special_read, :read, enabled: false
    end
  end
  
  defmodule MinimalResource do
    use TestDsl
    
    test_dsl do
      name "MinimalResource"
    end
    
    # No explicit actions - should get defaults from transformer
  end
  
  defmodule InvalidResource do
    # This will be used to test verifier errors
    defmacro define_invalid do
      quote do
        use TestDsl
        
        test_dsl do
          name "InvalidResource"
        end
        
        actions do
          action :update_without_id, :update
          action :duplicate, :create
          action :duplicate, :read  # Duplicate name should cause error
        end
        # No attributes - update action should fail verification
      end
    end
  end
  
  describe "Real Spark DSL Compilation" do
    test "DSL compiles successfully with proper introspection functions" do
      # Zach: Verify the DSL actually compiled and created the expected functions
      assert function_exported?(TestResource, :spark_dsl_config, 0)
      assert function_exported?(TestResource, :spark_is, 1)
      
      # Test the introspection functions work
      dsl_config = TestResource.spark_dsl_config()
      assert is_map(dsl_config)
      
      assert TestResource.spark_is(:test_dsl)
      refute TestResource.spark_is(:other_dsl)
    end
    
    test "transformers add default actions during compilation" do
      # Zach: Test that the transformer actually ran and added default actions
      {:ok, dsl_state} = Spark.Dsl.Extension.prepare(TestResource)
      actions = Spark.Dsl.Extension.get_entities(dsl_state, [:test_dsl, :actions])
      
      action_names = Enum.map(actions, & &1.name)
      
      # Should have both explicit actions and default ones added by transformer
      assert :custom_action in action_names
      assert :special_read in action_names
      assert :create in action_names  # Added by transformer
      assert :read in action_names    # Added by transformer  
      assert :update in action_names  # Added by transformer
      assert :delete in action_names  # Added by transformer
      
      # Verify transformer preserved explicit action properties
      custom_action = Enum.find(actions, &(&1.name == :custom_action))
      assert custom_action.type == :create
      assert custom_action.timeout == 10_000
      
      special_read = Enum.find(actions, &(&1.name == :special_read))
      assert special_read.enabled == false
    end
    
    test "transformers work on minimal DSL definitions" do
      # Zach: Test transformer adds defaults even when no actions are explicitly defined
      {:ok, dsl_state} = Spark.Dsl.Extension.prepare(MinimalResource)
      actions = Spark.Dsl.Extension.get_entities(dsl_state, [:test_dsl, :actions])
      
      action_names = Enum.map(actions, & &1.name)
      
      # Should have all default actions
      assert :create in action_names
      assert :read in action_names
      assert :update in action_names
      assert :delete in action_names
      assert length(actions) == 4
      
      # All should have default properties
      for action <- actions do
        assert action.enabled == true
        assert action.timeout in [3000, 5000]  # Different defaults for read vs others
      end
    end
    
    test "verifiers catch DSL validation errors during compilation" do
      # Zach: Test that verifiers actually run and catch errors
      assert_raise Spark.Error.DslError, fn ->
        Code.eval_quoted(InvalidResource.define_invalid())
      end
    end
    
    test "attributes are properly parsed and stored" do
      {:ok, dsl_state} = Spark.Dsl.Extension.prepare(TestResource)
      attributes = Spark.Dsl.Extension.get_entities(dsl_state, [:test_dsl, :attributes])
      
      assert length(attributes) == 4
      
      # Check specific attributes
      id_attr = Enum.find(attributes, &(&1.name == :id))
      assert id_attr.type == :integer
      assert id_attr.required == false
      
      name_attr = Enum.find(attributes, &(&1.name == :name))
      assert name_attr.type == :string
      assert name_attr.required == true
      
      email_attr = Enum.find(attributes, &(&1.name == :email))
      assert email_attr.type == :string
      assert email_attr.required == false
      
      metadata_attr = Enum.find(attributes, &(&1.name == :metadata))
      assert metadata_attr.type == :map
    end
    
    test "DSL configuration is accessible at runtime" do
      # Zach: Test that compiled DSL state is available for introspection
      {:ok, dsl_state} = Spark.Dsl.Extension.prepare(TestResource)
      
      # Test getting top-level configuration
      config = Spark.Dsl.Extension.get_opt(dsl_state, [:test_dsl], :name)
      assert config == "TestResource"
      
      description = Spark.Dsl.Extension.get_opt(dsl_state, [:test_dsl], :description)
      assert description == "A test resource for DSL compilation testing"
      
      # Test getting entities
      actions = Spark.Dsl.Extension.get_entities(dsl_state, [:test_dsl, :actions])
      attributes = Spark.Dsl.Extension.get_entities(dsl_state, [:test_dsl, :attributes])
      
      assert is_list(actions)
      assert is_list(attributes)
      assert length(actions) >= 4  # At least the 4 defaults
      assert length(attributes) == 4
    end
  end
  
  describe "Real DSL Compilation Performance" do
    test "compilation is fast enough for development workflow" do
      # Zach: Test that DSL compilation performance is acceptable
      
      compilation_time = :timer.tc(fn ->
        # Compile multiple resources to test performance
        for i <- 1..10 do
          module_name = String.to_atom("DynamicTestResource#{i}")
          
          # Create module dynamically
          ast = quote do
            defmodule unquote(module_name) do
              use TestDsl
              
              test_dsl do
                name unquote("Resource#{i}")
                description unquote("Dynamic resource #{i}")
              end
              
              attributes do
                attribute :id, :integer
                attribute :name, :string, required: true
                attribute unquote(String.to_atom("field#{i}")), :string
              end
              
              actions do
                action unquote(String.to_atom("custom#{i}")), :create
              end
            end
          end
          
          Code.eval_quoted(ast)
        end
      end)
      
      time_ms = elem(compilation_time, 0) / 1000
      
      # Should compile 10 resources in less than 1 second
      assert time_ms < 1000
    end
    
    test "compiled DSL state access is efficient" do
      # Zach: Test that runtime DSL introspection is fast
      {:ok, dsl_state} = Spark.Dsl.Extension.prepare(TestResource)
      
      access_time = :timer.tc(fn ->
        # Access DSL state many times
        for _i <- 1..1000 do
          _actions = Spark.Dsl.Extension.get_entities(dsl_state, [:test_dsl, :actions])
          _attributes = Spark.Dsl.Extension.get_entities(dsl_state, [:test_dsl, :attributes])
          _name = Spark.Dsl.Extension.get_opt(dsl_state, [:test_dsl], :name)
        end
      end)
      
      time_ms = elem(access_time, 0) / 1000
      
      # 1000 accesses should take less than 100ms
      assert time_ms < 100
    end
    
    test "memory usage is reasonable for large DSL definitions" do
      initial_memory = :erlang.memory(:total)
      
      # Create many DSL resources to test memory usage
      modules = for i <- 1..100 do
        module_name = String.to_atom("MemoryTestResource#{i}")
        
        ast = quote do
          defmodule unquote(module_name) do
            use TestDsl
            
            test_dsl do
              name unquote("MemoryResource#{i}")
            end
            
            attributes do
              attribute :id, :integer
              attribute :name, :string
              # Add many attributes to increase memory usage
              unquote_splicing(
                for j <- 1..20 do
                  attr_name = String.to_atom("attr#{j}")
                  quote do
                    attribute unquote(attr_name), :string
                  end
                end
              )
            end
          end
        end
        
        Code.eval_quoted(ast)
        module_name
      end
      
      final_memory = :erlang.memory(:total)
      memory_increase = final_memory - initial_memory
      
      # 100 DSL resources with 22 attributes each should use less than 20MB
      assert memory_increase < 20_000_000
      
      # Cleanup
      for module <- modules do
        :code.purge(module)
        :code.delete(module)
      end
    end
  end
  
  describe "Real DSL Error Handling" do
    test "compilation errors provide useful feedback" do
      # Zach: Test that DSL compilation errors are helpful for developers
      
      invalid_ast = quote do
        defmodule InvalidSyntaxResource do
          use TestDsl
          
          test_dsl do
            name 123  # Should be string, not integer
          end
        end
      end
      
      assert_raise Spark.Error.DslError, fn ->
        Code.eval_quoted(invalid_ast)
      end
    end
    
    test "verifier errors include context information" do
      # Zach: Test that verifier errors provide enough context for debugging
      
      invalid_update_ast = quote do
        defmodule InvalidUpdateResource do
          use TestDsl
          
          test_dsl do
            name "InvalidUpdate"
          end
          
          actions do
            action :update_no_id, :update
          end
          # No attributes, so update action should fail verification
        end
      end
      
      try do
        Code.eval_quoted(invalid_update_ast)
        flunk("Expected compilation to fail")
      rescue
        error in Spark.Error.DslError ->
          error_message = Exception.message(error)
          assert String.contains?(error_message, "update_no_id")
          assert String.contains?(error_message, "identifier")
      end
    end
  end
end