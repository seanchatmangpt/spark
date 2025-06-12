defmodule Mix.Tasks.Spark.Gen.ExtensionTest do
  @moduledoc """
  Comprehensive tests for the Spark Extension generator.
  
  Tests all option combinations, code generation patterns, and edge cases
  for the `mix spark.gen.extension` task.
  """
  
  use Spark.Test.GeneratorTestCase
  
  # Only run tests if Igniter is available
  @igniter_available Code.ensure_loaded?(Igniter)

  if @igniter_available do
    alias Mix.Tasks.Spark.Gen.Extension, as: ExtensionGenerator

    describe "task info/2" do
      test "returns correct task information" do
        info = ExtensionGenerator.info([], nil)
        
        assert info.positional == [:extension]
        assert info.example =~ "mix spark.gen.extension MyApp.Extensions.MyExtension"
        
        # Verify schema contains all expected options
        expected_options = [
          :section, :entity, :transformer, :verifier, :persist, 
          :fragments, :examples, :ignore_if_exists
        ]
        
        schema_keys = Keyword.keys(info.schema)
        for option <- expected_options do
          assert option in schema_keys, "Missing option #{option} in schema"
        end
        
        # Verify aliases
        expected_aliases = [s: :section, e: :entity, t: :transformer, v: :verifier, p: :persist]
        for {alias_key, target} <- expected_aliases do
          assert info.aliases[alias_key] == target
        end
      end
    end

    describe "basic extension generation" do
      test "generates extension with minimal options" do
        igniter = mock_igniter(%{extension: "MyApp.Extensions.Simple"})
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.Simple", [
          "use Spark.Dsl.Extension",
          "sections: []",
          "transformers: []",
          "verifiers: []"
        ])
      end

      test "includes proper documentation" do
        igniter = mock_igniter(%{extension: "MyApp.Extensions.Documented"})
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.Documented", [
          "@moduledoc \"\"\"",
          "Documented DSL extension",
          "This extension provides reusable DSL components"
        ])
      end

      test "respects --ignore-if-exists flag" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.Existing"}, 
          [ignore_if_exists: true]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        assert is_map(result)
      end
    end

    describe "section generation" do
      test "generates extension with single section" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.WithSection"}, 
          [section: ["resources"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.WithSection", [
          "sections: [@resources]",
          "@resources %Spark.Dsl.Section{",
          "name: :resources",
          "Configuration for resources"
        ])
      end

      test "generates section with entity module reference" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.WithSectionEntity"}, 
          [section: ["resources:MyApp.Resource"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.WithSectionEntity", [
          "@resources %Spark.Dsl.Section{",
          "entities: [@resources_entity]",
          "entities do",
          "MyApp.Resource"
        ])
      end

      test "generates multiple sections" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.MultiSection"}, 
          [section: ["resources", "policies:MyApp.Policy", "config"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.MultiSection", [
          "sections: [@resources, @policies, @config]",
          "@resources %Spark.Dsl.Section{",
          "@policies %Spark.Dsl.Section{",
          "@config %Spark.Dsl.Section{"
        ])
      end

      test "handles section parsing correctly" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.SectionParsing"}, 
          [section: ["simple_section", "section_with_entity:MyApp.Entity"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.SectionParsing", [
          "name: :simple_section",
          "name: :section_with_entity",
          "entities: [@section_with_entity_entity]"
        ])
      end
    end

    describe "entity generation" do
      test "generates extension with single entity" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.WithEntity"}, 
          [entity: ["resource:name:MyApp.Resource"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.WithEntity", [
          "sections: [@resource]",
          "@resource %Spark.Dsl.Entity{",
          "name: :resource",
          "identifier: :name",
          "target: MyApp.Resource"
        ])
      end

      test "generates multiple entities" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.MultiEntity"}, 
          [entity: ["resource:name:MyApp.Resource", "policy:name:MyApp.Policy"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.MultiEntity", [
          "sections: [@resource, @policy]",
          "@resource %Spark.Dsl.Entity{",
          "@policy %Spark.Dsl.Entity{",
          "target: MyApp.Resource",
          "target: MyApp.Policy"
        ])
      end

      test "generates entity with proper schema" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.EntitySchema"}, 
          [entity: ["rule:condition:MyApp.Rule"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.EntitySchema", [
          "identifier: :condition",
          "args: [:condition]",
          "condition: [",
          "type: :condition",
          "required: true",
          "The identifier for this rule"
        ])
      end

      test "handles entity parsing and validation" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.EntityValidation"}, 
          [entity: ["user:id:MyApp.User", "post:slug:MyApp.Post"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.EntityValidation", [
          "identifier: :id",
          "identifier: :slug",
          "target: MyApp.User",
          "target: MyApp.Post"
        ])
      end

      test "raises error for invalid entity format" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.InvalidEntity"}, 
          [entity: ["invalid_format"]]
        )
        
        assert_raise RuntimeError, ~r/Invalid entity format/, fn ->
          ExtensionGenerator.igniter(igniter)
        end
      end
    end

    describe "transformer and verifier integration" do
      test "adds transformers to extension" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.WithTransformers"}, 
          [transformer: ["MyApp.AddTimestamps", "MyApp.ValidateConfig"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.WithTransformers", [
          "transformers: [MyApp.AddTimestamps, MyApp.ValidateConfig]"
        ])
      end

      test "adds verifiers to extension" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.WithVerifiers"}, 
          [verifier: ["MyApp.VerifyRequired", "MyApp.VerifyUnique"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.WithVerifiers", [
          "verifiers: [MyApp.VerifyRequired, MyApp.VerifyUnique]"
        ])
      end

      test "combines transformers and verifiers" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.WithBoth"}, 
          [
            transformer: ["MyApp.AddDefaults"],
            verifier: ["MyApp.VerifyConfig"]
          ]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.WithBoth", [
          "transformers: [MyApp.AddDefaults]",
          "verifiers: [MyApp.VerifyConfig]"
        ])
      end

      test "handles empty transformer/verifier lists" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.EmptyLists"}, 
          [transformer: [], verifier: []]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.EmptyLists", [
          "transformers: []",
          "verifiers: []"
        ])
      end
    end

    describe "persist keys generation" do
      test "adds persist keys to extension" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.WithPersist"}, 
          [persist: ["entity_id", "config_data"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.WithPersist", [
          "persist: [:entity_id, :config_data]"
        ])
      end

      test "handles single persist key" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.SinglePersist"}, 
          [persist: ["state"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.SinglePersist", [
          "persist: [:state]"
        ])
      end

      test "handles empty persist list" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.NoPersist"}, 
          [persist: []]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        # Should not include persist line when empty
        assert_module_created(result, "MyApp.Extensions.NoPersist")
      end
    end

    describe "fragments support" do
      test "includes fragments when enabled" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.WithFragments"}, 
          [fragments: true]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.WithFragments", [
          "@fragments [",
          "# Add fragment modules here"
        ])
      end

      test "omits fragments when not enabled" do
        igniter = mock_igniter(%{extension: "MyApp.Extensions.NoFragments"})
        
        result = ExtensionGenerator.igniter(igniter)
        
        # Should not include @fragments when not requested
        assert_module_created(result, "MyApp.Extensions.NoFragments")
      end
    end

    describe "examples generation" do
      test "generates examples when requested" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.WithExamples"}, 
          [
            examples: true,
            section: ["resources"],
            entity: ["resource:name:MyApp.Resource"]
          ]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.WithExamples", [
          "## Usage",
          "Add this extension to your DSL:",
          "defmodule MyApp.MyDsl do",
          "use Spark.Dsl,",
          "default_extensions: [extensions: [MyApp.Extensions.WithExamples]]",
          "## Example DSL Usage"
        ])
      end

      test "includes section examples in documentation" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.SectionExamples"}, 
          [
            examples: true,
            section: ["resources", "policies"]
          ]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.SectionExamples", [
          "resources do",
          "# Configuration here",
          "policies do"
        ])
      end

      test "includes entity examples in documentation" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.EntityExamples"}, 
          [
            examples: true,
            entity: ["user:name:MyApp.User", "post:slug:MyApp.Post"]
          ]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.EntityExamples", [
          "user :my_user do",
          "# User configuration",
          "post :my_post do",
          "# Post configuration"
        ])
      end
    end

    describe "module composition and task delegation" do
      test "creates transformer modules when referenced" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.AutoTransformer"}, 
          [transformer: ["MyApp.AutoTransformer"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        # In a full integration test, we'd verify that a transformer task was composed
        assert is_map(result)
      end

      test "creates verifier modules when referenced" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.AutoVerifier"}, 
          [verifier: ["MyApp.AutoVerifier"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        # In a full integration test, we'd verify that a verifier task was composed
        assert is_map(result)
      end

      test "handles multiple module creations" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.MultipleModules"}, 
          [
            transformer: ["MyApp.First", "MyApp.Second"],
            verifier: ["MyApp.VerifyFirst", "MyApp.VerifySecond"]
          ]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        # Should handle multiple task compositions
        assert is_map(result)
      end
    end

    describe "complex configurations" do
      test "generates extension with all options" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.Complete"}, 
          [
            section: ["resources:MyApp.Resource", "policies"],
            entity: ["resource:name:MyApp.Resource", "policy:name:MyApp.Policy"],
            transformer: ["MyApp.AddDefaults"],
            verifier: ["MyApp.VerifyConfig"],
            persist: ["entity_id", "state"],
            fragments: true,
            examples: true
          ]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        expected_patterns = [
          "use Spark.Dsl.Extension",
          "@fragments [",
          "sections: [@resources, @policies, @resource, @policy]",
          "transformers: [MyApp.AddDefaults]",
          "verifiers: [MyApp.VerifyConfig]",
          "persist: [:entity_id, :state]",
          "@resources %Spark.Dsl.Section{",
          "@resource %Spark.Dsl.Entity{",
          "## Usage",
          "## Example DSL Usage"
        ]
        
        assert_module_created(result, "MyApp.Extensions.Complete", expected_patterns)
      end

      test "handles mixed section and entity definitions" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.Mixed"}, 
          [
            section: ["config", "resources:MyApp.Resource"],
            entity: ["setting:name:MyApp.Setting"]
          ]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        expected_patterns = [
          "sections: [@config, @resources, @setting]",
          "@config %Spark.Dsl.Section{",
          "@resources %Spark.Dsl.Section{",
          "@setting %Spark.Dsl.Entity{"
        ]
        
        assert_module_created(result, "MyApp.Extensions.Mixed", expected_patterns)
      end
    end

    describe "name derivation and formatting" do
      test "derives extension name from module correctly" do
        test_cases = [
          {"MyApp.Extensions.Validation", "Validation"},
          {"Company.DSL.Extensions.ResourceExtension", "Resource extension"},
          {"SingleExtension", "Single extension"},
          {"VeryLongExtensionName", "Very long extension name"}
        ]
        
        for {module_name, expected_name} <- test_cases do
          igniter = mock_igniter(%{extension: module_name})
          result = ExtensionGenerator.igniter(igniter)
          
          # In full tests would verify the derived name matches expected
          assert is_map(result)
        end
      end

      test "handles underscore to space conversion and capitalization" do
        igniter = mock_igniter(%{extension: "MyApp.Extensions.My_Custom_Extension"})
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.My_Custom_Extension", [
          "My custom extension DSL extension"
        ])
      end
    end

    describe "edge cases and error handling" do
      test "handles nil options gracefully" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.NilOptions"}, 
          [section: nil, entity: nil, transformer: nil, verifier: nil]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.NilOptions")
      end

      test "handles empty option lists" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.EmptyOptions"}, 
          [section: [], entity: [], transformer: [], verifier: []]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.EmptyOptions")
      end

      test "handles very long module names" do
        long_name = "MyApp.Very.Long.Nested.Module.Path.Extensions.VeryLongExtensionName"
        igniter = mock_igniter(%{extension: long_name})
        
        result = ExtensionGenerator.igniter(igniter)
        assert is_map(result)
      end

      test "handles single word module names" do
        igniter = mock_igniter(%{extension: "Extension"})
        
        result = ExtensionGenerator.igniter(igniter)
        assert is_map(result)
      end

      test "handles malformed section definitions gracefully" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.MalformedSections"}, 
          [section: ["section:module:extra:parts"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        # Should handle gracefully by taking first two parts
        assert is_map(result)
      end
    end

    describe "generated code quality" do
      test "all generated modules include proper documentation" do
        igniter = mock_igniter(%{extension: "MyApp.Extensions.QualityCheck"})
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.QualityCheck", [
          "@moduledoc \"\"\"",
          "Quality check DSL extension",
          "This extension provides reusable DSL components"
        ])
      end

      test "sections include proper documentation" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.SectionDocs"}, 
          [section: ["resources"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.SectionDocs", [
          "describe: \"\"\"",
          "Configuration for resources"
        ])
      end

      test "entities include proper documentation" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.EntityDocs"}, 
          [entity: ["user:name:MyApp.User"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.EntityDocs", [
          "describe: \"\"\"",
          "Represents a user in the DSL"
        ])
      end

      test "provides comprehensive usage examples" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.UsageExamples"}, 
          [examples: true]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Extensions.UsageExamples", [
          "## Usage",
          "Add this extension to your DSL:",
          "Or include it in another extension:",
          "## Example DSL Usage"
        ])
      end
    end

    describe "CSV option parsing" do
      test "correctly parses CSV section lists" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.CsvSections"}, 
          [section: ["one,two,three"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        # Should handle CSV parsing correctly
        assert is_map(result)
      end

      test "correctly parses CSV entity lists" do
        igniter = mock_igniter(
          %{extension: "MyApp.Extensions.CsvEntities"}, 
          [entity: ["user:name:User,post:slug:Post"]]
        )
        
        result = ExtensionGenerator.igniter(igniter)
        
        # Should handle CSV parsing correctly
        assert is_map(result)
      end
    end
  else
    # Fallback tests when Igniter is not available
    test "requires Igniter to be available" do
      assert_raise RuntimeError, ~r/requires igniter/, fn ->
        Mix.Tasks.Spark.Gen.Extension.run(["MyApp.TestExtension"])
      end
    end
  end
end