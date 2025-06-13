defmodule AsyncApi.PhoenixDsl do
  @moduledoc """
  A DSL for defining Phoenix channels using AsyncAPI specifications.
  
  This module provides a declarative way to define Phoenix channels with
  automatic routing, validation, and handler delegation based on AsyncAPI specs.
  
  ## Example
  
      defmodule MyAppWeb.ChatChannel do
        use AsyncApi.PhoenixDsl, api: MyApp.ChatApi
        
        join fn topic, payload, socket ->
          {:ok, socket}
        end
        
        plug MyAppWeb.ChannelPlugs.EnsureAuthenticated
        
        event "message:create", MyAppWeb.MessageHandler, :create
        
        handle "room:join", fn payload, bindings, socket ->
          # Handle room join logic
          {:reply, {:ok, %{status: "joined"}}, socket}
        end
        
        delegate "presence:", MyAppWeb.PresenceHandler
        
        scope "admin:" do
          plug &check_admin_permission/4
          
          event "user:*", MyAppWeb.AdminHandler, :handle_user_event
        end
      end
  """
  
  defmacro __using__(opts) do
    api_module = Keyword.get(opts, :api)
    
    quote do
      use Phoenix.Channel
      import AsyncApi.PhoenixDsl
      
      require Logger
      
      @api_module unquote(api_module)
      @event_handlers %{}
      @delegated_handlers []
      @join_handler nil
      @plugs []
      @scoped_handlers %{}
      
      Module.register_attribute(__MODULE__, :event_handlers, accumulate: true)
      Module.register_attribute(__MODULE__, :delegated_handlers, accumulate: true)
      Module.register_attribute(__MODULE__, :plugs, accumulate: true)
      Module.register_attribute(__MODULE__, :scoped_handlers, accumulate: true)
      
      @before_compile AsyncApi.PhoenixDsl
    end
  end
  
  @doc """
  Define a join handler for the channel.
  
  ## Examples
  
      join fn topic, payload, socket ->
        if authorized?(socket, topic) do
          {:ok, socket}
        else
          {:error, %{reason: "unauthorized"}}
        end
      end
  """
  defmacro join(handler) do
    quote do
      @join_handler unquote(handler)
    end
  end
  
  @doc """
  Add a plug to the channel processing pipeline.
  
  ## Examples
  
      plug MyAppWeb.ChannelPlugs.EnsureAuthenticated
      plug &check_permission/4, :admin
  """
  defmacro plug(plug_module, opts \\ []) do
    quote do
      @plugs {unquote(plug_module), unquote(opts)}
    end
  end
  
  @doc """
  Define an event handler for a specific event pattern.
  
  ## Examples
  
      event "message:create", MyAppWeb.MessageHandler, :create
      event "user:*", MyAppWeb.UserHandler, :handle_event
  """
  defmacro event(pattern, handler_module, function) do
    quote do
      @event_handlers {unquote(pattern), unquote(handler_module), unquote(function)}
    end
  end
  
  @doc """
  Define an inline event handler.
  
  ## Examples
  
      handle "room:join", fn payload, bindings, socket ->
        {:reply, {:ok, %{status: "joined"}}, socket}
      end
  """
  defmacro handle(pattern, handler) do
    quote do
      @event_handlers {unquote(pattern), :inline, unquote(handler)}
    end
  end
  
  @doc """
  Delegate all events matching a prefix to a handler module.
  
  ## Examples
  
      delegate "presence:", MyAppWeb.PresenceHandler
      delegate MyAppWeb.DefaultHandler  # catches all unmatched events
  """
  defmacro delegate(prefix_or_module, handler_module \\ nil) do
    case handler_module do
      nil ->
        # delegate MyAppWeb.DefaultHandler
        quote do
          @delegated_handlers {:all, unquote(prefix_or_module)}
        end
      
      _ ->
        # delegate "presence:", MyAppWeb.PresenceHandler
        quote do
          @delegated_handlers {unquote(prefix_or_module), unquote(handler_module)}
        end
    end
  end
  
  @doc """
  Define a scoped group of handlers with common plugs.
  
  ## Examples
  
      scope "admin:" do
        plug &check_admin_permission/4
        
        event "user:create", AdminHandler, :create_user
        event "user:delete", AdminHandler, :delete_user
      end
  """
  defmacro scope(prefix, do: block) do
    quote do
      @current_scope unquote(prefix)
      @scope_plugs []
      
      unquote(block)
      
      @scoped_handlers {@current_scope, @scope_plugs, @event_handlers}
      @current_scope nil
      @scope_plugs []
    end
  end
  
  @doc """
  Add a plug within a scope.
  """
  defmacro plug_scope(plug_module, opts \\ []) do
    quote do
      @scope_plugs {unquote(plug_module), unquote(opts)}
    end
  end
  
  # Compile-time hook to generate the channel implementation
  defmacro __before_compile__(_env) do
    quote do
      # Generate join/3 callback
      AsyncApi.PhoenixDsl.generate_join_callback(@join_handler)
      
      # Generate handle_in/3 callback with routing
      def handle_in(event, payload, socket) do
        AsyncApi.PhoenixDsl.route_event(
          event,
          payload,
          socket,
          @event_handlers,
          @delegated_handlers,
          @scoped_handlers,
          @plugs,
          @api_module
        )
      end
      
      # Generate validation helpers
      if @api_module do
        defp validate_message(message_type, payload) do
          AsyncApi.Validator.validate_message(@api_module, message_type, payload)
        end
        
        defp get_api_operations do
          AsyncApi.Info.operations(@api_module)
        end
        
        defp get_api_channels do
          AsyncApi.Info.channels(@api_module)
        end
      else
        defp validate_message(_message_type, _payload), do: :ok
        defp get_api_operations, do: %{}
        defp get_api_channels, do: %{}
      end
      
      # Generate helper functions
      defp extract_bindings(event, pattern) do
        AsyncApi.PhoenixDsl.extract_pattern_bindings(event, pattern)
      end
      
      defp apply_plugs(socket, payload, bindings, plugs) do
        AsyncApi.PhoenixDsl.apply_plug_pipeline(socket, payload, bindings, plugs)
      end
    end
  end
  
  @doc """
  Generate join callback based on defined handler.
  """
  def generate_join_callback(nil) do
    quote do
      def join(topic, payload, socket) do
        Logger.info("Joining topic: #{topic}")
        {:ok, socket}
      end
    end
  end
  
  def generate_join_callback(handler) do
    quote do
      def join(topic, payload, socket) do
        unquote(handler).(topic, payload, socket)
      end
    end
  end
  
  @doc """
  Route an incoming event to the appropriate handler.
  """
  def route_event(event, payload, socket, event_handlers, delegated_handlers, scoped_handlers, global_plugs, api_module) do
    # Apply global plugs first
    case apply_plug_pipeline(socket, payload, %{}, global_plugs) do
      {:cont, socket, payload, bindings} ->
        # Try to match event handlers
        case find_matching_handler(event, event_handlers ++ scoped_handlers) do
          {:ok, handler_info} ->
            execute_handler(handler_info, event, payload, socket, api_module)
            
          :not_found ->
            # Try delegated handlers
            case find_delegated_handler(event, delegated_handlers) do
              {:ok, handler_module} ->
                execute_delegated_handler(handler_module, event, payload, socket)
                
              :not_found ->
                Logger.warning("No handler found for event: #{event}")
                {:reply, {:error, %{reason: "unknown_event", event: event}}, socket}
            end
        end
        
      {:reply, response, socket} ->
        {:reply, response, socket}
        
      {:noreply, socket} ->
        {:noreply, socket}
    end
  end
  
  @doc """
  Find a matching handler for an event.
  """
  def find_matching_handler(event, handlers) do
    Enum.find_value(handlers, :not_found, fn
      {pattern, module, function} ->
        if pattern_matches?(event, pattern) do
          bindings = extract_pattern_bindings(event, pattern)
          {:ok, {module, function, bindings}}
        else
          nil
        end
      
      {scope_prefix, scope_plugs, scope_handlers} ->
        if String.starts_with?(event, scope_prefix) do
          scoped_event = String.replace_prefix(event, scope_prefix, "")
          case find_matching_handler(scoped_event, scope_handlers) do
            {:ok, {module, function, bindings}} ->
              {:ok, {module, function, bindings, scope_plugs}}
            :not_found ->
              nil
          end
        else
          nil
        end
    end)
  end
  
  @doc """
  Find a delegated handler for an event.
  """
  def find_delegated_handler(event, delegated_handlers) do
    Enum.find_value(delegated_handlers, :not_found, fn
      {:all, handler_module} ->
        {:ok, handler_module}
        
      {prefix, handler_module} ->
        if String.starts_with?(event, prefix) do
          {:ok, handler_module}
        else
          nil
        end
    end)
  end
  
  @doc """
  Execute a specific handler.
  """
  def execute_handler({module, function, bindings}, event, payload, socket, api_module) do
    execute_handler({module, function, bindings, []}, event, payload, socket, api_module)
  end
  
  def execute_handler({module, function, bindings, scope_plugs}, event, payload, socket, api_module) do
    # Apply scope plugs
    case apply_plug_pipeline(socket, payload, bindings, scope_plugs) do
      {:cont, socket, payload, bindings} ->
        case {module, function} do
          {:inline, handler_func} ->
            # Execute inline handler
            handler_func.(payload, bindings, socket)
            
          {handler_module, handler_function} ->
            # Validate payload if API module is available
            case validate_event_payload(event, payload, api_module) do
              :ok ->
                # Execute external handler
                apply(handler_module, handler_function, [payload, bindings, socket])
                
              {:error, validation_errors} ->
                Logger.warning("Validation failed for event #{event}: #{inspect(validation_errors)}")
                {:reply, {:error, %{reason: "validation_failed", details: validation_errors}}, socket}
            end
        end
        
      result ->
        result
    end
  end
  
  @doc """
  Execute a delegated handler.
  """
  def execute_delegated_handler(handler_module, event, payload, socket) do
    if function_exported?(handler_module, :handle_in, 4) do
      bindings = %{}
      apply(handler_module, :handle_in, [event, payload, bindings, socket])
    else
      Logger.error("Handler module #{handler_module} does not export handle_in/4")
      {:reply, {:error, %{reason: "handler_not_implemented"}}, socket}
    end
  end
  
  @doc """
  Apply a pipeline of plugs.
  """
  def apply_plug_pipeline(socket, payload, bindings, []), do: {:cont, socket, payload, bindings}
  
  def apply_plug_pipeline(socket, payload, bindings, [{plug_module, opts} | rest]) do
    case apply(plug_module, :call, [socket, payload, bindings, opts]) do
      {:cont, socket, payload, bindings} ->
        apply_plug_pipeline(socket, payload, bindings, rest)
        
      result ->
        result
    end
  end
  
  def apply_plug_pipeline(socket, payload, bindings, [plug_func | rest]) when is_function(plug_func) do
    case plug_func.(socket, payload, bindings) do
      {:cont, socket, payload, bindings} ->
        apply_plug_pipeline(socket, payload, bindings, rest)
        
      result ->
        result
    end
  end
  
  @doc """
  Check if an event matches a pattern.
  """
  def pattern_matches?(event, pattern) do
    regex_pattern = pattern
    |> String.replace("*", "([^:]*)")
    |> String.replace(":", "\\:")
    |> then(&"^#{&1}$")
    
    case Regex.compile(regex_pattern) do
      {:ok, regex} -> Regex.match?(regex, event)
      {:error, _} -> false
    end
  end
  
  @doc """
  Extract bindings from an event based on a pattern.
  """
  def extract_pattern_bindings(event, pattern) do
    # Convert pattern to regex and extract named captures
    parts = String.split(pattern, ":")
    event_parts = String.split(event, ":")
    
    parts
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {part, index}, acc ->
      cond do
        part == "*" ->
          Map.put(acc, "wildcard_#{index}", Enum.at(event_parts, index))
          
        String.starts_with?(part, "{") && String.ends_with?(part, "}") ->
          binding_name = String.slice(part, 1..-2)
          Map.put(acc, binding_name, Enum.at(event_parts, index))
          
        true ->
          acc
      end
    end)
  end
  
  @doc """
  Validate event payload against AsyncAPI specification.
  """
  def validate_event_payload(_event, _payload, nil), do: :ok
  
  def validate_event_payload(event, payload, api_module) do
    # Find corresponding message type in AsyncAPI spec
    operations = AsyncApi.Info.operations(api_module)
    
    case find_operation_for_event(event, operations) do
      {:ok, operation} ->
        message_type = operation[:message]
        AsyncApi.Validator.validate_message(api_module, message_type, payload)
        
      :not_found ->
        # No specific validation found, allow through
        :ok
    end
  end
  
  defp find_operation_for_event(event, operations) do
    # This is a simplified mapping - you might want more sophisticated matching
    operation = Enum.find(operations, fn {_name, op} ->
      # Match based on some convention, e.g., event name maps to operation name
      event_base = event |> String.split(":") |> List.first()
      to_string(op[:message]) == event_base
    end)
    
    case operation do
      {_name, op} -> {:ok, op}
      nil -> :not_found
    end
  end
end