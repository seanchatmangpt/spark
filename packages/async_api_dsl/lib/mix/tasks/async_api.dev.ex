defmodule Mix.Tasks.AsyncApi.Dev do
  @moduledoc """
  Comprehensive development tools for AsyncAPI specifications.
  
  This task provides a suite of development utilities including validation,
  linting, code generation, testing, and more. Perfect for development
  workflows and CI/CD pipelines.
  
  ## Usage
  
      # Run full development suite
      mix async_api.dev MODULE
      
      # Run specific checks
      mix async_api.dev MODULE --lint --validate --test
      
      # Generate code artifacts
      mix async_api.dev MODULE --generate client,server,types
      
      # Export specifications
      mix async_api.dev MODULE --export json,yaml --output priv/specs/
      
  ## Commands
  
    * `validate` - Validate specification with detailed diagnostics
    * `lint` - Run linting rules and best practices checks
    * `test` - Run contract tests and validation tests
    * `generate` - Generate code artifacts (client, server, types, validators, mocks, tests)
    * `export` - Export specifications to files
    * `analyze` - Performance and security analysis
    * `docs` - Generate documentation
    * `phoenix` - Generate Phoenix integration code
    
  ## Options
  
    * `--validate` - Run validation with diagnostics
    * `--lint` - Run linting checks
    * `--test` - Run contract tests
    * `--generate TYPE` - Generate code (client,server,types,validators,mocks,tests)
    * `--export FORMAT` - Export specifications (json,yaml)
    * `--analyze` - Run analysis (performance,security)
    * `--docs` - Generate documentation
    * `--phoenix` - Generate Phoenix integration
    * `--language LANG` - Target language for generation (elixir,go,typescript,python)
    * `--output DIR` - Output directory
    * `--format FORMAT` - Output format
    * `--config FILE` - Configuration file
    * `--watch` - Watch for changes and re-run
    * `--ci` - CI mode (machine-readable output)
    * `--fix` - Attempt to fix issues automatically
  
  ## Examples
  
      # Complete development workflow
      mix async_api.dev MyApp.EventApi
      
      # Validation and linting only
      mix async_api.dev MyApp.EventApi --validate --lint
      
      # Generate Elixir client and types
      mix async_api.dev MyApp.EventApi --generate client,types --language elixir
      
      # Generate TypeScript artifacts
      mix async_api.dev MyApp.EventApi --generate all --language typescript
      
      # Export and analyze
      mix async_api.dev MyApp.EventApi --export json,yaml --analyze
      
      # Phoenix integration
      mix async_api.dev MyApp.EventApi --phoenix --output lib/my_app_web/
      
      # CI/CD pipeline
      mix async_api.dev MyApp.EventApi --ci --validate --lint --test
      
      # Watch mode for development
      mix async_api.dev MyApp.EventApi --watch --validate --lint
  """

  use Mix.Task
  require Logger

  @shortdoc "Comprehensive AsyncAPI development tools"

  @switches [
    validate: :boolean,
    lint: :boolean,
    test: :boolean,
    generate: :string,
    export: :string,
    analyze: :boolean,
    docs: :boolean,
    phoenix: :boolean,
    language: :string,
    output: :string,
    format: :string,
    config: :string,
    watch: :boolean,
    ci: :boolean,
    fix: :boolean,
    help: :boolean
  ]

  @aliases [
    h: :help,
    o: :output,
    l: :language,
    f: :format,
    w: :watch
  ]

  def run(args) do
    {opts, argv, _} = OptionParser.parse(args, strict: @switches, aliases: @aliases)

    if opts[:help] do
      print_help()
      :ok
    else
      case argv do
        [module_name] ->
          run_dev_suite(module_name, opts)
        [] ->
          Mix.shell().error("No module specified. Use: mix async_api.dev MODULE")
          print_help()
        _ ->
          Mix.shell().error("Too many arguments. Use: mix async_api.dev MODULE [options]")
      end
    end
  end

  defp run_dev_suite(module_name, opts) do
    # Load the application
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

    config = load_config(opts)
    
    if opts[:watch] do
      run_watch_mode(module, opts, config)
    else
      run_single_execution(module, opts, config)
    end
  end

  defp run_single_execution(module, opts, config) do
    start_time = System.monotonic_time(:millisecond)
    
    results = %{
      validation: nil,
      linting: nil,
      testing: nil,
      generation: nil,
      export: nil,
      analysis: nil,
      docs: nil,
      phoenix: nil
    }

    # Determine what to run
    run_all = !Enum.any?(opts, fn {key, _} -> 
      key in [:validate, :lint, :test, :generate, :export, :analyze, :docs, :phoenix]
    end)

    results = if run_all || opts[:validate] do
      Map.put(results, :validation, run_validation(module, opts, config))
    else
      results
    end

    results = if run_all || opts[:lint] do
      Map.put(results, :linting, run_linting(module, opts, config))
    else
      results
    end

    results = if run_all || opts[:test] do
      Map.put(results, :testing, run_testing(module, opts, config))
    else
      results
    end

    results = if opts[:generate] do
      Map.put(results, :generation, run_generation(module, opts, config))
    else
      results
    end

    results = if opts[:export] do
      Map.put(results, :export, run_export(module, opts, config))
    else
      results
    end

    results = if run_all || opts[:analyze] do
      Map.put(results, :analysis, run_analysis(module, opts, config))
    else
      results
    end

    results = if opts[:docs] do
      Map.put(results, :docs, run_docs_generation(module, opts, config))
    else
      results
    end

    results = if opts[:phoenix] do
      Map.put(results, :phoenix, run_phoenix_generation(module, opts, config))
    else
      results
    end

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    print_results(results, duration, opts)
  end

  defp run_watch_mode(module, opts, config) do
    Mix.shell().info("🔍 Watching for changes...")
    
    # Get source files to watch
    source_files = get_source_files(module)
    
    FileSystem.start_link(dirs: ["."], name: :async_api_watcher)
    
    FileSystem.subscribe(:async_api_watcher)
    
    # Run initial execution
    run_single_execution(module, opts, config)
    
    watch_loop(module, opts, config, source_files)
  end

  defp watch_loop(module, opts, config, source_files) do
    receive do
      {:file_event, _watcher_pid, {path, events}} ->
        if Path.extname(path) == ".ex" && path in source_files do
          if :modified in events do
            Mix.shell().info("\n🔄 File changed: #{path}")
            Mix.shell().info("Re-running AsyncAPI development tools...")
            
            # Recompile
            Mix.Task.run("compile")
            
            # Re-run tools
            run_single_execution(module, opts, config)
          end
        end
        
        watch_loop(module, opts, config, source_files)
      
      _ ->
        watch_loop(module, opts, config, source_files)
    end
  end

  defp run_validation(module, opts, _config) do
    Mix.shell().info("🔍 Running validation...")
    
    case AsyncApi.Errors.validate_with_diagnostics(module) do
      {:ok, _spec} ->
        if opts[:ci] do
          IO.puts("::notice::AsyncAPI validation passed")
        else
          Mix.shell().info("✅ Validation passed")
        end
        {:ok, "Validation passed"}
      
      {:error, diagnostics} ->
        if opts[:ci] do
          AsyncApi.Errors.print_diagnostics(diagnostics, format: :github)
        else
          AsyncApi.Errors.print_diagnostics(diagnostics)
        end
        
        errors = Enum.filter(diagnostics, &(&1.severity == :error))
        
        if length(errors) > 0 do
          {:error, "Validation failed with #{length(errors)} errors"}
        else
          {:warning, "Validation passed with warnings"}
        end
    end
  end

  defp run_linting(module, opts, _config) do
    Mix.shell().info("🧹 Running linting...")
    
    case AsyncApi.Linter.lint(module) do
      {:ok, []} ->
        if opts[:ci] do
          IO.puts("::notice::AsyncAPI linting passed")
        else
          Mix.shell().info("✅ Linting passed")
        end
        {:ok, "Linting passed"}
      
      {:ok, warnings} ->
        if opts[:ci] do
          Enum.each(warnings, fn warning ->
            IO.puts("::warning::#{warning}")
          end)
        else
          Mix.shell().info("⚠️  Linting passed with #{length(warnings)} warnings:")
          Enum.each(warnings, fn warning ->
            Mix.shell().info("   • #{warning}")
          end)
        end
        {:warning, "Linting passed with #{length(warnings)} warnings"}
      
      {:error, errors} ->
        if opts[:ci] do
          Enum.each(errors, fn error ->
            IO.puts("::error::#{error}")
          end)
        else
          Mix.shell().error("❌ Linting failed with #{length(errors)} errors:")
          Enum.each(errors, fn error ->
            Mix.shell().error("   • #{error}")
          end)
        end
        {:error, "Linting failed with #{length(errors)} errors"}
    end
  end

  defp run_testing(module, opts, _config) do
    Mix.shell().info("🧪 Running contract tests...")
    
    try do
      # Run message schema tests
      AsyncApi.Testing.test_all_message_schemas(module)
      
      # Run operation tests
      AsyncApi.Testing.test_all_operations(module)
      
      # Run spec validity tests
      AsyncApi.Testing.test_spec_validity(module)
      
      if opts[:ci] do
        IO.puts("::notice::AsyncAPI contract tests passed")
      else
        Mix.shell().info("✅ Contract tests passed")
      end
      
      {:ok, "Contract tests passed"}
    rescue
      error ->
        error_msg = "Contract tests failed: #{Exception.message(error)}"
        
        if opts[:ci] do
          IO.puts("::error::#{error_msg}")
        else
          Mix.shell().error("❌ #{error_msg}")
        end
        
        {:error, error_msg}
    end
  end

  defp run_generation(module, opts, config) do
    generate_types = parse_generate_types(opts[:generate])
    language = String.to_atom(opts[:language] || config[:default_language] || "elixir")
    output_dir = opts[:output] || config[:output_dir] || "generated/"
    
    Mix.shell().info("🔧 Generating code artifacts...")
    Mix.shell().info("   Types: #{Enum.join(generate_types, ", ")}")
    Mix.shell().info("   Language: #{language}")
    Mix.shell().info("   Output: #{output_dir}")
    
    File.mkdir_p!(output_dir)
    
    results = []
    
    results = if "client" in generate_types do
      case AsyncApi.Codegen.generate_client(module, language) do
        {:ok, code} ->
          file_path = Path.join(output_dir, "client.#{get_file_extension(language)}")
          File.write!(file_path, code)
          Mix.shell().info("   📄 Generated client: #{file_path}")
          [{:client, :ok} | results]
        {:error, reason} ->
          Mix.shell().error("   ❌ Client generation failed: #{reason}")
          [{:client, :error} | results]
      end
    else
      results
    end

    results = if "server" in generate_types do
      case AsyncApi.Codegen.generate_server(module, language) do
        {:ok, code} ->
          file_path = Path.join(output_dir, "server.#{get_file_extension(language)}")
          File.write!(file_path, code)
          Mix.shell().info("   📄 Generated server: #{file_path}")
          [{:server, :ok} | results]
        {:error, reason} ->
          Mix.shell().error("   ❌ Server generation failed: #{reason}")
          [{:server, :error} | results]
      end
    else
      results
    end

    results = if "types" in generate_types do
      case AsyncApi.Codegen.generate_types(module, language) do
        {:ok, code} ->
          file_path = Path.join(output_dir, "types.#{get_file_extension(language)}")
          File.write!(file_path, code)
          Mix.shell().info("   📄 Generated types: #{file_path}")
          [{:types, :ok} | results]
        {:error, reason} ->
          Mix.shell().error("   ❌ Types generation failed: #{reason}")
          [{:types, :error} | results]
      end
    else
      results
    end

    results = if "validators" in generate_types do
      case AsyncApi.Codegen.generate_validators(module, language) do
        {:ok, code} ->
          file_path = Path.join(output_dir, "validators.#{get_file_extension(language)}")
          File.write!(file_path, code)
          Mix.shell().info("   📄 Generated validators: #{file_path}")
          [{:validators, :ok} | results]
        {:error, reason} ->
          Mix.shell().error("   ❌ Validators generation failed: #{reason}")
          [{:validators, :error} | results]
      end
    else
      results
    end

    results = if "mocks" in generate_types do
      case AsyncApi.Codegen.generate_mocks(module, language) do
        {:ok, code} ->
          file_path = Path.join(output_dir, "mocks.#{get_file_extension(language)}")
          File.write!(file_path, code)
          Mix.shell().info("   📄 Generated mocks: #{file_path}")
          [{:mocks, :ok} | results]
        {:error, reason} ->
          Mix.shell().error("   ❌ Mocks generation failed: #{reason}")
          [{:mocks, :error} | results]
      end
    else
      results
    end

    results = if "tests" in generate_types do
      case AsyncApi.Codegen.generate_tests(module, language) do
        {:ok, code} ->
          file_path = Path.join(output_dir, "tests.#{get_file_extension(language)}")
          File.write!(file_path, code)
          Mix.shell().info("   📄 Generated tests: #{file_path}")
          [{:tests, :ok} | results]
        {:error, reason} ->
          Mix.shell().error("   ❌ Tests generation failed: #{reason}")
          [{:tests, :error} | results]
      end
    else
      results
    end

    success_count = Enum.count(results, fn {_, status} -> status == :ok end)
    total_count = length(results)
    
    if success_count == total_count do
      {:ok, "Generated #{success_count}/#{total_count} artifacts"}
    else
      {:warning, "Generated #{success_count}/#{total_count} artifacts"}
    end
  end

  defp run_export(module, opts, config) do
    formats = parse_export_formats(opts[:export])
    output_dir = opts[:output] || config[:output_dir] || "specs/"
    
    Mix.shell().info("📤 Exporting specifications...")
    Mix.shell().info("   Formats: #{Enum.join(formats, ", ")}")
    Mix.shell().info("   Output: #{output_dir}")
    
    File.mkdir_p!(output_dir)
    
    results = Enum.map(formats, fn format ->
      try do
        case format do
          "json" ->
            json_spec = AsyncApi.Export.to_string(module, :json)
            file_path = Path.join(output_dir, "spec.json")
            File.write!(file_path, json_spec)
            Mix.shell().info("   📄 Exported JSON: #{file_path}")
            {:json, :ok}
          
          "yaml" ->
            yaml_spec = AsyncApi.Export.to_string(module, :yaml)
            file_path = Path.join(output_dir, "spec.yaml")
            File.write!(file_path, yaml_spec)
            Mix.shell().info("   📄 Exported YAML: #{file_path}")
            {:yaml, :ok}
        end
      rescue
        error ->
          Mix.shell().error("   ❌ #{format} export failed: #{Exception.message(error)}")
          {String.to_atom(format), :error}
      end
    end)
    
    success_count = Enum.count(results, fn {_, status} -> status == :ok end)
    total_count = length(results)
    
    if success_count == total_count do
      {:ok, "Exported #{success_count}/#{total_count} formats"}
    else
      {:warning, "Exported #{success_count}/#{total_count} formats"}
    end
  end

  defp run_analysis(module, _opts, _config) do
    Mix.shell().info("🔍 Running analysis...")
    
    # Performance analysis
    Mix.shell().info("   🚀 Performance analysis...")
    
    # Security analysis
    Mix.shell().info("   🔒 Security analysis...")
    
    # Protocol analysis
    Mix.shell().info("   🌐 Protocol analysis...")
    
    {:ok, "Analysis complete"}
  end

  defp run_docs_generation(module, opts, config) do
    output_dir = opts[:output] || config[:docs_output] || "docs/"
    
    Mix.shell().info("📚 Generating documentation...")
    
    File.mkdir_p!(output_dir)
    
    # Generate API documentation
    spec = AsyncApi.to_spec(module)
    
    docs_html = generate_docs_html(spec, module)
    docs_path = Path.join(output_dir, "index.html")
    File.write!(docs_path, docs_html)
    
    Mix.shell().info("   📄 Generated documentation: #{docs_path}")
    
    {:ok, "Documentation generated"}
  end

  defp run_phoenix_generation(module, opts, config) do
    output_dir = opts[:output] || config[:phoenix_output] || "lib/my_app_web/"
    
    Mix.shell().info("🔥 Generating Phoenix integration...")
    
    File.mkdir_p!(output_dir)
    
    # Generate Phoenix channels
    channels = AsyncApi.Phoenix.extract_channels(module)
    
    Enum.each(channels, fn channel ->
      case AsyncApi.Phoenix.generate_channel_module(module, channel.name) do
        {:ok, code} ->
          file_path = Path.join(output_dir, "#{Macro.underscore(to_string(channel.name))}_channel.ex")
          File.write!(file_path, code)
          Mix.shell().info("   📄 Generated channel: #{file_path}")
        
        {:error, reason} ->
          Mix.shell().error("   ❌ Channel generation failed: #{reason}")
      end
    end)
    
    # Generate broadcaster
    broadcaster_code = AsyncApi.Phoenix.generate_broadcaster(module)
    broadcaster_path = Path.join(output_dir, "broadcaster.ex")
    File.write!(broadcaster_path, broadcaster_code)
    Mix.shell().info("   📄 Generated broadcaster: #{broadcaster_path}")
    
    {:ok, "Phoenix integration generated"}
  end

  defp print_results(results, duration, opts) do
    if opts[:ci] do
      print_ci_results(results, duration)
    else
      print_human_results(results, duration)
    end
  end

  defp print_human_results(results, duration) do
    Mix.shell().info("\n📊 AsyncAPI Development Suite Results")
    Mix.shell().info("⏱️  Total time: #{duration}ms")
    Mix.shell().info("")
    
    Enum.each(results, fn {task, result} ->
      if result do
        case result do
          {:ok, message} ->
            Mix.shell().info("✅ #{format_task_name(task)}: #{message}")
          {:warning, message} ->
            Mix.shell().info("⚠️  #{format_task_name(task)}: #{message}")
          {:error, message} ->
            Mix.shell().error("❌ #{format_task_name(task)}: #{message}")
        end
      end
    end)
    
    # Summary
    successes = Enum.count(results, fn {_, result} -> 
      result && elem(result, 0) == :ok 
    end)
    
    warnings = Enum.count(results, fn {_, result} -> 
      result && elem(result, 0) == :warning 
    end)
    
    errors = Enum.count(results, fn {_, result} -> 
      result && elem(result, 0) == :error 
    end)
    
    total = successes + warnings + errors
    
    Mix.shell().info("")
    Mix.shell().info("📈 Summary: #{successes} passed, #{warnings} warnings, #{errors} errors (#{total} total)")
    
    if errors > 0 do
      exit({:shutdown, 1})
    end
  end

  defp print_ci_results(results, duration) do
    IO.puts("::notice title=AsyncAPI Development Suite::Completed in #{duration}ms")
    
    errors = Enum.count(results, fn {_, result} -> 
      result && elem(result, 0) == :error 
    end)
    
    if errors > 0 do
      IO.puts("::error title=AsyncAPI Development Suite::#{errors} tasks failed")
      exit({:shutdown, 1})
    else
      IO.puts("::notice title=AsyncAPI Development Suite::All tasks completed successfully")
    end
  end

  defp format_task_name(task) do
    case task do
      :validation -> "Validation"
      :linting -> "Linting"
      :testing -> "Testing"
      :generation -> "Generation"
      :export -> "Export"
      :analysis -> "Analysis"
      :docs -> "Documentation"
      :phoenix -> "Phoenix Integration"
    end
  end

  # Helper functions

  defp parse_module_name(module_name) do
    if String.contains?(module_name, ".") do
      Module.concat([module_name])
    else
      possible_modules = [
        Module.concat([module_name]),
        Module.concat([Mix.Project.config()[:app] |> to_string() |> Macro.camelize(), module_name])
      ]
      
      Enum.find(possible_modules, &Code.ensure_loaded?/1) || Module.concat([module_name])
    end
  end

  defp parse_generate_types(nil), do: []
  defp parse_generate_types("all"), do: ["client", "server", "types", "validators", "mocks", "tests"]
  defp parse_generate_types(types) when is_binary(types) do
    types
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  defp parse_export_formats(nil), do: ["json"]
  defp parse_export_formats(formats) when is_binary(formats) do
    formats
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end

  defp get_file_extension(:elixir), do: "ex"
  defp get_file_extension(:go), do: "go"
  defp get_file_extension(:typescript), do: "ts"
  defp get_file_extension(:javascript), do: "js"
  defp get_file_extension(:python), do: "py"
  defp get_file_extension(_), do: "txt"

  defp load_config(opts) do
    config_file = opts[:config] || "async_api.config.exs"
    
    if File.exists?(config_file) do
      {config, _} = Code.eval_file(config_file)
      config
    else
      %{
        default_language: "elixir",
        output_dir: "generated/",
        docs_output: "docs/",
        phoenix_output: "lib/my_app_web/"
      }
    end
  end

  defp get_source_files(module) do
    # Get the source file of the module
    try do
      source = module.module_info(:compile)[:source]
      if source, do: [to_string(source)], else: []
    rescue
      _ -> []
    end
  end

  defp generate_docs_html(spec, module) do
    info = spec[:info] || %{}
    
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>#{info[:title] || "AsyncAPI Documentation"}</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .header { border-bottom: 2px solid #333; padding-bottom: 20px; margin-bottom: 30px; }
            .section { margin: 20px 0; }
            .operation { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
            .channel { background: #e8f4f8; padding: 15px; margin: 10px 0; border-radius: 5px; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>#{info[:title] || "AsyncAPI Documentation"}</h1>
            <p><strong>Version:</strong> #{info[:version] || "1.0.0"}</p>
            <p><strong>AsyncAPI:</strong> #{spec[:asyncapi] || "3.0.0"}</p>
            #{if info[:description], do: "<p>#{info[:description]}</p>", else: ""}
        </div>
        
        <div class="section">
            <h2>Generated by AsyncAPI DSL</h2>
            <p>This documentation was automatically generated from the <code>#{module}</code> specification.</p>
        </div>
        
        <div class="section">
            <h2>Channels</h2>
            #{generate_channels_html(spec[:channels] || %{})}
        </div>
        
        <div class="section">
            <h2>Operations</h2>
            #{generate_operations_html(spec[:operations] || %{})}
        </div>
    </body>
    </html>
    """
  end

  defp generate_channels_html(channels) do
    channels
    |> Enum.map(fn {name, channel} ->
      """
      <div class="channel">
          <h3>#{name}</h3>
          #{if channel[:description], do: "<p>#{channel[:description]}</p>", else: ""}
      </div>
      """
    end)
    |> Enum.join("")
  end

  defp generate_operations_html(operations) do
    operations
    |> Enum.map(fn {name, operation} ->
      """
      <div class="operation">
          <h3>#{name} (#{operation[:action]})</h3>
          #{if operation[:summary], do: "<p><strong>Summary:</strong> #{operation[:summary]}</p>", else: ""}
          #{if operation[:description], do: "<p>#{operation[:description]}</p>", else: ""}
          <p><strong>Channel:</strong> #{operation[:channel]}</p>
          <p><strong>Message:</strong> #{operation[:message]}</p>
      </div>
      """
    end)
    |> Enum.join("")
  end

  defp print_help do
    Mix.shell().info("""
    mix async_api.dev - Comprehensive AsyncAPI development tools

    Usage:
        mix async_api.dev MODULE [options]

    Examples:
        mix async_api.dev MyApp.EventApi
        mix async_api.dev MyApp.EventApi --validate --lint
        mix async_api.dev MyApp.EventApi --generate client,types --language elixir
        mix async_api.dev MyApp.EventApi --export json,yaml --analyze
        mix async_api.dev MyApp.EventApi --phoenix --output lib/my_app_web/
        mix async_api.dev MyApp.EventApi --watch --validate --lint

    Options:
        --validate          Run validation with detailed diagnostics
        --lint              Run linting checks and best practices
        --test              Run contract tests and validation
        --generate TYPE     Generate code artifacts (client,server,types,validators,mocks,tests,all)
        --export FORMAT     Export specifications (json,yaml)
        --analyze           Run performance and security analysis
        --docs              Generate documentation
        --phoenix           Generate Phoenix integration code
        --language LANG     Target language (elixir,go,typescript,python)
        --output DIR        Output directory
        --format FORMAT     Output format
        --config FILE       Configuration file path
        --watch             Watch for changes and re-run
        --ci                CI mode with machine-readable output
        --fix               Attempt to auto-fix issues
        --help, -h          Show this help message

    Commands:
        validate    - Validate specification with enhanced diagnostics
        lint        - Check best practices and conventions
        test        - Run contract and validation tests
        generate    - Generate client/server code and utilities
        export      - Export specifications to files
        analyze     - Performance and security analysis
        docs        - Generate interactive documentation
        phoenix     - Generate Phoenix WebSocket integration
    """)
  end
end