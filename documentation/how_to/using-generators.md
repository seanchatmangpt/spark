# Using Spark Generators

Spark generators provide a fast, reliable way to create DSL components without writing boilerplate code. This guide shows you how to use them effectively.

## Quick Start

### Installation

Add the required dependencies to your `mix.exs`:

```elixir
defp deps do
  [
    {:spark, "~> 2.2.65"},
    {:igniter, "~> 0.6.6", only: [:dev]}  # Required for generators
  ]
end
```

### Your First DSL in 30 Seconds

```bash
# Generate a complete DSL
mix spark.gen.dsl MyApp.BlogDsl \
  --section posts \
  --entity post:title:string \
  --examples

# Use it immediately
defmodule MyApp.MyBlog do
  use MyApp.BlogDsl

  post :welcome do
    title "Welcome to My Blog"
    content "Created with Spark generators!"
  end
end
```

## Available Generators

| Generator | Purpose | Example |
|-----------|---------|---------|
| `spark.gen.dsl` | Complete DSL with sections/entities | `mix spark.gen.dsl MyApp.Dsl --section users` |
| `spark.gen.extension` | Reusable DSL extension | `mix spark.gen.extension MyApp.Validation` |
| `spark.gen.entity` | DSL entities with validation | `mix spark.gen.entity MyApp.User --identifier name:atom` |
| `spark.gen.section` | DSL sections that contain entities | `mix spark.gen.section MyApp.Users --entity user:name:module` |
| `spark.gen.transformer` | Compile-time processor | `mix spark.gen.transformer MyApp.AddDefaults --dsl MyApp.Dsl` |
| `spark.gen.verifier` | DSL validator | `mix spark.gen.verifier MyApp.ValidateRules --dsl MyApp.Dsl` |
| `spark.gen.info` | Runtime introspection | `mix spark.gen.info MyApp.Dsl.Info --extension MyApp.Dsl` |

## Common Patterns

### Resource Management DSL

```bash
# Create a DSL for managing resources
mix spark.gen.dsl MyApp.ResourceDsl \
  --section resources \
  --section relationships \
  --entity resource:name:module \
  --entity relationship:name:atom \
  --examples

# Add processing logic
mix spark.gen.transformer MyApp.Transformers.BuildSchema \
  --dsl MyApp.ResourceDsl \
  --persist resource_schemas \
  --examples

# Add validation
mix spark.gen.verifier MyApp.Verifiers.ValidateResources \
  --dsl MyApp.ResourceDsl \
  --sections resources,relationships \
  --examples

# Add runtime introspection
mix spark.gen.info MyApp.ResourceDsl.Info \
  --extension MyApp.ResourceDsl \
  --sections resources,relationships \
  --examples
```

### Configuration DSL

```bash
# Create a configuration DSL
mix spark.gen.dsl MyApp.ConfigDsl \
  --section environments \
  --section services \
  --entity environment:name:atom \
  --entity service:name:module \
  --opt global_timeout:pos_integer:30000 \
  --examples
```

### API Definition DSL

```bash
# Create an API definition DSL
mix spark.gen.dsl MyApp.ApiDsl \
  --section routes \
  --section middleware \
  --entity route:path:string \
  --entity middleware:name:atom \
  --examples
```

## Generator Options

### Common Options (All Generators)

- `--examples` - Generate comprehensive documentation and usage examples
- `--ignore-if-exists` - Skip generation if the module already exists

### DSL Generator Options

- `--section` / `-s` - Add a section: `name` or `name:entity_module`
- `--entity` / `-e` - Add an entity: `name:identifier_type:target_type`
- `--arg` / `-a` - Add an argument: `name:type:default`
- `--opt` / `-o` - Add an option: `name:type:default`
- `--transformer` / `-t` - Add a transformer module
- `--verifier` / `-v` - Add a verifier module
- `--extension` - Create as an extension instead of standalone DSL
- `--fragments` - Enable DSL fragments support

### Entity Generator Options

- `--identifier` - Set the identifier field: `name:type`
- `--args` - Positional arguments (comma-separated)
- `--schema` - Schema fields: `name:type:required/optional`

### Transformer Generator Options

- `--dsl` / `-d` - Target DSL module
- `--before` / `-b` - Run before these transformers
- `--after` / `-a` - Run after these transformers
- `--persist` / `-p` - Keys to persist in DSL state

### Verifier Generator Options

- `--dsl` / `-d` - Target DSL module
- `--sections` / `-s` - Sections to validate
- `--checks` / `-c` - Validation checks to implement
- `--error-module` - Custom error module for validation failures

### Info Generator Options

- `--extension` / `-e` - DSL extension to introspect
- `--sections` / `-s` - Sections to include
- `--functions` / `-f` - Custom functions to generate

## Type Reference

### Valid Types for Entities/Args/Options

- **Basic Types**: `:atom`, `:string`, `:boolean`, `:integer`, `:pos_integer`
- **Structured Types**: `:module`, `:keyword_list`, `:map`
- **Collection Types**: `{:list, type}`, `{:one_of, [values]}`

### Identifier Types

- `:atom` - Atomic identifier (most common)
- `:string` - String identifier
- `:integer` - Numeric identifier

### Target Types

- `module` - Elixir module (most common)
- `atom` - Atomic value
- `string` - String value
- Custom struct module name

## Building a Complete DSL System

Follow this workflow to build a complete DSL system:

### 1. Start with the DSL Module

```bash
mix spark.gen.dsl MyApp.MyDsl \
  --section items \
  --entity item:name:module \
  --examples
```

### 2. Add Data Processing

```bash
mix spark.gen.transformer MyApp.Transformers.ProcessItems \
  --dsl MyApp.MyDsl \
  --persist processed_items \
  --examples
```

### 3. Add Validation

```bash
mix spark.gen.verifier MyApp.Verifiers.ValidateItems \
  --dsl MyApp.MyDsl \
  --sections items \
  --checks required_fields,valid_types \
  --examples
```

### 4. Add Runtime Introspection

```bash
mix spark.gen.info MyApp.MyDsl.Info \
  --extension MyApp.MyDsl \
  --sections items \
  --functions get_item,find_items \
  --examples
```

### 5. Update Your DSL to Use the Components

Edit your generated DSL file to include the transformer and verifier:

```elixir
defmodule MyApp.MyDsl do
  use Spark.Dsl.Extension,
    transformers: [MyApp.Transformers.ProcessItems],
    verifiers: [MyApp.Verifiers.ValidateItems]

  # ... rest of generated code
end
```

## Testing Generated DSLs

Create tests to verify your DSL works correctly:

```elixir
defmodule MyApp.MyDslTest do
  use ExUnit.Case

  defmodule TestModule do
    use MyApp.MyDsl

    item :example do
      name "Example Item"
      type :test
    end
  end

  test "DSL generates correct structure" do
    items = MyApp.MyDsl.Info.get_items(TestModule)
    assert length(items) == 1
    assert hd(items).name == "Example Item"
  end

  test "runtime introspection works" do
    item = MyApp.MyDsl.Info.get_item(TestModule, :example)
    assert item.name == "Example Item"
    assert item.type == :test
  end
end
```

## Best Practices

### 1. Use `--examples` Always

Always generate with the `--examples` flag to get comprehensive documentation:

```bash
mix spark.gen.dsl MyApp.MyDsl --section items --examples
```

### 2. Start Simple, Add Complexity

Begin with a basic DSL structure and add transformers/verifiers incrementally:

```bash
# Start simple
mix spark.gen.dsl MyApp.SimpleDsl --section config

# Add complexity later
mix spark.gen.transformer MyApp.Transformers.AddDefaults --dsl MyApp.SimpleDsl
```

### 3. Follow Naming Conventions

Use consistent naming patterns:

- DSL modules: `MyApp.MyDsl`
- Entities: `MyApp.Entities.EntityName`
- Transformers: `MyApp.Transformers.TransformerName`
- Verifiers: `MyApp.Verifiers.VerifierName`
- Info modules: `MyApp.MyDsl.Info`

### 4. Test Your DSLs

Always create tests for your generated DSLs to ensure they work correctly.

### 5. Document Your DSLs

Use the generated documentation as a starting point and customize it for your specific use case.

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "Module already exists" | Use `--ignore-if-exists` flag |
| "Igniter required" | Add `{:igniter, "~> 0.6.6", only: [:dev]}` to deps |
| "Invalid type" | Check the type reference above |
| "Transformer not found" | Ensure the referenced transformer module exists |
| Compilation errors | Check DSL syntax and ensure all dependencies are correct |

### Getting Help

```bash
# Get help for any generator
mix help spark.gen.dsl
mix help spark.gen.entity
mix help spark.gen.transformer
# etc.
```

## Next Steps

1. **Choose a generator** that matches your use case
2. **Start with a simple example** using `--examples`
3. **Test your generated DSL** to ensure it works
4. **Add complexity incrementally** with transformers and verifiers
5. **Document your specific use case** for your team

For more comprehensive examples and advanced patterns, see the [Generators Cookbook](generators-cookbook.html) and [Complete Examples](generators-examples.html).