if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Spark.Gen.Info do
    @example """
    mix spark.gen.info MyApp.Resource.Info \\
      --extension MyApp.Resource.Dsl \\
      --sections fields,relationships,policies \\
      --functions get_field,get_relationship
    """
    
    @moduledoc """
    Generate a Spark DSL info module.

    Info modules provide runtime introspection capabilities for DSL-configured modules.
    They use Spark.InfoGenerator to create functions for accessing DSL data.

    ## Example

    ```bash
    #{@example}
    ```

    ## Options

    * `--extension` or `-e` - The DSL extension this info module introspects.
    * `--sections` or `-s` - Comma-separated list of sections to include.
    * `--functions` or `-f` - Custom functions to generate for data access.
    * `--opts` - Options to pass to the InfoGenerator.
    * `--examples` - Generate example usage documentation.
    * `--ignore-if-exists` - Does nothing if the info module already exists.
    """

    @shortdoc "Generate a Spark DSL info module."
    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        positional: [:info_module],
        example: @example,
        schema: [
          extension: :string,
          sections: :string,
          functions: :string,
          opts: :string,
          examples: :boolean,
          ignore_if_exists: :boolean
        ],
        aliases: [
          e: :extension,
          s: :sections,
          f: :functions,
          o: :opts
        ]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      info_module = Igniter.Project.Module.parse(igniter.args.positional.info_module)
      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, info_module)

      if igniter.args.options[:ignore_if_exists] && exists? do
        igniter
      else
        options = igniter.args.options
        
        extension = options[:extension] || infer_extension(info_module)
        sections = parse_sections(options[:sections])
        custom_functions = parse_functions(options[:functions])
        info_opts = parse_opts(options[:opts])
        
        examples = if options[:examples] do
          build_examples(info_module, extension, sections, custom_functions)
        end

        igniter
        |> Igniter.Project.Module.create_module(
          info_module,
          """
          defmodule #{inspect(info_module)} do
            @moduledoc \"\"\"
            Info module for #{extension || "DSL"} introspection.
            
            This module provides runtime access to DSL configuration data.
            It uses Spark.InfoGenerator to create functions for querying entities,
            options, and other DSL state.
            #{examples}
            \"\"\"

            use Spark.InfoGenerator,
              extension: #{extension || "YourDslExtension"},
              sections: #{inspect(sections)}#{info_opts}

            #{build_custom_functions(custom_functions, sections)}

            #{build_helper_functions(sections)}
          end
          """
        )
      end
    end

    defp infer_extension(info_module) do
      info_module
      |> Module.split()
      |> Enum.drop(-1)
      |> Kernel.++(["Dsl"])
      |> Module.concat()
      |> inspect()
    end

    defp parse_sections(nil), do: []
    defp parse_sections(""), do: []
    defp parse_sections(sections_string) do
      sections_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.to_atom/1)
    end

    defp parse_functions(nil), do: []
    defp parse_functions(""), do: []
    defp parse_functions(functions_string) do
      functions_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.filter(&valid_function_name?/1)
      |> Enum.map(&String.to_atom/1)
    end

    defp valid_function_name?(name) do
      # Function names must start with lowercase letter or underscore
      Regex.match?(~r/^[a-z_][a-zA-Z0-9_]*$/, name)
    end

    defp parse_opts(nil), do: ""
    defp parse_opts(opts_string) do
      """
              #{opts_string}
      """
    end

    defp build_custom_functions([], _sections), do: ""
    defp build_custom_functions(functions, sections) do
      functions
      |> Enum.map_join("\n\n", fn function_name ->
        build_custom_function(function_name, sections)
      end)
      |> then(fn funcs -> "\n  # Custom helper functions\n\n#{funcs}" end)
    end

    defp build_custom_function(function_name, sections) do
      function_doc = function_name
                    |> Atom.to_string()
                    |> String.replace("_", " ")
                    |> String.capitalize()

      section_examples = sections
                        |> Enum.take(2)
                        |> Enum.map_join(", ", &":#{&1}")

      """
        @doc \"\"\"
        #{function_doc} from the DSL configuration.
        
        ## Examples
        
        ```elixir
        #{function_name}(MyResource)
        #{function_name}(MyResource, :identifier)
        ```
        \"\"\"
        @spec #{function_name}(module() | Spark.Dsl.t()) :: term()
        @spec #{function_name}(module() | Spark.Dsl.t(), term()) :: term()
        def #{function_name}(dsl_or_module, identifier \\\\ nil) do
          # TODO: Implement custom function logic
          # You can use the generated functions like:
          # - entities(dsl_or_module, [#{section_examples}])
          # - options(dsl_or_module, [#{section_examples}])
          
          case identifier do
            nil -> 
              # Return all items
              []
            identifier ->
              # Return specific item by identifier
              nil
          end
        end
      """
    end

    defp build_helper_functions([]), do: ""
    defp build_helper_functions(sections) do
      section_functions = sections
                         |> Enum.map_join("\n\n", &build_section_function/1)

      """
      
        # Section-specific helper functions

        #{section_functions}

        @doc \"\"\"
        Get all configured sections.
        \"\"\"
        @spec configured_sections() :: [atom()]
        def configured_sections do
          #{inspect(sections)}
        end

        @doc \"\"\"
        Check if a section is configured.
        \"\"\"
        @spec has_section?(atom()) :: boolean()
        def has_section?(section_name) do
          section_name in configured_sections()
        end
      """
    end

    defp build_section_function(section) do
      section_name = Atom.to_string(section)
      function_name = "get_#{section_name}"
      single_function_name = section_name |> String.trim_trailing("s")

      """
        @doc \"\"\"
        Get all #{section_name} from the DSL configuration.
        \"\"\"
        @spec #{function_name}(module() | Spark.Dsl.t()) :: [term()]
        def #{function_name}(dsl_or_module) do
          entities(dsl_or_module, [:#{section}]) || []
        end

        @doc \"\"\"
        Get a specific #{single_function_name} by identifier.
        \"\"\"
        @spec get_#{single_function_name}(module() | Spark.Dsl.t(), term()) :: term() | nil
        def get_#{single_function_name}(dsl_or_module, identifier) do
          #{function_name}(dsl_or_module)
          |> Enum.find(fn entity ->
            # Assuming the entity has a name or identifier field
            Map.get(entity, :name) == identifier ||
            Map.get(entity, :identifier) == identifier
          end)
        end
      """
    end

    defp build_examples(info_module, _extension, sections, custom_functions) do
      section_examples = sections
                        |> Enum.take(3)
                        |> Enum.map_join("\n", fn section ->
                          "    entities = #{info_module}.get_#{section}(MyResource)"
                        end)

      custom_examples = custom_functions
                       |> Enum.take(2)  
                       |> Enum.map_join("\n", fn function ->
                         "    result = #{info_module}.#{function}(MyResource)"
                       end)

      """
      
      ## Usage
      
      Use this info module to introspect DSL-configured modules:
      
      ```elixir
      # In your application code
      defmodule MyApp.MyResource do
        use MyDsl
        
        # DSL configuration here
      end
      
      # Introspect the configuration
      #{section_examples}
      #{if custom_examples != "", do: custom_examples}
      
      # Check available sections
      sections = #{info_module}.configured_sections()
      
      # Check if specific section exists
      has_fields? = #{info_module}.has_section?(:fields)
      ```
      
      ## Generated Functions
      
      This module automatically generates functions for:
      #{sections |> Enum.map_join("\n", fn s -> "  - `get_#{s}/1` - Get all #{s}"end)}
      #{custom_functions |> Enum.map_join("\n", fn f -> "  - `#{f}/1` - Custom #{f} function" end)}
      """
    end
  end
else
  defmodule Mix.Tasks.Spark.Gen.Info do
    @moduledoc """
    Generate a Spark DSL info module.
    """

    @shortdoc "Generate a Spark DSL info module."

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'spark.gen.info' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end