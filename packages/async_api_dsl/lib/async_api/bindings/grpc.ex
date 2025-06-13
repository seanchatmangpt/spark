defmodule AsyncApi.Bindings.Grpc do
  @moduledoc """
  gRPC protocol bindings for AsyncAPI specifications.
  
  Provides support for gRPC streaming operations within AsyncAPI specs.
  Supports unary, server streaming, client streaming, and bidirectional streaming.
  
  ## Usage
  
      defmodule MyApp.GrpcStreamingApi do
        use AsyncApi
        
        servers do
          server :grpc_server, "grpc://api.example.com:443" do
            protocol :grpc
            
            bindings [
              grpc: [
                service_name: "UserService",
                package: "com.example.users.v1",
                reflection_enabled: true,
                max_message_size: 4_194_304,  # 4MB
                compression: "gzip"
              ]
            ]
          end
        end
        
        channels do
          channel "users.stream" do
            description "User event stream"
            
            bindings [
              grpc: [
                method: "StreamUsers",
                streaming_type: :server_streaming,
                timeout: 30_000,
                metadata_headers: ["authorization", "x-request-id"]
              ]
            ]
          end
        end
        
        operations do
          operation :streamUsers do
            action :receive
            channel "users.stream"
            message :userEvent
            
            bindings [
              grpc: [
                request_type: "StreamUsersRequest",
                response_type: "User",
                error_codes: [:NOT_FOUND, :PERMISSION_DENIED, :UNAVAILABLE]
              ]
            ]
          end
        end
      end
  """

  @type streaming_type :: :unary | :server_streaming | :client_streaming | :bidirectional_streaming
  @type grpc_status :: :OK | :CANCELLED | :UNKNOWN | :INVALID_ARGUMENT | :DEADLINE_EXCEEDED |
                      :NOT_FOUND | :ALREADY_EXISTS | :PERMISSION_DENIED | :RESOURCE_EXHAUSTED |
                      :FAILED_PRECONDITION | :ABORTED | :OUT_OF_RANGE | :UNIMPLEMENTED |
                      :INTERNAL | :UNAVAILABLE | :DATA_LOSS | :UNAUTHENTICATED

  @doc """
  Generate gRPC service definition from AsyncAPI specification.
  
  Converts AsyncAPI operations to gRPC service methods with proper
  streaming configurations and message types.
  """
  def generate_service_definition(api_module, opts \\ []) do
    spec = AsyncApi.to_spec(api_module)
    
    service_name = get_service_name(spec, opts)
    package_name = get_package_name(spec, opts)
    
    operations = get_grpc_operations(spec)
    
    %{
      syntax: "proto3",
      package: package_name,
      service: %{
        name: service_name,
        methods: Enum.map(operations, &convert_operation_to_method/1)
      },
      messages: generate_message_definitions(spec),
      imports: get_required_imports(spec)
    }
  end

  @doc """
  Generate Protocol Buffers (.proto) file content from AsyncAPI spec.
  """
  def generate_proto_file(api_module, opts \\ []) do
    service_def = generate_service_definition(api_module, opts)
    
    proto_content = "syntax = \"" <> service_def.syntax <> "\";\n\n" <>
                    "package " <> service_def.package <> ";\n\n" <>
                    generate_imports(service_def.imports) <> "\n\n" <>
                    generate_message_definitions_proto(service_def.messages) <> "\n\n" <>
                    "service " <> service_def.service.name <> " {\n" <>
                    generate_service_methods_proto(service_def.service.methods) <> "\n" <>
                    "}"
    
    String.trim(proto_content)
  end

  @doc """
  Validate gRPC bindings in an AsyncAPI specification.
  """
  def validate_grpc_bindings(api_module) do
    spec = AsyncApi.to_spec(api_module)
    errors = []
    
    # Validate server bindings
    errors = validate_server_bindings(spec, errors)
    
    # Validate channel bindings
    errors = validate_channel_bindings(spec, errors)
    
    # Validate operation bindings
    errors = validate_operation_bindings(spec, errors)
    
    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  @doc """
  Generate gRPC client code from AsyncAPI specification.
  """
  def generate_client_code(api_module, opts \\ []) do
    language = Keyword.get(opts, :language, :elixir)
    
    case language do
      :elixir -> generate_elixir_client(api_module, opts)
      :go -> generate_go_client(api_module, opts)
      :python -> generate_python_client(api_module, opts)
      _ -> {:error, "Unsupported language: #{language}"}
    end
  end

  @doc """
  Generate gRPC server stub code from AsyncAPI specification.
  """
  def generate_server_stub(api_module, opts \\ []) do
    language = Keyword.get(opts, :language, :elixir)
    
    case language do
      :elixir -> generate_elixir_server(api_module, opts)
      :go -> generate_go_server(api_module, opts)
      :python -> generate_python_server(api_module, opts)
      _ -> {:error, "Unsupported language: #{language}"}
    end
  end

  @doc """
  Extract gRPC metadata from AsyncAPI specification.
  """
  def extract_grpc_metadata(api_module) do
    spec = AsyncApi.to_spec(api_module)
    
    %{
      service_info: extract_service_info(spec),
      streaming_methods: extract_streaming_methods(spec),
      message_types: extract_message_types(spec),
      error_handling: extract_error_handling(spec),
      middleware: extract_middleware_config(spec)
    }
  end

  # Private helper functions

  defp get_service_name(spec, opts) do
    case Keyword.get(opts, :service_name) do
      nil ->
        # Extract from server bindings or use default
        servers = spec[:servers] || %{}
        
        service_name = servers
        |> Enum.find_value(fn {_name, server} ->
          get_in(server, [:bindings, :grpc, :service_name])
        end)
        
        service_name || "AsyncApiService"
      
      name -> name
    end
  end

  defp get_package_name(spec, opts) do
    case Keyword.get(opts, :package) do
      nil ->
        servers = spec[:servers] || %{}
        
        package = servers
        |> Enum.find_value(fn {_name, server} ->
          get_in(server, [:bindings, :grpc, :package])
        end)
        
        package || "asyncapi.v1"
      
      package -> package
    end
  end

  defp get_grpc_operations(spec) do
    operations = spec[:operations] || %{}
    channels = spec[:channels] || %{}
    
    Enum.filter(operations, fn {_name, operation} ->
      channel_name = operation[:channel]
      channel = Map.get(channels, String.to_atom(channel_name))
      
      channel && has_grpc_bindings?(channel)
    end)
  end

  defp has_grpc_bindings?(channel) do
    get_in(channel, [:bindings, :grpc]) != nil
  end

  defp convert_operation_to_method({operation_name, operation}) do
    grpc_bindings = get_operation_grpc_bindings(operation)
    
    %{
      name: grpc_bindings[:method] || Macro.camelize(to_string(operation_name)),
      streaming_type: grpc_bindings[:streaming_type] || :unary,
      input_type: grpc_bindings[:request_type] || "#{Macro.camelize(to_string(operation_name))}Request",
      output_type: grpc_bindings[:response_type] || "#{Macro.camelize(to_string(operation_name))}Response",
      description: operation[:summary] || operation[:description],
      options: extract_method_options(grpc_bindings)
    }
  end

  defp get_operation_grpc_bindings(operation) do
    get_in(operation, [:bindings, :grpc]) || %{}
  end

  defp extract_method_options(grpc_bindings) do
    options = []
    
    options = if timeout = grpc_bindings[:timeout] do
      [timeout: timeout] ++ options
    else
      options
    end
    
    options = if error_codes = grpc_bindings[:error_codes] do
      [error_codes: error_codes] ++ options
    else
      options
    end
    
    options
  end

  defp generate_message_definitions(spec) do
    schemas = get_in(spec, [:components, :schemas]) || %{}
    
    Enum.map(schemas, fn {schema_name, schema} ->
      convert_schema_to_message(schema_name, schema)
    end)
  end

  defp convert_schema_to_message(schema_name, schema) do
    fields = case schema[:properties] do
      nil -> []
      properties -> 
        properties
        |> Enum.with_index(1)
        |> Enum.map(fn {prop, index} ->
          convert_property_to_field(prop, index)
        end)
    end
    
    %{
      name: Macro.camelize(to_string(schema_name)),
      fields: fields,
      description: schema[:description]
    }
  end

  defp convert_property_to_field({prop_name, prop_schema}, field_number) do
    %{
      name: to_string(prop_name),
      number: field_number,
      type: convert_type_to_proto(prop_schema[:type]),
      label: if(prop_schema[:required], do: :required, else: :optional),
      description: prop_schema[:description]
    }
  end

  defp convert_type_to_proto(type) do
    case type do
      :string -> "string"
      :integer -> "int32"
      :number -> "double"
      :boolean -> "bool"
      :array -> "repeated"
      :object -> "message"
      _ -> "string"
    end
  end

  defp get_required_imports(_spec) do
    [
      "google/protobuf/timestamp.proto",
      "google/protobuf/empty.proto"
    ]
  end

  defp generate_imports(imports) do
    imports
    |> Enum.map(&"import \"#{&1}\";")
    |> Enum.join("\n")
  end

  defp generate_message_definitions_proto(messages) do
    messages
    |> Enum.map(&generate_message_proto/1)
    |> Enum.join("\n\n")
  end

  defp generate_message_proto(message) do
    fields_proto = message.fields
    |> Enum.map(&generate_field_proto/1)
    |> Enum.join("\n  ")
    
    "// " <> (message.description || "Generated from AsyncAPI") <> "\n" <>
    "message " <> message.name <> " {\n" <>
    "  " <> fields_proto <> "\n" <>
    "}"
  end

  defp generate_field_proto(field) do
    label = case field.label do
      :repeated -> "repeated "
      _ -> ""
    end
    
    comment = if field.description, do: " // #{field.description}", else: ""
    
    "#{label}#{field.type} #{field.name} = #{field.number};#{comment}"
  end

  defp generate_service_methods_proto(methods) do
    methods
    |> Enum.map(&generate_method_proto/1)
    |> Enum.join("\n  ")
  end

  defp generate_method_proto(method) do
    input_stream = if method.streaming_type in [:client_streaming, :bidirectional_streaming], do: "stream ", else: ""
    output_stream = if method.streaming_type in [:server_streaming, :bidirectional_streaming], do: "stream ", else: ""
    
    comment = if method.description, do: "  // #{method.description}\n", else: ""
    
    "#{comment}  rpc #{method.name}(#{input_stream}#{method.input_type}) returns (#{output_stream}#{method.output_type});"
  end

  defp generate_elixir_client(api_module, opts) do
    service_def = generate_service_definition(api_module, opts)
    module_name = Keyword.get(opts, :module_name, to_string(api_module) <> ".Client")
    
    client_code = "defmodule " <> module_name <> " do\n" <>
                  "  @moduledoc \"\"\"\n" <>
                  "  Generated gRPC client for " <> to_string(api_module) <> "\n" <>
                  "  \"\"\"\n" <>
                  "  \n" <>
                  "  use GRPC.Client, service: " <> service_def.service.name <> "\n" <>
                  "  \n" <>
                  generate_elixir_client_methods(service_def.service.methods) <> "\n" <>
                  "end"
    
    {:ok, client_code}
  end

  defp generate_elixir_client_methods(methods) do
    methods
    |> Enum.map(&generate_elixir_client_method/1)
    |> Enum.join("\n\n")
  end

  defp generate_elixir_client_method(method) do
    method_name = Macro.underscore(method.name)
    method_atom = String.to_atom(method.name)
    description = method.description || "Generated gRPC method"
    
    case method.streaming_type do
      :unary ->
        "@doc \"#{description}\"\n" <>
        "def #{method_name}(request, opts \\\\ []) do\n" <>
        "  GRPC.Client.call(__MODULE__, #{inspect(method_atom)}, request, opts)\n" <>
        "end"
      
      :server_streaming ->
        "@doc \"#{description} (server streaming)\"\n" <>
        "def #{method_name}_stream(request, opts \\\\ []) do\n" <>
        "  GRPC.Client.stream(__MODULE__, #{inspect(method_atom)}, request, opts)\n" <>
        "end"
      
      :client_streaming ->
        "@doc \"#{description} (client streaming)\"\n" <>
        "def #{method_name}_stream(stream, opts \\\\ []) do\n" <>
        "  GRPC.Client.stream(__MODULE__, #{inspect(method_atom)}, stream, opts)\n" <>
        "end"
      
      :bidirectional_streaming ->
        "@doc \"#{description} (bidirectional streaming)\"\n" <>
        "def #{method_name}_bidi_stream(stream, opts \\\\ []) do\n" <>
        "  GRPC.Client.stream(__MODULE__, #{inspect(method_atom)}, stream, opts)\n" <>
        "end"
    end
  end

  defp generate_elixir_server(api_module, opts) do
    service_def = generate_service_definition(api_module, opts)
    module_name = Keyword.get(opts, :module_name, to_string(api_module) <> ".Server")
    
    server_code = "defmodule " <> module_name <> " do" <> "\n" <>
                  "  @moduledoc \"\"\"" <> "\n" <>
                  "  Generated gRPC server for " <> to_string(api_module) <> "\n" <>
                  "  \"\"\"" <> "\n" <>
                  "  " <> "\n" <>
                  "  use GRPC.Server, service: " <> service_def.service.name <> "\n" <>
                  "  " <> "\n" <>
                  generate_elixir_server_methods(service_def.service.methods) <> "\n" <>
                  "end"
    
    {:ok, server_code}
  end

  defp generate_elixir_server_methods(methods) do
    methods
    |> Enum.map(&generate_elixir_server_method/1)
    |> Enum.join("\n\n")
  end

  defp generate_elixir_server_method(method) do
    method_name = Macro.underscore(method.name)
    description = method.description || "Handle " <> method.name <> " (unary)"
    
    case method.streaming_type do
      :unary ->
        "@doc \"" <> description <> "\"" <> "\n" <>
        "@spec " <> method_name <> "(" <> method.input_type <> ".t(), GRPC.Server.Stream.t()) ::" <> "\n" <>
        "        {:ok, " <> method.output_type <> ".t()} | {:error, term()}" <> "\n" <>
        "def " <> method_name <> "(request, _stream) do" <> "\n" <>
        "  # TODO: Implement your business logic here" <> "\n" <>
        "  {:error, GRPC.RPCError.exception(GRPC.Status.unimplemented(), \"Not implemented\")}" <> "\n" <>
        "end"
      
      :server_streaming ->
        server_description = method.description || "Handle " <> method.name <> " (server streaming)"
        "@doc \"" <> server_description <> "\"" <> "\n" <>
        "@spec " <> method_name <> "(" <> method.input_type <> ".t(), GRPC.Server.Stream.t()) ::" <> "\n" <>
        "        :ok | {:error, term()}" <> "\n" <>
        "def " <> method_name <> "(request, stream) do" <> "\n" <>
        "  # TODO: Implement your streaming logic here" <> "\n" <>
        "  # Use GRPC.Server.stream_send(stream, response) to send responses" <> "\n" <>
        "  {:error, GRPC.RPCError.exception(GRPC.Status.unimplemented(), \"Not implemented\")}" <> "\n" <>
        "end"
      
      :client_streaming ->
        client_description = method.description || "Handle " <> method.name <> " (client streaming)"
        "@doc \"" <> client_description <> "\"" <> "\n" <>
        "@spec " <> method_name <> "(Enumerable.t(), GRPC.Server.Stream.t()) ::" <> "\n" <>
        "        {:ok, " <> method.output_type <> ".t()} | {:error, term()}" <> "\n" <>
        "def " <> method_name <> "(stream, _server_stream) do" <> "\n" <>
        "  # TODO: Implement your streaming logic here" <> "\n" <>
        "  # Consume the client stream and return a single response" <> "\n" <>
        "  {:error, GRPC.RPCError.exception(GRPC.Status.unimplemented(), \"Not implemented\")}" <> "\n" <>
        "end"
      
      :bidirectional_streaming ->
        bidi_description = method.description || "Handle " <> method.name <> " (bidirectional streaming)"
        "@doc \"" <> bidi_description <> "\"" <> "\n" <>
        "@spec " <> method_name <> "(Enumerable.t(), GRPC.Server.Stream.t()) ::" <> "\n" <>
        "        :ok | {:error, term()}" <> "\n" <>
        "def " <> method_name <> "(stream, server_stream) do" <> "\n" <>
        "  # TODO: Implement your bidirectional streaming logic here" <> "\n" <>
        "  # Consume from client stream and send responses using GRPC.Server.stream_send" <> "\n" <>
        "  {:error, GRPC.RPCError.exception(GRPC.Status.unimplemented(), \"Not implemented\")}" <> "\n" <>
        "end"
    end
  end

  defp generate_go_client(api_module, opts) do
    service_def = generate_service_definition(api_module, opts)
    package_name = Keyword.get(opts, :package, "client")
    
    go_code = "package " <> package_name <> "\n\n" <>
              "import (\n" <>
              "    \"context\"\n" <>
              "    \"google.golang.org/grpc\"\n" <>
              "    pb \"./\" <> service_def.package <> \"\" // Update this import path\n" <>
              ")\n\n" <>
              "type " <> service_def.service.name <> "Client struct {\n" <>
              "    client pb." <> service_def.service.name <> "Client\n" <>
              "    conn   *grpc.ClientConn\n" <>
              "}\n\n" <>
              "func New" <> service_def.service.name <> "Client(conn *grpc.ClientConn) *" <> service_def.service.name <> "Client {\n" <>
              "    return &" <> service_def.service.name <> "Client{\n" <>
              "        client: pb.New" <> service_def.service.name <> "Client(conn),\n" <>
              "        conn:   conn,\n" <>
              "    }\n" <>
              "}\n\n" <>
              "func (c *" <> service_def.service.name <> "Client) Close() error {\n" <>
              "    return c.conn.Close()\n" <>
              "}\n\n" <>
              generate_go_client_methods(service_def.service.methods)
    
    {:ok, go_code}
  end

  defp generate_python_client(api_module, opts) do
    service_def = generate_service_definition(api_module, opts)
    class_name = Keyword.get(opts, :class_name, service_def.service.name <> "Client")
    
    python_code = "import grpc\n" <>
                  "from typing import Iterator, Optional\n" <>
                  "import " <> String.downcase(service_def.package) <> "_pb2 as pb2\n" <>
                  "import " <> String.downcase(service_def.package) <> "_pb2_grpc as pb2_grpc\n\n\n" <>
                  "class " <> class_name <> ":\n" <>
                  "    \"\"\"Generated gRPC client for " <> to_string(api_module) <> "\"\"\"\n" <>
                  "    \n" <>
                  "    def __init__(self, channel: grpc.Channel):\n" <>
                  "        self.stub = pb2_grpc." <> service_def.service.name <> "Stub(channel)\n" <>
                  "    \n" <>
                  "    @classmethod\n" <>
                  "    def from_target(cls, target: str, credentials=None, options=None):\n" <>
                  "        \"\"\"Create client from target address\"\"\"\n" <>
                  "        if credentials is None:\n" <>
                  "            channel = grpc.insecure_channel(target, options=options)\n" <>
                  "        else:\n" <>
                  "            channel = grpc.secure_channel(target, credentials, options=options)\n" <>
                  "        return cls(channel)\n\n" <>
                  generate_python_client_methods(service_def.service.methods)
    
    {:ok, python_code}
  end

  defp generate_go_server(api_module, opts) do
    service_def = generate_service_definition(api_module, opts)
    package_name = Keyword.get(opts, :package, "server")
    
    go_code = "package " <> package_name <> "\n\n" <>
              "import (\n" <>
              "    \"context\"\n" <>
              "    \"google.golang.org/grpc/codes\"\n" <>
              "    \"google.golang.org/grpc/status\"\n" <>
              "    pb \"./\" <> service_def.package <> \"\" // Update this import path\n" <>
              ")\n\n" <>
              "type " <> service_def.service.name <> "Server struct {\n" <>
              "    pb.Unimplemented" <> service_def.service.name <> "Server\n" <>
              "}\n\n" <>
              "func New" <> service_def.service.name <> "Server() *" <> service_def.service.name <> "Server {\n" <>
              "    return &" <> service_def.service.name <> "Server{}\n" <>
              "}\n\n" <>
              generate_go_server_methods(service_def.service.methods)
    
    {:ok, go_code}
  end

  defp generate_python_server(api_module, opts) do
    service_def = generate_service_definition(api_module, opts)
    class_name = Keyword.get(opts, :class_name, service_def.service.name <> "Servicer")
    
    python_code = "import grpc\n" <>
                  "from typing import Iterator, Optional\n" <>
                  "import " <> String.downcase(service_def.package) <> "_pb2 as pb2\n" <>
                  "import " <> String.downcase(service_def.package) <> "_pb2_grpc as pb2_grpc\n\n\n" <>
                  "class " <> class_name <> "(pb2_grpc." <> service_def.service.name <> "Servicer):\n" <>
                  "    \"\"\"Generated gRPC server for " <> to_string(api_module) <> "\"\"\"\n\n" <>
                  generate_python_server_methods(service_def.service.methods)
    
    {:ok, python_code}
  end

  defp validate_server_bindings(spec, errors) do
    servers = spec[:servers] || %{}
    
    Enum.reduce(servers, errors, fn {server_name, server}, acc ->
      grpc_bindings = get_in(server, [:bindings, :grpc])
      
      if grpc_bindings do
        validate_server_grpc_bindings(server_name, grpc_bindings, acc)
      else
        acc
      end
    end)
  end

  defp validate_server_grpc_bindings(server_name, bindings, errors) do
    errors = if !bindings[:service_name] do
      ["Server #{server_name}: gRPC binding missing service_name" | errors]
    else
      errors
    end
    
    errors = if !bindings[:package] do
      ["Server #{server_name}: gRPC binding missing package" | errors]
    else
      errors
    end
    
    errors
  end

  defp validate_channel_bindings(spec, errors) do
    channels = spec[:channels] || %{}
    
    Enum.reduce(channels, errors, fn {channel_name, channel}, acc ->
      grpc_bindings = get_in(channel, [:bindings, :grpc])
      
      if grpc_bindings do
        validate_channel_grpc_bindings(channel_name, grpc_bindings, acc)
      else
        acc
      end
    end)
  end

  defp validate_channel_grpc_bindings(channel_name, bindings, errors) do
    errors = if !bindings[:method] do
      ["Channel #{channel_name}: gRPC binding missing method name" | errors]
    else
      errors
    end
    
    streaming_type = bindings[:streaming_type]
    valid_types = [:unary, :server_streaming, :client_streaming, :bidirectional_streaming]
    
    errors = if streaming_type && !Enum.member?(valid_types, streaming_type) do
      ["Channel #{channel_name}: Invalid streaming_type #{streaming_type}" | errors]
    else
      errors
    end
    
    errors
  end

  defp validate_operation_bindings(spec, errors) do
    operations = spec[:operations] || %{}
    
    Enum.reduce(operations, errors, fn {operation_name, operation}, acc ->
      grpc_bindings = get_in(operation, [:bindings, :grpc])
      
      if grpc_bindings do
        validate_operation_grpc_bindings(operation_name, grpc_bindings, acc)
      else
        acc
      end
    end)
  end

  defp validate_operation_grpc_bindings(operation_name, bindings, errors) do
    errors = if error_codes = bindings[:error_codes] do
      invalid_codes = Enum.reject(error_codes, fn code ->
        code in [:OK, :CANCELLED, :UNKNOWN, :INVALID_ARGUMENT, :DEADLINE_EXCEEDED,
                :NOT_FOUND, :ALREADY_EXISTS, :PERMISSION_DENIED, :RESOURCE_EXHAUSTED,
                :FAILED_PRECONDITION, :ABORTED, :OUT_OF_RANGE, :UNIMPLEMENTED,
                :INTERNAL, :UNAVAILABLE, :DATA_LOSS, :UNAUTHENTICATED]
      end)
      
      if length(invalid_codes) > 0 do
        ["Operation #{operation_name}: Invalid gRPC error codes: #{inspect(invalid_codes)}" | errors]
      else
        errors
      end
    else
      errors
    end
    
    errors
  end

  defp extract_service_info(spec) do
    servers = spec[:servers] || %{}
    
    servers
    |> Enum.find_value(fn {_name, server} ->
      get_in(server, [:bindings, :grpc])
    end) || %{}
  end

  defp extract_streaming_methods(spec) do
    operations = spec[:operations] || %{}
    channels = spec[:channels] || %{}
    
    operations
    |> Enum.filter(fn {_name, operation} ->
      channel_name = operation[:channel]
      channel = Map.get(channels, String.to_atom(channel_name))
      
      channel && has_grpc_bindings?(channel)
    end)
    |> Enum.map(fn {name, operation} ->
      grpc_bindings = get_operation_grpc_bindings(operation)
      {name, grpc_bindings[:streaming_type] || :unary}
    end)
  end

  defp extract_message_types(spec) do
    schemas = get_in(spec, [:components, :schemas]) || %{}
    
    Enum.into(schemas, %{}, fn {name, schema} ->
      {name, extract_schema_info(schema)}
    end)
  end

  defp extract_schema_info(schema) do
    %{
      type: schema[:type],
      properties: schema[:properties] || %{},
      required: schema[:required] || [],
      description: schema[:description]
    }
  end

  defp extract_error_handling(spec) do
    operations = spec[:operations] || %{}
    
    operations
    |> Enum.flat_map(fn {name, operation} ->
      grpc_bindings = get_operation_grpc_bindings(operation)
      case grpc_bindings[:error_codes] do
        nil -> []
        codes -> [{name, codes}]
      end
    end)
    |> Enum.into(%{})
  end

  defp extract_middleware_config(spec) do
    servers = spec[:servers] || %{}
    
    servers
    |> Enum.flat_map(fn {_name, server} ->
      grpc_bindings = get_in(server, [:bindings, :grpc]) || %{}
      
      middleware = []
      
      middleware = if grpc_bindings[:compression] do
        [{:compression, grpc_bindings[:compression]} | middleware]
      else
        middleware
      end
      
      middleware = if grpc_bindings[:max_message_size] do
        [{:max_message_size, grpc_bindings[:max_message_size]} | middleware]
      else
        middleware
      end
      
      middleware
    end)
  end

  # Go client method generation helpers
  defp generate_go_client_methods(methods) do
    methods
    |> Enum.map(&generate_go_client_method/1)
    |> Enum.join("\n\n")
  end

  defp generate_go_client_method(method) do
    case method.streaming_type do
      :unary ->
        "func (c *" <> method.name <> "Client) " <> method.name <> "(ctx context.Context, req *pb." <> method.input_type <> ") (*pb." <> method.output_type <> ", error) {\n" <>
        "    return c.client." <> method.name <> "(ctx, req)\n" <>
        "}"
      
      :server_streaming ->
        "func (c *" <> method.name <> "Client) " <> method.name <> "(ctx context.Context, req *pb." <> method.input_type <> ") (pb." <> method.name <> "_" <> method.name <> "Client, error) {\n" <>
        "    return c.client." <> method.name <> "(ctx, req)\n" <>
        "}"
      
      :client_streaming ->
        "func (c *" <> method.name <> "Client) " <> method.name <> "(ctx context.Context) (pb." <> method.name <> "_" <> method.name <> "Client, error) {\n" <>
        "    return c.client." <> method.name <> "(ctx)\n" <>
        "}"
      
      :bidirectional_streaming ->
        "func (c *" <> method.name <> "Client) " <> method.name <> "(ctx context.Context) (pb." <> method.name <> "_" <> method.name <> "Client, error) {\n" <>
        "    return c.client." <> method.name <> "(ctx)\n" <>
        "}"
    end
  end

  # Go server method generation helpers
  defp generate_go_server_methods(methods) do
    methods
    |> Enum.map(&generate_go_server_method/1)
    |> Enum.join("\n\n")
  end

  defp generate_go_server_method(method) do
    case method.streaming_type do
      :unary ->
        "func (s *" <> method.name <> "Server) " <> method.name <> "(ctx context.Context, req *pb." <> method.input_type <> ") (*pb." <> method.output_type <> ", error) {\n" <>
        "    // TODO: Implement your business logic here\n" <>
        "    return nil, status.Errorf(codes.Unimplemented, \"method " <> method.name <> " not implemented\")\n" <>
        "}"
      
      :server_streaming ->
        "func (s *" <> method.name <> "Server) " <> method.name <> "(req *pb." <> method.input_type <> ", stream pb." <> method.name <> "_" <> method.name <> "Server) error {\n" <>
        "    // TODO: Implement your streaming logic here\n" <>
        "    return status.Errorf(codes.Unimplemented, \"method " <> method.name <> " not implemented\")\n" <>
        "}"
      
      :client_streaming ->
        "func (s *" <> method.name <> "Server) " <> method.name <> "(stream pb." <> method.name <> "_" <> method.name <> "Server) error {\n" <>
        "    // TODO: Implement your streaming logic here\n" <>
        "    return status.Errorf(codes.Unimplemented, \"method " <> method.name <> " not implemented\")\n" <>
        "}"
      
      :bidirectional_streaming ->
        "func (s *" <> method.name <> "Server) " <> method.name <> "(stream pb." <> method.name <> "_" <> method.name <> "Server) error {\n" <>
        "    // TODO: Implement your bidirectional streaming logic here\n" <>
        "    return status.Errorf(codes.Unimplemented, \"method " <> method.name <> " not implemented\")\n" <>
        "}"
    end
  end

  # Python client method generation helpers
  defp generate_python_client_methods(methods) do
    methods
    |> Enum.map(&generate_python_client_method/1)
    |> Enum.join("\n\n")
  end

  defp generate_python_client_method(method) do
    snake_name = Macro.underscore(method.name)
    
    case method.streaming_type do
      :unary ->
        description = method.description || "Call " <> method.name <> " (unary)"
        "def " <> snake_name <> "(self, request: pb2." <> method.input_type <> ", timeout=None, metadata=None) -> pb2." <> method.output_type <> ":\n" <>
        "    \"\"\"" <> description <> "\"\"\"\n" <>
        "    return self.stub." <> method.name <> "(request, timeout=timeout, metadata=metadata)"
      
      :server_streaming ->
        description = method.description || "Call " <> method.name <> " (server streaming)"
        "def " <> snake_name <> "(self, request: pb2." <> method.input_type <> ", timeout=None, metadata=None) -> Iterator[pb2." <> method.output_type <> "]:\n" <>
        "    \"\"\"" <> description <> "\"\"\"\n" <>
        "    return self.stub." <> method.name <> "(request, timeout=timeout, metadata=metadata)"
      
      :client_streaming ->
        description = method.description || "Call " <> method.name <> " (client streaming)"
        "def " <> snake_name <> "(self, request_iterator: Iterator[pb2." <> method.input_type <> "], timeout=None, metadata=None) -> pb2." <> method.output_type <> ":\n" <>
        "    \"\"\"" <> description <> "\"\"\"\n" <>
        "    return self.stub." <> method.name <> "(request_iterator, timeout=timeout, metadata=metadata)"
      
      :bidirectional_streaming ->
        description = method.description || "Call " <> method.name <> " (bidirectional streaming)"
        "def " <> snake_name <> "(self, request_iterator: Iterator[pb2." <> method.input_type <> "], timeout=None, metadata=None) -> Iterator[pb2." <> method.output_type <> "]:\n" <>
        "    \"\"\"" <> description <> "\"\"\"\n" <>
        "    return self.stub." <> method.name <> "(request_iterator, timeout=timeout, metadata=metadata)"
    end
  end

  # Python server method generation helpers
  defp generate_python_server_methods(methods) do
    methods
    |> Enum.map(&generate_python_server_method/1)
    |> Enum.join("\n\n")
  end

  defp generate_python_server_method(method) do
    case method.streaming_type do
      :unary ->
        description = method.description || "Handle " <> method.name <> " (unary)"
        "def " <> method.name <> "(self, request: pb2." <> method.input_type <> ", context: grpc.ServicerContext) -> pb2." <> method.output_type <> ":\n" <>
        "    \"\"\"" <> description <> "\"\"\"\n" <>
        "    # TODO: Implement your business logic here\n" <>
        "    context.set_code(grpc.StatusCode.UNIMPLEMENTED)\n" <>
        "    context.set_details('Method not implemented!')\n" <>
        "    raise NotImplementedError('Method not implemented!')"
      
      :server_streaming ->
        description = method.description || "Handle " <> method.name <> " (server streaming)"
        "def " <> method.name <> "(self, request: pb2." <> method.input_type <> ", context: grpc.ServicerContext) -> Iterator[pb2." <> method.output_type <> "]:\n" <>
        "    \"\"\"" <> description <> "\"\"\"\n" <>
        "    # TODO: Implement your streaming logic here\n" <>
        "    context.set_code(grpc.StatusCode.UNIMPLEMENTED)\n" <>
        "    context.set_details('Method not implemented!')\n" <>
        "    raise NotImplementedError('Method not implemented!')"
      
      :client_streaming ->
        description = method.description || "Handle " <> method.name <> " (client streaming)"
        "def " <> method.name <> "(self, request_iterator: Iterator[pb2." <> method.input_type <> "], context: grpc.ServicerContext) -> pb2." <> method.output_type <> ":\n" <>
        "    \"\"\"" <> description <> "\"\"\"\n" <>
        "    # TODO: Implement your streaming logic here\n" <>
        "    context.set_code(grpc.StatusCode.UNIMPLEMENTED)\n" <>
        "    context.set_details('Method not implemented!')\n" <>
        "    raise NotImplementedError('Method not implemented!')"
      
      :bidirectional_streaming ->
        description = method.description || "Handle " <> method.name <> " (bidirectional streaming)"
        "def " <> method.name <> "(self, request_iterator: Iterator[pb2." <> method.input_type <> "], context: grpc.ServicerContext) -> Iterator[pb2." <> method.output_type <> "]:\n" <>
        "    \"\"\"" <> description <> "\"\"\"\n" <>
        "    # TODO: Implement your bidirectional streaming logic here\n" <>
        "    context.set_code(grpc.StatusCode.UNIMPLEMENTED)\n" <>
        "    context.set_details('Method not implemented!')\n" <>
        "    raise NotImplementedError('Method not implemented!')"
    end
  end
end