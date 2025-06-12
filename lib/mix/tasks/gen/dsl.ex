if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Spark.Gen.Dsl do
    @example """
    mix spark.gen.dsl MyApp.MyDsl \\
      --section resources:MyApp.Resource \\
      --section policies \\
      --entity resource:name:module \\
      --entity policy:name:atom \\
      --arg timeout:pos_integer:5000 \\
      --opt verbose:boolean:false
    """
    
    @moduledoc """
    Generate a Spark DSL module with sections, entities, arguments and options.

    ## Example

    ```bash
    #{@example}
    ```

    ## Options

    * `--section` or `-s` - A section or comma separated list of sections to add, as `name` or `name:entity_module`.
    * `--entity` or `-e` - An entity definition as `name:identifier_type:entity_type`.
    * `--arg` or `-a` - An argument definition as `name:type:default`.
    * `--opt` or `-o` - An option definition as `name:type:default`.
    * `--singleton-entity` - Entity names that should be singletons (can only have one).
    * `--transformer` or `-t` - Transformers to add to the DSL.
    * `--verifier` or `-v` - Verifiers to add to the DSL.
    * `--extension` - Create as an extension rather than a standalone DSL.
    * `--fragments` - Enable DSL fragments support.
    * `--ignore-if-exists` - Does nothing if the DSL already exists.
    """

    @shortdoc "Generate a Spark DSL module."
    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        positional: [:dsl_module],
        example: @example,
        schema: [
          section: :csv,
          entity: :csv,
          arg: :csv,
          opt: :csv,
          singleton_entity: :csv,
          transformer: :csv,
          verifier: :csv,
          extension: :boolean,
          fragments: :boolean,
          ignore_if_exists: :boolean
        ],
        aliases: [
          s: :section,
          e: :entity,
          a: :arg,
          o: :opt,
          t: :transformer,
          v: :verifier
        ]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      dsl_module = Igniter.Project.Module.parse(igniter.args.positional.dsl_module)
      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, dsl_module)

      if igniter.args.options[:ignore_if_exists] && exists? do
        igniter
      else
        options = igniter.args.options
        
        sections = build_sections(options)
        entities = build_entities(options)
        args = build_args(options)
        opts = build_opts(options)
        transformers = build_transformers(options)
        verifiers = build_verifiers(options)
        
        use_statement = if options[:extension] do
          "use Spark.Dsl.Extension, transformers: #{inspect(transformers)}, verifiers: #{inspect(verifiers)}"
        else
          "use Spark.Dsl"
        end

        fragments = if options[:fragments] do
          """
          @fragments [
            # Add fragment modules here
          ]
          
          use Spark.Dsl.Fragment, fragments: @fragments
          """
        end

        igniter
        |> Igniter.Project.Module.create_module(
          dsl_module,
          """
          #{use_statement}

          #{fragments}

          @moduledoc \"\"\"
          DSL for #{inspect(dsl_module)}.
          \"\"\"

          #{sections}

          #{entities}

          #{args}

          #{opts}
          """
        )
        |> maybe_create_transformers(dsl_module, options[:transformer])
        |> maybe_create_verifiers(dsl_module, options[:verifier])
      end
    end

    defp build_sections(options) do
      options[:section]
      |> List.wrap()
      |> Enum.map(&parse_section/1)
      |> Enum.map_join("\n\n", fn {name, entity_module} ->
        entity_part = if entity_module do
          """
          entities do
            #{entity_module}
          end
          """
        end

        """
        @section #{inspect(name)}
        
        section #{inspect(name)} do
          @moduledoc \"\"\"
          Configuration for #{name}.
          \"\"\"
          
          #{entity_part}
        end
        """
      end)
    end

    defp parse_section(section) do
      case String.split(section, ":", parts: 2) do
        [name] -> {String.to_atom(name), nil}
        [name, entity] -> {String.to_atom(name), entity}
      end
    end

    defp build_entities(options) do
      singleton_entities = 
        options[:singleton_entity]
        |> List.wrap()
        |> Enum.map(&String.to_atom/1)
        |> MapSet.new()

      options[:entity]
      |> List.wrap()
      |> Enum.map(&parse_entity/1)
      |> Enum.map_join("\n\n", fn {name, identifier_type, entity_type} ->
        singleton = if MapSet.member?(singleton_entities, name) do
          "\n  singleton? true"
        end

        """
        @entity #{inspect(name)}
        
        entity #{inspect(name)} do
          @moduledoc \"\"\"
          Represents a #{name} in the DSL.
          \"\"\"
          
          identifier #{inspect(identifier_type)}
          target #{entity_type}#{singleton}
        end
        """
      end)
    end

    defp parse_entity(entity) do
      case String.split(entity, ":") do
        [name, identifier_type, entity_type] ->
          {String.to_atom(name), String.to_atom(identifier_type), entity_type}
        _ ->
          raise "Invalid entity format: #{entity}. Expected format: name:identifier_type:entity_type"
      end
    end

    defp build_args(options) do
      options[:arg]
      |> List.wrap()
      |> Enum.map(&parse_arg/1)
      |> Enum.map_join("\n\n", fn {name, type, default} ->
        default_part = if default do
          "\n  default #{inspect(default)}"
        end

        """
        @arg #{inspect(name)}
        
        arg #{inspect(name)} do
          @moduledoc \"\"\"
          The #{name} argument.
          \"\"\"
          
          type #{inspect(type)}#{default_part}
        end
        """
      end)
    end

    defp parse_arg(arg) do
      case String.split(arg, ":") do
        [name, type] ->
          {String.to_atom(name), parse_type(type), nil}
        [name, type, default] ->
          {String.to_atom(name), parse_type(type), parse_default(default, type)}
      end
    end

    defp build_opts(options) do
      options[:opt]
      |> List.wrap()
      |> Enum.map(&parse_opt/1)
      |> Enum.map_join("\n\n", fn {name, type, default, required} ->
        default_part = if default do
          "\n  default #{inspect(default)}"
        end
        
        required_part = if required do
          "\n  required? true"
        end

        """
        @opt #{inspect(name)}
        
        opt #{inspect(name)} do
          @moduledoc \"\"\"
          The #{name} option.
          \"\"\"
          
          type #{inspect(type)}#{default_part}#{required_part}
        end
        """
      end)
    end

    defp parse_opt(opt) do
      parts = String.split(opt, ":")
      
      case parts do
        [name, type] ->
          {String.to_atom(name), parse_type(type), nil, "required" in parts}
        [name, type, default | rest] ->
          {String.to_atom(name), parse_type(type), parse_default(default, type), "required" in rest}
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

    defp build_transformers(options) do
      options[:transformer]
      |> List.wrap()
      |> Enum.map(&Module.concat([&1]))
    end

    defp build_verifiers(options) do
      options[:verifier]
      |> List.wrap()
      |> Enum.map(&Module.concat([&1]))
    end

    defp maybe_create_transformers(igniter, _dsl_module, nil), do: igniter
    defp maybe_create_transformers(igniter, dsl_module, transformers) do
      transformers
      |> List.wrap()
      |> Enum.reduce(igniter, fn transformer, acc ->
        Igniter.compose_task(
          acc,
          "spark.gen.transformer",
          [transformer, "--dsl", inspect(dsl_module)]
        )
      end)
    end

    defp maybe_create_verifiers(igniter, _dsl_module, nil), do: igniter
    defp maybe_create_verifiers(igniter, dsl_module, verifiers) do
      verifiers
      |> List.wrap()
      |> Enum.reduce(igniter, fn verifier, acc ->
        Igniter.compose_task(
          acc,
          "spark.gen.verifier",
          [verifier, "--dsl", inspect(dsl_module)]
        )
      end)
    end
  end
else
  defmodule Mix.Tasks.Spark.Gen.Dsl do
    @moduledoc """
    Generate a Spark DSL module.
    """

    @shortdoc "Generate a Spark DSL module."

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'spark.gen.dsl' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
