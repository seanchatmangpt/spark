if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Spark.Gen.Extension do
    @example """
    mix spark.gen.extension MyApp.Extensions.MyExtension \\
      --section resources:MyApp.Resource \\
      --section policies \\
      --entity resource:name:module \\
      --entity policy:name:atom \\
      --transformer MyApp.Transformers.AddTimestamps \\
      --verifier MyApp.Verifiers.ValidateRules
    """
    
    @moduledoc """
    Generate a Spark DSL extension module.

    Extensions are reusable DSL components that can be added to any Spark DSL.
    They define sections, entities, transformers, and verifiers.

    ## Example

    ```bash
    #{@example}
    ```

    ## Options

    * `--section` or `-s` - A section as `name` or `name:entity_module`.
    * `--entity` or `-e` - An entity definition as `name:identifier_type:entity_type`.
    * `--transformer` or `-t` - Transformers to include in the extension.
    * `--verifier` or `-v` - Verifiers to include in the extension.
    * `--persist` or `-p` - Data keys to persist across transformer runs.
    * `--fragments` - Enable DSL fragments support.
    * `--examples` - Generate example usage documentation.
    * `--ignore-if-exists` - Does nothing if the extension already exists.
    """

    @shortdoc "Generate a Spark DSL extension module."
    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        positional: [:extension],
        example: @example,
        schema: [
          section: :csv,
          entity: :csv,
          transformer: :csv,
          verifier: :csv,
          persist: :csv,
          fragments: :boolean,
          examples: :boolean,
          ignore_if_exists: :boolean
        ],
        aliases: [
          s: :section,
          e: :entity,
          t: :transformer,
          v: :verifier,
          p: :persist
        ]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      extension = Igniter.Project.Module.parse(igniter.args.positional.extension)
      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, extension)

      if igniter.args.options[:ignore_if_exists] && exists? do
        igniter
      else
        options = igniter.args.options
        
        sections = build_sections(options[:section])
        _entities = build_entities(options[:entity])
        transformers = build_transformers(options[:transformer])
        verifiers = build_verifiers(options[:verifier])
        persist_keys = build_persist_keys(options[:persist])
        
        fragments = if options[:fragments] do
          """
          @fragments [
            # Add fragment modules here
          ]
          
          """
        end

        examples = if options[:examples] do
          build_examples(extension, options)
        end

        igniter
        |> Igniter.Project.Module.create_module(
          extension,
          """
          defmodule #{inspect(extension)} do
            @moduledoc \"\"\"
            #{extension_name(extension)} DSL extension.
            
            This extension provides reusable DSL components that can be added
            to any Spark DSL. It defines sections, entities, transformers, and verifiers.
            #{examples}
            \"\"\"

            #{fragments}use Spark.Dsl.Extension,
              sections: [#{sections}],
              transformers: [#{transformers}],
              verifiers: [#{verifiers}]#{persist_keys}

            #{build_section_definitions(options[:section])}

            #{build_entity_definitions(options[:entity])}
          end
          """
        )
        |> maybe_create_transformers(extension, options[:transformer])
        |> maybe_create_verifiers(extension, options[:verifier])
      end
    end

    defp extension_name(extension) do
      extension
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
      |> String.replace("_", " ")
      |> String.capitalize()
    end

    defp build_sections(nil), do: ""
    defp build_sections(sections) do
      sections
      |> Enum.map(&parse_section/1)
      |> Enum.map(fn {name, _} -> "@#{name}" end)
      |> Enum.join(", ")
    end

    defp build_entities(nil), do: ""
    defp build_entities(entities) do
      entities
      |> Enum.map(&parse_entity/1)
      |> Enum.map(fn {name, _, _} -> "@#{name}" end)
      |> Enum.join(", ")
    end

    defp build_transformers(nil), do: ""
    defp build_transformers(transformers) do
      transformers
      |> Enum.map(&Module.concat([&1]))
      |> Enum.map(&inspect/1)
      |> Enum.join(", ")
    end

    defp build_verifiers(nil), do: ""
    defp build_verifiers(verifiers) do
      verifiers
      |> Enum.map(&Module.concat([&1]))
      |> Enum.map(&inspect/1)
      |> Enum.join(", ")
    end

    defp build_persist_keys(nil), do: ""
    defp build_persist_keys([]), do: ""
    defp build_persist_keys(keys) do
      key_atoms = 
        keys
        |> Enum.map(&String.to_atom/1)
        |> inspect()
      
      """
              persist: #{key_atoms}
      """
    end

    defp build_section_definitions(nil), do: ""
    defp build_section_definitions(sections) do
      sections
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
        @#{name} %Spark.Dsl.Section{
          name: :#{name},
          describe: \"\"\"
          Configuration for #{name}.
          \"\"\",
          #{if entity_part, do: "entities: [@#{name}_entity],", else: ""}
          schema: [
            # Add section options here
          ]
        }
        """
      end)
    end

    defp build_entity_definitions(nil), do: ""
    defp build_entity_definitions(entities) do
      entities
      |> Enum.map(&parse_entity/1)
      |> Enum.map_join("\n\n", fn {name, identifier_type, entity_type} ->
        """
        @#{name} %Spark.Dsl.Entity{
          name: :#{name},
          describe: \"\"\"
          Represents a #{name} in the DSL.
          \"\"\",
          identifier: :#{identifier_type},
          target: #{entity_type},
          args: [:#{identifier_type}],
          schema: [
            #{identifier_type}: [
              type: :#{identifier_type},
              required: true,
              doc: "The identifier for this #{name}"
            ]
            # Add more schema fields here
          ]
        }
        """
      end)
    end

    defp parse_section(section) do
      case String.split(section, ":", parts: 2) do
        [name] -> {String.to_atom(name), nil}
        [name, entity] -> {String.to_atom(name), entity}
      end
    end

    defp parse_entity(entity) do
      case String.split(entity, ":") do
        [name, identifier_type, entity_type] ->
          {String.to_atom(name), String.to_atom(identifier_type), entity_type}
        _ ->
          raise "Invalid entity format: #{entity}. Expected format: name:identifier_type:entity_type"
      end
    end

    defp build_examples(extension, options) do
      sections = options[:section] || []
      entities = options[:entity] || []
      
      section_examples = Enum.map_join(sections, "\n      ", fn section ->
        {name, _} = parse_section(section)
        """
        #{name} do
          # Configuration here
        end
        """
      end)

      entity_examples = Enum.map_join(entities, "\n        ", fn entity ->
        {name, _identifier_type, _} = parse_entity(entity)
        """
        #{name} :my_#{name} do
          # #{String.capitalize(to_string(name))} configuration
        end
        """
      end)

      """
      
      ## Usage
      
      Add this extension to your DSL:
      
      ```elixir
      defmodule MyApp.MyDsl do
        use Spark.Dsl,
          default_extensions: [extensions: [#{inspect(extension)}]]
      end
      ```
      
      Or include it in another extension:
      
      ```elixir
      use Spark.Dsl.Extension,
        extensions: [#{inspect(extension)}]
      ```
      
      ## Example DSL Usage
      
      ```elixir
      defmodule MyApp.MyResource do
        use MyApp.MyDsl
      
        #{section_examples}
        #{if entity_examples != "", do: "\n        #{entity_examples}"}
      end
      ```
      """
    end

    defp maybe_create_transformers(igniter, _extension, nil), do: igniter
    defp maybe_create_transformers(igniter, extension, transformers) do
      transformers
      |> List.wrap()
      |> Enum.reduce(igniter, fn transformer, acc ->
        Igniter.compose_task(
          acc,
          "spark.gen.transformer",
          [transformer, "--dsl", inspect(extension)]
        )
      end)
    end

    defp maybe_create_verifiers(igniter, _extension, nil), do: igniter
    defp maybe_create_verifiers(igniter, extension, verifiers) do
      verifiers
      |> List.wrap()
      |> Enum.reduce(igniter, fn verifier, acc ->
        Igniter.compose_task(
          acc,
          "spark.gen.verifier",
          [verifier, "--dsl", inspect(extension)]
        )
      end)
    end
  end
else
  defmodule Mix.Tasks.Spark.Gen.Extension do
    @moduledoc """
    Generate a Spark DSL extension module.
    """

    @shortdoc "Generate a Spark DSL extension module."

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'spark.gen.extension' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end