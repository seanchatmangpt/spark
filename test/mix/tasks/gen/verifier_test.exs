defmodule Mix.Tasks.Spark.Gen.VerifierTest do
  @moduledoc """
  Comprehensive tests for the Spark Verifier generator.
  
  Tests all option combinations, code generation patterns, and edge cases
  for the `mix spark.gen.verifier` task.
  """
  
  use Spark.Test.GeneratorTestCase
  
  # Only run tests if Igniter is available
  @igniter_available Code.ensure_loaded?(Igniter)

  if @igniter_available do
    alias Mix.Tasks.Spark.Gen.Verifier, as: VerifierGenerator

    describe "task info/2" do
      test "returns correct task information" do
        info = VerifierGenerator.info([], nil)
        
        assert info.positional == [:verifier_module]
        assert info.example =~ "mix spark.gen.verifier MyApp.Verifiers.ValidateNotGandalf"
        
        # Verify schema contains all expected options
        expected_options = [
          :dsl, :sections, :checks, :error_module, :examples, :ignore_if_exists
        ]
        
        schema_keys = Keyword.keys(info.schema)
        for option <- expected_options do
          assert option in schema_keys, "Missing option #{option} in schema"
        end
        
        # Verify aliases
        expected_aliases = [d: :dsl, s: :sections, c: :checks, e: :error_module]
        for {alias_key, target} <- expected_aliases do
          assert info.aliases[alias_key] == target
        end
      end
    end

    describe "basic verifier generation" do
      test "generates verifier with minimal options" do
        igniter = mock_igniter(%{verifier_module: "MyApp.Verifiers.Simple"})
        
        result = VerifierGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Verifiers.Simple", [
          "use Spark.Dsl.Verifier",
          "@impl Spark.Dsl.Verifier",
          "def verify(dsl_state)",
          "alias Spark.Error.DslError"
        ])
      end

      test "includes proper documentation" do
        igniter = mock_igniter(%{verifier_module: "MyApp.Verifiers.Documented"})
        
        result = VerifierGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Verifiers.Documented", [
          "@moduledoc \"\"\"",
          "DSL verifier for documented",
          "This verifier validates the final DSL state"
        ])
      end

      test "respects --ignore-if-exists flag" do
        igniter = mock_igniter(
          %{verifier_module: "MyApp.Verifiers.Existing"}, 
          [ignore_if_exists: true]
        )
        
        result = VerifierGenerator.igniter(igniter)
        assert is_map(result)
      end
    end

    describe "sections configuration" do
      test "parses single section correctly" do
        igniter = mock_igniter(
          %{verifier_module: "MyApp.Verifiers.SingleSection"}, 
          [sections: "resources"]
        )
        
        result = VerifierGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Verifiers.SingleSection", [
          "defp get_resources(dsl_state)",
          "defp validate_resources_structure(dsl_state)"
        ])
      end

      test "parses multiple sections correctly" do
        igniter = mock_igniter(
          %{verifier_module: "MyApp.Verifiers.MultiSection"}, 
          [sections: "resources,policies,config"]
        )
        
        result = VerifierGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Verifiers.MultiSection", [
          "defp get_resources(dsl_state)",
          "defp get_policies(dsl_state)",
          "defp get_config(dsl_state)",
          "defp validate_resources_structure(dsl_state)",
          "defp validate_policies_structure(dsl_state)",
          "defp validate_config_structure(dsl_state)"
        ])
      end
    end

    describe "validation checks generation" do
      test "generates single custom check" do
        igniter = mock_igniter(
          %{verifier_module: "MyApp.Verifiers.SingleCheck"}, 
          [checks: "validate_email"]
        )
        
        result = VerifierGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Verifiers.SingleCheck", [
          "defp validate_custom_checks(dsl_state)",
          "defp validate_validate_email(dsl_state)",
          "# TODO: Implement Validate email validation"
        ])
      end

      test "generates multiple custom checks" do
        igniter = mock_igniter(
          %{verifier_module: "MyApp.Verifiers.MultiCheck"}, 
          [checks: "validate_email,check_permissions,verify_config"]
        )
        
        result = VerifierGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Verifiers.MultiCheck", [
          "defp validate_validate_email(dsl_state)",
          "defp validate_check_permissions(dsl_state)",
          "defp validate_verify_config(dsl_state)"
        ])
      end
    end

    describe "error module configuration" do
      test "uses default error module when not specified" do
        igniter = mock_igniter(%{verifier_module: "MyApp.Verifiers.DefaultError"})
        
        result = VerifierGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Verifiers.DefaultError", [
          "alias Spark.Error.DslError"
        ])
      end

      test "uses custom error module when specified" do
        igniter = mock_igniter(
          %{verifier_module: "MyApp.Verifiers.CustomError"}, 
          [error_module: "MyApp.CustomError"]
        )
        
        result = VerifierGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Verifiers.CustomError", [
          "alias MyApp.CustomError"
        ])
      end
    end

    describe "examples generation" do
      test "generates examples when requested" do
        igniter = mock_igniter(
          %{verifier_module: "MyApp.Verifiers.WithExamples"}, 
          [
            examples: true,
            dsl: "MyApp.TestDsl",
            sections: "resources,policies",
            checks: "validate_names,check_permissions"]
        )
        
        result = VerifierGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Verifiers.WithExamples", [
          "## Usage",
          "Add this verifier to your DSL extension:",
          "use Spark.Dsl.Extension,",
          "verifiers: [MyApp.Verifiers.WithExamples]",
          "Or in MyApp.TestDsl:",
          "defmodule MyApp.TestDsl do"
        ])
      end
    end

    describe "complex configurations" do
      test "generates verifier with all options" do
        igniter = mock_igniter(
          %{verifier_module: "MyApp.Verifiers.Complete"}, 
          [
            dsl: "MyApp.CompleteDsl",
            sections: "resources,policies,config",
            checks: "validate_names,check_permissions,verify_structure",
            error_module: "MyApp.CustomError",
            examples: true
          ]
        )
        
        result = VerifierGenerator.igniter(igniter)
        
        expected_patterns = [
          "use Spark.Dsl.Verifier",
          "alias MyApp.CustomError",
          "def verify(dsl_state)",
          "validate_custom_checks(dsl_state)",
          "defp validate_validate_names(dsl_state)",
          "defp validate_check_permissions(dsl_state)",
          "defp validate_verify_structure(dsl_state)",
          "defp get_resources(dsl_state)",
          "defp get_policies(dsl_state)",
          "defp get_config(dsl_state)",
          "## Usage",
          "defmodule MyApp.CompleteDsl do"
        ]
        
        assert_module_created(result, "MyApp.Verifiers.Complete", expected_patterns)
      end
    end

    describe "edge cases and error handling" do
      test "handles nil options gracefully" do
        igniter = mock_igniter(
          %{verifier_module: "MyApp.Verifiers.NilOptions"}, 
          [dsl: nil, sections: nil, checks: nil, error_module: nil]
        )
        
        result = VerifierGenerator.igniter(igniter)
        
        assert_module_created(result, "MyApp.Verifiers.NilOptions")
      end

      test "handles very long module names" do
        long_name = "MyApp.Very.Long.Nested.Module.Path.Verifiers.VeryLongVerifierName"
        igniter = mock_igniter(%{verifier_module: long_name})
        
        result = VerifierGenerator.igniter(igniter)
        assert is_map(result)
      end
    end
  else
    # Fallback tests when Igniter is not available
    test "requires Igniter to be available" do
      assert_raise RuntimeError, ~r/requires igniter/, fn ->
        Mix.Tasks.Spark.Gen.Verifier.run(["MyApp.TestVerifier"])
      end
    end
  end
end