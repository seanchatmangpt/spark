defmodule AsyncApi.ChannelHandler do
  @moduledoc """
  Behaviour and utilities for creating channel handlers.
  
  Channel handlers are modules that implement the business logic for
  handling specific events in Phoenix channels using the AsyncAPI DSL.
  
  ## Example
  
      defmodule MyAppWeb.MessageHandler do
        use AsyncApi.ChannelHandler
        
        # Add plugs specific to this handler
        plug MyAppWeb.ChannelPlugs.CheckPermission, :send_messages when action in [:create]
        plug &rate_limit/4
        
        def handle_in(event, payload, bindings, socket) do
          # Handle any delegated event
          Logger.info("Handling delegated event: " <> to_string(event))
          {:noreply, socket}
        end
        
        def create(payload, bindings, socket) do
          case MyApp.Messages.create_message(payload, socket.assigns.user_id) do
            {:ok, message} ->
              # Broadcast to room
              broadcast_from(socket, "message:created", message)
              {:reply, {:ok, message}, socket}
              
            {:error, changeset} ->
              {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
          end
        end
        
        def update(payload, bindings, socket) do
          message_id = bindings["message_id"]
          
          case MyApp.Messages.update_message(message_id, payload, socket.assigns.user_id) do
            {:ok, message} ->
              broadcast_from(socket, "message:updated", message)
              {:reply, {:ok, message}, socket}
              
            {:error, :not_found} ->
              {:reply, {:error, %{reason: "message_not_found"}}, socket}
              
            {:error, :unauthorized} ->
              {:reply, {:error, %{reason: "unauthorized"}}, socket}
          end
        end
        
        defp rate_limit(socket, payload, bindings, _opts) do
          case check_user_rate_limit(socket.assigns.user_id) do
            :ok -> {:cont, socket, payload, bindings}
            {:error, :rate_limited} -> {:reply, {:error, %{reason: "rate_limited"}}, socket}
          end
        end
        
        defp check_user_rate_limit(user_id) do
          # Implement rate limiting logic
          :ok
        end
      end
  """
  
  @callback handle_in(event :: String.t(), payload :: map(), bindings :: map(), socket :: Phoenix.Socket.t()) ::
    {:reply, {:ok | :error, map()}, Phoenix.Socket.t()} |
    {:noreply, Phoenix.Socket.t()} |
    {:stop, reason :: any(), Phoenix.Socket.t()}
  
  defmacro __using__(_opts) do
    quote do
      @behaviour AsyncApi.ChannelHandler
      
      import Phoenix.Channel
      require Logger
      
      @handler_plugs []
      @current_action nil
      
      Module.register_attribute(__MODULE__, :handler_plugs, accumulate: true)
      
      @before_compile AsyncApi.ChannelHandler
      
      # Default implementation for handle_in/4
      def handle_in(event, payload, bindings, socket) do
        Logger.info("Unhandled event in #{__MODULE__}: #{event}")
        {:noreply, socket}
      end
      
      defoverridable handle_in: 4
    end
  end
  
  defmacro __before_compile__(_env) do
    quote do
      # Generate plug application wrapper for handler functions
      AsyncApi.ChannelHandler.generate_handler_wrappers(__MODULE__, @handler_plugs)
    end
  end
  
  @doc """
  Add a plug to the handler pipeline.
  
  Plugs can be conditional based on the action being performed.
  
  ## Examples
  
      plug MyAppWeb.ChannelPlugs.CheckPermission, :send_messages
      plug &rate_limit/4 when action in [:create, :update]
  """
  defmacro plug(plug_module, opts \\ [], conditions \\ []) do
    quote do
      @handler_plugs {unquote(plug_module), unquote(opts), unquote(conditions)}
    end
  end
  
  @doc """
  Generate handler wrapper functions that apply plugs.
  """
  def generate_handler_wrappers(module, plugs) do
    # Get all exported functions from the module
    functions = module.__info__(:functions)
    
    # Filter for handler functions (exclude handle_in and standard callbacks)
    handler_functions = Enum.filter(functions, fn
      {:handle_in, 4} -> false
      {:__info__, 1} -> false
      {:module_info, _} -> false
      {name, arity} when arity == 3 -> true  # payload, bindings, socket
      _ -> false
    end)
    
    # Generate wrapped versions
    Enum.each(handler_functions, fn {function_name, _arity} ->
      generate_handler_wrapper(module, function_name, plugs)
    end)
  end
  
  defp generate_handler_wrapper(module, function_name, plugs) do
    # Filter plugs applicable to this function
    applicable_plugs = Enum.filter(plugs, fn {_plug, _opts, conditions} ->
      case conditions do
        [] -> true
        conditions -> function_name in Keyword.get(conditions, :action, [])
      end
    end)
    
    if not Enum.empty?(applicable_plugs) do
      # Create wrapper function that applies plugs before calling original
      original_function = :"#{function_name}_original"
      
      # Rename original function
      :code.purge(module)
      {:module, _} = :code.load_binary(module, to_charlist("#{module}.beam"), 
        rename_function(module, function_name, original_function))
      
      # Define new function with plug pipeline
      Code.eval_quoted(
        quote do
          def unquote(function_name)(payload, bindings, socket) do
            case apply_handler_plugs(socket, payload, bindings, unquote(applicable_plugs)) do
              {:cont, socket, payload, bindings} ->
                unquote(original_function)(payload, bindings, socket)
                
              result ->
                result
            end
          end
        end,
        [],
        __ENV__
      )
    end
  end
  
  @doc """
  Apply handler-specific plugs.
  """
  def apply_handler_plugs(socket, payload, bindings, []), do: {:cont, socket, payload, bindings}
  
  def apply_handler_plugs(socket, payload, bindings, [{plug_module, opts, _conditions} | rest]) do
    case apply(plug_module, :call, [socket, payload, bindings, opts]) do
      {:cont, socket, payload, bindings} ->
        apply_handler_plugs(socket, payload, bindings, rest)
        
      result ->
        result
    end
  end
  
  def apply_handler_plugs(socket, payload, bindings, [plug_func | rest]) when is_function(plug_func, 4) do
    case plug_func.(socket, payload, bindings, []) do
      {:cont, socket, payload, bindings} ->
        apply_handler_plugs(socket, payload, bindings, rest)
        
      result ->
        result
    end
  end
  
  # Helper function for bytecode manipulation (simplified)
  defp rename_function(module, old_name, new_name) do
    # This is a simplified version - in practice you'd need proper bytecode manipulation
    # For now, this serves as a placeholder for the concept
    module.__info__(:compile)[:source]
  end
  
  @doc """
  Format changeset errors for API responses.
  """
  def format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
  
  @doc """
  Broadcast a message to all subscribers of the current topic.
  """
  def broadcast_to_topic(socket, event, payload) do
    Phoenix.Channel.broadcast(socket, event, payload)
  end
  
  @doc """
  Broadcast a message to all subscribers except the current socket.
  """
  def broadcast_from_topic(socket, event, payload) do
    Phoenix.Channel.broadcast_from(socket, event, payload)
  end
  
  @doc """
  Reply with success response.
  """
  def reply_success(socket, data \\ %{}) do
    {:reply, {:ok, data}, socket}
  end
  
  @doc """
  Reply with error response.
  """
  def reply_error(socket, reason, details \\ %{}) do
    error_data = %{reason: reason}
    error_data = if Enum.empty?(details), do: error_data, else: Map.put(error_data, :details, details)
    {:reply, {:error, error_data}, socket}
  end
  
  @doc """
  Get user ID from socket assigns.
  """
  def current_user_id(socket) do
    socket.assigns[:user_id] || socket.assigns[:current_user_id]
  end
  
  @doc """
  Get current user from socket assigns.
  """
  def current_user(socket) do
    socket.assigns[:current_user] || socket.assigns[:user]
  end
  
  @doc """
  Check if user is authenticated.
  """
  def authenticated?(socket) do
    not is_nil(current_user_id(socket))
  end
  
  @doc """
  Extract parameter from bindings with optional default.
  """
  def get_binding(bindings, key, default \\ nil) do
    Map.get(bindings, key, default)
  end
  
  @doc """
  Validate required parameters are present in payload.
  """
  def validate_required_params(payload, required_keys) do
    missing_keys = Enum.filter(required_keys, fn key ->
      not Map.has_key?(payload, key) or is_nil(Map.get(payload, key))
    end)
    
    case missing_keys do
      [] -> :ok
      keys -> {:error, "Missing required parameters: #{Enum.join(keys, ", ")}"}
    end
  end
  
  @doc """
  Create a standardized timestamp.
  """
  def timestamp do
    DateTime.utc_now() |> DateTime.to_iso8601()
  end
  
  @doc """
  Generate a UUID.
  """
  def generate_id do
    UUID.uuid4()
  end
end