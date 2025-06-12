if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Spark.Gen.Section do
    @example """
    mix spark.gen.section MyApp.Sections.Resources \\
      --name resources \\
      --entities MyApp.Resource \\
      --opts timeout:integer:5000 \\
      --docs "Configuration for application resources"
    """
    
    @moduledoc """
    Generate a Spark DSL Section.

    Sections are containers for entities and options in a DSL.
    They provide structure and organization for DSL configurations.

    ## Example

    ```bash
    #{@example}
    ```

    ## Options

    * `--name` or `-n` - The section name (defaults to module name).
    * `--entities` or `-e` - Entity modules this section contains.
    * `--opts` or `-o` - Section options as `name:type:default`.
    * `--docs` or `-d` - Documentation for the section.
    * `--examples` - Generate example usage documentation.
    * `--ignore-if-exists` - Does nothing if the section already exists.
    """

    @shortdoc "Generate a Spark DSL Section."
    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        positional: [:section_module],
        example: @example,
        schema: [
          name: :string,
          entities: :csv,
          opts: :csv,
          docs: :string,
          examples: :boolean,
          ignore_if_exists: :boolean
        ],
        aliases: [
          n: :name,
          e: :entities,
          o: :opts,
          d: :docs
        ]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      section_module = Igniter.Project.Module.parse(igniter.args.positional.section_module)
      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, section_module)

      if igniter.args.options[:ignore_if_exists] && exists? do
        igniter
      else
        options = igniter.args.options
        
        section_name = case options[:name] do
          nil -> 
            section_module
            |> Module.split()
            |> List.last()
            |> Macro.underscore()
            |> String.to_atom()
          name when is_binary(name) -> String.to_atom(name)
          name when is_atom(name) -> name
        end

        entities = build_entities(options[:entities])
        section_opts = build_section_opts(options[:opts])
        docs = options[:docs] || "Configuration for #{section_name}."
        
        examples = if options[:examples] do
          build_examples(section_name, options[:entities], options[:opts])
        end

        igniter
        |> Igniter.Project.Module.create_module(
          section_module,
          """
          defmodule #{inspect(section_module)} do
            @moduledoc \"\"\"
            #{section_name |> Atom.to_string() |> String.capitalize()} DSL section.
            
            #{docs}
            #{examples}
            \"\"\"

            use Spark.Dsl.Section

            @section %Spark.Dsl.Section{
              name: :#{section_name},
              describe: \"\"\"
              #{docs}
              \"\"\",
              #{entities}#{section_opts}
            }

            @doc \"\"\"
            Get the section definition.
            \"\"\"
            def section, do: @section

            #{build_helper_functions(section_name, options[:entities])}
          end
          """
        )
      end
    end

    defp build_entities(nil), do: ""
    defp build_entities([]), do: ""
    defp build_entities(entities) do
      entity_list = 
        entities
        |> Enum.map(&Module.concat([&1]))
        |> inspect()
      
      "entities: #{entity_list},\n              "
    end

    defp build_section_opts(nil), do: ""
    defp build_section_opts([]), do: ""
    defp build_section_opts(opts) do
      schema_fields = 
        opts
        |> Enum.map(&parse_opt/1)
        |> Enum.map(fn {name, type, default} ->
          default_part = if default, do: ", default: #{inspect(default)}", else: ""
          "#{name}: [type: #{inspect(type)}#{default_part}]"
        end)
        |> Enum.join(",\n                ")
      
      "schema: [\n                #{schema_fields}\n              ],\n              "
    end

    defp parse_opt(opt) do
      case String.split(opt, ":") do
        [name, type] ->
          {String.to_atom(name), parse_type(type), nil}
        [name, type, default] ->
          {String.to_atom(name), parse_type(type), parse_default(default, type)}
      end
    end

    defp parse_type(type) do
      case type do
        "atom" -> :atom
        "string" -> :string
        "boolean" -> :boolean
        "integer" -> :integer
        "pos_integer" -> :pos_integer
        "module" -> :module
        "keyword_list" -> :keyword_list
        "map" -> :map
        "list" -> {:list, :any}
        type -> String.to_atom(type)
      end
    end

    defp parse_default(default, type) do
      case type do
        "boolean" -> default == "true"
        "integer" -> String.to_integer(default)
        "pos_integer" -> String.to_integer(default)
        "atom" -> String.to_atom(default)
        _ -> default
      end
    end

    defp build_helper_functions(section_name, entities) do
      entity_functions = if entities && !Enum.empty?(entities) do
        """
        @doc \"\"\"
        Get all entities in this section.
        \"\"\"
        def get_entities(dsl_state) do
          Spark.Dsl.Transformer.get_entities(dsl_state, [:#{section_name}])
        end

        @doc \"\"\"
        Add an entity to this section.
        \"\"\"
        def add_entity(dsl_state, entity) do
          Spark.Dsl.Transformer.add_entity(dsl_state, [:#{section_name}], entity)
        end
        """
      end
      
      """
      @doc \"\"\"
      Get section options.
      \"\"\"
      def get_options(dsl_state) do
        Spark.Dsl.Transformer.get_option(dsl_state, [:#{section_name}])
      end

      #{entity_functions}
      """
    end

    defp build_examples(section_name, entities, opts) do
      entity_examples = if entities && !Enum.empty?(entities) do
        entity_name = entities |> List.first() |> String.split(".") |> List.last() |> Macro.underscore()
        """
        
        #{entity_name} :my_#{entity_name} do
          # Entity configuration
        end
        """
      end

      opt_examples = if opts && !Enum.empty?(opts) do
        opts
        |> Enum.take(2)
        |> Enum.map_join("\n        ", fn opt ->
          {name, type, default} = parse_opt(opt)
          value = default || example_value(type)
          "#{name} #{inspect(value)}"
        end)
      end

      """
      
      ## Usage
      
      Use this section in your DSL:
      
      ```elixir
      defmodule MyApp.MyResource do
        use MyDsl
        
        #{section_name} do
          #{opt_examples}#{entity_examples}
        end
      end
      ```
      """
    end

    defp example_value(:string), do: "example"
    defp example_value(:atom), do: :example
    defp example_value(:integer), do: 42
    defp example_value(:boolean), do: true
    defp example_value(_), do: nil
  end
else
  defmodule Mix.Tasks.Spark.Gen.Section do
    @moduledoc """
    Generate a Spark DSL Section.
    """

    @shortdoc "Generate a Spark DSL Section."

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'spark.gen.section' requires Igniter to be installed.

      Please install Igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end