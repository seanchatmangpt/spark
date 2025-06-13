# Building DSL Frameworks: A Meta-Framework Design Document

## Vision: Making DSL Creation Effortless

Instead of building framework-specific features, we should focus on making it **trivially easy** for other framework authors to build their own Spark-like DSL systems. This document outlines a meta-framework approach that abstracts the common patterns of DSL creation.

## Current Problem: DSL Creation is Hard

Building a domain-specific language today requires:
- Deep understanding of Elixir macros and AST manipulation
- Implementing entity/transformer patterns from scratch
- Building validation, documentation, and testing infrastructure
- Creating runtime introspection capabilities
- Handling edge cases and error scenarios

**Result**: Only expert Elixir developers can create DSLs, limiting adoption.

## Solution: DSL Framework Generator

A meta-framework that generates complete DSL frameworks from high-level specifications.

### Core Concept: DSL-as-Data

Instead of writing macros, framework authors define their DSL using a declarative specification:

```elixir
defmodule MyFramework.DSL do
  use Spark.DSLFramework

  # Define your domain entities
  domain "web_framework" do
    description "A DSL for defining web applications"
    
    entity :route do
      fields do
        field :path, :string, required: true
        field :method, :atom, default: :get, enum: [:get, :post, :put, :delete]
        field :handler, :module, required: true
        field :middleware, {:array, :module}, default: []
      end
      
      validations do
        validate :path, &validate_path/1
        validate :handler, &Code.ensure_loaded?/1
      end
      
      transformations do
        transform :compile_route, &compile_route_definition/1
      end
    end
    
    entity :middleware do
      fields do
        field :name, :atom, required: true
        field :config, :map, default: %{}
        field :priority, :integer, default: 100
      end
      
      relationships do
        belongs_to :router
        has_many :routes
      end
    end
    
    sections do
      section :router do
        entities [:route, :middleware]
        description "Define routes and middleware"
        
        compile_hooks do
          before_compile &validate_router_coherence/1
          after_compile &generate_router_module/1
        end
      end
    end
  end
  
  # Generate client libraries
  generate do
    phoenix_integration do
      router_module true
      controller_templates true
      test_helpers true
    end
    
    documentation do
      auto_docs true
      examples true
      api_reference true
    end
    
    tooling do
      formatter true
      linter true
      language_server true
    end
  end
end
```

**Result**: This specification automatically generates a complete DSL framework with all the boilerplate, validation, testing, and tooling.

## Meta-Framework Architecture

### 1. DSL Specification Language

A declarative language for describing DSL structures:

```elixir
defmodule Spark.DSLFramework do
  @moduledoc """
  Meta-framework for generating complete DSL systems.
  """
  
  defmacro __using__(_opts) do
    quote do
      import Spark.DSLFramework.{Entity, Section, Validation, Generation}
      Module.register_attribute(__MODULE__, :domain_spec, accumulate: false)
      Module.register_attribute(__MODULE__, :entities, accumulate: true)
      Module.register_attribute(__MODULE__, :sections, accumulate: true)
      Module.register_attribute(__MODULE__, :generators, accumulate: true)
      @before_compile Spark.DSLFramework
    end
  end
  
  defmacro domain(name, do: block) do
    quote do
      @domain_spec {unquote(name), unquote(block)}
    end
  end
  
  defmacro __before_compile__(env) do
    domain_spec = Module.get_attribute(env.module, :domain_spec)
    entities = Module.get_attribute(env.module, :entities)
    sections = Module.get_attribute(env.module, :sections)
    generators = Module.get_attribute(env.module, :generators)
    
    # Generate complete DSL framework
    quote do
      # Generate entity modules
      unquote_splicing(generate_entity_modules(entities))
      
      # Generate section modules
      unquote_splicing(generate_section_modules(sections))
      
      # Generate main DSL module
      unquote(generate_main_dsl_module(domain_spec, entities, sections))
      
      # Generate tooling
      unquote_splicing(generate_tooling_modules(generators))
      
      # Generate documentation
      unquote(generate_documentation(domain_spec, entities, sections))
    end
  end
end
```

### 2. Universal Entity System

Reusable entity patterns that work across domains:

```elixir
defmodule Spark.DSLFramework.Entity do
  @moduledoc """
  Universal entity system for DSL frameworks.
  """
  
  defmacro entity(name, do: block) do
    quote do
      @entities {unquote(name), unquote(Macro.escape(block))}
    end
  end
  
  defmacro fields(do: block) do
    # Parse field definitions and generate structs
    fields = extract_fields(block)
    generate_field_definitions(fields)
  end
  
  defmacro validations(do: block) do
    # Generate compile-time and runtime validations
    validations = extract_validations(block)
    generate_validation_functions(validations)
  end
  
  defmacro transformations(do: block) do
    # Generate transformation pipeline
    transformations = extract_transformations(block)
    generate_transformer_modules(transformations)
  end
  
  defmacro relationships(do: block) do
    # Generate relationship handling
    relationships = extract_relationships(block)
    generate_relationship_functions(relationships)
  end
end
```

### 3. Code Generation Templates

Template system for generating framework-specific code:

```elixir
defmodule Spark.DSLFramework.Templates do
  @moduledoc """
  Template system for generating framework code.
  """
  
  # Phoenix integration template
  def phoenix_template(domain_spec) do
    """
    defmodule <%= @module_name %>Web.Router do
      use Phoenix.Router
      
      <%= for route <- @routes do %>
      <%= route.method %> "<%= route.path %>", <%= route.handler %>, :<%= route.action %>
      <% end %>
    end
    
    defmodule <%= @module_name %>Web.Controller do
      use Phoenix.Controller
      
      <%= for route <- @routes do %>
      def <%= route.action %>(conn, params) do
        # Generated controller action
        <%= route.handler %>.call(conn, params)
      end
      <% end %>
    end
    """
  end
  
  # LiveView integration template
  def liveview_template(domain_spec) do
    """
    defmodule <%= @module_name %>Web.Live.<%= @component_name %> do
      use Phoenix.LiveView
      
      def mount(_params, _session, socket) do
        {:ok, assign(socket, :data, load_data())}
      end
      
      def render(assigns) do
        ~H\"\"\"
        <%= render_component_template(@entities) %>
        \"\"\"
      end
    end
    """
  end
  
  # Test template
  def test_template(domain_spec) do
    """
    defmodule <%= @module_name %>Test do
      use ExUnit.Case, async: true
      
      <%= for entity <- @entities do %>
      describe "<%= entity.name %>" do
        test "validates required fields" do
          # Generated property-based tests
          <%= generate_property_tests(entity) %>
        end
        
        test "transforms correctly" do
          # Generated transformation tests
          <%= generate_transformation_tests(entity) %>
        end
      end
      <% end %>
    end
    """
  end
end
```

### 4. Universal Validation Framework

Pluggable validation system that works across domains:

```elixir
defmodule Spark.DSLFramework.Validation do
  @moduledoc """
  Universal validation framework for DSL entities.
  """
  
  # Built-in validators
  def validate_required(value, _opts) when value in [nil, ""], do: {:error, "is required"}
  def validate_required(_value, _opts), do: :ok
  
  def validate_type(value, type) do
    case {value, type} do
      {v, :string} when is_binary(v) -> :ok
      {v, :atom} when is_atom(v) -> :ok
      {v, :integer} when is_integer(v) -> :ok
      {v, :module} when is_atom(v) -> 
        if Code.ensure_loaded?(v), do: :ok, else: {:error, "module not found"}
      {v, {:array, inner_type}} when is_list(v) ->
        validate_array_type(v, inner_type)
      _ -> {:error, "invalid type"}
    end
  end
  
  def validate_enum(value, options) do
    if value in options do
      :ok
    else
      {:error, "must be one of #{inspect(options)}"}
    end
  end
  
  # Custom validator framework
  defmacro defvalidator(name, do: block) do
    quote do
      def unquote(:"validate_#{name}")(value, opts) do
        unquote(block)
      end
    end
  end
  
  # Validation composition
  def validate_all(value, validators) do
    Enum.reduce_while(validators, :ok, fn {validator, opts}, _acc ->
      case apply(__MODULE__, validator, [value, opts]) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end
end
```

### 5. Documentation Generation

Automatic documentation from DSL specifications:

```elixir
defmodule Spark.DSLFramework.Documentation do
  @moduledoc """
  Automatic documentation generation for DSL frameworks.
  """
  
  def generate_docs(domain_spec, entities, sections) do
    %{
      overview: generate_overview(domain_spec),
      entities: generate_entity_docs(entities),
      sections: generate_section_docs(sections),
      examples: generate_examples(domain_spec, entities),
      api_reference: generate_api_reference(entities, sections),
      guides: generate_guides(domain_spec)
    }
  end
  
  defp generate_overview({name, spec}) do
    """
    # #{String.capitalize(name)} DSL
    
    #{extract_description(spec)}
    
    ## Quick Start
    
    ```elixir
    defmodule MyApp.#{String.capitalize(name)} do
      use #{name |> String.capitalize()}.DSL
      
      #{generate_quickstart_example(spec)}
    end
    ```
    
    ## Features
    
    #{generate_feature_list(spec)}
    """
  end
  
  defp generate_entity_docs(entities) do
    Enum.map(entities, fn {name, spec} ->
      """
      ## #{String.capitalize(to_string(name))}
      
      #{extract_entity_description(spec)}
      
      ### Fields
      
      #{generate_field_table(extract_fields(spec))}
      
      ### Example
      
      ```elixir
      #{generate_entity_example(name, spec)}
      ```
      """
    end)
    |> Enum.join("\n\n")
  end
end
```

### 6. Language Server Protocol Integration

Automatic LSP support for generated DSLs:

```elixir
defmodule Spark.DSLFramework.LanguageServer do
  @moduledoc """
  Language Server Protocol integration for DSL frameworks.
  """
  
  def generate_lsp_server(domain_spec, entities, sections) do
    %{
      completion: generate_completion_handlers(entities, sections),
      hover: generate_hover_handlers(entities),
      diagnostics: generate_diagnostic_handlers(entities),
      formatting: generate_formatting_handlers(domain_spec),
      goto_definition: generate_goto_handlers(entities),
      references: generate_reference_handlers(entities)
    }
  end
  
  defp generate_completion_handlers(entities, sections) do
    """
    defmodule MyDSL.LanguageServer.Completion do
      def complete(document, position) do
        context = analyze_context(document, position)
        
        case context do
          #{Enum.map_join(sections, "\n", fn {section, _} ->
            "  {:section, :#{section}} -> complete_section_#{section}()"
          end)}
          #{Enum.map_join(entities, "\n", fn {entity, _} ->
            "  {:entity, :#{entity}} -> complete_entity_#{entity}()"
          end)}
          _ -> []
        end
      end
      
      #{Enum.map_join(entities, "\n\n", &generate_entity_completion/1)}
    end
    """
  end
end
```

## Framework Author Experience

### Before (Current State)
```elixir
# Framework authors must implement everything manually
defmodule MyFramework.DSL do
  use Spark.Dsl, default_extensions: [extensions: [MyFramework.Dsl]]
  
  # Hundreds of lines of boilerplate...
  # Entity definitions, transformers, validations, etc.
end
```

### After (With Meta-Framework)
```elixir
# Framework authors just describe their domain
defmodule MyFramework.DSL do
  use Spark.DSLFramework
  
  domain "my_framework" do
    entity :config do
      field :name, :string, required: true
      field :timeout, :integer, default: 5000
    end
    
    section :configuration do
      entities [:config]
    end
  end
  
  generate do
    phoenix_integration true
    documentation true
    language_server true
  end
end
```

**Result**: 95% less code, automatic tooling, comprehensive documentation.

## Implementation Strategy

### Phase 1: Meta-Framework Core
- [ ] DSL specification language
- [ ] Universal entity system
- [ ] Basic code generation
- [ ] Validation framework

### Phase 2: Integration Templates
- [ ] Phoenix integration templates
- [ ] LiveView component templates
- [ ] Ecto schema templates
- [ ] OTP application templates

### Phase 3: Developer Tooling
- [ ] Language server integration
- [ ] Documentation generation
- [ ] Testing framework
- [ ] Migration tools

### Phase 4: Ecosystem Integration
- [ ] Hex package generation
- [ ] CI/CD templates
- [ ] Docker integration
- [ ] Deployment tools

## Benefits for Framework Authors

1. **Rapid Development**: Build complete DSL frameworks in hours instead of months
2. **Consistent Quality**: Automatic testing, documentation, and validation
3. **Rich Tooling**: Language server, formatter, linter come for free
4. **Community**: Shared patterns and best practices across frameworks
5. **Maintenance**: Updates to meta-framework benefit all derived DSLs

## Benefits for DSL Users

1. **Consistent Experience**: All DSLs built with meta-framework feel familiar
2. **Rich IDE Support**: Completion, hover, diagnostics work everywhere
3. **Quality**: Comprehensive testing and validation built-in
4. **Documentation**: Always up-to-date and comprehensive
5. **Migration**: Tools for evolving DSL schemas over time

## Example Framework Implementations

### Web Framework DSL
```elixir
use Spark.DSLFramework

domain "web_framework" do
  entity :route do
    field :path, :string, required: true
    field :handler, :module, required: true
  end
  
  section :router do
    entities [:route]
  end
end
```

### State Machine DSL
```elixir
use Spark.DSLFramework

domain "state_machine" do
  entity :state do
    field :name, :atom, required: true
    field :entry_actions, {:array, :function}, default: []
  end
  
  entity :transition do
    field :from, :atom, required: true
    field :to, :atom, required: true
    field :event, :atom, required: true
  end
  
  section :machine do
    entities [:state, :transition]
  end
end
```

### GraphQL Schema DSL
```elixir
use Spark.DSLFramework

domain "graphql_schema" do
  entity :type do
    field :name, :string, required: true
    field :fields, {:array, :field}, default: []
  end
  
  entity :field do
    field :name, :string, required: true
    field :type, :string, required: true
    field :resolver, :function
  end
  
  section :schema do
    entities [:type, :field]
  end
end
```

## Conclusion: Democratizing DSL Creation

By abstracting the common patterns of DSL creation into a meta-framework, we can:

- **Lower the barrier** to creating domain-specific languages
- **Standardize best practices** across the ecosystem
- **Accelerate innovation** by reducing boilerplate
- **Improve quality** through shared tooling and validation
- **Build a community** around DSL design patterns

This approach transforms Spark from a specific DSL framework into a **platform for building DSL frameworks**, enabling the next generation of domain-specific tooling in the Elixir ecosystem.