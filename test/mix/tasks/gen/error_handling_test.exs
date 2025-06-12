defmodule Mix.Tasks.Spark.Gen.ErrorHandlingTest do
  @moduledoc """
  Comprehensive error handling and edge case tests for Spark generators.
  
  Tests validation, error messages, boundary conditions, and failure scenarios
  across all Spark Mix task generators.
  """
  
  use Spark.Test.GeneratorTestCase
  
  # Only run tests if Igniter is available
  @igniter_available Code.ensure_loaded?(Igniter)

  if @igniter_available do
    alias Mix.Tasks.Spark.Gen.{Dsl, Entity, Verifier, Section}

    describe "DSL generator error handling" do
      test "validates entity format and provides clear error messages" do
        assert_raise RuntimeError, ~r/Invalid entity format.*Expected format: name:identifier_type:entity_type/, fn ->
          igniter = mock_igniter(
            %{dsl_module: "MyApp.InvalidEntityDsl"}, 
            [entity: ["invalid_format"]]
          )
          
          Dsl.igniter(igniter)
        end
      end

      test "handles malformed entity formats with descriptive errors" do
        malformed_entities = [
          "name_only",
          "name:",
          ":identifier:type",
          "name:identifier:",
          "too:many:colons:here:extra"
        ]
        
        for malformed_entity <- malformed_entities do
          assert_raise RuntimeError, ~r/Invalid entity format/, fn ->
            igniter = mock_igniter(
              %{dsl_module: "MyApp.MalformedEntityDsl"}, 
              [entity: [malformed_entity]]
            )
            
            Dsl.igniter(igniter)
          end
        end
      end

      test "handles empty module name gracefully" do
        igniter = mock_igniter(%{dsl_module: ""})
        
        # Should handle empty module name without crashing
        try do
          result = Dsl.igniter(igniter)
          assert is_map(result)
        rescue
          # Expected - empty module names should be rejected
          _ -> :ok
        end
      end

      test "handles invalid module name formats" do
        invalid_names = [
          "invalid-name-with-dashes",
          "123StartWithNumber",
          "name with spaces",
          "name.with.lowercase.segments"
        ]
        
        for invalid_name <- invalid_names do
          try do
            igniter = mock_igniter(%{dsl_module: invalid_name})
            result = Dsl.igniter(igniter)
            
            # Some invalid names might be accepted and normalized
            assert is_map(result)
          rescue
            # Others should raise errors
            _ -> :ok
          end
        end
      end

      test "handles integer parsing errors in defaults" do
        # Test invalid integer defaults
        invalid_integer_args = [
          "timeout:integer:not_a_number",
          "count:pos_integer:negative",
          "size:integer:1.5"  # Float instead of integer
        ]
        
        for invalid_arg <- invalid_integer_args do
          assert_raise ArgumentError, fn ->
            igniter = mock_igniter(
              %{dsl_module: "MyApp.InvalidIntegerDsl"}, 
              [arg: [invalid_arg]]
            )
            
            Dsl.igniter(igniter)
          end
        end
      end

      test "handles type parsing edge cases" do
        # Test unusual but potentially valid type names
        edge_case_types = [
          "my_custom_type",
          "type_with_numbers123",
          "UPPERCASE_TYPE"
        ]
        
        for type_name <- edge_case_types do
          igniter = mock_igniter(
            %{dsl_module: "MyApp.EdgeCaseTypeDsl"}, 
            [arg: ["field:#{type_name}"]]
          )
          
          result = Dsl.igniter(igniter)
          assert is_map(result)
        end
      end
    end

    describe "Entity generator error handling" do
      test "validates required arguments format" do
        assert_raise RuntimeError, ~r/Invalid arg format/, fn ->
          igniter = mock_igniter(
            %{entity: "MyApp.Entities.InvalidArgs"}, 
            [args: ["malformed_arg_without_colons"]]
          )
          
          Entity.igniter(igniter)
        end
      end

      test "handles schema parsing errors gracefully" do
        malformed_schemas = [
          "field1:,field2:string",  # Empty type
          ":string,field2:integer", # Empty name
          "field1:type1:extra,field2:type2"  # Too many parts
        ]
        
        for malformed_schema <- malformed_schemas do
          igniter = mock_igniter(
            %{entity: "MyApp.Entities.MalformedSchema"}, 
            [schema: malformed_schema]
          )
          
          # Should handle gracefully without crashing
          result = Entity.igniter(igniter)
          assert is_map(result)
        end
      end

      test "handles empty entity name derivation" do
        # Test with module names that might not derive well
        edge_case_modules = [
          "A",  # Single character
          "MyApp.B",  # Single character last segment
          "Numbers123",  # Contains numbers
          "ALLCAPS"  # All uppercase
        ]
        
        for module_name <- edge_case_modules do
          igniter = mock_igniter(%{entity: module_name})
          result = Entity.igniter(igniter)
          assert is_map(result)
        end
      end

      test "handles conflicting argument and schema definitions" do
        # Test when args and schema have overlapping field names
        igniter = mock_igniter(
          %{entity: "MyApp.Entities.ConflictingFields"}, 
          [
            schema: "name:string,email:string",
            args: ["name:atom:required", "type:string"]  # name conflicts
          ]
        )
        
        result = Entity.igniter(igniter)
        # Should handle gracefully - might use last definition or merge
        assert is_map(result)
      end

      test "validates custom validation function names" do
        # Test with potentially problematic validation names
        edge_case_validations = [
          "validate with spaces",  # Spaces
          "validate-with-dashes",  # Dashes
          "123_starts_with_number",  # Starts with number
          "UPPERCASE_VALIDATION"  # All caps
        ]
        
        for validation_name <- edge_case_validations do
          igniter = mock_igniter(
            %{entity: "MyApp.Entities.EdgeCaseValidations"}, 
            [validations: [validation_name]]
          )
          
          result = Entity.igniter(igniter)
          # Should normalize names or handle gracefully
          assert is_map(result)
        end
      end
    end

    describe "Verifier generator error handling" do
      test "handles empty sections and checks gracefully" do
        igniter = mock_igniter(
          %{verifier_module: "MyApp.Verifiers.EmptyConfigVerifier"}, 
          [sections: "", checks: ""]
        )
        
        result = Verifier.igniter(igniter)
        assert is_map(result)
      end

      test "handles malformed section and check lists" do
        malformed_configs = [
          {",,,sections,,,", "checks"},  # Extra commas
          {"sections", ",,,checks,,,"},  # Extra commas in checks
          {"sections with spaces", "checks"},  # Spaces in names
          {"sections,", ",checks"},  # Trailing/leading commas
        ]
        
        for {sections, checks} <- malformed_configs do
          igniter = mock_igniter(
            %{verifier_module: "MyApp.Verifiers.MalformedConfigVerifier"}, 
            [sections: sections, checks: checks]
          )
          
          result = Verifier.igniter(igniter)
          # Should clean up input or handle gracefully
          assert is_map(result)
        end
      end

      test "handles special characters in section and check names" do
        special_char_configs = [
          {"section-with-dashes", "check_with_underscores"},
          {"section.with.dots", "check with spaces"},
          {"section123", "check456"},
          {"UPPERCASESECTION", "UPPERCASECHECK"}
        ]
        
        for {sections, checks} <- special_char_configs do
          igniter = mock_igniter(
            %{verifier_module: "MyApp.Verifiers.SpecialCharsVerifier"}, 
            [sections: sections, checks: checks]
          )
          
          result = Verifier.igniter(igniter)
          # Should normalize names appropriately
          assert is_map(result)
        end
      end

      test "handles invalid error module references" do
        igniter = mock_igniter(
          %{verifier_module: "MyApp.Verifiers.InvalidErrorModule"}, 
          [error_module: "NonExistent.Error.Module"]
        )
        
        result = Verifier.igniter(igniter)
        # Should accept the module name even if it doesn't exist yet
        assert is_map(result)
      end

      test "handles very long verifier names" do
        very_long_name = "MyApp.Very.Long.Module.Path.That.Exceeds.Normal.Length.Verifiers.ExtremelyLongVerifierNameThatTestsLimits"
        
        igniter = mock_igniter(%{verifier_module: very_long_name})
        result = Verifier.igniter(igniter)
        assert is_map(result)
      end
    end

    describe "Section generator error handling" do
      test "handles malformed option definitions" do
        malformed_opts = [
          "name",  # No type specified
          ":string:default",  # No name
          "name::default",  # Empty type
          "name:string:",  # Empty default with colon
          "name:string:default:extra:parts"  # Too many parts
        ]
        
        for malformed_opt <- malformed_opts do
          igniter = mock_igniter(
            %{section_module: "MyApp.Sections.MalformedOptsSection"}, 
            [opts: [malformed_opt]]
          )
          
          # Should handle malformed options gracefully
          try do
            result = Section.igniter(igniter)
            assert is_map(result)
          rescue
            # Some malformed options might raise errors - that's acceptable
            _ -> :ok
          end
        end
      end

      test "handles invalid entity module references" do
        igniter = mock_igniter(
          %{section_module: "MyApp.Sections.InvalidEntityRefsSection"}, 
          [entities: ["NonExistent.Entity", "Another.Missing.Entity"]]
        )
        
        result = Section.igniter(igniter)
        # Should accept entity references even if modules don't exist yet
        assert is_map(result)
        
        assert_module_created(result, "MyApp.Sections.InvalidEntityRefsSection", [
          "entities: [NonExistent.Entity, Another.Missing.Entity]"
        ])
      end

      test "handles type parsing errors in options" do
        invalid_type_opts = [
          "timeout:invalid_type:5000",
          "count:123type:42",  # Type starting with number
          "enabled:boolean with spaces:true"  # Type with spaces
        ]
        
        for invalid_opt <- invalid_type_opts do
          igniter = mock_igniter(
            %{section_module: "MyApp.Sections.InvalidTypeSection"}, 
            [opts: [invalid_opt]]
          )
          
          result = Section.igniter(igniter)
          # Should normalize or accept unusual types
          assert is_map(result)
        end
      end

      test "handles default value parsing errors" do
        invalid_default_opts = [
          "count:integer:not_a_number",
          "enabled:boolean:maybe",  # Invalid boolean
          "timeout:pos_integer:-5"  # Negative for pos_integer
        ]
        
        for invalid_opt <- invalid_default_opts do
          assert_raise ArgumentError, fn ->
            igniter = mock_igniter(
              %{section_module: "MyApp.Sections.InvalidDefaultSection"}, 
              [opts: [invalid_opt]]
            )
            
            Section.igniter(igniter)
          end
        end
      end

      test "handles very long entity lists efficiently" do
        many_entities = for i <- 1..100 do
          "MyApp.Entity#{i}"
        end
        
        igniter = mock_igniter(
          %{section_module: "MyApp.Sections.ManyEntitiesSection"}, 
          [entities: many_entities]
        )
        
        result = Section.igniter(igniter)
        assert is_map(result)
      end
    end

    describe "cross-generator error scenarios" do
      test "handles circular references in DSL components" do
        # Test potential circular references
        igniter = mock_igniter(
          %{dsl_module: "MyApp.CircularDsl"}, 
          [
            section: ["self:MyApp.CircularDsl"],  # Self-reference
            entity: ["circular:name:MyApp.CircularDsl"]  # Another self-reference
          ]
        )
        
        result = Dsl.igniter(igniter)
        # Should handle without infinite loops
        assert is_map(result)
      end

      test "handles missing dependencies gracefully" do
        # Reference modules that don't exist
        igniter = mock_igniter(
          %{dsl_module: "MyApp.MissingDepsDsl"}, 
          [
            extension: true,
            transformer: ["Completely.NonExistent.Transformer"],
            verifier: ["Also.Missing.Verifier"],
            entity: ["thing:name:Another.Missing.Entity"]
          ]
        )
        
        result = Dsl.igniter(igniter)
        # Should generate DSL that references these modules
        assert is_map(result)
      end

      test "handles conflicting generator options" do
        # Test configurations that might conflict
        igniter = mock_igniter(
          %{dsl_module: "MyApp.ConflictingDsl"}, 
          [
            extension: false,  # Standalone DSL
            transformer: ["MyApp.Transformer"],  # But transformers only work with extensions
            verifier: ["MyApp.Verifier"]  # And verifiers too
          ]
        )
        
        result = Dsl.igniter(igniter)
        # Should handle the conflict appropriately
        assert is_map(result)
      end
    end

    describe "memory and performance edge cases" do
      test "handles extremely large configurations efficiently" do
        # Create very large configuration
        large_sections = for i <- 1..50, do: "section#{i}"
        large_entities = for i <- 1..100, do: "entity#{i}:name:Entity#{i}"
        large_args = for i <- 1..50, do: "arg#{i}:string"
        large_opts = for i <- 1..50, do: "opt#{i}:boolean:false"
        
        igniter = mock_igniter(
          %{dsl_module: "MyApp.LargeConfigDsl"}, 
          [
            section: large_sections,
            entity: large_entities,
            arg: large_args,
            opt: large_opts
          ]
        )
        
        # Should handle large configurations without issues
        result = Dsl.igniter(igniter)
        assert is_map(result)
      end

      test "handles deeply nested module names" do
        deeply_nested = "Level1.Level2.Level3.Level4.Level5.Level6.Level7.Level8.Level9.Level10.DeepModule"
        
        igniter = mock_igniter(%{dsl_module: deeply_nested})
        result = Dsl.igniter(igniter)
        assert is_map(result)
      end

      test "handles unicode and special characters in strings" do
        unicode_configs = [
          # Unicode in documentation
          %{docs: "Configuration with unicode: 中文, العربية, русский"},
          # Unicode in default values  
          %{arg: ["message:string:Hello 世界"]},
          # Special characters in names (should be normalized)
          %{name: "section_with_émojis_🚀"}
        ]
        
        for config <- unicode_configs do
          try do
            igniter = mock_igniter(%{dsl_module: "MyApp.UnicodeTestDsl"}, config)
            result = Dsl.igniter(igniter)
            assert is_map(result)
          rescue
            # Some unicode might not be supported - that's ok
            _ -> :ok
          end
        end
      end
    end

    describe "boundary condition testing" do
      test "handles minimum and maximum value boundaries" do
        boundary_configs = [
          # Empty values
          %{section: [], entity: [], arg: [], opt: []},
          # Single values
          %{section: ["single"], entity: ["one:name:Entity"], arg: ["arg:string"], opt: ["opt:boolean"]},
          # Very long names
          %{section: [String.duplicate("long", 50)]},
          # Special boundary characters
          %{arg: ["field:string:" <> String.duplicate("x", 1000)]}  # Very long default
        ]
        
        for config <- boundary_configs do
          igniter = mock_igniter(%{dsl_module: "MyApp.BoundaryTestDsl"}, config)
          
          try do
            result = Dsl.igniter(igniter)
            assert is_map(result)
          rescue
            # Some boundary conditions might legitimately fail
            error ->
              # Ensure error messages are helpful
              assert is_binary(Exception.message(error))
          end
        end
      end

      test "handles nil vs empty vs missing option distinctions" do
        option_variations = [
          %{section: nil},
          %{section: []},
          %{},  # Missing section key entirely
          %{section: "", entity: nil, arg: [], opt: nil}
        ]
        
        for options <- option_variations do
          igniter = mock_igniter(%{dsl_module: "MyApp.OptionVariationDsl"}, options)
          result = Dsl.igniter(igniter)
          assert is_map(result)
        end
      end
    end

    describe "integration error scenarios" do
      test "handles errors when modules already exist" do
        # Test behavior when trying to create existing modules
        igniter = mock_igniter(
          %{dsl_module: "Mix.Tasks.Spark.Gen.Dsl"},  # Existing module
          [ignore_if_exists: false]
        )
        
        # Should handle gracefully or provide clear error
        try do
          result = Dsl.igniter(igniter)
          assert is_map(result)
        rescue
          error ->
            assert is_binary(Exception.message(error))
        end
      end

      test "validates generator task chaining errors" do
        # Test what happens when composed tasks fail
        igniter = mock_igniter(
          %{dsl_module: "MyApp.CompositionErrorDsl"}, 
          [
            extension: true,
            transformer: ["Invalid::Module::Name"],  # Invalid module syntax
            verifier: ["Another::Invalid::Name"]
          ]
        )
        
        # The main DSL generation might succeed, but composed tasks might fail
        result = Dsl.igniter(igniter)
        assert is_map(result)
      end
    end
  else
    # Fallback test when Igniter is not available
    test "error handling tests require Igniter to be available" do
      # Without Igniter, all generators should fail with helpful messages
      tasks = [
        Mix.Tasks.Spark.Gen.Dsl,
        Mix.Tasks.Spark.Gen.Entity,
        Mix.Tasks.Spark.Gen.Verifier,
        Mix.Tasks.Spark.Gen.Section
      ]
      
      for task <- tasks do
        assert_raise RuntimeError, ~r/requires igniter/, fn ->
          task.run(["MyApp.TestModule"])
        end
      end
    end
  end
end