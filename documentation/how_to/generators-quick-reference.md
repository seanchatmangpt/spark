# Generators Quick Reference

Quick lookup reference for all Spark generators with commands, options, and examples.

## All Generators Overview

| Generator | Purpose | Quick Example |
|-----------|---------|---------------|
| `spark.gen.dsl` | Complete DSL with sections/entities | `mix spark.gen.dsl MyApp.Dsl --section users` |
| `spark.gen.extension` | Reusable DSL extension | `mix spark.gen.extension MyApp.Ext --section config` |
| `spark.gen.entity` | DSL entity with validation | `mix spark.gen.entity MyApp.User --identifier name:atom` |
| `spark.gen.section` | DSL section container | `mix spark.gen.section MyApp.Users --entity user:name:module` |
| `spark.gen.transformer` | Compile-time processor | `mix spark.gen.transformer MyApp.AddDefaults --dsl MyApp.Dsl` |
| `spark.gen.verifier` | DSL validator | `mix spark.gen.verifier MyApp.Validate --dsl MyApp.Dsl` |
| `spark.gen.info` | Runtime introspection | `mix spark.gen.info MyApp.Info --extension MyApp.Dsl` |

## Common Commands

### Create Simple DSL
```bash
mix spark.gen.dsl MyApp.SimpleDsl --section config --opt debug:boolean:false
```

### Create Resource DSL
```bash
mix spark.gen.dsl MyApp.ResourceDsl \
  --section resources \
  --entity resource:name:module \
  --arg timeout:pos_integer:5000
```

### Create Extension
```bash
mix spark.gen.extension MyApp.ValidationExt \
  --section validations \
  --entity rule:name:atom \
  --verifier MyApp.Validators.Required
```

### Create Entity
```bash
mix spark.gen.entity MyApp.Entities.Field \
  --identifier name:atom \
  --args name,type \
  --examples
```

### Create Transformer
```bash
mix spark.gen.transformer MyApp.Transformers.AddDefaults \
  --dsl MyApp.ResourceDsl \
  --persist defaults
```

### Create Verifier
```bash
mix spark.gen.verifier MyApp.Verifiers.ValidateFields \
  --dsl MyApp.ResourceDsl \
  --sections resources \
  --checks required_fields,valid_types
```

### Create Info Module
```bash
mix spark.gen.info MyApp.ResourceDsl.Info \
  --extension MyApp.ResourceDsl \
  --sections resources \
  --functions get_resource,find_field
```

## Option Quick Reference

### Common Options (All Generators)
- `--examples` - Generate usage examples and documentation
- `--ignore-if-exists` - Skip if module already exists

### DSL Generator Options
- `--section` / `-s` - Add section: `name` or `name:entity_module`
- `--entity` / `-e` - Add entity: `name:identifier_type:target_type`
- `--arg` / `-a` - Add argument: `name:type:default`
- `--opt` / `-o` - Add option: `name:type:default`
- `--transformer` / `-t` - Add transformer module
- `--verifier` / `-v` - Add verifier module
- `--extension` - Create as extension instead of standalone DSL
- `--fragments` - Enable DSL fragments support

### Entity Generator Options
- `--identifier` - Set identifier: `name:type`
- `--args` - Positional arguments (comma-separated)
- `--examples` - Generate usage examples

### Transformer Generator Options
- `--dsl` / `-d` - Target DSL module
- `--before` / `-b` - Run before these transformers
- `--after` / `-a` - Run after these transformers
- `--persist` / `-p` - Keys to persist in DSL state

### Verifier Generator Options
- `--dsl` / `-d` - Target DSL module
- `--sections` / `-s` - Sections to validate
- `--checks` / `-c` - Validation checks to implement
- `--error-module` - Custom error module

### Info Generator Options
- `--extension` / `-e` - DSL extension to introspect
- `--sections` / `-s` - Sections to include
- `--functions` / `-f` - Custom functions to generate

## Type Reference

### Valid Types for Entities/Args/Options
- **Basic:** `:atom`, `:string`, `:boolean`, `:integer`, `:pos_integer`
- **Structured:** `:module`, `:keyword_list`, `:map`
- **Collections:** `{:list, type}`, `{:one_of, [values]}`

### Identifier Types
- `:atom` - Atomic identifier (most common)
- `:string` - String identifier
- `:integer` - Numeric identifier

### Target Types
- `module` - Elixir module
- `atom` - Atomic value
- `string` - String value
- Custom struct module name

## Quick Workflow

### 1. Start with DSL
```bash
mix spark.gen.dsl MyApp.MyDsl --section items --entity item:name:module
```

### 2. Add Processing
```bash
mix spark.gen.transformer MyApp.Transformers.ProcessItems \
  --dsl MyApp.MyDsl --persist processed_items
```

### 3. Add Validation
```bash
mix spark.gen.verifier MyApp.Verifiers.ValidateItems \
  --dsl MyApp.MyDsl --sections items
```

### 4. Add Introspection
```bash
mix spark.gen.info MyApp.MyDsl.Info \
  --extension MyApp.MyDsl --sections items
```

## Usage Patterns

### Use Generated DSL
```elixir
defmodule MyApp.MyResource do
  use MyApp.MyDsl
  
  item :user do
    # configuration here
  end
end
```

### Introspect at Runtime
```elixir
items = MyApp.MyDsl.Info.get_items(MyApp.MyResource)
specific_item = MyApp.MyDsl.Info.get_item(MyApp.MyResource, :user)
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Module already exists" | Use `--ignore-if-exists` or delete existing |
| "Invalid type" | Check type reference above |
| "Igniter required" | Add `{:igniter, "~> 0.6.6", only: [:dev]}` |
| "Transformer not found" | Ensure referenced transformer exists |

## Help Commands

```bash
mix help spark.gen.dsl         # DSL generator help
mix help spark.gen.extension   # Extension generator help
mix help spark.gen.entity      # Entity generator help
mix help spark.gen.transformer # Transformer generator help
mix help spark.gen.verifier    # Verifier generator help
mix help spark.gen.info        # Info generator help
```

## Quick Examples by Use Case

### Configuration Management
```bash
mix spark.gen.dsl MyApp.ConfigDsl \
  --section environments \
  --entity environment:name:atom \
  --opt timeout:pos_integer:5000
```

### API Definition
```bash
mix spark.gen.dsl MyApp.ApiDsl \
  --section routes \
  --entity route:path:string \
  --opt base_url:string:/api/v1
```

### Resource Management
```bash
mix spark.gen.dsl MyApp.ResourceDsl \
  --section resources \
  --entity resource:name:module \
  --transformer MyApp.Transformers.BuildSchema
```

### Form Validation
```bash
mix spark.gen.dsl MyApp.FormDsl \
  --section forms \
  --entity field:name:atom \
  --verifier MyApp.Verifiers.ValidateForm
```

### Authentication
```bash
mix spark.gen.dsl MyApp.AuthDsl \
  --section strategies \
  --entity strategy:name:module \
  --opt session_timeout:pos_integer:3600
```

For complete examples and detailed recipes, see:
- [Generators Examples](../tutorials/generators-examples.html)
- [Generators Cookbook](../tutorials/generators-cookbook.html)