defmodule Mix.Tasks.AsyncApi.Gen do
  @moduledoc """
  Generate AsyncAPI specification files from DSL modules.

  This task generates AsyncAPI specification files in JSON or YAML format from
  modules that use the AsyncAPI DSL.

  ## Usage

      mix async_api.gen MODULE [options]

  ## Examples

      # Generate JSON specification
      mix async_api.gen MyApp.EventApi

      # Generate YAML specification
      mix async_api.gen MyApp.EventApi --format yaml

      # Specify output directory
      mix async_api.gen MyApp.EventApi --output priv/static/specs/

      # Generate both JSON and YAML
      mix async_api.gen MyApp.EventApi --format json,yaml

      # Generate with custom filename
      mix async_api.gen MyApp.EventApi --filename my_custom_api

  ## Options

    * `--format` - Output format: json, yaml, or both (comma-separated)
    * `--output` - Output directory (default: spec/)
    * `--filename` - Custom filename without extension (default: module name)
    * `--validate` - Validate specification before generating (default: true)
    * `--pretty` - Pretty print JSON output (default: true)

  """
  use Mix.Task

  @shortdoc "Generate AsyncAPI specification files"

  @switches [
    format: :string,
    output: :string,
    filename: :string,
    validate: :boolean,
    pretty: :boolean,
    help: :boolean
  ]

  @aliases [
    f: :format,
    o: :output,
    h: :help
  ]

  def run(args) do
    {opts, argv, _} = OptionParser.parse(args, strict: @switches, aliases: @aliases)

    if opts[:help] do
      print_help()
      exit(:normal)
    end

    case argv do
      [module_name] ->
        generate_specs(module_name, opts)
      [] ->
        Mix.shell().error("No module specified. Use: mix async_api.gen MODULE")
        print_help()
      _ ->
        Mix.shell().error("Too many arguments. Use: mix async_api.gen MODULE [options]")
    end
  end

  defp generate_specs(module_name, opts) do
    # Load the application to ensure modules are available
    Mix.Task.run("loadpaths")
    Mix.Task.run("compile")

    module = parse_module_name(module_name)
    
    unless Code.ensure_loaded?(module) do
      Mix.shell().error("Module #{module_name} not found or not compiled")
      exit({:shutdown, 1})
    end

    unless function_exported?(module, :spark_dsl_config, 0) do
      Mix.shell().error("Module #{module_name} does not use AsyncApi DSL")
      exit({:shutdown, 1})
    end

    formats = parse_formats(opts[:format] || "json")
    output_dir = opts[:output] || AsyncApi.Config.output_directory()
    filename = opts[:filename] || derive_filename(module_name)
    validate? = Keyword.get(opts, :validate, true)

    if validate? do
      case validate_specification(module) do
        :ok -> :ok
        {:error, errors} ->
          Mix.shell().error("Specification validation failed:")
          Enum.each(errors, &Mix.shell().error("  - #{&1}"))
          exit({:shutdown, 1})
      end
    end

    # Ensure output directory exists
    File.mkdir_p!(output_dir)

    # Generate specifications for each format
    Enum.each(formats, fn format ->
      generate_single_spec(module, output_dir, filename, format, opts)
    end)

    Mix.shell().info("✅ AsyncAPI specifications generated successfully")
  end

  defp generate_single_spec(module, output_dir, filename, format, opts) do
    extension = case format do
      :json -> "json"
      :yaml -> "yaml"
    end
    
    file_path = Path.join(output_dir, "#{filename}.#{extension}")
    
    try do
      content = case format do
        :json ->
          if Keyword.get(opts, :pretty, true) do
            AsyncApi.Export.to_string_pretty(module, :json)
          else
            AsyncApi.Export.to_string(module, :json)
          end
        :yaml ->
          AsyncApi.Export.to_string(module, :yaml)
      end
      
      File.write!(file_path, content)
      Mix.shell().info("📄 Generated #{file_path}")
    rescue
      error ->
        Mix.shell().error("Failed to generate #{file_path}: #{Exception.message(error)}")
    end
  end

  defp parse_module_name(module_name) do
    if String.contains?(module_name, ".") do
      Module.concat([module_name])
    else
      # Try to find the module in common namespaces
      possible_modules = [
        Module.concat([module_name]),
        Module.concat(["#{Mix.Project.config()[:app] |> to_string() |> Macro.camelize()}", module_name]),
        Module.concat([Mix.Project.config()[:app] |> to_string() |> Macro.camelize(), "Api", module_name])
      ]
      
      Enum.find(possible_modules, &Code.ensure_loaded?/1) || Module.concat([module_name])
    end
  end

  defp parse_formats(format_string) do
    format_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_atom/1)
    |> Enum.filter(&(&1 in [:json, :yaml]))
  end

  defp derive_filename(module_name) do
    module_name
    |> String.split(".")
    |> List.last()
    |> Macro.underscore()
  end

  defp validate_specification(module) do
    try do
      _spec = AsyncApi.to_spec(module)
      :ok
    rescue
      error -> {:error, [Exception.message(error)]}
    end
  end

  defp print_help do
    Mix.shell().info("""
    mix async_api.gen - Generate AsyncAPI specification files

    Usage:
        mix async_api.gen MODULE [options]

    Examples:
        mix async_api.gen MyApp.EventApi
        mix async_api.gen MyApp.EventApi --format yaml
        mix async_api.gen MyApp.EventApi --output priv/static/specs/
        mix async_api.gen MyApp.EventApi --format json,yaml

    Options:
        --format, -f    Output format: json, yaml, or both (comma-separated)
        --output, -o    Output directory (default: spec/)
        --filename      Custom filename without extension
        --validate      Validate specification before generating (default: true)
        --pretty        Pretty print JSON output (default: true)
        --help, -h      Show this help message
    """)
  end
end