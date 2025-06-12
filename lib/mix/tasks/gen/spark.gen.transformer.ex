if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Spark.Gen.Transformer do
    @example """
    mix spark.gen.transformer MyApp.Transformers.AddTimestamps \\
      --dsl MyApp.Dsl \\
      --before MyApp.Transformers.Validate \\
      --after MyApp.Transformers.SetDefaults \\
      --persist entity_id
    """
    
    @moduledoc """
    Generate a Spark DSL transformer module.

    Transformers are used to modify the DSL state during compilation.
    They run in a specific order and can add, modify, or remove entities.

    ## Example

    ```bash
    #{@example}
    ```

    ## Options

    * `--dsl` or `-d` - The DSL module this transformer belongs to.
    * `--before` or `-b` - Transformers this should run before.
    * `--after` or `-a` - Transformers this should run after.
    * `--persist` or `-p` - Data keys to persist across transformer runs.
    * `--examples` - Generate example usage documentation.
    * `--ignore-if-exists` - Does nothing if the transformer already exists.
    """

    @shortdoc "Generate a Spark DSL transformer module."
    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        positional: [:transformer],
        example: @example,
        schema: [
          dsl: :string,
          before: :csv,
          after: :csv,
          persist: :csv,
          examples: :boolean,
          ignore_if_exists: :boolean
        ],
        aliases: [
          d: :dsl,
          b: :before,
          a: :after,
          p: :persist
        ]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      transformer = Igniter.Project.Module.parse(igniter.args.positional.transformer)
      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, transformer)

      if igniter.args.options[:ignore_if_exists] && exists? do
        igniter
      else
        options = igniter.args.options
        
        before_transformers = build_transformer_list(options[:before])
        after_transformers = build_transformer_list(options[:after])
        persist_keys = build_persist_keys(options[:persist])
        
        examples = if options[:examples] do
          build_examples(transformer, options[:dsl])
        end

        igniter
        |> Igniter.Project.Module.create_module(
          transformer,
          """
          defmodule #{inspect(transformer)} do
            @moduledoc \"\"\"
            DSL transformer for #{transformer_name(transformer)}.
            
            This transformer runs during DSL compilation to modify the DSL state.
            It can add, modify, or remove entities from the DSL configuration.
            #{examples}
            \"\"\"

            use Spark.Dsl.Transformer

            #{before_transformers}#{after_transformers}#{persist_keys}

            @doc \"\"\"
            Transform the DSL state.
            
            This function is called during DSL compilation and receives the current
            DSL state. It should return either `{:ok, dsl_state}` for success or
            `{:error, reason}` for failure.
            \"\"\"
            @impl Spark.Dsl.Transformer
            def transform(dsl_state) do
              # TODO: Implement transformation logic
              # 
              # Example transformations:
              # - Add computed fields to entities
              # - Validate cross-entity relationships  
              # - Set default values
              # - Reorganize entity structure
              #
              # Access entities with: Spark.Dsl.Transformer.get_entities(dsl_state, [:section_name])
              # Add entities with: Spark.Dsl.Transformer.add_entity(dsl_state, [:section_name], entity)
              # Remove entities with: Spark.Dsl.Transformer.remove_entity(dsl_state, [:section_name], entity)
              
              {:ok, dsl_state}
            end

            @doc \"\"\"
            Handle transformer errors.
            
            This function is called when the transformer returns an error.
            It can be used to provide better error messages or handle specific error cases.
            \"\"\"
            @impl Spark.Dsl.Transformer
            def handle_error(error, dsl_state) do
              # Default error handling - can be customized
              {:error, error}
            end

            # Private helper functions

            defp transform_entity(entity) do
              # Helper function to transform individual entities
              entity
            end

            defp validate_entity(entity) do
              # Helper function to validate entities
              {:ok, entity}
            end

            defp add_computed_fields(entity) do
              # Helper function to add computed fields
              entity
            end
          end
          """
        )
      end
    end

    defp transformer_name(transformer) do
      transformer
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
      |> String.replace("_", " ")
    end

    defp build_transformer_list(nil), do: ""
    defp build_transformer_list([]), do: ""
    defp build_transformer_list(transformers) do
      transformer_modules = 
        transformers
        |> Enum.map(&Module.concat([&1]))
        |> inspect()
      
      """
      @before #{transformer_modules}

      """
    end

    defp build_persist_keys(nil), do: ""
    defp build_persist_keys([]), do: ""
    defp build_persist_keys(keys) do
      key_atoms = 
        keys
        |> Enum.map(&String.to_atom/1)
        |> inspect()
      
      """
      @persist #{key_atoms}

      """
    end

    defp build_examples(transformer, dsl) do
      dsl_name = if dsl, do: dsl, else: "YourDsl"
      
      """
      
      ## Usage
      
      Add this transformer to your DSL extension:
      
      ```elixir
      use Spark.Dsl.Extension,
        transformers: [#{inspect(transformer)}]
      ```
      
      Or in #{dsl_name}:
      
      ```elixir
      defmodule #{dsl_name} do
        use Spark.Dsl.Extension,
          transformers: [
            # ... other transformers
            #{inspect(transformer)}
          ]
      end
      ```
      
      ## Example Transformations
      
      ```elixir
      # Before transformation
      entity :user do
        field :name, :string
      end
      
      # After transformation (example)
      entity :user do
        field :name, :string
        field :id, :uuid, generated: true
        field :created_at, :datetime, generated: true
      end
      ```
      """
    end
  end
else
  defmodule Mix.Tasks.Spark.Gen.Transformer do
    @moduledoc """
    Generate a Spark DSL transformer module.
    """

    @shortdoc "Generate a Spark DSL transformer module."

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'spark.gen.transformer' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end