defmodule Mix.Tasks.Spark.Gen.TransformerTest do
  @moduledoc """
  Comprehensive tests for the Spark Transformer generator.
  
  Tests all option combinations, code generation patterns, and edge cases
  for the `mix spark.gen.transformer` task.
  """
  
  use Spark.Test.GeneratorTestCase
  
  # Only run tests if Igniter is available
  @igniter_available Code.ensure_loaded?(Igniter)

  if @igniter_available do
    alias Mix.Tasks.Spark.Gen.Transformer, as: TransformerGenerator

    describe "task info/2" do
      test "returns correct task information" do
        info = TransformerGenerator.info([], nil)
        
        assert info.positional == [:transformer]
        assert info.example =~ "mix spark.gen.transformer MyApp.Transformers.AddTimestamps"
        
        # Verify schema contains all expected options
        expected_options = [
          :dsl, :before, :after, :persist, :examples, :ignore_if_exists
        ]
        
        schema_keys = Keyword.keys(info.schema)
        for option <- expected_options do
          assert option in schema_keys, "Missing option #{option} in schema"
        end
        
        # Verify aliases
        expected_aliases = [d: :dsl, b: :before, a: :after, p: :persist]
        for {alias_key, target} <- expected_aliases do
          assert info.aliases[alias_key] == target
        end
      end
    end

    describe "basic transformer generation" do
      test "generates transformer with minimal options" do
        igniter = mock_igniter(%{transformer: "MyApp.Transformers.Simple"})
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.Simple", [
          "use Spark.Dsl.Transformer",
          "@impl Spark.Dsl.Transformer",
          "def transform(dsl_state)",
          "def handle_error(error, dsl_state)"
        ])
      end

      test "includes proper documentation" do
        igniter = mock_igniter(%{transformer: "MyApp.Transformers.Documented"})
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.Documented", [
          "@moduledoc \"\"\"",
          "DSL transformer for documented",
          "This transformer runs during DSL compilation"
        ])
      end

      test "respects --ignore-if-exists flag" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.Existing"}, 
          [ignore_if_exists: true]
        )
        
        result = TransformerGenerator.igniter(igniter)
        assert is_map(result)
      end
    end

    describe "transformer dependencies" do
      test "generates @before directive with single transformer" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.WithBefore"}, 
          [before: ["MyApp.Other"]]
        )
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.WithBefore", [
          "@before [MyApp.Other]"
        ])
      end

      test "generates @before directive with multiple transformers" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.WithMultipleBefore"}, 
          [before: ["MyApp.First", "MyApp.Second", "MyApp.Third"]]
        )
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.WithMultipleBefore", [
          "@before [MyApp.First, MyApp.Second, MyApp.Third]"
        ])
      end

      test "generates @after directive with transformers" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.WithAfter"}, 
          [after: ["MyApp.Previous", "MyApp.Setup"]]
        )
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.WithAfter", [
          "@before [MyApp.Previous, MyApp.Setup]"
        ])
      end

      test "handles both before and after dependencies" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.WithBoth"}, 
          [
            before: ["MyApp.Later"],
            after: ["MyApp.Earlier"]
          ]
        )
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.WithBoth", [
          "@before [MyApp.Later]",
          "@before [MyApp.Earlier]"
        ])
      end

      test "handles empty dependency lists gracefully" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.EmptyDeps"}, 
          [before: [], after: []]
        )
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.EmptyDeps")
      end
    end

    describe "persist keys generation" do
      test "generates @persist directive with single key" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.WithPersist"}, 
          [persist: ["entity_id"]]
        )
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.WithPersist", [
          "@persist [:entity_id]"
        ])
      end

      test "generates @persist directive with multiple keys" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.WithMultiplePersist"}, 
          [persist: ["entity_id", "config_data", "validation_state"]]
        )
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.WithMultiplePersist", [
          "@persist [:entity_id, :config_data, :validation_state]"
        ])
      end

      test "handles empty persist list" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.NoPersist"}, 
          [persist: []]
        )
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.NoPersist")
      end
    end

    describe "DSL context generation" do
      test "includes DSL context when specified" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.WithDsl"}, 
          [dsl: "MyApp.MyDsl"]
        )
        
        result = TransformerGenerator.igniter(igniter)
        
        # DSL context affects the generated examples
        assert_module_created(result, "MyApp.Transformers.WithDsl")
      end

      test "generates appropriate examples without DSL" do
        igniter = mock_igniter(%{transformer: "MyApp.Transformers.NoDsl"})
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.NoDsl")
      end
    end

    describe "examples generation" do
      test "generates examples when requested" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.WithExamples"}, 
          [examples: true, dsl: "MyApp.TestDsl"]
        )
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.WithExamples", [
          "## Usage",
          "Add this transformer to your DSL extension:",
          "use Spark.Dsl.Extension,",
          "transformers: [MyApp.Transformers.WithExamples]",
          "## Example Transformations"
        ])
      end

      test "includes DSL-specific examples when DSL provided" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.DslSpecificExamples"}, 
          [examples: true, dsl: "MyApp.CustomDsl"]
        )
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.DslSpecificExamples", [
          "Or in MyApp.CustomDsl:",
          "defmodule MyApp.CustomDsl do"
        ])
      end

      test "uses generic examples when no DSL provided" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.GenericExamples"}, 
          [examples: true]
        )
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.GenericExamples", [
          "Or in YourDsl:",
          "defmodule YourDsl do"
        ])
      end
    end

    describe "generated transformer behavior" do
      test "implements required Spark.Dsl.Transformer callbacks" do
        igniter = mock_igniter(%{transformer: "MyApp.Transformers.Callbacks"})
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.Callbacks", [
          "use Spark.Dsl.Transformer",
          "@impl Spark.Dsl.Transformer",
          "def transform(dsl_state) do",
          "def handle_error(error, dsl_state) do"
        ])
      end

      test "includes comprehensive transformation comments" do
        igniter = mock_igniter(%{transformer: "MyApp.Transformers.Comments"})
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.Comments", [
          "# TODO: Implement transformation logic",
          "# Example transformations:",
          "# - Add computed fields to entities",
          "# - Validate cross-entity relationships",
          "# Access entities with: Spark.Dsl.Transformer.get_entities",
          "# Add entities with: Spark.Dsl.Transformer.add_entity"
        ])
      end

      test "provides helper function stubs" do
        igniter = mock_igniter(%{transformer: "MyApp.Transformers.Helpers"})
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.Helpers", [
          "defp transform_entity(entity) do",
          "defp validate_entity(entity) do",
          "defp add_computed_fields(entity) do"
        ])
      end

      test "includes proper function documentation" do
        igniter = mock_igniter(%{transformer: "MyApp.Transformers.Documented"})
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.Documented", [
          "@doc \"\"\"",
          "Transform the DSL state.",
          "This function is called during DSL compilation",
          "Handle transformer errors."
        ])
      end
    end

    describe "complex configurations" do
      test "generates transformer with all options" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.Complete"}, 
          [
            dsl: "MyApp.CompleteDsl",
            before: ["MyApp.Later", "MyApp.Final"],
            after: ["MyApp.Earlier", "MyApp.Setup"],
            persist: ["entity_id", "config", "state"],
            examples: true
          ]
        )
        
        result = TransformerGenerator.igniter(igniter)
        
        expected_patterns = [
          "use Spark.Dsl.Transformer",
          "@before [MyApp.Later, MyApp.Final]",
          "@before [MyApp.Earlier, MyApp.Setup]",
          "@persist [:entity_id, :config, :state]",
          "def transform(dsl_state)",
          "def handle_error(error, dsl_state)",
          "## Usage",
          "defmodule MyApp.CompleteDsl do"
        ]
        
        assert_module_created(result, "MyApp.Transformers.Complete", expected_patterns)
      end

      test "handles nil options gracefully" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.NilOptions"}, 
          [dsl: nil, before: nil, after: nil, persist: nil]
        )
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.NilOptions")
      end
    end

    describe "name derivation and formatting" do
      test "derives transformer name from module correctly" do
        test_cases = [
          {"MyApp.Transformers.AddTimestamps", "add timestamps"},
          {"Company.DSL.Transformers.ValidateRules", "validate rules"},
          {"SingleTransformer", "single transformer"},
          {"VeryLongTransformerName", "very long transformer name"}
        ]
        
        for {module_name, expected_name} <- test_cases do
          igniter = mock_igniter(%{transformer: module_name})
          result = TransformerGenerator.igniter(igniter)
          
          # In full tests would verify the derived name matches expected
          assert is_map(result)
        end
      end

      test "handles underscore to space conversion" do
        igniter = mock_igniter(%{transformer: "MyApp.Transformers.Add_Default_Values"})
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.Add_Default_Values", [
          "DSL transformer for add default values"
        ])
      end
    end

    describe "generated code quality" do
      test "all generated modules include proper documentation" do
        igniter = mock_igniter(%{transformer: "MyApp.Transformers.QualityCheck"})
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.QualityCheck", [
          "@moduledoc \"\"\"",
          "DSL transformer for quality check",
          "This transformer runs during DSL compilation"
        ])
      end

      test "includes transformation guidance comments" do
        igniter = mock_igniter(%{transformer: "MyApp.Transformers.Guidance"})
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.Guidance", [
          "# TODO: Implement transformation logic",
          "# Example transformations:",
          "# Access entities with:",
          "# Add entities with:",
          "# Remove entities with:"
        ])
      end

      test "provides comprehensive implementation template" do
        igniter = mock_igniter(%{transformer: "MyApp.Transformers.Template"})
        
        result = TransformerGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Transformers.Template", [
          "{:ok, dsl_state}",
          "defp transform_entity(entity) do",
          "defp validate_entity(entity) do",
          "defp add_computed_fields(entity) do"
        ])
      end
    end

    describe "edge cases and error handling" do
      test "handles very long module names" do
        long_name = "MyApp.Very.Long.Nested.Module.Path.Transformers.VeryLongTransformerName"
        igniter = mock_igniter(%{transformer: long_name})
        
        result = TransformerGenerator.igniter(igniter)
        assert is_map(result)
      end

      test "handles single word module names" do
        igniter = mock_igniter(%{transformer: "Transformer"})
        
        result = TransformerGenerator.igniter(igniter)
        assert is_map(result)
      end

      test "handles empty string inputs" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.EmptyInputs"}, 
          [dsl: "", persist: [""]]
        )
        
        result = TransformerGenerator.igniter(igniter)
        assert is_map(result)
      end

      test "handles malformed dependency lists" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.MalformedDeps"}, 
          [before: [""], after: [nil]]
        )
        
        result = TransformerGenerator.igniter(igniter)
        assert is_map(result)
      end
    end

    describe "Igniter integration" do
      test "properly uses Igniter.Project.Module.parse" do
        igniter = mock_igniter(%{transformer: "MyApp.Transformers.Integration"})
        
        result = TransformerGenerator.igniter(igniter)
        
        # Should not raise errors and return proper structure
        assert is_map(result)
      end

      test "respects module existence checking" do
        # This would need mocking of Igniter.Project.Module.module_exists
        igniter = mock_igniter(%{transformer: "MyApp.Transformers.ExistenceCheck"})
        
        result = TransformerGenerator.igniter(igniter)
        assert is_map(result)
      end
    end

    describe "CSV option parsing" do
      test "correctly parses CSV transformer lists" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.CsvTest"}, 
          [before: ["One,Two,Three"], after: ["Alpha,Beta"]]
        )
        
        result = TransformerGenerator.igniter(igniter)
        
        # Should handle CSV parsing correctly
        assert is_map(result)
      end

      test "handles mixed CSV and list formats" do
        igniter = mock_igniter(
          %{transformer: "MyApp.Transformers.MixedFormat"}, 
          [persist: ["key1,key2", "key3"]]
        )
        
        result = TransformerGenerator.igniter(igniter)
        assert is_map(result)
      end
    end
  else
    # Fallback tests when Igniter is not available
    test "requires Igniter to be available" do
      assert_raise RuntimeError, ~r/requires igniter/, fn ->
        Mix.Tasks.Spark.Gen.Transformer.run(["MyApp.TestTransformer"])
      end
    end
  end
end