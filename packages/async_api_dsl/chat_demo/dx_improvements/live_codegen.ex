defmodule AsyncApi.LiveCodegen do
  @moduledoc """
  Real-time code generation and hot reloading system that watches AsyncAPI
  specifications and automatically regenerates client code, documentation,
  and test suites on changes.
  """

  use GenServer
  require Logger

  defstruct [
    :watcher_pid,
    :generators,
    :last_generation,
    :file_checksums,
    :config
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def watch_api_module(api_module, opts \\ []) do
    GenServer.call(__MODULE__, {:watch_module, api_module, opts})
  end

  def add_generator(generator_module, opts \\ []) do
    GenServer.call(__MODULE__, {:add_generator, generator_module, opts})
  end

  # Built-in generators
  def enable_typescript_generation(output_dir) do
    add_generator(AsyncApi.Generators.TypeScript, output_dir: output_dir)
  end

  def enable_phoenix_generation(output_dir) do
    add_generator(AsyncApi.Generators.Phoenix, output_dir: output_dir)
  end

  def enable_documentation_generation(output_dir) do
    add_generator(AsyncApi.Generators.Documentation, output_dir: output_dir)
  end

  # GenServer implementation
  def init(opts) do
    {:ok, watcher_pid} = FileSystem.start_link(dirs: ["."])
    FileSystem.subscribe(watcher_pid)

    state = %__MODULE__{
      watcher_pid: watcher_pid,
      generators: [],
      file_checksums: %{},
      config: Map.new(opts)
    }

    {:ok, state}
  end

  def handle_call({:watch_module, api_module, opts}, _from, state) do
    # Start watching the module file for changes
    module_file = get_module_file_path(api_module)
    Logger.info("Watching AsyncAPI module: #{api_module} at #{module_file}")
    
    # Perform initial generation
    generate_all_for_module(api_module, state.generators, opts)
    
    updated_state = %{state | 
      file_checksums: Map.put(state.file_checksums, module_file, get_file_checksum(module_file))
    }
    
    {:reply, :ok, updated_state}
  end

  def handle_call({:add_generator, generator_module, opts}, _from, state) do
    generator = %{module: generator_module, opts: opts}
    updated_generators = [generator | state.generators]
    
    {:reply, :ok, %{state | generators: updated_generators}}
  end

  def handle_info({:file_event, watcher_pid, {path, events}}, %{watcher_pid: watcher_pid} = state) do
    if should_regenerate?(path, events, state) do
      Logger.info("AsyncAPI file changed: #{path}, regenerating...")
      
      case detect_api_module(path) do
        {:ok, api_module} ->
          generate_all_for_module(api_module, state.generators, %{})
          updated_checksums = Map.put(state.file_checksums, path, get_file_checksum(path))
          {:noreply, %{state | file_checksums: updated_checksums}}
        
        {:error, _reason} ->
          {:noreply, state}
      end
    else
      {:noreply, state}
    end
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # Smart generation orchestration
  defp generate_all_for_module(api_module, generators, opts) do
    spec = AsyncApi.to_spec(api_module)
    timestamp = DateTime.utc_now()
    
    Logger.info("Generating code for #{api_module}...")
    
    # Run all generators in parallel
    tasks = Enum.map(generators, fn generator ->
      Task.async(fn ->
        try do
          result = apply(generator.module, :generate, [spec, generator.opts])
          {generator.module, :ok, result}
        rescue
          error ->
            Logger.error("Generator #{generator.module} failed: #{inspect(error)}")
            {generator.module, :error, error}
        end
      end)
    end)
    
    # Collect results
    results = Task.await_many(tasks, 30_000)
    
    # Log generation summary
    log_generation_results(results, timestamp)
    
    # Trigger hot reload if in development
    if Mix.env() == :dev do
      trigger_hot_reload(api_module)
    end
  end

  defp should_regenerate?(path, events, state) do
    # Only regenerate for .ex files that contain AsyncAPI modules
    String.ends_with?(path, ".ex") and 
    :modified in events and
    file_checksum_changed?(path, state.file_checksums)
  end

  defp file_checksum_changed?(path, checksums) do
    current_checksum = get_file_checksum(path)
    previous_checksum = Map.get(checksums, path)
    current_checksum != previous_checksum
  end

  defp get_file_checksum(path) do
    case File.read(path) do
      {:ok, content} -> :crypto.hash(:md5, content) |> Base.encode16()
      {:error, _} -> nil
    end
  end

  defp detect_api_module(file_path) do
    # Parse the file to find AsyncAPI modules
    try do
      {ast, _} = Code.string_to_quoted(File.read!(file_path))
      module_name = extract_module_name(ast)
      
      if uses_async_api?(ast) do
        {:ok, Module.concat([module_name])}
      else
        {:error, :not_async_api_module}
      end
    rescue
      _ -> {:error, :parse_error}
    end
  end

  defp extract_module_name(ast) do
    # Extract module name from AST
    # Implementation would traverse AST to find defmodule
    nil
  end

  defp uses_async_api?(ast) do
    # Check if the module uses AsyncApi
    # Implementation would check for "use AsyncApi" in AST
    false
  end

  defp trigger_hot_reload(api_module) do
    # Trigger Phoenix hot reload
    Phoenix.CodeReloader.reload!()
    
    # Notify LiveView clients of updates
    Phoenix.PubSub.broadcast(
      MyApp.PubSub,
      "async_api_updates",
      {:code_regenerated, api_module, DateTime.utc_now()}
    )
  end

  defp log_generation_results(results, timestamp) do
    successful = Enum.count(results, fn {_, status, _} -> status == :ok end)
    failed = Enum.count(results, fn {_, status, _} -> status == :error end)
    
    Logger.info("""
    Code generation completed at #{timestamp}
    ✅ Successful: #{successful}
    ❌ Failed: #{failed}
    """)
    
    # Log individual generator results
    Enum.each(results, fn
      {generator, :ok, result} ->
        Logger.debug("✅ #{generator}: #{inspect(result)}")
      {generator, :error, error} ->
        Logger.error("❌ #{generator}: #{inspect(error)}")
    end)
  end
end

# Generator behavior for consistent interface
defmodule AsyncApi.Generator do
  @callback generate(spec :: map(), opts :: keyword()) :: {:ok, term()} | {:error, term()}
end

# TypeScript client generator
defmodule AsyncApi.Generators.TypeScript do
  @behaviour AsyncApi.Generator

  def generate(spec, opts) do
    output_dir = Keyword.get(opts, :output_dir, "assets/js/generated")
    
    client_code = generate_typescript_client(spec)
    types_code = generate_typescript_types(spec)
    
    files = [
      {"#{output_dir}/client.ts", client_code},
      {"#{output_dir}/types.ts", types_code},
      {"#{output_dir}/index.ts", generate_index_file(spec)}
    ]
    
    Enum.each(files, fn {path, content} ->
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, content)
    end)
    
    {:ok, %{files_generated: length(files), output_dir: output_dir}}
  end

  defp generate_typescript_client(spec) do
    operations = spec[:operations] || %{}
    
    """
    // Auto-generated TypeScript client
    // Generated at: #{DateTime.utc_now()}
    
    import { Socket, Channel } from 'phoenix';
    import * as Types from './types';

    export class ApiClient {
      private socket: Socket;
      
      constructor(endpoint: string, params?: object) {
        this.socket = new Socket(endpoint, { params });
      }

      connect(): Promise<void> {
        return new Promise((resolve, reject) => {
          this.socket.onOpen(() => resolve());
          this.socket.onError(() => reject(new Error('Connection failed')));
          this.socket.connect();
        });
      }

      #{Enum.map_join(operations, "\n\n", fn {op_id, operation} ->
        generate_typescript_method(op_id, operation)
      end)}
    }
    """
  end

  defp generate_typescript_method(operation_id, operation) do
    """
      #{operation_id}(params: Types.#{Macro.camelize("#{operation_id}_params")}): Promise<Types.#{Macro.camelize("#{operation_id}_response")}> {
        const channel = this.socket.channel('#{operation["channel"]}', params);
        
        return new Promise((resolve, reject) => {
          channel.join()
            .receive('ok', resolve)
            .receive('error', reject);
        });
      }
    """
  end

  defp generate_typescript_types(spec) do
    # Generate TypeScript interfaces from AsyncAPI schemas
    """
    // Auto-generated TypeScript types
    // Generated at: #{DateTime.utc_now()}
    
    #{generate_interfaces_from_schemas(spec[:components][:schemas] || %{})}
    """
  end

  defp generate_index_file(_spec) do
    """
    // Auto-generated exports
    export * from './client';
    export * from './types';
    """
  end
end

# Phoenix channel generator
defmodule AsyncApi.Generators.Phoenix do
  @behaviour AsyncApi.Generator

  def generate(spec, opts) do
    output_dir = Keyword.get(opts, :output_dir, "lib/my_app_web/channels/generated")
    
    channels = generate_phoenix_channels(spec)
    
    files = Enum.map(channels, fn {name, code} ->
      filename = "#{output_dir}/#{Macro.underscore(name)}.ex"
      {filename, code}
    end)
    
    Enum.each(files, fn {path, content} ->
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, content)
    end)
    
    {:ok, %{channels_generated: length(files), output_dir: output_dir}}
  end

  defp generate_phoenix_channels(spec) do
    operations = spec[:operations] || %{}
    
    Enum.map(operations, fn {operation_id, operation} ->
      channel_name = "Generated#{Macro.camelize("#{operation_id}")}Channel"
      channel_code = generate_channel_module(channel_name, operation)
      {channel_name, channel_code}
    end)
  end

  defp generate_channel_module(name, operation) do
    """
    defmodule MyAppWeb.Channels.#{name} do
      @moduledoc \"\"\"
      Auto-generated Phoenix channel for operation: #{operation["summary"] || "N/A"}
      Generated at: #{DateTime.utc_now()}
      \"\"\"
      
      use Phoenix.Channel
      
      def join("#{operation["channel"]}", params, socket) do
        # Auto-generated parameter validation
        case validate_join_params(params) do
          {:ok, validated_params} ->
            socket = assign(socket, :params, validated_params)
            {:ok, socket}
          {:error, errors} ->
            {:error, %{reason: "Invalid parameters", errors: errors}}
        end
      end
      
      #{generate_message_handlers(operation["messages"] || [])}
      
      defp validate_join_params(params) do
        # Implementation would validate against AsyncAPI parameter schemas
        {:ok, params}
      end
    end
    """
  end

  defp generate_message_handlers(messages) do
    Enum.map_join(messages, "\n\n", fn message ->
      """
        def handle_in("#{message["name"]}", payload, socket) do
          case validate_message_payload(payload, "#{message["name"]}") do
            {:ok, validated_payload} ->
              broadcast!(socket, "#{message["name"]}", validated_payload)
              {:reply, {:ok, %{status: "received"}}, socket}
            {:error, errors} ->
              {:reply, {:error, %{reason: "Invalid payload", errors: errors}}, socket}
          end
        end
      """
    end)
  end
end