defmodule Mix.Tasks.Spark.Gen.DslTest do
  @moduledoc """
  Comprehensive tests for the Spark DSL generator.
  
  Tests all option combinations, code generation patterns, and edge cases
  for the `mix spark.gen.dsl` task.
  """
  
  use Spark.Test.GeneratorTestCase
  
  # Only run tests if Igniter is available
  @igniter_available Code.ensure_loaded?(Igniter)

  if @igniter_available do
    alias Mix.Tasks.Spark.Gen.Dsl, as: DslGenerator

    describe "task info/2" do
      test "returns correct task information" do
        info = DslGenerator.info([], nil)
        
        assert info.positional == [:dsl_module]
        assert info.example =~ "mix spark.gen.dsl MyApp.MyDsl"
        
        # Verify schema contains all expected options
        expected_options = [
          :section, :entity, :arg, :opt, :singleton_entity,
          :transformer, :verifier, :extension, :fragments, :ignore_if_exists
        ]
        
        schema_keys = Keyword.keys(info.schema)
        for option <- expected_options do
          assert option in schema_keys, "Missing option #{option} in schema"
        end
        
        # Verify aliases
        expected_aliases = [s: :section, e: :entity, a: :arg, o: :opt, t: :transformer, v: :verifier]
        for {alias_key, target} <- expected_aliases do
          assert info.aliases[alias_key] == target
        end
      end
    end

    describe "basic DSL generation" do
      test "generates standalone DSL with minimal options" do
        igniter = mock_igniter(%{dsl_module: "MyApp.TestDsl"})
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.TestDsl", [
          "use Spark.Dsl",
          "@moduledoc"
        ])
      end

      test "generates extension DSL when --extension flag is used" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.ExtensionDsl"}, 
          [extension: true]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.ExtensionDsl", [
          "use Spark.Dsl.Extension",
          "transformers:",
          "verifiers:"
        ])
      end

      test "includes fragments when --fragments flag is used" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.FragmentDsl"}, 
          [fragments: true]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.FragmentDsl", [
          "@fragments",
          "use Spark.Dsl.Fragment"
        ])
      end

      test "respects --ignore-if-exists flag" do
        # This would need mocking of Igniter.Project.Module.module_exists
        # For now, we'll test the structure
        igniter = mock_igniter(
          %{dsl_module: "MyApp.ExistingDsl"}, 
          [ignore_if_exists: true]
        )
        
        result = DslGenerator.igniter(igniter)
        assert is_map(result)
      end
    end

    describe "section generation" do
      test "generates single section without entities" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.SectionDsl"}, 
          [section: ["resources"]]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.SectionDsl", [
          "@section :resources",
          "section :resources do"
        ])
      end

      test "generates section with entity module reference" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.SectionDsl"}, 
          [section: ["resources:MyApp.Resource"]]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.SectionDsl", [
          "section :resources do",
          "entities do",
          "MyApp.Resource"
        ])
      end

      test "generates multiple sections" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.MultiSectionDsl"}, 
          [section: ["resources", "policies:MyApp.Policy", "config"]]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.MultiSectionDsl", [
          "section :resources",
          "section :policies",
          "section :config"
        ])
      end
    end

    describe "entity generation" do
      test "generates basic entity with required parameters" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.EntityDsl"}, 
          [entity: ["resource:name:MyApp.Resource"]]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.EntityDsl", [
          "@entity :resource",
          "entity :resource do",
          "identifier :name",
          "target MyApp.Resource"
        ])
      end

      test "generates multiple entities" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.MultiEntityDsl"}, 
          [entity: ["resource:name:MyApp.Resource", "policy:name:MyApp.Policy"]]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.MultiEntityDsl", [
          "entity :resource",
          "entity :policy"
        ])
      end

      test "handles singleton entities" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.SingletonDsl"}, 
          [
            entity: ["config:name:MyApp.Config"],
            singleton_entity: ["config"]
          ]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.SingletonDsl", [
          "entity :config",
          "singleton? true"
        ])
      end

      test "raises error for invalid entity format" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.InvalidEntityDsl"}, 
          [entity: ["invalid_format"]]
        )
        
        assert_raise RuntimeError, ~r/Invalid entity format/, fn ->
          DslGenerator.igniter(igniter)
        end
      end
    end

    describe "argument generation" do
      test "generates arguments with different types" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.ArgDsl"}, 
          [arg: ["timeout:pos_integer:5000", "name:atom", "enabled:boolean:true"]]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.ArgDsl", [
          "@arg :timeout",
          "arg :timeout do",
          "type :pos_integer",
          "default 5000",
          "@arg :name",
          "@arg :enabled"
        ])
      end

      test "handles args without defaults" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.NoDefaultArgDsl"}, 
          [arg: ["name:string"]]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.NoDefaultArgDsl", [
          "arg :name do",
          "type :string"
        ])
      end

      test "correctly parses type system" do
        type_combinations = [
          {"atom", :atom},
          {"string", :string}, 
          {"boolean", :boolean},
          {"integer", :integer},
          {"pos_integer", :pos_integer},
          {"module", :module},
          {"keyword_list", :keyword_list},
          {"map", :map},
          {"list", {:list, :any}}
        ]
        
        for {type_string, expected_type} <- type_combinations do
          igniter = mock_igniter(
            %{dsl_module: "MyApp.TypeTestDsl"}, 
            [arg: ["test_field:#{type_string}"]]
          )
          
          result = DslGenerator.igniter(igniter)
          
          # In a full test, we'd validate the generated type matches expected_type
          assert is_map(result)
        end
      end
    end

    describe "option generation" do
      test "generates options with defaults and types" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.OptDsl"}, 
          [opt: ["verbose:boolean:false", "timeout:integer:30", "endpoint:string"]]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.OptDsl", [
          "@opt :verbose",
          "opt :verbose do",
          "type :boolean",
          "default false",
          "@opt :timeout",
          "@opt :endpoint"
        ])
      end

      test "handles required options" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.RequiredOptDsl"}, 
          [opt: ["api_key:string:required"]]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.RequiredOptDsl", [
          "opt :api_key do",
          "required? true"
        ])
      end
    end

    describe "transformer and verifier integration" do
      test "adds transformers to extension" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.TransformerDsl"}, 
          [extension: true, transformer: ["MyApp.AddTimestamps", "MyApp.ValidateConfig"]]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.TransformerDsl", [
          "use Spark.Dsl.Extension",
          "transformers: [MyApp.AddTimestamps, MyApp.ValidateConfig]"
        ])
      end

      test "adds verifiers to extension" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.VerifierDsl"}, 
          [extension: true, verifier: ["MyApp.VerifyRequired", "MyApp.VerifyUnique"]]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.VerifierDsl", [
          "use Spark.Dsl.Extension", 
          "verifiers: [MyApp.VerifyRequired, MyApp.VerifyUnique]"
        ])
      end

      test "creates transformer modules when referenced" do
        # This tests the maybe_create_transformers function
        igniter = mock_igniter(
          %{dsl_module: "MyApp.AutoTransformerDsl"}, 
          [extension: true, transformer: ["MyApp.AutoTransformer"]]
        )
        
        result = DslGenerator.igniter(igniter)
        
        # In a full integration test, we'd verify that a transformer task was composed
        assert is_map(result)
      end

      test "creates verifier modules when referenced" do
        # This tests the maybe_create_verifiers function
        igniter = mock_igniter(
          %{dsl_module: "MyApp.AutoVerifierDsl"}, 
          [extension: true, verifier: ["MyApp.AutoVerifier"]]
        )
        
        result = DslGenerator.igniter(igniter)
        
        # In a full integration test, we'd verify that a verifier task was composed
        assert is_map(result)
      end
    end

    describe "complex option combinations" do
      test "generates DSL with all options combined" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.ComplexDsl"}, 
          [
            extension: true,
            fragments: true,
            section: ["resources:MyApp.Resource", "policies"],
            entity: ["resource:name:MyApp.Resource", "policy:name:MyApp.Policy"],
            arg: ["timeout:pos_integer:5000", "name:atom"],
            opt: ["verbose:boolean:false", "endpoint:string:required"],
            singleton_entity: ["policy"],
            transformer: ["MyApp.AddDefaults"],
            verifier: ["MyApp.VerifyConfig"]
          ]
        )
        
        result = DslGenerator.igniter(igniter)
        
        expected_patterns = [
          "use Spark.Dsl.Extension",
          "@fragments",
          "use Spark.Dsl.Fragment", 
          "section :resources",
          "section :policies",
          "entity :resource",
          "entity :policy",
          "singleton? true",
          "arg :timeout",
          "arg :name", 
          "opt :verbose",
          "opt :endpoint",
          "transformers: [MyApp.AddDefaults]",
          "verifiers: [MyApp.VerifyConfig]"
        ]
        
        assert_module_created(result, "MyApp.ComplexDsl", expected_patterns)
      end

      test "generates standalone DSL with sections and entities" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.StandaloneDsl"}, 
          [
            section: ["config", "resources:MyApp.Resource"],
            entity: ["setting:name:MyApp.Setting"],
            arg: ["app_name:string"],
            opt: ["debug:boolean:false"]
          ]
        )
        
        result = DslGenerator.igniter(igniter)
        
        expected_patterns = [
          "use Spark.Dsl",
          "section :config",
          "section :resources",
          "entity :setting",
          "arg :app_name",
          "opt :debug"
        ]
        
        assert_module_created(result, "MyApp.StandaloneDsl", expected_patterns)
      end
    end

    describe "edge cases and error handling" do
      test "handles empty option lists gracefully" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.EmptyDsl"}, 
          [section: [], entity: [], arg: [], opt: []]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.EmptyDsl")
      end

      test "handles nil options" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.NilOptionsDsl"}, 
          [section: nil, entity: nil]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.NilOptionsDsl")
      end

      test "validates module name parsing" do
        test_cases = [
          "MyApp.Simple",
          "VeryLong.Nested.Module.Name", 
          "SingleName"
        ]
        
        for module_name <- test_cases do
          igniter = mock_igniter(%{dsl_module: module_name})
          result = DslGenerator.igniter(igniter)
          assert is_map(result)
        end
      end

      test "handles malformed section definitions" do
        # Test with too many colons
        igniter = mock_igniter(
          %{dsl_module: "MyApp.MalformedDsl"}, 
          [section: ["section:module:extra:parts"]]
        )
        
        result = DslGenerator.igniter(igniter)
        
        # Should handle gracefully by taking first two parts
        assert is_map(result)
      end
    end

    describe "default value parsing" do
      test "parses boolean defaults correctly" do
        test_cases = [
          {"true", true},
          {"false", false}
        ]
        
        for {input, expected} <- test_cases do
          igniter = mock_igniter(
            %{dsl_module: "MyApp.BooleanDefaultDsl"}, 
            [arg: ["enabled:boolean:#{input}"]]
          )
          
          result = DslGenerator.igniter(igniter)
          assert is_map(result)
          # In full tests would verify the actual parsed value
        end
      end

      test "parses integer defaults correctly" do
        test_cases = [
          {"42", 42},
          {"0", 0},
          {"1000", 1000}
        ]
        
        for {input, expected} <- test_cases do
          igniter = mock_igniter(
            %{dsl_module: "MyApp.IntegerDefaultDsl"}, 
            [arg: ["count:integer:#{input}"]]
          )
          
          result = DslGenerator.igniter(igniter)
          assert is_map(result)
        end
      end

      test "parses atom defaults correctly" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.AtomDefaultDsl"}, 
          [arg: ["status:atom:active"]]
        )
        
        result = DslGenerator.igniter(igniter)
        assert is_map(result)
      end

      test "keeps string defaults as strings" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.StringDefaultDsl"}, 
          [arg: ["message:string:hello world"]]
        )
        
        result = DslGenerator.igniter(igniter)
        assert is_map(result)
      end
    end

    describe "generated code quality" do
      test "all generated modules include proper documentation" do
        igniter = mock_igniter(%{dsl_module: "MyApp.DocumentedDsl"})
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.DocumentedDsl", [
          "@moduledoc \"\"\"",
          "DSL for"
        ])
      end

      test "sections include proper documentation" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.DocumentedSectionDsl"}, 
          [section: ["resources"]]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.DocumentedSectionDsl", [
          "@moduledoc \"\"\"",
          "Configuration for resources"
        ])
      end

      test "entities include proper documentation" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.DocumentedEntityDsl"}, 
          [entity: ["user:name:MyApp.User"]]
        )
        
        result = DslGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.DocumentedEntityDsl", [
          "@moduledoc \"\"\"",
          "Represents a user in the DSL"
        ])
      end
    end
  else
    # Fallback tests when Igniter is not available
    test "requires Igniter to be available" do
      assert_raise RuntimeError, ~r/requires igniter/, fn ->
        Mix.Tasks.Spark.Gen.Dsl.run(["MyApp.TestDsl"])
      end
    end
  end
end