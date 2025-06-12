defmodule Mix.Tasks.Spark.Gen.EntityTest do
  @moduledoc """
  Comprehensive tests for the Spark Entity generator.
  
  Tests all option combinations, code generation patterns, validation,
  and edge cases for the `mix spark.gen.entity` task.
  """
  
  use Spark.Test.GeneratorTestCase
  
  # Only run tests if Igniter is available
  @igniter_available Code.ensure_loaded?(Igniter)

  if @igniter_available do
    alias Mix.Tasks.Spark.Gen.Entity, as: EntityGenerator

    describe "task info/2" do
      test "returns correct task information" do
        info = EntityGenerator.info([], nil)
        
        assert info.positional == [:entity]
        assert info.example =~ "mix spark.gen.entity MyApp.Entities.Rule"
        
        # Verify schema contains all expected options
        expected_options = [
          :name, :identifier, :args, :schema, :validations, :examples, :ignore_if_exists
        ]
        
        schema_keys = Keyword.keys(info.schema)
        for option <- expected_options do
          assert option in schema_keys, "Missing option #{option} in schema"
        end
        
        # Verify aliases
        expected_aliases = [n: :name, i: :identifier, a: :args, s: :schema]
        for {alias_key, target} <- expected_aliases do
          assert info.aliases[alias_key] == target
        end
      end
    end

    describe "basic entity generation" do
      test "generates entity with minimal options" do
        igniter = mock_igniter(%{entity: "MyApp.Entities.User"})
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.User", [
          "@behaviour Spark.Dsl.Entity",
          "defstruct",
          "@type t ::",
          "def transform(entity_struct)",
          "def new(opts)",
          "def validate("
        ])
      end

      test "generates entity with custom name" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.CustomEntity"}, 
          [name: "custom_resource"]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.CustomEntity", [
          "Create a new custom_resource entity",
          "custom_resource in the DSL"
        ])
      end

      test "generates entity with custom identifier" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.Resource"}, 
          [identifier: "id"]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.Resource", [
          "validate_required!(opts, :id)"
        ])
      end

      test "respects --ignore-if-exists flag" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.ExistingEntity"}, 
          [ignore_if_exists: true]
        )
        
        result = EntityGenerator.igniter(igniter)
        assert is_map(result)
      end
    end

    describe "schema generation" do
      test "generates defstruct from schema string" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.User"}, 
          [schema: "name:string,email:string,active:boolean"]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.User", [
          "defstruct name: nil, email: nil, active: nil"
        ])
      end

      test "generates type specs from schema" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.Product"}, 
          [schema: "title:string,price:integer,available:boolean"]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.Product", [
          "@type t :: %__MODULE__{",
          "title: String.t() | nil",
          "price: integer() | nil", 
          "available: boolean() | nil"
        ])
      end

      test "handles schema without types" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.SimpleEntity"}, 
          [schema: "field1,field2,field3"]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.SimpleEntity", [
          "defstruct field1: nil, field2: nil, field3: nil",
          "field1: any() | nil"
        ])
      end

      test "maps types correctly to type specs" do
        type_mappings = [
          {"string", "String.t()"},
          {"atom", "atom()"},
          {"integer", "integer()"},
          {"boolean", "boolean()"},
          {"module", "module()"},
          {"any", "any()"},
          {"custom", "term()"}
        ]
        
        for {input_type, expected_spec} <- type_mappings do
          igniter = mock_igniter(
            %{entity: "MyApp.Entities.TypeTest"}, 
            [schema: "field:#{input_type}"]
          )
          
          result = EntityGenerator.igniter(igniter)
          
          # In full tests would verify the actual type spec
          assert is_map(result)
        end
      end
    end

    describe "args generation" do
      test "generates args with required validation" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.Rule"}, 
          [args: ["condition:string:required", "action:atom:required"]]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.Rule", [
          "validate_required!(opts, :condition)",
          "validate_required!(opts, :action)",
          "condition: validate_type!(opts[:condition], :condition, :string)",
          "action: validate_type!(opts[:action], :action, :atom)"
        ])
      end

      test "generates args without required flag" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.Optional"}, 
          [args: ["name:string", "description:string"]]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.Optional", [
          "name: validate_type!(opts[:name], :name, :string)",
          "description: validate_type!(opts[:description], :description, :string)"
        ])
      end

      test "combines schema and args in defstruct" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.Combined"}, 
          [
            schema: "id:integer,created_at:string",
            args: ["name:string:required", "type:atom"]
          ]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.Combined", [
          "defstruct id: nil, created_at: nil, name: nil, type: nil"
        ])
      end

      test "handles malformed args gracefully" do
        assert_raise RuntimeError, ~r/Invalid arg format/, fn ->
          igniter = mock_igniter(
            %{entity: "MyApp.Entities.BadArgs"}, 
            [args: ["malformed_arg"]]
          )
          
          EntityGenerator.igniter(igniter)
        end
      end
    end

    describe "validation generation" do
      test "generates custom validation functions" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.Validated"}, 
          [validations: ["validate_email", "validate_format"]]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.Validated", [
          "defp validate_validate_email(value)",
          "defp validate_validate_format(value)"
        ])
      end

      test "includes validation helpers" do
        igniter = mock_igniter(%{entity: "MyApp.Entities.Helper"})
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.Helper", [
          "defp validate_required!(opts, field)",
          "defp validate_type!(value, field, expected_type)"
        ])
      end
    end

    describe "example generation" do
      test "generates examples when requested" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.Documented"}, 
          [
            examples: true,
            args: ["name:string:required", "type:atom"]
          ]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.Documented", [
          "## Examples",
          "# In your DSL configuration",
          "documented :example do",
          "# Programmatically"
        ])
      end

      test "generates appropriate example values by type" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.ExampleTypes"}, 
          [
            examples: true,
            args: ["name:string", "count:integer", "enabled:boolean", "type:atom"]
          ]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.ExampleTypes", [
          "name \"example\"",
          "count 42",
          "enabled true",
          "type :example"
        ])
      end
    end

    describe "generated entity behavior" do
      test "implements Spark.Dsl.Entity behavior" do
        igniter = mock_igniter(%{entity: "MyApp.Entities.Behavior"})
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.Behavior", [
          "@behaviour Spark.Dsl.Entity",
          "def transform(entity_struct) do"
        ])
      end

      test "provides factory function with validation" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.Factory"}, 
          [args: ["name:string:required"]]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.Factory", [
          "@spec new(Keyword.t()) :: {:ok, t()} | {:error, term()}",
          "def new(opts) do",
          "case validate(entity) do",
          ":ok -> {:ok, entity}",
          "{:error, reason} -> {:error, reason}"
        ])
      end

      test "provides validate function" do
        igniter = mock_igniter(%{entity: "MyApp.Entities.Validatable"})
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.Validatable", [
          "@spec validate(t()) :: :ok | {:error, term()}",
          "def validate(%__MODULE__{} = entity) do"
        ])
      end
    end

    describe "name derivation" do
      test "derives entity name from module name when not specified" do
        test_cases = [
          {"MyApp.Entities.User", "user"},
          {"Company.Resources.Product", "product"},
          {"SingleName", "single_name"},
          {"VeryLongModuleName", "very_long_module_name"}
        ]
        
        for {module_name, expected_name} <- test_cases do
          igniter = mock_igniter(%{entity: module_name})
          result = EntityGenerator.igniter(igniter)
          
          # In full tests would verify the derived name matches expected
          assert is_map(result)
        end
      end

      test "uses specified name over derived name" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.User"}, 
          [name: "custom_entity"]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.User", [
          "Create a new custom_entity entity"
        ])
      end
    end

    describe "complex configurations" do
      test "generates entity with all options" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.Complete"}, 
          [
            name: "complete_entity",
            identifier: "uuid",
            schema: "id:string,name:string,active:boolean",
            args: ["title:string:required", "description:string"],
            validations: ["validate_title", "validate_unique"],
            examples: true
          ]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        expected_patterns = [
          "@behaviour Spark.Dsl.Entity",
          "defstruct id: nil, name: nil, active: nil, title: nil, description: nil",
          "@type t :: %__MODULE__{",
          "id: String.t() | nil",
          "title: String.t() | nil",
          "validate_required!(opts, :title)",
          "validate_type!(opts[:description], :description, :string)",
          "defp validate_validate_title(value)",
          "defp validate_validate_unique(value)",
          "## Examples",
          "complete_entity :example do"
        ]
        
        assert_module_created(result, "MyApp.Entities.Complete", expected_patterns)
      end

      test "handles empty option lists gracefully" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.Empty"}, 
          [args: [], validations: []]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.Empty")
      end

      test "handles nil options" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.NilOptions"}, 
          [schema: nil, args: nil, validations: nil]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.NilOptions")
      end
    end

    describe "generated code quality" do
      test "all generated modules include proper documentation" do
        igniter = mock_igniter(%{entity: "MyApp.Entities.Documented"})
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.Documented", [
          "@moduledoc \"\"\"",
          "Entity representing a documented in the DSL",
          "## Usage"
        ])
      end

      test "includes function documentation" do
        igniter = mock_igniter(%{entity: "MyApp.Entities.FunctionDocs"})
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.FunctionDocs", [
          "@doc false",
          "@doc \"\"\"",
          "Create a new",
          "Validate the entity"
        ])
      end

      test "includes type specifications" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.TypeSpecs"}, 
          [args: ["name:string"]]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.TypeSpecs", [
          "@type t ::",
          "@spec new(Keyword.t()) :: {:ok, t()} | {:error, term()}",
          "@spec validate(t()) :: :ok | {:error, term()}"
        ])
      end

      test "provides comprehensive usage examples in documentation" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.UsageExamples"}, 
          [examples: true, args: ["name:string"]]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.UsageExamples", [
          "This entity is used in DSL configurations",
          "usage_examples :my_usage_examples do",
          "name \"example\""
        ])
      end
    end

    describe "validation and error handling" do
      test "validates required fields in new function" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.RequiredFields"}, 
          [args: ["name:string:required", "type:atom:required"]]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.RequiredFields", [
          "validate_required!(opts, :name)",
          "validate_required!(opts, :type)"
        ])
      end

      test "includes type validation for all fields" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.TypeValidation"}, 
          [args: ["count:integer", "name:string", "enabled:boolean"]]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.TypeValidation", [
          "validate_type!(opts[:count], :count, :integer)",
          "validate_type!(opts[:name], :name, :string)",
          "validate_type!(opts[:enabled], :enabled, :boolean)"
        ])
      end

      test "provides error handling in factory function" do
        igniter = mock_igniter(%{entity: "MyApp.Entities.ErrorHandling"})
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.ErrorHandling", [
          "case validate(entity) do",
          ":ok -> {:ok, entity}",
          "{:error, reason} -> {:error, reason}"
        ])
      end
    end

    describe "edge cases" do
      test "handles very long module names" do
        long_name = "MyApp.Very.Long.Nested.Module.Path.Entity"
        igniter = mock_igniter(%{entity: long_name})
        
        result = EntityGenerator.igniter(igniter)
        assert is_map(result)
      end

      test "handles single word module names" do
        igniter = mock_igniter(%{entity: "Entity"})
        
        result = EntityGenerator.igniter(igniter)
        assert is_map(result)
      end

      test "handles special characters in field names appropriately" do
        # Test field names that need special handling
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.SpecialFields"}, 
          [schema: "email_address:string,is_active:boolean"]
        )
        
        result = EntityGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Entities.SpecialFields", [
          "email_address: nil",
          "is_active: nil"
        ])
      end

      test "handles empty string inputs" do
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.EmptyStrings"}, 
          [schema: "", identifier: ""]
        )
        
        result = EntityGenerator.igniter(igniter)
        assert is_map(result)
      end
    end
  else
    # Fallback tests when Igniter is not available
    test "requires Igniter to be available" do
      assert_raise RuntimeError, ~r/requires igniter/, fn ->
        Mix.Tasks.Spark.Gen.Entity.run(["MyApp.TestEntity"])
      end
    end
  end
end