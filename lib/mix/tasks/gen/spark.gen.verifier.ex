if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Spark.Gen.Verifier do
    @example """
    mix spark.gen.verifier MyApp.Verifiers.ValidateNotGandalf \\
      --dsl MyApp.Dsl \\
      --sections fields,relationships \\
      --checks name_not_gandalf,email_required
    """
    
    @moduledoc """
    Generate a Spark DSL Verifier.

    Verifiers validate the final DSL state after all transformations are complete.
    They ensure that the DSL configuration is valid and meets business rules.

    ## Example

    ```bash
    #{@example}
    ```

    ## Options

    * `--dsl` or `-d` - The DSL module this verifier belongs to.
    * `--sections` or `-s` - Sections this verifier should validate.
    * `--checks` or `-c` - Specific validation checks to implement.
    * `--error-module` - Custom error module for validation failures.
    * `--examples` - Generate example usage documentation.
    * `--ignore-if-exists` - Does nothing if the verifier already exists.
    """

    @shortdoc "Generate a Spark DSL Verifier."
    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        positional: [:verifier_module],
        example: @example,
        schema: [
          dsl: :string,
          sections: :string,
          checks: :string,
          error_module: :string,
          examples: :boolean,
          ignore_if_exists: :boolean
        ],
        aliases: [
          d: :dsl,
          s: :sections,
          c: :checks,
          e: :error_module
        ]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      verifier_module = Igniter.Project.Module.parse(igniter.args.positional.verifier_module)
      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, verifier_module)

      if igniter.args.options[:ignore_if_exists] && exists? do
        igniter
      else
        options = igniter.args.options
        
        dsl = options[:dsl]
        sections = parse_sections(options[:sections])
        checks = parse_checks(options[:checks])
        error_module = options[:error_module] || "Spark.Error.DslError"
        
        examples = if options[:examples] do
          build_examples(verifier_module, dsl, sections, checks)
        end

        igniter
        |> Igniter.Project.Module.create_module(
          verifier_module,
          """
          defmodule #{inspect(verifier_module)} do
            @moduledoc \"\"\"
            DSL verifier for #{verifier_name(verifier_module)}.
            
            This verifier validates the final DSL state after all transformations
            are complete. It ensures the configuration meets business rules and
            constraints.
            #{examples}
            \"\"\"

            use Spark.Dsl.Verifier

            alias #{error_module}

            @doc \"\"\"
            Verify the DSL state.
            
            This function is called after all transformers have run and receives
            the final DSL state. It should return `:ok` for valid configurations
            or `{:error, reason}` for invalid ones.
            \"\"\"
            @impl Spark.Dsl.Verifier
            def verify(dsl_state) do
              # Run all validation checks
              with :ok <- validate_structure(dsl_state),
                   :ok <- validate_business_rules(dsl_state),
                   #{build_check_validations(checks, sections)} do
                :ok
              else
                {:error, reason} -> {:error, reason}
                error -> {:error, \"Validation failed: \#{inspect(error)}\"}
              end
            end

            # Validation functions

            defp validate_structure(dsl_state) do
              # TODO: Implement structural validation
              # Example: Check that required sections exist
              # Example: Validate entity relationships
              :ok
            end

            defp validate_business_rules(dsl_state) do
              # TODO: Implement business rule validation
              # Example: Check that certain combinations are valid
              # Example: Validate cross-entity constraints
              :ok
            end

            #{build_check_functions(checks, sections)}

            # Helper functions

            defp get_entities(dsl_state, section_path) do
              Spark.Dsl.Transformer.get_entities(dsl_state, section_path) || []
            end

            defp get_options(dsl_state, section_path) do
              Spark.Dsl.Transformer.get_option(dsl_state, section_path) || []
            end

            defp validation_error(message) do
              {:error, DslError.exception(message: message)}
            end

            defp validation_error(message, opts) do
              {:error, DslError.exception([message: message] ++ opts)}
            end

            #{build_section_helpers(sections)}
          end
          """
        )
      end
    end

    defp verifier_name(verifier_module) do
      verifier_module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
      |> String.replace("_", " ")
    end

    defp parse_sections(nil), do: []
    defp parse_sections(sections_string) do
      sections_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.to_atom/1)
    end

    defp parse_checks(nil), do: []
    defp parse_checks(checks_string) do
      checks_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.to_atom/1)
    end

    defp build_check_validations([], _sections), do: ":ok <- :ok"
    defp build_check_validations(checks, _sections) do
      if Enum.empty?(checks) do
        ":ok <- :ok"
      else
        ":ok <- validate_custom_checks(dsl_state)"
      end
    end

    defp build_check_functions([], _sections), do: ""
    defp build_check_functions(checks, sections) do
      individual_checks = checks
                         |> Enum.map_join("\n\n", &build_check_function(&1, sections))

      """
      defp validate_custom_checks(dsl_state) do
        # Run all custom validation checks
        #{checks |> Enum.map_join("\n        ", fn check -> 
          "with :ok <- validate_#{check}(dsl_state) do"
        end)}
        #{String.duplicate("        ", length(checks))}:ok
        #{checks |> Enum.map(fn _ -> "      end" end) |> Enum.join("\n")}
      end

      #{individual_checks}
      """
    end

    defp build_check_function(check, sections) do
      check_doc = check
                 |> Atom.to_string()
                 |> String.replace("_", " ")
                 |> String.capitalize()

      section_examples = sections
                        |> Enum.take(2)
                        |> Enum.map_join("\n", fn section ->
                          "      entities = get_entities(dsl_state, [:#{section}])"
                        end)

      """
      defp validate_#{check}(dsl_state) do
        # TODO: Implement #{check_doc} validation
        #{section_examples}
        
        # Example validation logic:
        # case some_condition do
        #   true -> :ok
        #   false -> validation_error("#{check_doc} validation failed")
        # end
        
        :ok
      end
      """
    end

    defp build_section_helpers([]), do: ""
    defp build_section_helpers(sections) do
      section_functions = sections
                         |> Enum.map_join("\n\n", &build_section_helper/1)

      """
      # Section-specific helper functions

      #{section_functions}
      """
    end

    defp build_section_helper(section) do
      section_name = Atom.to_string(section)
      
      """
      defp get_#{section_name}(dsl_state) do
        get_entities(dsl_state, [:#{section}])
      end

      defp validate_#{section_name}_structure(dsl_state) do
        #{section_name} = get_#{section_name}(dsl_state)
        
        # TODO: Add #{section_name} specific validation
        # Example: Check required fields, validate types, etc.
        
        :ok
      end
      """
    end

    defp build_examples(verifier_module, dsl, sections, checks) do
      dsl_name = if dsl, do: dsl, else: "YourDsl"
      
      check_examples = checks
                      |> Enum.take(2)
                      |> Enum.map_join("\n", fn check ->
                        "  - #{check |> Atom.to_string() |> String.replace("_", " ")}"
                      end)

      section_examples = sections
                        |> Enum.take(3)
                        |> Enum.map_join("\n", fn section ->
                          "  - #{section} entities and options"
                        end)

      """
      
      ## Usage
      
      Add this verifier to your DSL extension:
      
      ```elixir
      use Spark.Dsl.Extension,
        verifiers: [#{inspect(verifier_module)}]
      ```
      
      Or in #{dsl_name}:
      
      ```elixir
      defmodule #{dsl_name} do
        use Spark.Dsl.Extension,
          verifiers: [
            # ... other verifiers
            #{inspect(verifier_module)}
          ]
      end
      ```
      
      ## Validation Checks
      
      This verifier validates:
      #{check_examples}
      
      ## Validated Sections
      
      #{section_examples}
      
      ## Example Errors
      
      ```elixir
      # This configuration would fail validation:
      defmodule MyResource do
        use #{dsl_name}
        
        # Invalid configuration that triggers verifier
      end
      
      # Error: #{verifier_name(verifier_module)} validation failed
      ```
      """
    end
  end
else
  defmodule Mix.Tasks.Spark.Gen.Verifier do
    @moduledoc """
    Generate a Spark DSL Verifier.
    """

    @shortdoc "Generate a Spark DSL Verifier."

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'spark.gen.verifier' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end