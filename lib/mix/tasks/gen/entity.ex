if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Spark.Gen.Entity do
    @example """
    mix spark.gen.entity MyApp.Entities.Rule \\
      --name rule \\
      --identifier name \\
      --args condition:string:required \\
      --args action:atom:required \\
      --schema name:string,condition:string,action:atom
    """
    
    @moduledoc """
    Generate a Spark DSL entity module.

    Entities are the target modules referenced in DSL entity definitions.

    ## Example

    ```bash
    #{@example}
    ```

    ## Options

    * `--name` or `-n` - The entity name in the DSL (defaults to module name).
    * `--identifier` or `-i` - The field used as the entity identifier.
    * `--args` or `-a` - Arguments the entity accepts as `name:type:modifiers`.
    * `--schema` or `-s` - Schema fields as comma-separated `name:type` pairs.
    * `--validations` - Custom validations to add.
    * `--examples` - Generate example usage documentation.
    * `--ignore-if-exists` - Does nothing if the entity already exists.
    """

    @shortdoc "Generate a Spark DSL entity module."
    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        positional: [:entity],
        example: @example,
        schema: [
          name: :string,
          identifier: :string,
          args: :csv,
          schema: :string,
          validations: :csv,
          examples: :boolean,
          ignore_if_exists: :boolean
        ],
        aliases: [
          n: :name,
          i: :identifier,
          a: :args,
          s: :schema
        ]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      entity = Igniter.Project.Module.parse(igniter.args.positional.entity)
      {exists?, igniter} = Igniter.Project.Module.module_exists(igniter, entity)

      if igniter.args.options[:ignore_if_exists] && exists? do
        igniter
      else
        options = igniter.args.options
        
        entity_name = options[:name] || 
          entity
          |> Module.split()
          |> List.last()
          |> Macro.underscore()
          |> String.to_atom()

        identifier = options[:identifier] || "name"
        
        schema_fields = parse_schema(options[:schema])
        args = parse_entity_args(options[:args])
        
        defstruct_fields = build_defstruct(schema_fields, args)
        type_specs = build_type_specs(schema_fields, args)
        new_function = build_new_function(entity_name, identifier, args)
        validation_functions = build_validations(options[:validations])
        
        examples = if options[:examples] do
          build_examples(entity_name, args)
        end

        igniter
        |> Igniter.Project.Module.create_module(
          entity,
          """
          defmodule #{inspect(entity)} do
            @moduledoc \"\"\"
            Entity representing a #{entity_name} in the DSL.
            
            ## Usage
            
            This entity is used in DSL configurations:
            
            ```elixir
            #{entity_name} :my_#{entity_name} do
              # Configuration here
            end
            ```
            #{examples}
            \"\"\"

            @behaviour Spark.Dsl.Entity

            #{defstruct_fields}

            #{type_specs}

            @doc false
            def transform(entity_struct) do
              # Optional: Transform the entity after building
              {:ok, entity_struct}
            end

            #{new_function}

            #{validation_functions}

            # Private functions

            defp validate_required!(opts, field) do
              if is_nil(opts[field]) do
                raise ArgumentError, "Required field \#{field} is missing"
              end
            end

            defp validate_type!(value, field, expected_type) do
              # Add type validation logic here
              value
            end
          end
          """
        )
      end
    end

    defp parse_schema(nil), do: []
    defp parse_schema(schema_string) do
      schema_string
      |> String.split(",")
      |> Enum.map(fn field ->
        case String.split(field, ":") do
          [name, type] -> {String.to_atom(name), String.to_atom(type)}
          [name] -> {String.to_atom(name), :any}
        end
      end)
    end

    defp parse_entity_args(nil), do: []
    defp parse_entity_args(args) do
      args
      |> Enum.map(fn arg ->
        case String.split(arg, ":") do
          [name, type, "required"] ->
            {String.to_atom(name), String.to_atom(type), true}
          [name, type] ->
            {String.to_atom(name), String.to_atom(type), false}
          _ ->
            raise "Invalid arg format: #{arg}"
        end
      end)
    end

    defp build_defstruct(schema_fields, args) do
      all_fields = 
        Enum.map(schema_fields, fn {name, _type} -> name end) ++
        Enum.map(args, fn {name, _type, _required} -> name end)
      
      defaults = Enum.map(all_fields, fn field ->
        "#{field}: nil"
      end)
      
      "defstruct #{Enum.join(defaults, ", ")}"
    end

    defp build_type_specs(schema_fields, args) do
      type_defs = 
        (schema_fields ++ Enum.map(args, fn {n, t, _} -> {n, t} end))
        |> Enum.map(fn {name, type} ->
          "  #{name}: #{type_to_spec(type)} | nil"
        end)
        |> Enum.join(",\n")
      
      """
      @type t :: %__MODULE__{
      #{type_defs}
      }
      """
    end

    defp type_to_spec(type) do
      case type do
        :string -> "String.t()"
        :atom -> "atom()"
        :integer -> "integer()"
        :boolean -> "boolean()"
        :module -> "module()"
        :any -> "any()"
        _ -> "term()"
      end
    end

    defp build_new_function(entity_name, identifier, args) do
      required_args = Enum.filter(args, fn {_, _, required} -> required end)
      
      validations = Enum.map_join(required_args, "\n    ", fn {name, _type, _} ->
        "validate_required!(opts, :#{name})"
      end)
      
      field_assignments = Enum.map_join(args, ",\n      ", fn {name, type, _} ->
        "#{name}: validate_type!(opts[:#{name}], :#{name}, :#{type})"
      end)
      
      """
      @doc \"\"\"
      Create a new #{entity_name} entity.
      \"\"\"
      @spec new(Keyword.t()) :: {:ok, t()} | {:error, term()}
      def new(opts) do
        # Validate required fields
        #{validations}
        
        # Build the entity
        entity = %__MODULE__{
          #{field_assignments}
        }
        
        # Additional validation
        case validate(entity) do
          :ok -> {:ok, entity}
          {:error, reason} -> {:error, reason}
        end
      end

      @doc \"\"\"
      Validate the entity.
      \"\"\"
      @spec validate(t()) :: :ok | {:error, term()}
      def validate(%__MODULE__{} = entity) do
        # Add custom validation logic here
        :ok
      end
      """
    end

    defp build_validations(nil), do: ""
    defp build_validations(validations) do
      validations
      |> Enum.map_join("\n\n", fn validation ->
        """
        defp validate_#{validation}(value) do
          # Add #{validation} validation logic
          :ok
        end
        """
      end)
    end

    defp build_examples(entity_name, args) do
      arg_examples = Enum.map_join(args, "\n    ", fn {name, type, required} ->
        value = case type do
          :string -> "\"example\""
          :atom -> ":example"
          :integer -> "42"
          :boolean -> "true"
          _ -> "value"
        end
        
        req = if required, do: " # required", else: ""
        "#{name} #{value}#{req}"
      end)
      
      """
      
      ## Examples
      
      ```elixir
      # In your DSL configuration
      #{entity_name} :example do
        #{arg_examples}
      end
      
      # Programmatically
      {:ok, entity} = #{inspect(__MODULE__)}.new(
        #{Enum.map_join(args, ",\n    ", fn {n, t, _} -> 
          "#{n}: #{example_value(t)}" 
        end)}
      )
      ```
      """
    end

    defp example_value(:string), do: "\"example\""
    defp example_value(:atom), do: ":example"
    defp example_value(:integer), do: "42"
    defp example_value(:boolean), do: "true"
    defp example_value(_), do: "nil"
  end
else
  defmodule Mix.Tasks.Spark.Gen.Entity do
    @moduledoc """
    Generate a Spark DSL entity module.
    """

    @shortdoc "Generate a Spark DSL entity module."

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'spark.gen.entity' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
