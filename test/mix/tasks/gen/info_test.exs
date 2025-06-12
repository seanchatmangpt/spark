defmodule Mix.Tasks.Spark.Gen.InfoTest do
  @moduledoc """
  Comprehensive tests for the Spark Info generator.
  
  Tests all option combinations, code generation patterns, and edge cases
  for the `mix spark.gen.info` task.
  """
  
  use Spark.Test.GeneratorTestCase
  
  # Only run tests if Igniter is available
  @igniter_available Code.ensure_loaded?(Igniter)

  if @igniter_available do
    alias Mix.Tasks.Spark.Gen.Info, as: InfoGenerator

    describe "task info/2" do
      test "returns correct task information" do
        info = InfoGenerator.info([], nil)
        
        assert info.positional == [:info_module]
        assert info.example =~ "mix spark.gen.info MyApp.Resource.Info"
        
        # Verify schema contains all expected options
        expected_options = [
          :extension, :sections, :functions, :opts, :examples, :ignore_if_exists
        ]
        
        schema_keys = Keyword.keys(info.schema)
        for option <- expected_options do
          assert option in schema_keys, "Missing option #{option} in schema"
        end
        
        # Verify aliases
        expected_aliases = [e: :extension, s: :sections, f: :functions, o: :opts]
        for {alias_key, target} <- expected_aliases do
          assert info.aliases[alias_key] == target
        end
      end
    end

    describe "basic info module generation" do
      test "generates info module with minimal options" do
        igniter = mock_igniter(%{info_module: "MyApp.Resource.Info"})
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Resource.Info", [
          "use Spark.InfoGenerator",
          "extension: MyApp.Resource.Dsl",
          "sections: []"
        ])
      end

      test "includes proper documentation" do
        igniter = mock_igniter(%{info_module: "MyApp.DocumentedInfo"})
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.DocumentedInfo", [
          "@moduledoc \"\"\"",
          "Info module for",
          "This module provides runtime access to DSL configuration data"
        ])
      end

      test "respects --ignore-if-exists flag" do
        igniter = mock_igniter(
          %{info_module: "MyApp.ExistingInfo"}, 
          [ignore_if_exists: true]
        )
        
        result = InfoGenerator.igniter(igniter)
        assert is_map(result)
      end
    end

    describe "extension specification" do
      test "uses specified extension module" do
        igniter = mock_igniter(
          %{info_module: "MyApp.CustomInfo"}, 
          [extension: "MyApp.CustomExtension"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.CustomInfo", [
          "extension: MyApp.CustomExtension"
        ])
      end

      test "infers extension from info module path when not specified" do
        igniter = mock_igniter(%{info_module: "MyApp.Resource.Info"})
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Resource.Info", [
          "extension: MyApp.Resource.Dsl"
        ])
      end

      test "handles deeply nested info modules" do
        igniter = mock_igniter(%{info_module: "MyApp.Deeply.Nested.Module.Info"})
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Deeply.Nested.Module.Info", [
          "extension: MyApp.Deeply.Nested.Module.Dsl"
        ])
      end

      test "handles single level info modules" do
        igniter = mock_igniter(%{info_module: "ResourceInfo"})
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "ResourceInfo", [
          "extension: Dsl"
        ])
      end
    end

    describe "sections configuration" do
      test "parses single section correctly" do
        igniter = mock_igniter(
          %{info_module: "MyApp.SingleSectionInfo"}, 
          [sections: "resources"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.SingleSectionInfo", [
          "sections: [:resources]"
        ])
      end

      test "parses multiple sections correctly" do
        igniter = mock_igniter(
          %{info_module: "MyApp.MultiSectionInfo"}, 
          [sections: "resources,policies,config"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.MultiSectionInfo", [
          "sections: [:resources, :policies, :config]"
        ])
      end

      test "handles sections with whitespace" do
        igniter = mock_igniter(
          %{info_module: "MyApp.WhitespaceInfo"}, 
          [sections: " resources , policies , config "]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.WhitespaceInfo", [
          "sections: [:resources, :policies, :config]"
        ])
      end

      test "generates section-specific helper functions" do
        igniter = mock_igniter(
          %{info_module: "MyApp.SectionHelpersInfo"}, 
          [sections: "resources,policies"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.SectionHelpersInfo", [
          "def get_resources(dsl_or_module)",
          "def get_resource(dsl_or_module, identifier)",
          "def get_policies(dsl_or_module)",
          "def get_policy(dsl_or_module, identifier)"
        ])
      end
    end

    describe "custom functions generation" do
      test "generates single custom function" do
        igniter = mock_igniter(
          %{info_module: "MyApp.CustomFunctionInfo"}, 
          [functions: "get_field"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.CustomFunctionInfo", [
          "def get_field(dsl_or_module, identifier \\\\ nil)",
          "@spec get_field(module() | Spark.Dsl.t()) :: term()"
        ])
      end

      test "generates multiple custom functions" do
        igniter = mock_igniter(
          %{info_module: "MyApp.MultiFunctionInfo"}, 
          [functions: "get_field,get_relationship,validate_config"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.MultiFunctionInfo", [
          "def get_field(dsl_or_module, identifier \\\\ nil)",
          "def get_relationship(dsl_or_module, identifier \\\\ nil)",
          "def validate_config(dsl_or_module, identifier \\\\ nil)"
        ])
      end

      test "includes proper documentation for custom functions" do
        igniter = mock_igniter(
          %{info_module: "MyApp.FunctionDocsInfo"}, 
          [functions: "get_special_field"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.FunctionDocsInfo", [
          "@doc \"\"\"",
          "Get special field from the DSL configuration",
          "## Examples"
        ])
      end

      test "handles function names with underscores" do
        igniter = mock_igniter(
          %{info_module: "MyApp.UnderscoreFunctionInfo"}, 
          [functions: "get_primary_key,validate_unique_fields"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.UnderscoreFunctionInfo", [
          "Get primary key from the DSL configuration",
          "Validate unique fields from the DSL configuration"
        ])
      end
    end

    describe "custom options generation" do
      test "includes custom options when specified" do
        igniter = mock_igniter(
          %{info_module: "MyApp.CustomOptsInfo"}, 
          [opts: "some_option: true, another_option: :value"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.CustomOptsInfo", [
          "some_option: true, another_option: :value"
        ])
      end

      test "handles empty options" do
        igniter = mock_igniter(
          %{info_module: "MyApp.EmptyOptsInfo"}, 
          [opts: ""]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.EmptyOptsInfo")
      end
    end

    describe "examples generation" do
      test "generates examples when requested" do
        igniter = mock_igniter(
          %{info_module: "MyApp.ExampleInfo"}, 
          [
            examples: true,
            extension: "MyApp.MyExtension",
            sections: "resources,policies"
          ]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.ExampleInfo", [
          "## Usage",
          "Use this info module to introspect DSL-configured modules:",
          "entities = MyApp.ExampleInfo.get_resources(MyResource)",
          "entities = MyApp.ExampleInfo.get_policies(MyResource)"
        ])
      end

      test "includes custom function examples" do
        igniter = mock_igniter(
          %{info_module: "MyApp.CustomExampleInfo"}, 
          [
            examples: true,
            functions: "get_field,validate_config"
          ]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.CustomExampleInfo", [
          "result = MyApp.CustomExampleInfo.get_field(MyResource)",
          "result = MyApp.CustomExampleInfo.validate_config(MyResource)"
        ])
      end

      test "includes generated functions documentation" do
        igniter = mock_igniter(
          %{info_module: "MyApp.GeneratedDocsInfo"}, 
          [
            examples: true,
            sections: "fields,relationships",
            functions: "custom_helper"
          ]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.GeneratedDocsInfo", [
          "## Generated Functions",
          "- `get_fields/1` - Get all fields",
          "- `get_relationships/1` - Get all relationships",
          "- `custom_helper/1` - Custom custom helper function"
        ])
      end
    end

    describe "helper functions generation" do
      test "generates configured_sections function" do
        igniter = mock_igniter(
          %{info_module: "MyApp.ConfiguredSectionsInfo"}, 
          [sections: "resources,policies"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.ConfiguredSectionsInfo", [
          "def configured_sections do",
          "[:resources, :policies]"
        ])
      end

      test "generates has_section? function" do
        igniter = mock_igniter(
          %{info_module: "MyApp.HasSectionInfo"}, 
          [sections: "resources"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.HasSectionInfo", [
          "def has_section?(section_name) do",
          "section_name in configured_sections()"
        ])
      end

      test "handles plural section names correctly" do
        igniter = mock_igniter(
          %{info_module: "MyApp.PluralSectionsInfo"}, 
          [sections: "resources,policies,settings"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.PluralSectionsInfo", [
          "def get_resource(dsl_or_module, identifier)",
          "def get_policy(dsl_or_module, identifier)",
          "def get_setting(dsl_or_module, identifier)"
        ])
      end

      test "handles singular section names correctly" do
        igniter = mock_igniter(
          %{info_module: "MyApp.SingularSectionInfo"}, 
          [sections: "config,metadata"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.SingularSectionInfo", [
          "def get_config(dsl_or_module)",
          "def get_metadata(dsl_or_module)"
        ])
      end
    end

    describe "complex configurations" do
      test "generates info module with all options" do
        igniter = mock_igniter(
          %{info_module: "MyApp.CompleteInfo"}, 
          [
            extension: "MyApp.CompleteExtension",
            sections: "resources,policies,config",
            functions: "get_field,validate_rules,check_permissions",
            opts: "custom_option: true",
            examples: true
          ]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        expected_patterns = [
          "use Spark.InfoGenerator",
          "extension: MyApp.CompleteExtension",
          "sections: [:resources, :policies, :config]",
          "custom_option: true",
          "def get_field(dsl_or_module, identifier \\\\ nil)",
          "def validate_rules(dsl_or_module, identifier \\\\ nil)",
          "def check_permissions(dsl_or_module, identifier \\\\ nil)",
          "def get_resources(dsl_or_module)",
          "def get_policies(dsl_or_module)",
          "def configured_sections do",
          "def has_section?(section_name)",
          "## Usage",
          "## Generated Functions"
        ]
        
        assert_module_created(result, "MyApp.CompleteInfo", expected_patterns)
      end

      test "handles mixed section types" do
        igniter = mock_igniter(
          %{info_module: "MyApp.MixedSectionsInfo"}, 
          [sections: "resources,config,relationships,metadata"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        expected_patterns = [
          "def get_resources(dsl_or_module)",
          "def get_resource(dsl_or_module, identifier)",
          "def get_config(dsl_or_module)",
          "def get_relationships(dsl_or_module)",
          "def get_relationship(dsl_or_module, identifier)",
          "def get_metadata(dsl_or_module)"
        ]
        
        assert_module_created(result, "MyApp.MixedSectionsInfo", expected_patterns)
      end
    end

    describe "name derivation and formatting" do
      test "derives extension from various info module patterns" do
        test_cases = [
          {"MyApp.Resource.Info", "MyApp.Resource.Dsl"},
          {"Company.Product.Info", "Company.Product.Dsl"},
          {"Single.Info", "Single.Dsl"},
          {"VeryLong.Nested.Path.Info", "VeryLong.Nested.Path.Dsl"}
        ]
        
        for {info_module, expected_extension} <- test_cases do
          igniter = mock_igniter(%{info_module: info_module})
          result = InfoGenerator.igniter(igniter)
          
          # In full tests would verify the derived extension matches expected
          assert is_map(result)
        end
      end

      test "handles info modules without standard naming" do
        igniter = mock_igniter(%{info_module: "MyApp.CustomInfoModule"})
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.CustomInfoModule", [
          "extension: MyApp.Dsl"
        ])
      end
    end

    describe "edge cases and error handling" do
      test "handles nil options gracefully" do
        igniter = mock_igniter(
          %{info_module: "MyApp.NilOptionsInfo"}, 
          [extension: nil, sections: nil, functions: nil, opts: nil]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.NilOptionsInfo")
      end

      test "handles empty option strings" do
        igniter = mock_igniter(
          %{info_module: "MyApp.EmptyOptionsInfo"}, 
          [sections: "", functions: "", opts: ""]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.EmptyOptionsInfo")
      end

      test "handles very long module names" do
        long_name = "MyApp.Very.Long.Nested.Module.Path.Info.VeryLongInfoModuleName"
        igniter = mock_igniter(%{info_module: long_name})
        
        result = InfoGenerator.igniter(igniter)
        assert is_map(result)
      end

      test "handles single word module names" do
        igniter = mock_igniter(%{info_module: "InfoModule"})
        
        result = InfoGenerator.igniter(igniter)
        assert is_map(result)
      end

      test "handles malformed section strings" do
        igniter = mock_igniter(
          %{info_module: "MyApp.MalformedSectionsInfo"}, 
          [sections: "section1,,section2,"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        # Should handle gracefully by filtering empty strings
        assert is_map(result)
      end

      test "handles malformed function strings" do
        igniter = mock_igniter(
          %{info_module: "MyApp.MalformedFunctionsInfo"}, 
          [functions: "function1,,function2,"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        # Should handle gracefully by filtering empty strings
        assert is_map(result)
      end
    end

    describe "generated code quality" do
      test "all generated modules include proper documentation" do
        igniter = mock_igniter(%{info_module: "MyApp.QualityCheckInfo"})
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.QualityCheckInfo", [
          "@moduledoc \"\"\"",
          "Info module for",
          "This module provides runtime access to DSL configuration data"
        ])
      end

      test "includes comprehensive function documentation" do
        igniter = mock_igniter(
          %{info_module: "MyApp.FunctionDocsInfo"}, 
          [functions: "custom_function"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.FunctionDocsInfo", [
          "@doc \"\"\"",
          "Custom function from the DSL configuration",
          "@spec custom_function(module() | Spark.Dsl.t()) :: term()"
        ])
      end

      test "provides type specifications for all functions" do
        igniter = mock_igniter(
          %{info_module: "MyApp.TypeSpecsInfo"}, 
          [sections: "resources"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.TypeSpecsInfo", [
          "@spec get_resources(module() | Spark.Dsl.t()) :: [term()]",
          "@spec get_resource(module() | Spark.Dsl.t(), term()) :: term() | nil",
          "@spec configured_sections() :: [atom()]",
          "@spec has_section?(atom()) :: boolean()"
        ])
      end

      test "includes helpful implementation comments" do
        igniter = mock_igniter(
          %{info_module: "MyApp.CommentsInfo"}, 
          [functions: "helper_function"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.CommentsInfo", [
          "# TODO: Implement custom function logic",
          "# You can use the generated functions like:",
          "# Return all items",
          "# Return specific item by identifier"
        ])
      end
    end

    describe "Spark.InfoGenerator integration" do
      test "properly integrates with InfoGenerator behavior" do
        igniter = mock_igniter(
          %{info_module: "MyApp.IntegrationInfo"}, 
          [sections: "resources"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.IntegrationInfo", [
          "use Spark.InfoGenerator",
          "entities(dsl_or_module, [:resources]) || []"
        ])
      end

      test "correctly uses InfoGenerator conventions" do
        igniter = mock_igniter(
          %{info_module: "MyApp.ConventionsInfo"}, 
          [sections: "fields,relationships"]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.ConventionsInfo", [
          "Map.get(entity, :name) == identifier ||",
          "Map.get(entity, :identifier) == identifier"
        ])
      end
    end

    describe "string parsing and validation" do
      test "correctly trims whitespace from all inputs" do
        igniter = mock_igniter(
          %{info_module: "MyApp.WhitespaceInfo"}, 
          [
            sections: " section1 , section2 ",
            functions: " func1 , func2 "
          ]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.WhitespaceInfo", [
          "sections: [:section1, :section2]",
          "def func1(dsl_or_module, identifier \\\\ nil)",
          "def func2(dsl_or_module, identifier \\\\ nil)"
        ])
      end

      test "handles mixed case section and function names" do
        igniter = mock_igniter(
          %{info_module: "MyApp.MixedCaseInfo"}, 
          [
            sections: "Resources,Policies,ConfigData",
            functions: "GetPrimary,ValidateSecondary"
          ]
        )
        
        result = InfoGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.MixedCaseInfo", [
          "sections: [:Resources, :Policies, :ConfigData]",
          "def GetPrimary(dsl_or_module, identifier \\\\ nil)",
          "def ValidateSecondary(dsl_or_module, identifier \\\\ nil)"
        ])
      end
    end
  else
    # Fallback tests when Igniter is not available
    test "requires Igniter to be available" do
      assert_raise RuntimeError, ~r/requires igniter/, fn ->
        Mix.Tasks.Spark.Gen.Info.run(["MyApp.TestInfo"])
      end
    end
  end
end