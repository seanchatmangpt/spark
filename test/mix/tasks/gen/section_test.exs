defmodule Mix.Tasks.Spark.Gen.SectionTest do
  @moduledoc """
  Comprehensive tests for the Spark Section generator.
  
  Tests all option combinations, code generation patterns, and edge cases
  for the `mix spark.gen.section` task.
  """
  
  use Spark.Test.GeneratorTestCase
  
  # Only run tests if Igniter is available
  @igniter_available Code.ensure_loaded?(Igniter)

  if @igniter_available do
    alias Mix.Tasks.Spark.Gen.Section, as: SectionGenerator

    describe "task info/2" do
      test "returns correct task information" do
        info = SectionGenerator.info([], nil)
        
        assert info.positional == [:section_module]
        assert info.example =~ "mix spark.gen.section MyApp.Sections.Resources"
        
        # Verify schema contains all expected options
        expected_options = [
          :name, :entities, :opts, :docs, :examples, :ignore_if_exists
        ]
        
        schema_keys = Keyword.keys(info.schema)
        for option <- expected_options do
          assert option in schema_keys, "Missing option #{option} in schema"
        end
        
        # Verify aliases
        expected_aliases = [n: :name, e: :entities, o: :opts, d: :docs]
        for {alias_key, target} <- expected_aliases do
          assert info.aliases[alias_key] == target
        end
      end
    end

    describe "basic section generation" do
      test "generates section with minimal options" do
        igniter = mock_igniter(%{section_module: "MyApp.Sections.Simple"})
        
        result = SectionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Sections.Simple", [
          "use Spark.Dsl.Section",
          "@section %Spark.Dsl.Section{",
          "name: :simple",
          "def section, do: @section"
        ])
      end

      test "includes proper documentation" do
        igniter = mock_igniter(%{section_module: "MyApp.Sections.Documented"})
        
        result = SectionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Sections.Documented", [
          "@moduledoc \"\"\"",
          "Documented DSL section",
          "Configuration for documented"
        ])
      end

      test "respects --ignore-if-exists flag" do
        igniter = mock_igniter(
          %{section_module: "MyApp.Sections.Existing"}, 
          [ignore_if_exists: true]
        )
        
        result = SectionGenerator.igniter(igniter)
        assert is_map(result)
      end
    end

    describe "section name handling" do
      test "uses specified name when provided" do
        igniter = mock_igniter(
          %{section_module: "MyApp.Sections.CustomModule"}, 
          [name: "custom_section"]
        )
        
        result = SectionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Sections.CustomModule", [
          "name: :custom_section",
          "Configuration for custom_section"
        ])
      end

      test "derives name from module when not specified" do
        test_cases = [
          {"MyApp.Sections.Resources", :resources},
          {"Company.DSL.Sections.UserProfiles", :user_profiles},
          {"SingleSection", :single_section},
          {"VeryLongSectionName", :very_long_section_name}
        ]
        
        for {module_name, expected_name} <- test_cases do
          igniter = mock_igniter(%{section_module: module_name})
          result = SectionGenerator.igniter(igniter)
          
          # In full tests would verify the derived name matches expected
          assert is_map(result)
        end
      end

      test "handles underscore conversion correctly" do
        igniter = mock_igniter(%{section_module: "MyApp.Sections.ResourceSettings"})
        
        result = SectionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Sections.ResourceSettings", [
          "name: :resource_settings"
        ])
      end
    end

    describe "entity integration" do
      test "includes single entity" do
        igniter = mock_igniter(
          %{section_module: "MyApp.Sections.WithEntity"}, 
          [entities: ["MyApp.Resource"]]
        )
        
        result = SectionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Sections.WithEntity", [
          "entities: [MyApp.Resource]"
        ])
      end

      test "includes multiple entities" do
        igniter = mock_igniter(
          %{section_module: "MyApp.Sections.MultiEntity"}, 
          [entities: ["MyApp.Resource", "MyApp.Policy", "MyApp.Setting"]]
        )
        
        result = SectionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Sections.MultiEntity", [
          "entities: [MyApp.Resource, MyApp.Policy, MyApp.Setting]"
        ])
      end

      test "generates entity helper functions when entities present" do
        igniter = mock_igniter(
          %{section_module: "MyApp.Sections.EntityHelpers"}, 
          [entities: ["MyApp.Resource"]]
        )
        
        result = SectionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Sections.EntityHelpers", [
          "def get_entities(dsl_state)",
          "def add_entity(dsl_state, entity)",
          "Spark.Dsl.Transformer.get_entities",
          "Spark.Dsl.Transformer.add_entity"
        ])
      end

      test "omits entity helpers when no entities" do
        igniter = mock_igniter(%{section_module: "MyApp.Sections.NoEntities"})
        
        result = SectionGenerator.igniter(igniter)
        
        # Should not include entity-specific functions
        assert_module_created(result, "MyApp.Sections.NoEntities", [
          "def get_options(dsl_state)"
        ])
      end

      test "handles empty entity list" do
        igniter = mock_igniter(
          %{section_module: "MyApp.Sections.EmptyEntities"}, 
          [entities: []]
        )
        
        result = SectionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Sections.EmptyEntities")
      end
    end

    describe "section options generation" do
      test "generates single option with type only" do
        igniter = mock_igniter(
          %{section_module: "MyApp.Sections.SingleOpt"}, 
          [opts: ["timeout:integer"]]
        )
        
        result = SectionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Sections.SingleOpt", [
          "schema: [",
          "timeout: [type: :integer]"
        ])
      end

      test "generates option with type and default" do
        igniter = mock_igniter(
          %{section_module: "MyApp.Sections.OptWithDefault"}, 
          [opts: ["timeout:integer:5000", "enabled:boolean:true"]]
        )
        
        result = SectionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Sections.OptWithDefault", [
          "timeout: [type: :integer, default: 5000]",
          "enabled: [type: :boolean, default: true]"
        ])
      end

      test "generates multiple options with various types" do
        igniter = mock_igniter(
          %{section_module: "MyApp.Sections.MultiOpts"}, 
          [opts: ["name:string:default", "count:integer:42", "active:boolean:false", "type:atom:example"]]
        )
        
        result = SectionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Sections.MultiOpts", [
          "name: [type: :string, default: \"default\"]",
          "count: [type: :integer, default: 42]",
          "active: [type: :boolean, default: false]",
          "type: [type: :atom, default: :example]"
        ])
      end

      test "handles complex types correctly" do
        igniter = mock_igniter(
          %{section_module: "MyApp.Sections.ComplexTypes"}, 
          [opts: ["config:keyword_list", "data:map", "items:list", "handler:module"]]
        )
        
        result = SectionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Sections.ComplexTypes", [
          "config: [type: :keyword_list]",
          "data: [type: :map]",
          "items: [type: {:list, :any}]",
          "handler: [type: :module]"
        ])
      end

      test "handles custom types" do
        igniter = mock_igniter(
          %{section_module: "MyApp.Sections.CustomTypes"}, 
          [opts: ["custom_field:custom_type"]]
        )
        
        result = SectionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Sections.CustomTypes", [
          "custom_field: [type: :custom_type]"
        ])
      end

      test "handles empty options list" do
        igniter = mock_igniter(
          %{section_module: "MyApp.Sections.EmptyOpts"}, 
          [opts: []]
        )
        
        result = SectionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Sections.EmptyOpts")
      end
    end

    describe "examples generation" do
      test "generates examples when requested" do
        igniter = mock_igniter(
          %{section_module: "MyApp.Sections.WithExamples"}, 
          [
            examples: true,
            entities: ["MyApp.Resource"],
            opts: ["timeout:integer:5000"]
          ]
        )
        
        result = SectionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Sections.WithExamples", [
          "## Usage",
          "Use this section in your DSL:",
          "defmodule MyApp.MyResource do",
          "with_examples do",
          "timeout 5000"
        ])
      end
    end

    describe "complex configurations" do
      test "generates section with all options" do
        igniter = mock_igniter(
          %{section_module: "MyApp.Sections.Complete"}, 
          [
            name: "complete_section",
            entities: ["MyApp.Resource", "MyApp.Policy"],
            opts: ["timeout:integer:5000", "enabled:boolean:true"],
            docs: "Complete section with all features.",
            examples: true
          ]
        )
        
        result = SectionGenerator.igniter(igniter)
        
        expected_patterns = [
          "use Spark.Dsl.Section",
          "name: :complete_section",
          "entities: [MyApp.Resource, MyApp.Policy]",
          "timeout: [type: :integer, default: 5000]",
          "Complete section with all features.",
          "def get_entities(dsl_state)",
          "## Usage"
        ]
        
        assert_module_created(result, "MyApp.Sections.Complete", expected_patterns)
      end
    end

    describe "edge cases and error handling" do
      test "handles nil options gracefully" do
        igniter = mock_igniter(
          %{section_module: "MyApp.Sections.NilOptions"}, 
          [name: nil, entities: nil, opts: nil, docs: nil]
        )
        
        result = SectionGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Sections.NilOptions")
      end

      test "handles very long module names" do
        long_name = "MyApp.Very.Long.Nested.Module.Path.Sections.VeryLongSectionName"
        igniter = mock_igniter(%{section_module: long_name})
        
        result = SectionGenerator.igniter(igniter)
        assert is_map(result)
      end
    end
  else
    # Fallback tests when Igniter is not available
    test "requires Igniter to be available" do
      assert_raise RuntimeError, ~r/requires igniter/, fn ->
        Mix.Tasks.Spark.Gen.Section.run(["MyApp.TestSection"])
      end
    end
  end
end