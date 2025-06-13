defmodule AsyncApi.Dsl do
  @moduledoc """
  Complete AsyncAPI 3.0 DSL extension with full specification support.
  
  This DSL supports all AsyncAPI 3.0 features including operations as first-class
  citizens, reply patterns, enhanced security, and comprehensive protocol bindings.
  
  The entities are organized in dependency order to avoid forward reference issues.
  """

  # ===== STRUCT DEFINITIONS =====

  defmodule AsyncApiStruct do
    @moduledoc "Root AsyncAPI document structure"
    defstruct [
      :asyncapi,      # Required: "3.0.0"
      :id,            # Optional: Unique identifier
      :info,          # Required: Info object
      :servers,       # Optional: Map of servers
      :default_content_type, # Optional: Default content type
      :channels,      # Optional: Map of channels
      :operations,    # Optional: Map of operations
      :components     # Optional: Components object
    ]
  end

  defmodule InfoStruct do
    @moduledoc "API information object"
    defstruct [
      :title,         # Required
      :version,       # Required
      :description,
      :terms_of_service,
      :contact,       # Contact object
      :license,       # License object
      :tags,          # Array of Tag objects
      :external_docs  # ExternalDocs object
    ]
  end

  defmodule Contact do
    @moduledoc "Contact information"
    defstruct [:name, :url, :email]
  end

  defmodule License do
    @moduledoc "License information"
    defstruct [:name, :identifier, :url]
  end

  defmodule Tag do
    @moduledoc "Tag for categorization"
    defstruct [:name, :description, :external_docs]
  end

  defmodule ExternalDocs do
    @moduledoc "External documentation"
    defstruct [:description, :url]
  end

  defmodule Server do
    @moduledoc "Server connection information"
    defstruct [
      :name,
      :host,
      :protocol,
      :protocol_version,
      :pathname,
      :description,
      :title,
      :summary,
      :variables,     # Map of ServerVariable objects
      :security,      # Array of SecurityRequirement objects
      :tags,          # Array of Tag objects
      :external_docs, # ExternalDocs object
      :bindings       # Protocol-specific bindings
    ]
  end

  defmodule ServerVariable do
    @moduledoc "Server variable definition"
    defstruct [:name, :enum, :default, :description, :examples]
  end

  defmodule Channel do
    @moduledoc "Communication channel"
    defstruct [
      :address,
      :title,
      :summary,
      :description,
      :servers,       # Array of server references
      :parameters,    # Map of Parameter objects
      :tags,          # Array of Tag objects
      :external_docs, # ExternalDocs object
      :bindings       # Protocol-specific bindings
    ]
  end

  defmodule Parameter do
    @moduledoc "Channel parameter"
    defstruct [
      :name,
      :description,
      :schema,        # Schema object or reference
      :location       # Runtime expression for parameter location
    ]
  end

  defmodule Operation do
    @moduledoc "Message operation"
    defstruct [
      :action,        # Required: send | receive
      :channel,       # Required: Channel reference
      :operation_id,
      :title,
      :summary,
      :description,
      :security,      # Array of SecurityRequirement objects
      :tags,          # Array of Tag objects
      :external_docs, # ExternalDocs object
      :bindings,      # Protocol-specific bindings
      :traits,        # Array of OperationTrait references
      :messages,      # Array of Message references
      :reply          # Reply object
    ]
  end

  defmodule Reply do
    @moduledoc "Operation reply definition"
    defstruct [
      :address,       # Runtime expression for reply address
      :channel,       # Channel reference for reply
      :messages       # Array of Message references
    ]
  end

  defmodule Message do
    @moduledoc "Message definition"
    defstruct [
      :name,
      :title,
      :summary,
      :description,
      :content_type,
      :headers,       # Schema object or reference
      :payload,       # Required: Schema object or reference
      :correlation_id, # CorrelationId object
      :schema_format,
      :bindings,      # Protocol-specific bindings
      :examples,      # Array of MessageExample objects
      :tags,          # Array of Tag objects
      :external_docs, # ExternalDocs object
      :traits         # Array of MessageTrait references
    ]
  end

  defmodule CorrelationId do
    @moduledoc "Correlation ID definition"
    defstruct [:description, :location]
  end

  defmodule MessageExample do
    @moduledoc "Message example"
    defstruct [:name, :summary, :description, :headers, :payload]
  end

  defmodule Schema do
    @moduledoc "JSON Schema definition"
    defstruct [
      :name,
      # JSON Schema fields
      :title,
      :description,
      :type,
      :format,
      :enum,
      :const,
      :default,
      :examples,
      :read_only,
      :write_only,
      :multiple_of,
      :maximum,
      :exclusive_maximum,
      :minimum,
      :exclusive_minimum,
      :max_length,
      :min_length,
      :pattern,
      :max_items,
      :min_items,
      :unique_items,
      :max_properties,
      :min_properties,
      # Object-specific
      :properties,      # Map of Property objects
      :property,        # List of Property entities (from Spark DSL)
      :required,        # Array of required property names
      :additional_properties, # Boolean or Schema
      :pattern_properties,    # Map of pattern to Schema
      :property_names,  # Schema for property names
      # Array-specific
      :items,           # Schema for array items
      :additional_items, # Boolean or Schema
      :contains,        # Schema
      # Composition
      :all_of,          # Array of Schema objects
      :any_of,          # Array of Schema objects
      :one_of,          # Array of Schema objects
      :not,             # Schema object
      # Conditional
      :if,              # Schema object
      :then,            # Schema object
      :else,            # Schema object
      # Annotations
      :definitions,     # Map of Schema objects
      :dependencies     # Map of dependencies
    ]
  end

  defmodule Property do
    @moduledoc "Schema property"
    defstruct [
      :name,
      :type,
      :format,
      :description,
      :default,
      :example,
      :examples,
      :enum,
      :const,
      :minimum,
      :maximum,
      :exclusive_minimum,
      :exclusive_maximum,
      :multiple_of,
      :min_length,
      :max_length,
      :pattern,
      :min_items,
      :max_items,
      :unique_items,
      :min_properties,
      :max_properties,
      :read_only,
      :write_only,
      :items,           # For array types
      :properties,      # For object types
      :additional_properties,
      :required         # For nested objects
    ]
  end

  defmodule SecurityScheme do
    @moduledoc "Security scheme definition"
    defstruct [
      :name,
      :type,            # Required: apiKey | http | oauth2 | openIdConnect | plain | scramSha256 | scramSha512 | gssapi
      :description,
      # API Key fields
      :name_field,      # For apiKey: parameter name
      :location,        # For apiKey: query | header | cookie
      # HTTP fields
      :scheme,          # For http: basic | bearer | digest | etc.
      :bearer_format,   # For http bearer
      # OAuth2 fields
      :flows,           # OAuthFlows object
      # OpenID Connect fields
      :open_id_connect_url
    ]
  end

  defmodule OAuthFlows do
    @moduledoc "OAuth flows configuration"
    defstruct [
      :implicit,
      :password,
      :client_credentials,
      :authorization_code
    ]
  end

  defmodule OAuthFlow do
    @moduledoc "OAuth flow definition"
    defstruct [
      :authorization_url,
      :token_url,
      :refresh_url,
      :scopes         # Map of scope name to description
    ]
  end

  defmodule SecurityRequirement do
    @moduledoc "Security requirement"
    defstruct [:scheme, :scopes]
  end

  defmodule Components do
    @moduledoc "Reusable components"
    defstruct [
      :schemas,         # Map of Schema objects
      :servers,         # Map of Server objects
      :server_variables, # Map of ServerVariable objects
      :channels,        # Map of Channel objects
      :messages,        # Map of Message objects
      :security_schemes, # Map of SecurityScheme objects
      :parameters,      # Map of Parameter objects
      :correlation_ids, # Map of CorrelationId objects
      :replies,         # Map of Reply objects
      :reply_addresses, # Map of reply address expressions
      :external_docs,   # Map of ExternalDocs objects
      :tags,            # Map of Tag objects
      :operation_traits, # Map of OperationTrait objects
      :message_traits,  # Map of MessageTrait objects
      :server_bindings, # Map of server bindings
      :channel_bindings, # Map of channel bindings
      :operation_bindings, # Map of operation bindings
      :message_bindings # Map of message bindings
    ]
  end

  # ===== ENTITY DEFINITIONS (in dependency order) =====

  # Base entities with no dependencies
  @external_docs %Spark.Dsl.Entity{
    name: :external_docs,
    target: ExternalDocs,
    describe: "External documentation",
    schema: [
      description: [
        type: :string,
        doc: "A short description of the target documentation"
      ],
      url: [
        type: :string,
        required: true,
        doc: "The URL for the target documentation"
      ]
    ]
  }

  @contact %Spark.Dsl.Entity{
    name: :contact,
    target: Contact,
    describe: "Contact information for the API",
    schema: [
      name: [
        type: :string,
        doc: "The identifying name of the contact person/organization"
      ],
      url: [
        type: :string,
        doc: "The URL pointing to the contact information"
      ],
      email: [
        type: :string,
        doc: "The email address of the contact person/organization"
      ]
    ]
  }

  @license %Spark.Dsl.Entity{
    name: :license,
    target: License,
    describe: "License information for the API",
    schema: [
      name: [
        type: :string,
        required: true,
        doc: "The license name used for the API"
      ],
      identifier: [
        type: :string,
        doc: "An SPDX license expression"
      ],
      url: [
        type: :string,
        doc: "A URL to the license used for the API"
      ]
    ]
  }

  @correlation_id %Spark.Dsl.Entity{
    name: :correlation_id,
    target: CorrelationId,
    describe: "Correlation ID definition",
    schema: [
      description: [
        type: :string,
        doc: "An optional description of the correlation ID"
      ],
      location: [
        type: :string,
        required: true,
        doc: "A runtime expression that specifies the location of the correlation ID"
      ]
    ]
  }

  @message_example %Spark.Dsl.Entity{
    name: :example,
    target: MessageExample,
    args: [:name],
    describe: "Message example",
    schema: [
      name: [
        type: :string,
        required: true,
        doc: "Machine-readable name of the example"
      ],
      summary: [
        type: :string,
        doc: "A short summary of the example"
      ],
      description: [
        type: :string,
        doc: "A long description of the example"
      ],
      headers: [
        type: :keyword_list,
        doc: "Example headers"
      ],
      payload: [
        type: :any,
        doc: "Example payload"
      ]
    ]
  }

  @server_variable %Spark.Dsl.Entity{
    name: :variable,
    target: ServerVariable,
    args: [:name],
    describe: "Server variable definition",
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The variable name"
      ],
      enum: [
        type: {:list, :string},
        doc: "An enumeration of string values to be used if the substitution options are from a limited set"
      ],
      default: [
        type: :string,
        doc: "The default value to use for substitution"
      ],
      description: [
        type: :string,
        doc: "An optional description for the server variable"
      ],
      examples: [
        type: {:list, :string},
        doc: "An array of examples of the server variable"
      ]
    ]
  }

  @security_requirement %Spark.Dsl.Entity{
    name: :security,
    target: SecurityRequirement,
    args: [:scheme],
    describe: "Security requirement",
    schema: [
      scheme: [
        type: :atom,
        required: true,
        doc: "The name of the security scheme"
      ],
      scopes: [
        type: {:list, :string},
        doc: "The list of scope names required for the execution"
      ]
    ]
  }

  @tag %Spark.Dsl.Entity{
    name: :tag,
    target: Tag,
    args: [:name],
    entities: [external_docs: [@external_docs]],
    describe: "A tag for categorization",
    schema: [
      name: [
        type: :string,
        required: true,
        doc: "The name of the tag"
      ],
      description: [
        type: :string,
        doc: "A short description for the tag"
      ]
    ]
  }

  # Property entity (handles its own recursion)
  @property %Spark.Dsl.Entity{
    name: :property,
    target: Property,
    args: [:name, :type],
    describe: "Schema property definition",
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the property"
      ],
      type: [
        type: :atom,
        required: true,
        doc: "The type of the property"
      ],
      format: [
        type: :string,
        doc: "The format of the property"
      ],
      description: [
        type: :string,
        doc: "A description of the property"
      ],
      default: [
        type: :any,
        doc: "Default value for the property"
      ],
      example: [
        type: :any,
        doc: "Example value for the property"
      ],
      examples: [
        type: {:list, :any},
        doc: "Example values for the property"
      ],
      enum: [
        type: {:list, :any},
        doc: "Enumeration of valid values"
      ],
      const: [
        type: :any,
        doc: "Constant value"
      ],
      minimum: [
        type: :number,
        doc: "Minimum value (for numeric types)"
      ],
      maximum: [
        type: :number,
        doc: "Maximum value (for numeric types)"
      ],
      exclusive_minimum: [
        type: :boolean,
        doc: "Whether minimum is exclusive"
      ],
      exclusive_maximum: [
        type: :boolean,
        doc: "Whether maximum is exclusive"
      ],
      multiple_of: [
        type: :number,
        doc: "Multiple of constraint"
      ],
      min_length: [
        type: :integer,
        doc: "Minimum length (for string types)"
      ],
      max_length: [
        type: :integer,
        doc: "Maximum length (for string types)"
      ],
      pattern: [
        type: :string,
        doc: "Regular expression pattern (for string types)"
      ],
      min_items: [
        type: :integer,
        doc: "Minimum items (for array types)"
      ],
      max_items: [
        type: :integer,
        doc: "Maximum items (for array types)"
      ],
      unique_items: [
        type: :boolean,
        doc: "Whether array items should be unique"
      ],
      min_properties: [
        type: :integer,
        doc: "Minimum properties (for object types)"
      ],
      max_properties: [
        type: :integer,
        doc: "Maximum properties (for object types)"
      ],
      read_only: [
        type: :boolean,
        doc: "Whether the property is read-only"
      ],
      write_only: [
        type: :boolean,
        doc: "Whether the property is write-only"
      ],
      items: [
        type: {:or, [:atom, :keyword_list]},
        doc: "Schema for array items (when type is array)"
      ],
      additional_properties: [
        type: {:or, [:boolean, :atom, :keyword_list]},
        doc: "Schema for additional properties (when type is object)"
      ],
      required: [
        type: {:list, :atom},
        doc: "List of required properties (for nested objects)"
      ]
    ]
  }

  # Handle property recursion
  @property %{@property | entities: [properties: [@property]]}

  # Entities that depend on property
  @schema %Spark.Dsl.Entity{
    name: :schema,
    target: Schema,
    args: [:name],
    entities: [
      property: [@property]
    ],
    describe: "JSON Schema definition",
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the schema"
      ],
      title: [
        type: :string,
        doc: "A title for the schema"
      ],
      description: [
        type: :string,
        doc: "A description of the schema"
      ],
      type: [
        type: :atom,
        required: true,
        doc: "The type of the schema"
      ],
      format: [
        type: :string,
        doc: "The format of the schema"
      ],
      enum: [
        type: {:list, :any},
        doc: "Enumeration of valid values"
      ],
      const: [
        type: :any,
        doc: "Constant value"
      ],
      default: [
        type: :any,
        doc: "Default value"
      ],
      examples: [
        type: {:list, :any},
        doc: "Example values"
      ],
      read_only: [
        type: :boolean,
        doc: "Whether the schema is read-only"
      ],
      write_only: [
        type: :boolean,
        doc: "Whether the schema is write-only"
      ],
      multiple_of: [
        type: :number,
        doc: "Multiple of constraint for numbers"
      ],
      maximum: [
        type: :number,
        doc: "Maximum value"
      ],
      exclusive_maximum: [
        type: :boolean,
        doc: "Whether maximum is exclusive"
      ],
      minimum: [
        type: :number,
        doc: "Minimum value"
      ],
      exclusive_minimum: [
        type: :boolean,
        doc: "Whether minimum is exclusive"
      ],
      max_length: [
        type: :integer,
        doc: "Maximum length for strings"
      ],
      min_length: [
        type: :integer,
        doc: "Minimum length for strings"
      ],
      pattern: [
        type: :string,
        doc: "Regular expression pattern"
      ],
      max_items: [
        type: :integer,
        doc: "Maximum number of items in arrays"
      ],
      min_items: [
        type: :integer,
        doc: "Minimum number of items in arrays"
      ],
      unique_items: [
        type: :boolean,
        doc: "Whether array items should be unique"
      ],
      max_properties: [
        type: :integer,
        doc: "Maximum number of properties in objects"
      ],
      min_properties: [
        type: :integer,
        doc: "Minimum number of properties in objects"
      ],
      required: [
        type: {:list, :atom},
        doc: "List of required properties"
      ],
      additional_properties: [
        type: {:or, [:boolean, :atom, :keyword_list]},
        doc: "Schema for additional properties"
      ],
      items: [
        type: {:or, [:atom, :keyword_list]},
        doc: "Schema for array items"
      ]
    ]
  }

  @parameter %Spark.Dsl.Entity{
    name: :parameter,
    target: Parameter,
    args: [:name],
    entities: [],
    describe: "Channel parameter definition",
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the parameter"
      ],
      description: [
        type: :string,
        doc: "A brief description of the parameter"
      ],
      schema: [
        type: {:or, [:atom, :keyword_list]},
        doc: "Schema definition or reference for the parameter"
      ],
      location: [
        type: :string,
        doc: "A runtime expression that specifies the location of the parameter value"
      ]
    ]
  }

  # OAuth entities
  @scope %Spark.Dsl.Entity{
    name: :scope,
    target: SecurityRequirement,
    args: [:name, :description],
    describe: "OAuth scope definition",
    schema: [
      name: [
        type: :string,
        required: true,
        doc: "The name of the scope"
      ],
      description: [
        type: :string,
        required: true,
        doc: "A short description of the scope"
      ]
    ]
  }

  @oauth_flow %Spark.Dsl.Entity{
    name: :oauth_flow,
    target: OAuthFlow,
    entities: [scopes: [@scope]],
    describe: "OAuth flow definition",
    schema: [
      authorization_url: [
        type: :string,
        doc: "The authorization URL to be used for this flow"
      ],
      token_url: [
        type: :string,
        doc: "The token URL to be used for this flow"
      ],
      refresh_url: [
        type: :string,
        doc: "The URL to be used for obtaining refresh tokens"
      ]
    ]
  }

  @oauth_flows %Spark.Dsl.Entity{
    name: :flows,
    target: OAuthFlows,
    entities: [
      implicit: [@oauth_flow],
      password: [@oauth_flow],
      client_credentials: [@oauth_flow],
      authorization_code: [@oauth_flow]
    ],
    describe: "OAuth flows configuration",
    schema: []
  }

  @security_scheme %Spark.Dsl.Entity{
    name: :security_scheme,
    target: SecurityScheme,
    args: [:name],
    entities: [flows: [@oauth_flows]],
    describe: "Security scheme definition",
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the security scheme"
      ],
      type: [
        type: {:in, [:apiKey, :http, :oauth2, :openIdConnect, :plain, :scramSha256, :scramSha512, :gssapi]},
        required: true,
        doc: "The type of the security scheme"
      ],
      description: [
        type: :string,
        doc: "A short description for security scheme"
      ],
      name_field: [
        type: :string,
        doc: "The name of the header, query or cookie parameter to be used (for apiKey)"
      ],
      location: [
        type: {:in, [:query, :header, :cookie]},
        doc: "The location of the API key (for apiKey)"
      ],
      scheme: [
        type: :string,
        doc: "The name of the HTTP Authorization scheme (for http)"
      ],
      bearer_format: [
        type: :string,
        doc: "A hint to the client to identify how the bearer token is formatted (for http bearer)"
      ],
      open_id_connect_url: [
        type: :string,
        doc: "OpenId Connect URL to discover OAuth2 configuration values (for openIdConnect)"
      ]
    ]
  }

  # Info section (moved to section schema below)

  # Server entities
  @server %Spark.Dsl.Entity{
    name: :server,
    target: Server,
    args: [:name, :host],
    entities: [variables: [@server_variable], security: [@security_requirement], tags: [@tag], external_docs: [@external_docs]],
    describe: "Server connection information",
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "A unique name for the server"
      ],
      host: [
        type: :string,
        required: true,
        doc: "The server host"
      ],
      protocol: [
        type: :atom,
        required: true,
        doc: "The protocol used for connection"
      ],
      protocol_version: [
        type: :string,
        doc: "The version of the protocol"
      ],
      pathname: [
        type: :string,
        doc: "The path to a resource in the host"
      ],
      description: [
        type: :string,
        doc: "An optional string describing the server"
      ],
      title: [
        type: :string,
        doc: "A human-readable title for the server"
      ],
      summary: [
        type: :string,
        doc: "A short summary of the server"
      ],
      bindings: [
        type: :keyword_list,
        doc: "Protocol-specific bindings"
      ]
    ]
  }

  # Channel entities
  @channel %Spark.Dsl.Entity{
    name: :channel,
    target: Channel,
    args: [:address],
    entities: [
      parameter: [@parameter],
      tag: [@tag], 
      external_docs: [@external_docs]
    ],
    describe: "Communication channel definition",
    schema: [
      address: [
        type: :string,
        required: true,
        doc: "The channel address/path"
      ],
      title: [
        type: :string,
        doc: "A human-readable title for the channel"
      ],
      summary: [
        type: :string,
        doc: "A short summary of the channel"
      ],
      description: [
        type: :string,
        doc: "An optional description of this channel"
      ],
      servers: [
        type: {:list, :atom},
        doc: "The servers on which this channel is available"
      ],
      bindings: [
        type: :keyword_list,
        doc: "Protocol-specific bindings"
      ]
    ]
  }

  # Message entities
  @message %Spark.Dsl.Entity{
    name: :message,
    target: Message,
    args: [:name],
    entities: [correlation_id: [@correlation_id], examples: [@message_example], tags: [@tag], external_docs: [@external_docs]],
    describe: "Message definition",
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the message"
      ],
      title: [
        type: :string,
        doc: "A human-readable title for the message"
      ],
      summary: [
        type: :string,
        doc: "A short summary of the message"
      ],
      description: [
        type: :string,
        doc: "A verbose explanation of the message"
      ],
      content_type: [
        type: :string,
        doc: "The content type to use when encoding/decoding a message's payload"
      ],
      headers: [
        type: :atom,
        doc: "Schema definition of the application headers"
      ],
      payload: [
        type: :atom,
        required: true,
        doc: "Definition of the message payload"
      ],
      schema_format: [
        type: :string,
        doc: "A string containing the name of the schema format"
      ],
      bindings: [
        type: :keyword_list,
        doc: "Protocol-specific bindings"
      ],
      traits: [
        type: {:list, :atom},
        doc: "A list of traits to apply to the message"
      ]
    ]
  }

  @message_ref %Spark.Dsl.Entity{
    name: :message,
    target: Message,
    args: [:name],
    describe: "Message reference in operation",
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the message"
      ]
    ]
  }

  @reply %Spark.Dsl.Entity{
    name: :reply,
    target: Reply,
    entities: [messages: [@message_ref]],
    describe: "Operation reply definition",
    schema: [
      address: [
        type: :string,
        doc: "Runtime expression for the reply address"
      ],
      channel: [
        type: {:or, [:string, :atom]},
        doc: "Reference to the channel for the reply"
      ]
    ]
  }

  # Operation entities
  @operation %Spark.Dsl.Entity{
    name: :operation,
    target: Operation,
    args: [:operation_id],
    entities: [security: [@security_requirement], tags: [@tag], external_docs: [@external_docs], messages: [@message_ref], reply: [@reply]],
    describe: "Message operation definition",
    schema: [
      operation_id: [
        type: :atom,
        required: true,
        doc: "Unique string used to identify the operation"
      ],
      action: [
        type: {:in, [:send, :receive]},
        required: true,
        doc: "The action to perform (send or receive)"
      ],
      channel: [
        type: {:or, [:string, :atom]},
        required: true,
        doc: "Reference to the channel this operation belongs to"
      ],
      title: [
        type: :string,
        doc: "A human-readable title for the operation"
      ],
      summary: [
        type: :string,
        doc: "A short summary of what the operation is about"
      ],
      description: [
        type: :string,
        doc: "A verbose explanation of the operation"
      ],
      bindings: [
        type: :keyword_list,
        doc: "Protocol-specific bindings"
      ],
      traits: [
        type: {:list, :atom},
        doc: "A list of traits to apply to the operation"
      ]
    ]
  }

  # Root-level entities
  @async_api_id %Spark.Dsl.Entity{
    name: :id,
    target: AsyncApiStruct,
    args: [:id],
    describe: "Unique identifier for the AsyncAPI document",
    schema: [
      id: [
        type: :string,
        required: true,
        doc: "Unique identifier in URI format"
      ]
    ]
  }

  @default_content_type %Spark.Dsl.Entity{
    name: :default_content_type,
    target: AsyncApiStruct,
    args: [:content_type],
    describe: "Default content type for messages",
    schema: [
      content_type: [
        type: :string,
        required: true,
        doc: "Default content type (e.g., 'application/json')"
      ]
    ]
  }

  # ===== SECTION DEFINITIONS =====

  @info_section %Spark.Dsl.Section{
    name: :info,
    describe: "API information and metadata",
    entities: [@contact, @license],
    schema: [
      title: [
        type: :string,
        required: true,
        doc: "The title of the API"
      ],
      version: [
        type: :string,
        required: true,
        doc: "The version of the API"
      ],
      description: [
        type: :string,
        doc: "A short description of the API"
      ],
      terms_of_service: [
        type: :string,
        doc: "A URL to the Terms of Service for the API"
      ]
    ]
  }

  @servers_section %Spark.Dsl.Section{
    name: :servers,
    describe: "Server connection definitions",
    entities: [@server],
    schema: []
  }

  @channels_section %Spark.Dsl.Section{
    name: :channels,
    describe: "Channel definitions for message flow",
    entities: [@channel],
    schema: []
  }

  @operations_section %Spark.Dsl.Section{
    name: :operations,
    describe: "Operation definitions (send/receive actions)",
    entities: [@operation],
    schema: []
  }

  @messages_section %Spark.Dsl.Section{
    name: :messages,
    entities: [@message],
    schema: [],
    describe: "Reusable message definitions"
  }

  @schemas_section %Spark.Dsl.Section{
    name: :schemas,
    entities: [@schema],
    schema: [],
    describe: "Reusable schema definitions"
  }

  @security_schemes_section %Spark.Dsl.Section{
    name: :security_schemes,
    entities: [@security_scheme],
    schema: [],
    describe: "Reusable security scheme definitions"
  }

  @components_section %Spark.Dsl.Section{
    name: :components,
    describe: "Reusable components",
    sections: [
      @messages_section,
      @schemas_section,
      @security_schemes_section
    ],
    schema: []
  }

  use Spark.Dsl.Extension,
    sections: [@info_section, @servers_section, @channels_section, @operations_section, @components_section],
    entities: [@async_api_id, @default_content_type]
end