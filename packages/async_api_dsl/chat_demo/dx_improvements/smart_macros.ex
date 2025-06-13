defmodule AsyncApi.SmartMacros do
  @moduledoc """
  Advanced macro system that generates Phoenix channels, LiveViews, and client code
  automatically from AsyncAPI definitions.
  """

  defmacro __using__(_opts) do
    quote do
      import AsyncApi.SmartMacros
      Module.register_attribute(__MODULE__, :generated_channels, accumulate: true)
      Module.register_attribute(__MODULE__, :generated_clients, accumulate: true)
      @before_compile AsyncApi.SmartMacros
    end
  end

  @doc """
  Auto-generates Phoenix channel from AsyncAPI operation
  """
  defmacro auto_channel(operation_name, opts \\ []) do
    quote do
      @generated_channels {unquote(operation_name), unquote(opts)}
    end
  end

  @doc """
  Auto-generates TypeScript/JavaScript client code
  """
  defmacro auto_client(language, opts \\ []) do
    quote do
      @generated_clients {unquote(language), unquote(opts)}
    end
  end

  defmacro __before_compile__(env) do
    channels = Module.get_attribute(env.module, :generated_channels)
    clients = Module.get_attribute(env.module, :generated_clients)
    
    channel_modules = generate_channel_modules(channels, env.module)
    client_files = generate_client_files(clients, env.module)

    quote do
      # Generate Phoenix channels at compile time
      unquote_splicing(channel_modules)
      
      # Write client files to disk during compilation
      unquote(write_client_files(client_files))
    end
  end

  # Generate Phoenix channel modules from AsyncAPI operations
  defp generate_channel_modules(channels, module) do
    Enum.map(channels, fn {operation_name, opts} ->
      operation = get_operation(module, operation_name)
      
      quote do
        defmodule unquote(Module.concat([module, "Channels", Macro.camelize("#{operation_name}")])) do
          use Phoenix.Channel
          
          # Auto-generated join handler
          def join(unquote(operation.channel), params, socket) do
            # Smart validation based on AsyncAPI schema
            case validate_params(params, unquote(Macro.escape(operation.parameters))) do
              {:ok, validated_params} ->
                socket = assign(socket, :params, validated_params)
                {:ok, socket}
              {:error, errors} ->
                {:error, %{reason: "Invalid parameters", errors: errors}}
            end
          end

          # Auto-generated message handlers
          unquote_splicing(generate_message_handlers(operation))

          # Smart parameter validation
          defp validate_params(params, schema) do
            # Use ExJsonSchema for compile-time generated validation
            AsyncApi.Validation.validate(params, schema)
          end
        end
      end
    end)
  end

  # Generate message handlers for each operation message
  defp generate_message_handlers(operation) do
    operation.messages
    |> Enum.map(fn message ->
      quote do
        def handle_in(unquote("#{message.name}"), payload, socket) do
          case validate_message(payload, unquote(Macro.escape(message.payload))) do
            {:ok, validated_payload} ->
              # Auto-broadcast with intelligent routing
              broadcast!(socket, unquote("#{message.name}"), validated_payload)
              {:reply, {:ok, %{status: "received"}}, socket}
            {:error, errors} ->
              {:reply, {:error, %{reason: "Invalid payload", errors: errors}}, socket}
          end
        end
      end
    end)
  end

  # Generate client code files
  defp generate_client_files(clients, module) do
    Enum.map(clients, fn {language, opts} ->
      case language do
        :typescript -> generate_typescript_client(module, opts)
        :javascript -> generate_javascript_client(module, opts)
        :elixir -> generate_elixir_client(module, opts)
        :python -> generate_python_client(module, opts)
      end
    end)
  end

  defp generate_typescript_client(module, _opts) do
    operations = AsyncApi.Info.operations(module)
    
    """
    // Auto-generated TypeScript client for #{module}
    import { Socket } from 'phoenix';

    export class #{module}Client {
      private socket: Socket;
      private channels: Map<string, any> = new Map();

      constructor(socketUrl: string, params?: object) {
        this.socket = new Socket(socketUrl, { params });
        this.socket.connect();
      }

      #{Enum.map_join(operations, "\n\n", &generate_ts_method/1)}
    }
    """
  end

  defp generate_ts_method(operation) do
    """
      async #{operation.operation_id}(params: #{generate_ts_interface(operation.parameters)}): Promise<#{generate_ts_return_type(operation)}> {
        const channel = this.socket.channel('#{operation.channel}', params);
        
        return new Promise((resolve, reject) => {
          channel.join()
            .receive('ok', (response) => resolve(response))
            .receive('error', (error) => reject(error));
        });
      }
    """
  end

  defp write_client_files(client_files) do
    quote do
      Enum.each(unquote(client_files), fn {filename, content} ->
        File.mkdir_p!(Path.dirname(filename))
        File.write!(filename, content)
        IO.puts("Generated client: #{filename}")
      end)
    end
  end
end