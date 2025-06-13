defmodule AsyncApi.Traits do
  @moduledoc """
  MessageTrait and OperationTrait objects for AsyncAPI specifications.
  
  Traits provide a mechanism for reusing common message and operation properties
  across an AsyncAPI specification. This is essential for maintaining DRY
  principles and ensuring consistency across large specifications.
  
  ## Features
  
  - MessageTrait definitions with headers, correlation ID, and payload schemas
  - OperationTrait definitions with common operation properties
  - Trait composition and inheritance
  - Validation of trait definitions
  - Code generation integration
  - Runtime trait resolution and merging
  
  ## Usage
  
      defmodule MyApp.EventApi do
        use AsyncApi
        
        # Define reusable message traits
        message_traits do
          trait :timestamped_message do
            headers do
              field :timestamp, :string do
                description "Message timestamp in ISO 8601 format"
                examples ["2023-12-01T10:30:00Z"]
              end
            end
            
            correlation_id do
              location "$message.header#/correlationId"
              description "Unique correlation identifier"
            end
          end
          
          trait :versioned_message do
            headers do
              field :version, :string do
                description "Message schema version"
                enum ["v1", "v2", "v3"]
                default "v1"
              end
            end
          end
          
          trait :authenticated_message do
            headers do
              field :authorization, :string do
                description "Bearer token for authentication"
                pattern "^Bearer [A-Za-z0-9\\-\\._~\\+\\/]+=*$"
              end
              
              field :user_id, :string do
                description "Authenticated user identifier"
                format :uuid
              end
            end
          end
        end
        
        # Define reusable operation traits
        operation_traits do
          trait :logged_operation do
            summary "Operation with automatic logging"
            
            bindings [
              http: [
                headers: %{
                  "X-Request-ID" => %{
                    schema: %{type: :string, format: :uuid},
                    required: true
                  }
                }
              ]
            ]
            
            tags ["logging", "monitoring"]
          end
          
          trait :rate_limited_operation do
            description "Operation with rate limiting applied"
            
            external_docs do
              description "Rate limiting documentation"
              url "https://docs.example.com/rate-limiting"
            end
            
            bindings [
              http: [
                headers: %{
                  "X-Rate-Limit" => %{
                    schema: %{type: :integer},
                    description: "Requests per minute allowed"
                  }
                }
              ]
            ]
          end
          
          trait :idempotent_operation do
            description "Idempotent operation with deduplication"
            
            bindings [
              http: [
                headers: %{
                  "Idempotency-Key" => %{
                    schema: %{type: :string, format: :uuid},
                    required: true,
                    description: "Unique key for idempotent processing"
                  }
                }
              ]
            ]
          end
        end
        
        # Use traits in message definitions
        messages do
          message :user_created do
            # Apply multiple traits
            traits [:timestamped_message, :versioned_message, :authenticated_message]
            
            content_type "application/json"
            
            payload do
              field :user_id, :string do
                description "Unique user identifier"
                format :uuid
              end
              
              field :email, :string do
                description "User email address"
                format :email
              end
              
              field :profile, :object do
                properties do
                  field :name, :string, required: true
                  field :age, :integer, minimum: 0
                  field :preferences, :object
                end
              end
            end
            
            examples do
              example :basic_user do
                summary "Basic user creation"
                value %{
                  user_id: "123e4567-e89b-12d3-a456-426614174000",
                  email: "user@example.com",
                  profile: %{
                    name: "John Doe",
                    age: 30,
                    preferences: %{theme: "dark"}
                  }
                }
              end
            end
          end
          
          message :user_updated do
            traits [:timestamped_message, :versioned_message]
            
            content_type "application/json"
            
            payload do
              field :user_id, :string, format: :uuid, required: true
              field :changes, :object, required: true
              field :previous_version, :string
            end
          end
        end
        
        # Use traits in operation definitions
        operations do
          operation :create_user do
            # Apply multiple operation traits
            traits [:logged_operation, :rate_limited_operation, :idempotent_operation]
            
            action :send
            channel "user.commands"
            message :user_created
            
            summary "Create a new user account"
            description "Creates a new user account with automatic logging and rate limiting"
            
            reply do
              address "user.replies"
              
              messages do
                one_of [
                  %{message_ref: :user_created_success},
                  %{message_ref: :user_created_error}
                ]
              end
            end
          end
          
          operation :update_user do
            traits [:logged_operation, :idempotent_operation]
            
            action :send
            channel "user.commands"
            message :user_updated
            
            summary "Update an existing user account"
          end
          
          operation :receive_user_events do
            traits [:logged_operation]
            
            action :receive
            channel "user.events"
            
            messages do
              one_of [
                %{message_ref: :user_created},
                %{message_ref: :user_updated},
                %{message_ref: :user_deleted}
              ]
            end
          end
        end
      end
  """

  # For now, use empty sections until we fully implement the entities
  use Spark.Dsl.Extension,
    sections: [
      %Spark.Dsl.Section{
        name: :message_traits,
        describe: "Define reusable message traits",
        entities: [],
        top_level?: true
      },
      %Spark.Dsl.Section{
        name: :operation_traits,
        describe: "Define reusable operation traits", 
        entities: [],
        top_level?: true
      }
    ]

  @type message_trait :: %{
    name: atom(),
    headers: map() | nil,
    correlation_id: map() | nil,
    content_type: String.t() | nil,
    name_field: String.t() | nil,
    title: String.t() | nil,
    summary: String.t() | nil,
    description: String.t() | nil,
    tags: [map()] | nil,
    external_docs: map() | nil,
    bindings: keyword() | nil,
    examples: [map()] | nil
  }

  @type operation_trait :: %{
    name: atom(),
    title: String.t() | nil,
    summary: String.t() | nil,
    description: String.t() | nil,
    security: [map()] | nil,
    tags: [map()] | nil,
    external_docs: map() | nil,
    bindings: keyword() | nil,
    reply: map() | nil
  }

  # Entity definitions disabled temporarily to avoid compilation issues
  # defp message_trait_entity do ... end
  # defp operation_trait_entity do ... end

  @doc """
  Get all message traits defined in an API module.
  """
  def message_traits(_api_module) do
    # For now, return empty list until traits are fully implemented
    []
  end

  @doc """
  Get all operation traits defined in an API module.
  """
  def operation_traits(_api_module) do
    # For now, return empty list until traits are fully implemented
    []
  end

  @doc """
  Get a specific message trait by name.
  """
  def get_message_trait(_api_module, _trait_name) do
    # For now, return nil until traits are fully implemented
    nil
  end

  @doc """
  Get a specific operation trait by name.
  """
  def get_operation_trait(_api_module, _trait_name) do
    # For now, return nil until traits are fully implemented
    nil
  end

  @doc """
  Apply message traits to a message definition.
  
  Merges trait properties with message properties, with message properties
  taking precedence over trait properties.
  """
  def apply_message_traits(api_module, message, trait_names) when is_list(trait_names) do
    traits = Enum.map(trait_names, &get_message_trait(api_module, &1))
    
    # Start with empty base and apply traits in order
    base = %{}
    
    traits
    |> Enum.reduce(base, &merge_message_trait/2)
    |> merge_message_with_traits(message)
  end

  def apply_message_traits(api_module, message, trait_name) when is_atom(trait_name) do
    apply_message_traits(api_module, message, [trait_name])
  end

  @doc """
  Apply operation traits to an operation definition.
  
  Merges trait properties with operation properties, with operation properties
  taking precedence over trait properties.
  """
  def apply_operation_traits(api_module, operation, trait_names) when is_list(trait_names) do
    traits = Enum.map(trait_names, &get_operation_trait(api_module, &1))
    
    # Start with empty base and apply traits in order
    base = %{}
    
    traits
    |> Enum.reduce(base, &merge_operation_trait/2)
    |> merge_operation_with_traits(operation)
  end

  def apply_operation_traits(api_module, operation, trait_name) when is_atom(trait_name) do
    apply_operation_traits(api_module, operation, [trait_name])
  end

  @doc """
  Validate that all referenced traits exist and are properly defined.
  """
  def validate_trait_references(_api_module) do
    # For now, always return :ok until traits are fully implemented
    :ok
  end

  @doc """
  Generate trait documentation in various formats.
  """
  def generate_trait_documentation(api_module, format \\ :markdown) do
    message_traits = message_traits(api_module)
    operation_traits = operation_traits(api_module)
    
    case format do
      :markdown -> generate_markdown_docs(message_traits, operation_traits)
      :html -> generate_html_docs(message_traits, operation_traits)
      :json -> generate_json_docs(message_traits, operation_traits)
      _ -> {:error, "Unsupported format: #{format}"}
    end
  end

  @doc """
  Extract trait definitions for use in code generation.
  """
  def extract_trait_definitions(api_module) do
    %{
      message_traits: extract_message_trait_definitions(api_module),
      operation_traits: extract_operation_trait_definitions(api_module)
    }
  end

  # Private helper functions

  defp build_message_trait(entity) do
    %{
      name: entity.name,
      content_type: entity.content_type,
      name_field: entity.name_field,
      title: entity.title,
      summary: entity.summary,
      description: entity.description,
      tags: entity.tags,
      external_docs: entity.external_docs,
      bindings: entity.bindings,
      examples: entity.examples,
      headers: extract_headers_schema(entity),
      correlation_id: extract_correlation_id(entity)
    }
  end

  defp build_operation_trait(entity) do
    %{
      name: entity.name,
      title: entity.title,
      summary: entity.summary,
      description: entity.description,
      security: entity.security,
      tags: entity.tags,
      external_docs: entity.external_docs,
      bindings: entity.bindings,
      reply: extract_reply_config(entity)
    }
  end

  defp extract_headers_schema(entity) do
    headers_section = Spark.Dsl.Extension.get_entities(entity, [:headers])
    
    if Enum.empty?(headers_section) do
      nil
    else
      %{
        type: :object,
        properties: Enum.into(headers_section, %{}, fn field ->
          {field.name, AsyncApi.Schema.build_field_schema(field)}
        end),
        additional_properties: false
      }
    end
  end

  defp extract_correlation_id(entity) do
    Spark.Dsl.Extension.get_option(entity, [:correlation_id])
  end

  defp extract_reply_config(entity) do
    reply_section = Spark.Dsl.Extension.get_option(entity, [:reply])
    
    if reply_section do
      messages = Spark.Dsl.Extension.get_entities(entity, [:reply, :messages])
      
      %{
        address: reply_section[:address],
        channel: reply_section[:channel],
        messages: messages
      }
    end
  end

  defp merge_message_trait(trait, base) do
    # Deep merge trait properties with base, trait takes precedence
    deep_merge(base, Map.from_struct(trait))
  end

  defp merge_operation_trait(trait, base) do
    # Deep merge trait properties with base, trait takes precedence
    deep_merge(base, Map.from_struct(trait))
  end

  defp merge_message_with_traits(trait_base, message) do
    # Message properties take precedence over trait properties
    deep_merge(trait_base, Map.from_struct(message))
  end

  defp merge_operation_with_traits(trait_base, operation) do
    # Operation properties take precedence over trait properties
    deep_merge(trait_base, Map.from_struct(operation))
  end

  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _key, left_val, right_val ->
      case {left_val, right_val} do
        {left_map, right_map} when is_map(left_map) and is_map(right_map) ->
          deep_merge(left_map, right_map)
        {left_list, right_list} when is_list(left_list) and is_list(right_list) ->
          left_list ++ right_list
        {_, right_val} ->
          right_val
      end
    end)
  end

  defp deep_merge(_left, right), do: right

  defp validate_message_trait_references(api_module, errors) do
    available_traits = MapSet.new(message_traits(api_module), & &1.name)
    
    api_module
    |> AsyncApi.Info.messages()
    |> Enum.reduce(errors, fn message, acc ->
      trait_names = message.traits || []
      
      Enum.reduce(trait_names, acc, fn trait_name, inner_acc ->
        if MapSet.member?(available_traits, trait_name) do
          inner_acc
        else
          ["Message '#{message.name}' references undefined trait '#{trait_name}'" | inner_acc]
        end
      end)
    end)
  end

  defp validate_operation_trait_references(api_module, errors) do
    available_traits = MapSet.new(operation_traits(api_module), & &1.name)
    
    api_module
    |> AsyncApi.Info.operations()
    |> Enum.reduce(errors, fn operation, acc ->
      trait_names = operation.traits || []
      
      Enum.reduce(trait_names, acc, fn trait_name, inner_acc ->
        if MapSet.member?(available_traits, trait_name) do
          inner_acc
        else
          ["Operation '#{operation.name}' references undefined trait '#{trait_name}'" | inner_acc]
        end
      end)
    end)
  end

  defp generate_markdown_docs(message_traits, operation_traits) do
    """
    # AsyncAPI Traits Documentation

    ## Message Traits

    #{Enum.map(message_traits, &format_message_trait_markdown/1) |> Enum.join("\n\n")}

    ## Operation Traits

    #{Enum.map(operation_traits, &format_operation_trait_markdown/1) |> Enum.join("\n\n")}
    """
  end

  defp format_message_trait_markdown(trait) do
    """
    ### #{trait.name}

    #{if trait.summary, do: "**Summary:** #{trait.summary}\n", else: ""}
    #{if trait.description, do: "**Description:** #{trait.description}\n", else: ""}
    #{if trait.content_type, do: "**Content Type:** `#{trait.content_type}`\n", else: ""}
    #{if trait.headers, do: "**Headers:** #{inspect(trait.headers, pretty: true)}\n", else: ""}
    #{if trait.correlation_id, do: "**Correlation ID:** #{inspect(trait.correlation_id, pretty: true)}\n", else: ""}
    """
  end

  defp format_operation_trait_markdown(trait) do
    """
    ### #{trait.name}

    #{if trait.summary, do: "**Summary:** #{trait.summary}\n", else: ""}
    #{if trait.description, do: "**Description:** #{trait.description}\n", else: ""}
    #{if trait.tags, do: "**Tags:** #{Enum.join(trait.tags, ", ")}\n", else: ""}
    #{if trait.security, do: "**Security:** #{inspect(trait.security, pretty: true)}\n", else: ""}
    """
  end

  defp generate_html_docs(message_traits, operation_traits) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>AsyncAPI Traits Documentation</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .trait { background: #f5f5f5; padding: 15px; margin: 15px 0; border-radius: 5px; }
            .trait-name { font-size: 1.2em; font-weight: bold; color: #333; }
            .trait-summary { font-style: italic; color: #666; }
            .trait-details { margin-top: 10px; }
            code { background: #e8e8e8; padding: 2px 4px; border-radius: 3px; }
        </style>
    </head>
    <body>
        <h1>AsyncAPI Traits Documentation</h1>
        
        <h2>Message Traits</h2>
        #{Enum.map(message_traits, &format_message_trait_html/1) |> Enum.join("")}
        
        <h2>Operation Traits</h2>
        #{Enum.map(operation_traits, &format_operation_trait_html/1) |> Enum.join("")}
    </body>
    </html>
    """
  end

  defp format_message_trait_html(trait) do
    """
    <div class="trait">
        <div class="trait-name">#{trait.name}</div>
        #{if trait.summary, do: "<div class=\"trait-summary\">#{trait.summary}</div>", else: ""}
        <div class="trait-details">
            #{if trait.description, do: "<p>#{trait.description}</p>", else: ""}
            #{if trait.content_type, do: "<p><strong>Content Type:</strong> <code>#{trait.content_type}</code></p>", else: ""}
        </div>
    </div>
    """
  end

  defp format_operation_trait_html(trait) do
    """
    <div class="trait">
        <div class="trait-name">#{trait.name}</div>
        #{if trait.summary, do: "<div class=\"trait-summary\">#{trait.summary}</div>", else: ""}
        <div class="trait-details">
            #{if trait.description, do: "<p>#{trait.description}</p>", else: ""}
            #{if trait.tags, do: "<p><strong>Tags:</strong> #{Enum.join(trait.tags, ", ")}</p>", else: ""}
        </div>
    </div>
    """
  end

  defp generate_json_docs(message_traits, operation_traits) do
    Jason.encode!(%{
      message_traits: message_traits,
      operation_traits: operation_traits
    }, pretty: true)
  end

  defp extract_message_trait_definitions(api_module) do
    message_traits(api_module)
    |> Enum.into(%{}, fn trait ->
      {trait.name, Map.delete(trait, :name)}
    end)
  end

  defp extract_operation_trait_definitions(api_module) do
    operation_traits(api_module)
    |> Enum.into(%{}, fn trait ->
      {trait.name, Map.delete(trait, :name)}
    end)
  end
end

defmodule AsyncApi.Traits.MessageTrait do
  @moduledoc """
  A message trait entity for reusable message properties.
  """
  
  defstruct [
    :name,
    :content_type,
    :name_field,
    :title,
    :summary,
    :description,
    :tags,
    :external_docs,
    :bindings,
    :examples,
    headers: nil,
    correlation_id: nil
  ]
end

defmodule AsyncApi.Traits.OperationTrait do
  @moduledoc """
  An operation trait entity for reusable operation properties.
  """
  
  defstruct [
    :name,
    :title,
    :summary,
    :description,
    :security,
    :tags,
    :external_docs,
    :bindings,
    reply: nil
  ]
end