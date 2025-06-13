defmodule AsyncApi do
  @moduledoc """
  A DSL for defining AsyncAPI 3.0 specifications in Elixir.

  AsyncAPI is a specification for describing event-driven APIs and message-driven architectures.
  This DSL provides a clean, readable way to define AsyncAPI 3.0 specifications that can be
  validated at compile time and used to generate documentation and client code.

  ## Example

      defmodule MyApp.EventApi do
        use AsyncApi

        # Root-level configuration
        id "urn:com:example:user-events"
        default_content_type "application/json"

        info do
          title "My Event API"
          version "1.0.0"
          description "Real-time event streaming API"
          
          contact do
            name "API Support"
            url "https://example.com/support"
            email "support@example.com"
          end
          
          license do
            name "MIT"
            url "https://opensource.org/licenses/MIT"
          end
          
          tags do
            tag :user_events do
              name "User Events"
              description "Events related to user activities"
            end
          end
        end

        servers do
          server :production, "wss://api.example.com" do
            protocol :websockets
            description "Production WebSocket server"
            
            variables do
              variable :environment do
                default "prod"
                description "Environment name"
                enum ["prod", "staging", "dev"]
              end
            end
          end
        end

        channels do
          channel "/user/{userId}/notifications" do
            description "User-specific notifications"
            
            parameters do
              parameter :userId do
                description "The user ID"
                schema do
                  type :string
                  pattern "^[0-9]+$"
                end
              end
            end
          end
        end

        operations do
          operation :receive_user_notifications do
            action :receive
            channel "/user/{userId}/notifications"
            summary "Receive user notifications"
            description "Subscribe to receive user-specific notifications"
            
            messages do
              message :notification_message
            end
            
            reply do
              address "/user/{userId}/notifications/ack"
              messages do
                message :ack_message
              end
            end
          end
        end

        components do
          messages do
            message :notification_message do
              name "User Notification"
              title "User Notification Message"
              summary "A notification sent to users"
              content_type "application/json"
              payload :notification_schema
              
              correlation_id do
                description "Correlation ID for request tracking"
                location "$message.header#/correlationId"
              end
            end

            message :ack_message do
              name "Acknowledgment"
              title "Message Acknowledgment"
              content_type "application/json"
              payload :ack_schema
            end
          end
          
          schemas do
            schema :notification_schema do
              type :object
              title "Notification"
              description "User notification payload"
              
              properties do
                property :id, :string do
                  description "Unique notification ID"
                  format "uuid"
                end
                property :message, :string do
                  description "Notification message"
                  min_length 1
                  max_length 500
                end
                property :timestamp, :string do
                  description "Notification timestamp"
                  format "date-time"
                end
                property :priority, :string do
                  description "Notification priority"
                  enum ["low", "medium", "high", "urgent"]
                  default "medium"
                end
              end
              
              required [:id, :message, :timestamp]
            end

            schema :ack_schema do
              type :object
              title "Acknowledgment"
              
              properties do
                property :messageId, :string do
                  description "ID of the acknowledged message"
                  format "uuid"
                end
                property :status, :string do
                  description "Acknowledgment status"
                  enum ["received", "processed", "error"]
                end
              end
              
              required [:messageId, :status]
            end
          end

          security_schemes do
            security_scheme :apiKey do
              type :apiKey
              name "X-API-Key"
              location :header
              description "API key for authentication"
            end

            security_scheme :oauth2 do
              type :oauth2
              description "OAuth2 authentication"
              
              flows do
                authorization_code do
                  authorization_url "https://example.com/oauth/authorize"
                  token_url "https://example.com/oauth/token"
                  
                  scopes do
                    scope "notifications:read", "Read user notifications"
                    scope "notifications:write", "Send user notifications"
                  end
                end
              end
            end
          end
        end
      end

  ## Sections

  - `info` - API metadata including title, version, and description
  - `servers` - Server connection details and protocols  
  - `channels` - Communication channels for message flow
  - `operations` - Specific message operations (send/receive) - NEW in v3.0
  - `components` - Reusable schemas, messages, security schemes, and other components

  ## AsyncAPI 3.0 Features

  This DSL supports all AsyncAPI 3.0 features including:
  - Operations as first-class citizens (separate from channels)
  - Reply operations for request-reply patterns
  - Enhanced security scheme definitions
  - Message and operation traits for reusability
  - Comprehensive protocol bindings
  - Server variables for dynamic configuration
  - Rich metadata with tags, contact, and license information

  ## Runtime Introspection

  You can introspect AsyncAPI definitions at runtime:

      iex> AsyncApi.Info.info(MyApp.EventApi)
      %{title: "My Event API", version: "1.0.0", ...}

      iex> AsyncApi.Info.operations(MyApp.EventApi)
      [%AsyncApi.Operation{...}]

  """

  use Spark.Dsl,
    default_extensions: [extensions: [AsyncApi.Dsl]]

  @doc """
  Generates the complete AsyncAPI 3.0 specification as a map.

  This can be serialized to JSON or YAML to create a valid AsyncAPI 3.0 document.
  Supports all AsyncAPI 3.0 features including operations, replies, enhanced security,
  and comprehensive metadata.

  ## Examples

      spec = AsyncApi.to_spec(MyApp.EventApi)
      json_spec = Jason.encode!(spec)
      yaml_spec = YamlElixir.write_to_string!(spec)

  """
  def to_spec(module) do
    %{
      asyncapi: "3.0.0",
      info: AsyncApi.Info.info(module)
    }
    # Add optional root-level fields
    |> add_if_present(:id, AsyncApi.Info.id(module))
    |> add_if_present(:defaultContentType, AsyncApi.Info.default_content_type(module))
    |> add_if_present(:servers, servers_to_spec(AsyncApi.Info.servers(module)))
    |> add_if_present(:channels, channels_to_spec(AsyncApi.Info.channels(module)))
    |> add_if_present(:operations, operations_to_spec(AsyncApi.Info.operations(module)))
    |> add_if_present(:components, components_to_spec(AsyncApi.Info.components(module)))
  end

  # Helper function to add fields only if they have content
  defp add_if_present(spec, _key, nil), do: spec
  defp add_if_present(spec, _key, []), do: spec
  defp add_if_present(spec, _key, %{} = map) when map_size(map) == 0, do: spec
  defp add_if_present(spec, key, value), do: Map.put(spec, key, value)

  # ===== SERVERS =====

  defp servers_to_spec(servers) when length(servers) == 0, do: nil
  defp servers_to_spec(servers) do
    servers
    |> Enum.map(fn server ->
      server_spec = %{
        host: server.host,
        protocol: to_string(server.protocol)
      }
      |> add_if_present(:protocolVersion, server.protocol_version)
      |> add_if_present(:pathname, server.pathname)
      |> add_if_present(:title, server.title)
      |> add_if_present(:summary, server.summary)
      |> add_if_present(:description, server.description)
      |> add_if_present(:variables, server_variables_to_spec(server.variables))
      |> add_if_present(:security, security_requirements_to_spec(server.security))
      |> add_if_present(:tags, tags_to_spec(server.tags))
      |> add_if_present(:externalDocs, external_docs_to_spec(server.external_docs))
      |> add_if_present(:bindings, server.bindings)

      {server.name, server_spec}
    end)
    |> Map.new()
  end

  defp server_variables_to_spec(nil), do: nil
  defp server_variables_to_spec([]), do: nil
  defp server_variables_to_spec(variables) do
    variables
    |> Enum.map(fn var ->
      var_spec = %{}
      |> add_if_present(:enum, var.enum)
      |> add_if_present(:default, var.default)
      |> add_if_present(:description, var.description)
      |> add_if_present(:examples, var.examples)

      {var.name, var_spec}
    end)
    |> Map.new()
  end

  # ===== CHANNELS =====

  defp channels_to_spec(channels) when length(channels) == 0, do: nil
  defp channels_to_spec(channels) do
    channels
    |> Enum.map(fn channel ->
      channel_spec = %{}
      |> add_if_present(:title, channel.title)
      |> add_if_present(:summary, channel.summary)
      |> add_if_present(:description, channel.description)
      |> add_if_present(:servers, channel.servers)
      |> add_if_present(:parameters, parameters_to_spec(channel.parameters))
      |> add_if_present(:tags, tags_to_spec(channel.tags))
      |> add_if_present(:externalDocs, external_docs_to_spec(channel.external_docs))
      |> add_if_present(:bindings, channel.bindings)

      {channel.address, channel_spec}
    end)
    |> Map.new()
  end

  defp parameters_to_spec(nil), do: nil
  defp parameters_to_spec([]), do: nil
  defp parameters_to_spec(parameters) do
    parameters
    |> Enum.map(fn param ->
      param_spec = %{}
      |> add_if_present(:description, param.description)
      |> add_if_present(:schema, schema_to_spec(param.schema))
      |> add_if_present(:location, param.location)

      {param.name, param_spec}
    end)
    |> Map.new()
  end

  # ===== OPERATIONS (AsyncAPI 3.0 Feature) =====

  defp operations_to_spec(operations) when length(operations) == 0, do: nil
  defp operations_to_spec(operations) do
    operations
    |> Enum.map(fn operation ->
      operation_spec = %{
        action: operation.action,
        channel: channel_ref_to_spec(operation.channel)
      }
      |> add_if_present(:title, operation.title)
      |> add_if_present(:summary, operation.summary)
      |> add_if_present(:description, operation.description)
      |> add_if_present(:security, security_requirements_to_spec(operation.security))
      |> add_if_present(:tags, tags_to_spec(operation.tags))
      |> add_if_present(:externalDocs, external_docs_to_spec(operation.external_docs))
      |> add_if_present(:bindings, operation.bindings)
      |> add_if_present(:traits, traits_to_spec(operation.traits))
      |> add_if_present(:messages, operation_messages_to_spec(operation.messages))
      |> add_if_present(:reply, reply_to_spec(operation.reply))

      {operation.operation_id, operation_spec}
    end)
    |> Map.new()
  end

  defp channel_ref_to_spec(channel_ref) when is_atom(channel_ref) do
    %{"$ref" => "#/channels/#{channel_ref}"}
  end
  defp channel_ref_to_spec(channel_ref) when is_binary(channel_ref) do
    %{"$ref" => "#/channels/#{URI.encode(channel_ref)}"}
  end

  defp operation_messages_to_spec(nil), do: nil
  defp operation_messages_to_spec([]), do: nil
  defp operation_messages_to_spec(messages) do
    messages
    |> Enum.map(fn
      %{name: name} -> %{"$ref" => "#/components/messages/#{name}"}
      name when is_atom(name) -> %{"$ref" => "#/components/messages/#{name}"}
    end)
  end

  defp reply_to_spec(nil), do: nil
  defp reply_to_spec([]), do: nil
  defp reply_to_spec(reply) do
    reply_spec = %{}
    |> add_if_present(:address, reply.address)
    |> add_if_present(:channel, channel_ref_to_spec(reply.channel))
    |> add_if_present(:messages, operation_messages_to_spec(reply.messages))

    reply_spec
  end

  # ===== COMPONENTS =====

  defp components_to_spec(%{messages: [], schemas: [], security_schemes: []}), do: nil
  defp components_to_spec(components) do
    %{}
    |> add_if_present(:messages, component_messages_to_spec(components.messages))
    |> add_if_present(:schemas, component_schemas_to_spec(components.schemas))
    |> add_if_present(:securitySchemes, component_security_schemes_to_spec(components.security_schemes))
  end

  defp component_messages_to_spec([]), do: nil
  defp component_messages_to_spec(messages) do
    messages
    |> Enum.map(fn message ->
      message_spec = %{}
      |> add_if_present(:title, message.title)
      |> add_if_present(:summary, message.summary)
      |> add_if_present(:description, message.description)
      |> add_if_present(:contentType, message.content_type)
      |> add_if_present(:headers, schema_ref_to_spec(message.headers))
      |> add_if_present(:payload, schema_ref_to_spec(message.payload))
      |> add_if_present(:correlationId, correlation_id_to_spec(message.correlation_id))
      |> add_if_present(:schemaFormat, message.schema_format)
      |> add_if_present(:bindings, message.bindings)
      |> add_if_present(:examples, message_examples_to_spec(message.examples))
      |> add_if_present(:tags, tags_to_spec(message.tags))
      |> add_if_present(:externalDocs, external_docs_to_spec(message.external_docs))
      |> add_if_present(:traits, traits_to_spec(message.traits))

      {message.name, message_spec}
    end)
    |> Map.new()
  end

  defp component_schemas_to_spec([]), do: nil
  defp component_schemas_to_spec(schemas) do
    schemas
    |> Enum.map(fn schema ->
      {schema.name, schema_to_spec(schema)}
    end)
    |> Map.new()
  end

  defp component_security_schemes_to_spec([]), do: nil
  defp component_security_schemes_to_spec(security_schemes) do
    security_schemes
    |> Enum.map(fn scheme ->
      scheme_spec = %{
        type: scheme.type
      }
      |> add_if_present(:description, scheme.description)
      |> add_security_scheme_fields(scheme)

      {scheme.name, scheme_spec}
    end)
    |> Map.new()
  end

  defp add_security_scheme_fields(spec, %{type: :apiKey} = scheme) do
    spec
    |> add_if_present(:name, scheme.name_field)
    |> add_if_present(:in, scheme.location)
  end

  defp add_security_scheme_fields(spec, %{type: :http} = scheme) do
    spec
    |> add_if_present(:scheme, scheme.scheme)
    |> add_if_present(:bearerFormat, scheme.bearer_format)
  end

  defp add_security_scheme_fields(spec, %{type: :oauth2} = scheme) do
    spec
    |> add_if_present(:flows, oauth_flows_to_spec(scheme.flows))
  end

  defp add_security_scheme_fields(spec, %{type: :openIdConnect} = scheme) do
    spec
    |> add_if_present(:openIdConnectUrl, scheme.open_id_connect_url)
  end

  defp add_security_scheme_fields(spec, _scheme), do: spec

  # ===== SCHEMAS =====

  defp schema_to_spec(%{name: _name} = schema) do
    # Full schema object
    schema_spec = %{}
    |> add_if_present(:title, schema.title)
    |> add_if_present(:description, schema.description)
    |> add_if_present(:type, to_string(schema.type))
    |> add_if_present(:format, schema.format)
    |> add_if_present(:enum, schema.enum)
    |> add_if_present(:const, schema.const)
    |> add_if_present(:default, schema.default)
    |> add_if_present(:examples, schema.examples)
    |> add_if_present(:readOnly, schema.read_only)
    |> add_if_present(:writeOnly, schema.write_only)
    |> add_if_present(:multipleOf, schema.multiple_of)
    |> add_if_present(:maximum, schema.maximum)
    |> add_if_present(:exclusiveMaximum, schema.exclusive_maximum)
    |> add_if_present(:minimum, schema.minimum)
    |> add_if_present(:exclusiveMinimum, schema.exclusive_minimum)
    |> add_if_present(:maxLength, schema.max_length)
    |> add_if_present(:minLength, schema.min_length)
    |> add_if_present(:pattern, schema.pattern)
    |> add_if_present(:maxItems, schema.max_items)
    |> add_if_present(:minItems, schema.min_items)
    |> add_if_present(:uniqueItems, schema.unique_items)
    |> add_if_present(:maxProperties, schema.max_properties)
    |> add_if_present(:minProperties, schema.min_properties)
    |> add_if_present(:required, schema.required)
    |> add_if_present(:additionalProperties, schema.additional_properties)
    |> add_if_present(:items, schema.items && schema_to_spec(schema.items))
    |> add_if_present(:properties, properties_to_spec(schema.property))

    schema_spec
  end

  defp schema_to_spec(schema_ref) when is_atom(schema_ref) do
    %{"$ref" => "#/components/schemas/#{schema_ref}"}
  end

  defp schema_to_spec(nil), do: nil

  defp schema_ref_to_spec(nil), do: nil
  defp schema_ref_to_spec(schema_ref) when is_atom(schema_ref) do
    %{"$ref" => "#/components/schemas/#{schema_ref}"}
  end

  defp properties_to_spec(nil), do: nil
  defp properties_to_spec([]), do: nil
  defp properties_to_spec(properties) do
    properties
    |> Enum.map(fn property ->
      property_spec = %{
        type: to_string(property.type)
      }
      |> add_if_present(:format, property.format)
      |> add_if_present(:description, property.description)
      |> add_if_present(:default, property.default)
      |> add_if_present(:example, property.example)
      |> add_if_present(:examples, property.examples)
      |> add_if_present(:enum, property.enum)
      |> add_if_present(:const, property.const)
      |> add_if_present(:minimum, property.minimum)
      |> add_if_present(:maximum, property.maximum)
      |> add_if_present(:exclusiveMinimum, property.exclusive_minimum)
      |> add_if_present(:exclusiveMaximum, property.exclusive_maximum)
      |> add_if_present(:multipleOf, property.multiple_of)
      |> add_if_present(:minLength, property.min_length)
      |> add_if_present(:maxLength, property.max_length)
      |> add_if_present(:pattern, property.pattern)
      |> add_if_present(:minItems, property.min_items)
      |> add_if_present(:maxItems, property.max_items)
      |> add_if_present(:uniqueItems, property.unique_items)
      |> add_if_present(:minProperties, property.min_properties)
      |> add_if_present(:maxProperties, property.max_properties)
      |> add_if_present(:readOnly, property.read_only)
      |> add_if_present(:writeOnly, property.write_only)
      |> add_if_present(:items, property.items && schema_to_spec(property.items))
      |> add_if_present(:additionalProperties, property.additional_properties)
      |> add_if_present(:required, property.required)

      {property.name, property_spec}
    end)
    |> Map.new()
  end

  # ===== HELPER FUNCTIONS =====

  defp tags_to_spec(nil), do: nil
  defp tags_to_spec([]), do: nil
  defp tags_to_spec(tags) do
    tags
    |> Enum.map(fn tag ->
      tag_spec = %{
        name: tag.name
      }
      |> add_if_present(:description, tag.description)
      |> add_if_present(:externalDocs, external_docs_to_spec(tag.external_docs))

      tag_spec
    end)
  end

  defp external_docs_to_spec(nil), do: nil
  defp external_docs_to_spec([]), do: nil
  defp external_docs_to_spec(external_docs) do
    %{
      url: external_docs.url
    }
    |> add_if_present(:description, external_docs.description)
  end

  defp correlation_id_to_spec(nil), do: nil
  defp correlation_id_to_spec([]), do: nil
  defp correlation_id_to_spec(correlation_id) do
    %{
      location: correlation_id.location
    }
    |> add_if_present(:description, correlation_id.description)
  end

  defp message_examples_to_spec(nil), do: nil
  defp message_examples_to_spec([]), do: nil
  defp message_examples_to_spec(examples) do
    examples
    |> Enum.map(fn example ->
      example_spec = %{
        name: example.name
      }
      |> add_if_present(:summary, example.summary)
      |> add_if_present(:description, example.description)
      |> add_if_present(:headers, example.headers)
      |> add_if_present(:payload, example.payload)

      {example.name, example_spec}
    end)
    |> Map.new()
  end

  defp security_requirements_to_spec(nil), do: nil
  defp security_requirements_to_spec([]), do: nil
  defp security_requirements_to_spec(requirements) do
    requirements
    |> Enum.map(fn req ->
      %{req.scheme => req.scopes || []}
    end)
  end

  defp traits_to_spec(nil), do: nil
  defp traits_to_spec([]), do: nil
  defp traits_to_spec(traits) do
    traits
    |> Enum.map(fn trait ->
      %{"$ref" => "#/components/traits/#{trait}"}
    end)
  end

  defp oauth_flows_to_spec(nil), do: nil
  defp oauth_flows_to_spec(flows) do
    flows_spec = %{}
    |> add_if_present(:implicit, oauth_flow_to_spec(flows.implicit))
    |> add_if_present(:password, oauth_flow_to_spec(flows.password))
    |> add_if_present(:clientCredentials, oauth_flow_to_spec(flows.client_credentials))
    |> add_if_present(:authorizationCode, oauth_flow_to_spec(flows.authorization_code))

    flows_spec
  end

  defp oauth_flow_to_spec(nil), do: nil
  defp oauth_flow_to_spec(flow) do
    flow_spec = %{}
    |> add_if_present(:authorizationUrl, flow.authorization_url)
    |> add_if_present(:tokenUrl, flow.token_url)
    |> add_if_present(:refreshUrl, flow.refresh_url)
    |> add_if_present(:scopes, flow.scopes || %{})

    flow_spec
  end
end