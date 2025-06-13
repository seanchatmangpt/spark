defmodule AsyncApi.Info do
  @moduledoc """
  Introspection module for AsyncAPI 3.0 DSL.

  This module provides functions to retrieve information about AsyncAPI 3.0 specifications
  defined using the AsyncAPI DSL at runtime. It supports all AsyncAPI 3.0 features including
  operations, replies, enhanced security, and comprehensive metadata.
  """

  alias AsyncApi.Dsl.{
    AsyncApiStruct, InfoStruct, Contact, License, Tag, ExternalDocs,
    Server, ServerVariable, Channel, Parameter, Operation, Reply,
    Message, CorrelationId, MessageExample, Schema, Property,
    SecurityScheme, OAuthFlows, OAuthFlow, SecurityRequirement,
    Components
  }

  # ===== ROOT DOCUMENT =====

  @doc """
  Get the AsyncAPI document ID.

  ## Examples

      iex> AsyncApi.Info.id(MyApp.EventApi)
      "urn:com:example:user-events"
  """
  def id(module) do
    case Spark.Dsl.Extension.get_entities(module, [:id]) do
      [%{id: id}] -> id
      [] -> nil
    end
  end

  @doc """
  Get the default content type.

  ## Examples

      iex> AsyncApi.Info.default_content_type(MyApp.EventApi)
      "application/json"
  """
  def default_content_type(module) do
    case Spark.Dsl.Extension.get_entities(module, [:default_content_type]) do
      [%{content_type: content_type}] -> content_type
      [] -> nil
    end
  end

  # ===== INFO SECTION =====

  @doc """
  Get the API info section from a module.

  ## Examples

      iex> AsyncApi.Info.info(MyApp.EventApi)
      %{
        title: "My Event API",
        version: "1.0.0",
        description: "Real-time event streaming API",
        contact: %{name: "API Support", email: "support@example.com"},
        license: %{name: "MIT", url: "https://opensource.org/licenses/MIT"}
      }
  """
  def info(module) do
    # Get basic info from section options
    title = Spark.Dsl.Extension.get_opt(module, [:info], :title)
    version = Spark.Dsl.Extension.get_opt(module, [:info], :version)
    description = Spark.Dsl.Extension.get_opt(module, [:info], :description)
    terms_of_service = Spark.Dsl.Extension.get_opt(module, [:info], :terms_of_service)
    
    # Get contact and license from entities
    contact_entities = Spark.Dsl.Extension.get_entities(module, [:info, :contact])
    license_entities = Spark.Dsl.Extension.get_entities(module, [:info, :license])
    
    contact = case contact_entities do
      [contact] -> contact
      _ -> nil
    end
    
    license = case license_entities do
      [license] -> license
      _ -> nil
    end
    
    # Only return info if at least title and version are present
    if title && version do
      %{
        title: title,
        version: version,
        description: description,
        terms_of_service: terms_of_service,
        contact: contact,
        license: license
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()
    else
      nil
    end
  end

  @doc """
  Get contact information from a module.

  ## Examples

      iex> AsyncApi.Info.contact(MyApp.EventApi)
      %AsyncApi.Dsl.Contact{name: "API Support", email: "support@example.com"}
  """
  def contact(module) do
    case info(module) do
      %{contact: contact} -> contact
      _ -> nil
    end
  end

  @doc """
  Get license information from a module.

  ## Examples

      iex> AsyncApi.Info.license(MyApp.EventApi)
      %AsyncApi.Dsl.License{name: "MIT", url: "https://opensource.org/licenses/MIT"}
  """
  def license(module) do
    case info(module) do
      %{license: license} -> license
      _ -> nil
    end
  end

  @doc """
  Get tags from info section.

  ## Examples

      iex> AsyncApi.Info.info_tags(MyApp.EventApi)
      [%AsyncApi.Dsl.Tag{name: "user_events", description: "Events related to user activities"}]
  """
  def info_tags(module) do
    case info(module) do
      %{tags: tags} when is_list(tags) -> tags
      _ -> []
    end
  end

  # ===== SERVERS =====

  @doc """
  Get all servers from a module.

  ## Examples

      iex> AsyncApi.Info.servers(MyApp.EventApi)
      [%AsyncApi.Dsl.Server{name: :production, host: "wss://api.example.com", ...}]
  """
  def servers(module) do
    Spark.Dsl.Extension.get_entities(module, [:servers])
  end

  @doc """
  Get a specific server by name.

  ## Examples

      iex> AsyncApi.Info.server(MyApp.EventApi, :production)
      %AsyncApi.Dsl.Server{name: :production, host: "wss://api.example.com", ...}
  """
  def server(module, name) do
    servers(module)
    |> Enum.find(&(&1.name == name))
  end

  @doc """
  Get server variables for a specific server.

  ## Examples

      iex> AsyncApi.Info.server_variables(MyApp.EventApi, :production)
      [%AsyncApi.Dsl.ServerVariable{name: :environment, default: "prod", ...}]
  """
  def server_variables(module, server_name) do
    case server(module, server_name) do
      nil -> []
      server -> server.variables || []
    end
  end

  @doc """
  Get all server names.

  ## Examples

      iex> AsyncApi.Info.server_names(MyApp.EventApi)
      [:production, :staging]
  """
  def server_names(module) do
    servers(module)
    |> Enum.map(& &1.name)
  end

  # ===== CHANNELS =====

  @doc """
  Get all channels from a module.

  ## Examples

      iex> AsyncApi.Info.channels(MyApp.EventApi)
      [%AsyncApi.Dsl.Channel{address: "/user/{userId}/notifications", ...}]
  """
  def channels(module) do
    Spark.Dsl.Extension.get_entities(module, [:channels])
  end

  @doc """
  Get a specific channel by address.

  ## Examples

      iex> AsyncApi.Info.channel(MyApp.EventApi, "/user/{userId}/notifications")
      %AsyncApi.Dsl.Channel{address: "/user/{userId}/notifications", ...}
  """
  def channel(module, address) do
    channels(module)
    |> Enum.find(&(&1.address == address))
  end

  @doc """
  Get all parameters for a specific channel.

  ## Examples

      iex> AsyncApi.Info.channel_parameters(MyApp.EventApi, "/user/{userId}/notifications")
      [%AsyncApi.Dsl.Parameter{name: :userId, ...}]
  """
  def channel_parameters(module, address) do
    case channel(module, address) do
      nil -> []
      channel -> channel.parameters || []
    end
  end

  @doc """
  Get all channel addresses.

  ## Examples

      iex> AsyncApi.Info.channel_addresses(MyApp.EventApi)
      ["/user/{userId}/notifications"]
  """
  def channel_addresses(module) do
    channels(module)
    |> Enum.map(& &1.address)
  end

  # ===== OPERATIONS (AsyncAPI 3.0 Feature) =====

  @doc """
  Get all operations from a module.

  ## Examples

      iex> AsyncApi.Info.operations(MyApp.EventApi)
      [%AsyncApi.Dsl.Operation{operation_id: :receive_user_notifications, ...}]
  """
  def operations(module) do
    Spark.Dsl.Extension.get_entities(module, [:operations])
  end

  @doc """
  Get a specific operation by ID.

  ## Examples

      iex> AsyncApi.Info.operation(MyApp.EventApi, :receive_user_notifications)
      %AsyncApi.Dsl.Operation{operation_id: :receive_user_notifications, ...}
  """
  def operation(module, operation_id) do
    operations(module)
    |> Enum.find(&(&1.operation_id == operation_id))
  end

  @doc """
  Get operations by action type.

  ## Examples

      iex> AsyncApi.Info.operations_by_action(MyApp.EventApi, :receive)
      [%AsyncApi.Dsl.Operation{action: :receive, ...}]
  """
  def operations_by_action(module, action) when action in [:send, :receive] do
    operations(module)
    |> Enum.filter(&(&1.action == action))
  end

  @doc """
  Get operations for a specific channel.

  ## Examples

      iex> AsyncApi.Info.operations_for_channel(MyApp.EventApi, "/user/{userId}/notifications")
      [%AsyncApi.Dsl.Operation{channel: "/user/{userId}/notifications", ...}]
  """
  def operations_for_channel(module, channel_address) do
    operations(module)
    |> Enum.filter(fn operation ->
      case operation.channel do
        ^channel_address -> true
        channel_atom when is_atom(channel_atom) -> Atom.to_string(channel_atom) == channel_address
        _ -> false
      end
    end)
  end

  @doc """
  Get operations for a specific channel (alias for operations_for_channel).

  ## Examples

      iex> AsyncApi.Info.channel_operations(MyApp.EventApi, "/user/{userId}/notifications")
      [%AsyncApi.Dsl.Operation{channel: "/user/{userId}/notifications", ...}]
  """
  def channel_operations(module, channel_address) do
    operations_for_channel(module, channel_address)
  end

  @doc """
  Get reply definition for an operation.

  ## Examples

      iex> AsyncApi.Info.operation_reply(MyApp.EventApi, :receive_user_notifications)
      %AsyncApi.Dsl.Reply{address: "/user/{userId}/notifications/ack", ...}
  """
  def operation_reply(module, operation_id) do
    case operation(module, operation_id) do
      nil -> nil
      operation -> operation.reply
    end
  end

  @doc """
  Get all operation IDs.

  ## Examples

      iex> AsyncApi.Info.operation_ids(MyApp.EventApi)
      [:receive_user_notifications, :send_user_command]
  """
  def operation_ids(module) do
    operations(module)
    |> Enum.map(& &1.operation_id)
  end

  # ===== COMPONENTS =====

  @doc """
  Get all component messages from a module.

  ## Examples

      iex> AsyncApi.Info.component_messages(MyApp.EventApi)
      [%AsyncApi.Dsl.Message{name: :notification_message, ...}]
  """
  def component_messages(module) do
    Spark.Dsl.Extension.get_entities(module, [:components, :messages])
  end

  @doc """
  Get all component schemas from a module.

  ## Examples

      iex> AsyncApi.Info.component_schemas(MyApp.EventApi)
      [%AsyncApi.Dsl.Schema{name: :notification_schema, ...}]
  """
  def component_schemas(module) do
    Spark.Dsl.Extension.get_entities(module, [:components, :schemas])
  end

  @doc """
  Get all security schemes from a module.

  ## Examples

      iex> AsyncApi.Info.security_schemes(MyApp.EventApi)
      [%AsyncApi.Dsl.SecurityScheme{name: :apiKey, type: :apiKey, ...}]
  """
  def security_schemes(module) do
    Spark.Dsl.Extension.get_entities(module, [:components, :security_schemes])
  end

  @doc """
  Get a specific component message by name.

  ## Examples

      iex> AsyncApi.Info.component_message(MyApp.EventApi, :notification_message)
      %AsyncApi.Dsl.Message{name: :notification_message, ...}
  """
  def component_message(module, name) do
    component_messages(module)
    |> Enum.find(&(&1.name == name))
  end

  @doc """
  Get a specific component schema by name.

  ## Examples

      iex> AsyncApi.Info.component_schema(MyApp.EventApi, :notification_schema)
      %AsyncApi.Dsl.Schema{name: :notification_schema, ...}
  """
  def component_schema(module, name) do
    component_schemas(module)
    |> Enum.find(&(&1.name == name))
  end

  @doc """
  Get a specific security scheme by name.

  ## Examples

      iex> AsyncApi.Info.security_scheme(MyApp.EventApi, :apiKey)
      %AsyncApi.Dsl.SecurityScheme{name: :apiKey, type: :apiKey, ...}
  """
  def security_scheme(module, name) do
    security_schemes(module)
    |> Enum.find(&(&1.name == name))
  end

  @doc """
  Get all properties for a specific schema.

  ## Examples

      iex> AsyncApi.Info.schema_properties(MyApp.EventApi, :notification_schema)
      [%AsyncApi.Dsl.Property{name: :id, type: :string, ...}]
  """
  def schema_properties(module, schema_name) do
    case component_schema(module, schema_name) do
      nil -> []
      schema -> schema.properties || []
    end
  end

  @doc """
  Get correlation ID for a message.

  ## Examples

      iex> AsyncApi.Info.message_correlation_id(MyApp.EventApi, :notification_message)
      %AsyncApi.Dsl.CorrelationId{location: "$message.header#/correlationId", ...}
  """
  def message_correlation_id(module, message_name) do
    case component_message(module, message_name) do
      nil -> nil
      message -> message.correlation_id
    end
  end

  @doc """
  Get examples for a message.

  ## Examples

      iex> AsyncApi.Info.message_examples(MyApp.EventApi, :notification_message)
      [%AsyncApi.Dsl.MessageExample{name: "basic_notification", ...}]
  """
  def message_examples(module, message_name) do
    case component_message(module, message_name) do
      nil -> []
      message -> message.examples || []
    end
  end

  @doc """
  Get the complete components structure.

  ## Examples

      iex> AsyncApi.Info.components(MyApp.EventApi)
      %{
        messages: [%AsyncApi.Dsl.Message{...}],
        schemas: [%AsyncApi.Dsl.Schema{...}],
        security_schemes: [%AsyncApi.Dsl.SecurityScheme{...}]
      }
  """
  def components(module) do
    %{
      messages: component_messages(module),
      schemas: component_schemas(module),
      security_schemes: security_schemes(module)
    }
  end

  # ===== CONVENIENCE FUNCTIONS =====

  @doc """
  Get all message names.

  ## Examples

      iex> AsyncApi.Info.message_names(MyApp.EventApi)
      [:notification_message, :ack_message]
  """
  def message_names(module) do
    component_messages(module)
    |> Enum.map(& &1.name)
  end

  @doc """
  Get all schema names.

  ## Examples

      iex> AsyncApi.Info.schema_names(MyApp.EventApi)
      [:notification_schema, :ack_schema]
  """
  def schema_names(module) do
    component_schemas(module)
    |> Enum.map(& &1.name)
  end

  @doc """
  Get all security scheme names.

  ## Examples

      iex> AsyncApi.Info.security_scheme_names(MyApp.EventApi)
      [:apiKey, :oauth2]
  """
  def security_scheme_names(module) do
    security_schemes(module)
    |> Enum.map(& &1.name)
  end

  # ===== EXISTENCE CHECKS =====

  @doc """
  Check if a module has a specific channel.

  ## Examples

      iex> AsyncApi.Info.has_channel?(MyApp.EventApi, "/user/{userId}/notifications")
      true
  """
  def has_channel?(module, address) do
    channel(module, address) != nil
  end

  @doc """
  Check if a module has a specific server.

  ## Examples

      iex> AsyncApi.Info.has_server?(MyApp.EventApi, :production)
      true
  """
  def has_server?(module, name) do
    server(module, name) != nil
  end

  @doc """
  Check if a module has a specific operation.

  ## Examples

      iex> AsyncApi.Info.has_operation?(MyApp.EventApi, :receive_user_notifications)
      true
  """
  def has_operation?(module, operation_id) do
    operation(module, operation_id) != nil
  end

  @doc """
  Check if a module has a specific message.

  ## Examples

      iex> AsyncApi.Info.has_message?(MyApp.EventApi, :notification_message)
      true
  """
  def has_message?(module, name) do
    component_message(module, name) != nil
  end

  @doc """
  Check if a module has a specific schema.

  ## Examples

      iex> AsyncApi.Info.has_schema?(MyApp.EventApi, :notification_schema)
      true
  """
  def has_schema?(module, name) do
    component_schema(module, name) != nil
  end

  @doc """
  Check if a module has a specific security scheme.

  ## Examples

      iex> AsyncApi.Info.has_security_scheme?(MyApp.EventApi, :apiKey)
      true
  """
  def has_security_scheme?(module, name) do
    security_scheme(module, name) != nil
  end

  # ===== TAGS AND EXTERNAL DOCS =====

  @doc """
  Get all tags used throughout the specification.

  ## Examples

      iex> AsyncApi.Info.all_tags(MyApp.EventApi)
      [%AsyncApi.Dsl.Tag{name: "user_events", ...}]
  """
  def all_tags(module) do
    # Collect tags from all sections
    info_tags = info_tags(module)
    server_tags = servers(module) |> Enum.flat_map(& &1.tags || [])
    channel_tags = channels(module) |> Enum.flat_map(& &1.tags || [])
    operation_tags = operations(module) |> Enum.flat_map(& &1.tags || [])
    message_tags = component_messages(module) |> Enum.flat_map(& &1.tags || [])
    
    (info_tags ++ server_tags ++ channel_tags ++ operation_tags ++ message_tags)
    |> Enum.uniq_by(& &1.name)
  end

  @doc """
  Get external documentation references.

  ## Examples

      iex> AsyncApi.Info.external_docs(MyApp.EventApi)
      %AsyncApi.Dsl.ExternalDocs{url: "https://docs.example.com", ...}
  """
  def external_docs(module) do
    case info(module) do
      %{external_docs: external_docs} -> external_docs
      _ -> nil
    end
  end
end