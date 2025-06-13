defmodule AsyncApiPolyglot do
  @moduledoc """
  Extended AsyncAPI DSL with polyglot code generation capabilities.
  
  This module provides the same AsyncAPI DSL functionality as `AsyncApi`,
  but with additional transformers that automatically generate:
  
  - Cap'n Proto schemas for zero-copy serialization
  - High-performance clients in Rust, Python, Elixir, and TypeScript
  - Build files, documentation, and CI/CD configurations
  - Docker containers and deployment configurations
  
  ## Usage
  
      defmodule MyApp.EventApi do
        use AsyncApiPolyglot
        
        info do
          title "My Event API"
          version "1.0.0"
          description "High-performance event streaming API"
        end
        
        servers do
          server :production, "nats://events.example.com:4222" do
            protocol :nats
            description "Production NATS server"
          end
        end
        
        channels do
          channel "user.events.{userId}" do
            description "User-specific event stream"
            
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
          operation :publishUserEvent do
            action :send
            channel "user.events.{userId}"
            message :userEvent
          end
          
          operation :receiveUserEvent do
            action :receive
            channel "user.events.{userId}"
            message :userEvent
          end
        end
        
        components do
          messages do
            message :userEvent do
              title "User Event"
              payload :userEventPayload
            end
          end
          
          schemas do
            schema :userEventPayload do
              type :object
              
              property :eventType, :string do
                description "Type of user event"
                enum ["login", "logout", "purchase", "profile_update"]
              end
              
              property :userId, :string do
                description "User identifier"
                pattern "^[0-9]+$"
              end
              
              property :timestamp, :string do
                description "Event timestamp"
                format "date-time"
              end
              
              property :metadata, :object do
                description "Additional event metadata"
                additional_properties true
              end
              
              required [:eventType, :userId, :timestamp]
            end
          end
        end
      end
  
  ## Generated Artifacts
  
  When you compile a module using `AsyncApiPolyglot`, it will automatically generate:
  
  ### Cap'n Proto Schemas
  - `priv/generated/{api}/schema/schema.capnp` - Main event structures
  - `priv/generated/{api}/schema/types.capnp` - Type definitions
  - `priv/generated/{api}/schema/events.capnp` - Event-specific schemas
  
  ### Rust Client
  - High-performance async client with Tokio
  - Zero-allocation serialization with Cap'n Proto
  - NATS, WebSocket, and memory transport implementations
  - Complete Cargo project with dependencies and build scripts
  
  ### Python Client
  - AsyncIO-compatible client with type hints
  - NumPy integration for high-performance data processing
  - Automatic batch operations for throughput optimization
  - pip-installable package with all dependencies
  
  ### Elixir Client
  - GenServer-based event bus with supervision trees
  - NIF integration for performance-critical paths
  - Phoenix integration examples
  - Complete Mix project with dependencies
  
  ### TypeScript Client
  - Promise-based API with full type safety
  - WebSocket and NATS transport support
  - Node.js and browser compatibility
  - npm package with TypeScript definitions
  
  ### Build and Deployment
  - Makefile for building all clients
  - Docker Compose setup for development
  - GitHub Actions CI/CD workflows
  - Documentation and usage examples
  
  ## Performance Features
  
  The generated clients are optimized for high-performance scenarios:
  
  - **Zero-copy serialization** using Cap'n Proto
  - **Buffer pooling** to minimize memory allocations
  - **Batch operations** for high-throughput scenarios
  - **Async/await patterns** for non-blocking I/O
  - **Language-specific optimizations** (SIMD in Rust, NumPy in Python, NIFs in Elixir)
  
  ## Example Usage
  
  Once generated, you can use the clients in each language:
  
  ### Rust
      let bus = EventBus::new(transport);
      bus.publish_user_event(payload).await?;
  
  ### Python
      bus = EventBus(transport)
      await bus.publish_user_event(payload)
  
  ### Elixir
      EventBus.publish_user_event(payload)
  
  ### TypeScript
      await bus.publishUserEvent(payload);
  
  All clients provide the same API surface with language-appropriate conventions.
  """

  defmacro __using__(_opts) do
    quote do
      use Spark.Dsl, default_extensions: [extensions: [AsyncApi.DslExtensions]]
      
      @doc """
      Compile the AsyncAPI specification and generate all polyglot artifacts.
      
      This function triggers the generation of Cap'n Proto schemas and clients
      in all supported languages. It should be called at compile time to ensure
      all artifacts are available.
      """
      def compile! do
        # Trigger the transformer pipeline
        __MODULE__.spark_dsl_config()
        :ok
      end
      
      @doc """
      Get the generated Cap'n Proto schema content.
      """
      def capnp_schema do
        config = __MODULE__.spark_dsl_config()
        Spark.Dsl.Extension.get_option(config, [:capnproto, :main_schema])
      end
      
      @doc """
      Get the base path for generated artifacts.
      """
      def generated_path do
        api_info = __MODULE__.spark_dsl_config()
        |> Spark.Dsl.Extension.get_option([:capnproto, :api_info])
        
        package_name = api_info.title
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9]/, "-")
        
        "priv/generated/#{package_name}"
      end
      
      @doc """
      List all generated files.
      """
      def generated_files do
        base_path = generated_path()
        
        if File.exists?(base_path) do
          Path.wildcard("#{base_path}/**/*")
          |> Enum.filter(&File.regular?/1)
          |> Enum.sort()
        else
          []
        end
      end
      
      @doc """
      Get generation statistics.
      """
      def generation_stats do
        files = generated_files()
        
        stats = %{
          total_files: length(files),
          rust_files: Enum.count(files, &String.contains?(&1, "/rust/")),
          python_files: Enum.count(files, &String.contains?(&1, "/python/")),
          elixir_files: Enum.count(files, &String.contains?(&1, "/elixir/")),
          typescript_files: Enum.count(files, &String.contains?(&1, "/typescript/")),
          schema_files: Enum.count(files, &String.contains?(&1, "/schema/")),
          total_size: files |> Enum.map(&File.stat!/1) |> Enum.map(& &1.size) |> Enum.sum()
        }
        
        Map.put(stats, :languages, [:rust, :python, :elixir, :typescript])
      end
    end
  end
end