# Spark DSL Generators Complete Guide

This guide provides comprehensive documentation for all Spark DSL generators, making them as easy as possible to use.

## Overview

Spark provides a powerful set of code generators to quickly scaffold DSL components:

- **`spark.gen.dsl`** - Generate complete DSL modules with sections, entities, arguments, and options
- **`spark.gen.extension`** - Generate DSL extensions with transformers and verifiers  
- **`spark.gen.entity`** - Generate DSL entities with validation schemas
- **`spark.gen.section`** - Generate DSL sections that contain entities
- **`spark.gen.transformer`** - Generate DSL transformers for compile-time processing
- **`spark.gen.verifier`** - Generate DSL verifiers for validation
- **`spark.gen.info`** - Generate info modules for runtime DSL introspection

## Installation & Requirements

All generators require [Igniter](https://hexdocs.pm/igniter) to be installed in your project:

```elixir
# mix.exs
defp deps do
  [
    {:igniter, "~> 0.6.6", only: [:dev]}
  ]
end
```

## Quick Start Examples

### 1. Create a Complete DSL (spark.gen.dsl)

Generate a full DSL with sections, entities, and options:

```bash
mix spark.gen.dsl MyApp.UserDsl \
  --section users \
  --section roles \
  --entity user:name:module \
  --entity role:name:atom \
  --arg timeout:pos_integer:5000 \
  --opt debug:boolean:false
```

**Generated code:**
```elixir
defmodule MyApp.UserDsl do
  use Spark.Dsl

  @moduledoc """
  DSL for MyApp.UserDsl.
  """

  @section :users
  
  section :users do
    @moduledoc """
    Configuration for users.
    """
  end

  @section :roles
  
  section :roles do
    @moduledoc """
    Configuration for roles.
    """
  end

  @entity :user
  
  entity :user do
    @moduledoc """
    Represents a user in the DSL.
    """
    
    identifier :name
    target module
  end

  @entity :role
  
  entity :role do
    @moduledoc """
    Represents a role in the DSL.
    """
    
    identifier :name
    target atom
  end

  @arg :timeout
  
  arg :timeout do
    @moduledoc """
    The timeout argument.
    """
    
    type :pos_integer
    default 5000
  end

  @opt :debug
  
  opt :debug do
    @moduledoc """
    The debug option.
    """
    
    type :boolean
    default false
  end
end
```

### 2. Create a DSL Extension (spark.gen.extension)

Generate a reusable DSL extension:

```bash
mix spark.gen.extension MyApp.ValidationExtension \
  --section validations \
  --entity validator:name:module \
  --transformer MyApp.Transformers.AddValidation \
  --verifier MyApp.Verifiers.ValidateRequired \
  --examples
```

### 3. Create an Entity (spark.gen.entity)

Generate a DSL entity with validation:

```bash
mix spark.gen.entity MyApp.Entities.Field \
  --identifier name:atom \
  --args name,type \
  --schema name:atom:required,type:atom:required,default:any \
  --examples
```

### 4. Create a Transformer (spark.gen.transformer)

Generate a compile-time transformer:

```bash
mix spark.gen.transformer MyApp.Transformers.AddDefaults \
  --dsl MyApp.UserDsl \
  --after MyApp.Transformers.ValidateFields \
  --persist defaults \
  --examples
```

### 5. Create a Verifier (spark.gen.verifier)

Generate a DSL verifier:

```bash
mix spark.gen.verifier MyApp.Verifiers.ValidateUsers \
  --dsl MyApp.UserDsl \
  --sections users,roles \
  --checks name_required,valid_role \
  --examples
```

### 6. Create an Info Module (spark.gen.info)

Generate runtime introspection:

```bash
mix spark.gen.info MyApp.UserDsl.Info \
  --extension MyApp.UserDsl \
  --sections users,roles \
  --functions get_user,find_role \
  --examples
```

## Detailed Generator Reference

### spark.gen.dsl

**Purpose:** Generate complete DSL modules with all components.

**Usage:**
```bash
mix spark.gen.dsl MODULE_NAME [options]
```

**Options:**
- `--section` / `-s` - Section name or `name:entity_module`
- `--entity` / `-e` - Entity as `name:identifier_type:target_type`
- `--arg` / `-a` - Argument as `name:type:default`
- `--opt` / `-o` - Option as `name:type:default`
- `--singleton-entity` - Entity names that are singletons
- `--transformer` / `-t` - Transformers to add
- `--verifier` / `-v` - Verifiers to add
- `--extension` - Create as extension instead of standalone DSL
- `--fragments` - Enable DSL fragments support

**Example Patterns:**

1. **Simple DSL:**
```bash
mix spark.gen.dsl MyApp.SimpleDsl --section config
```

2. **Complex DSL with relationships:**
```bash
mix spark.gen.dsl MyApp.ResourceDsl \
  --section resources \
  --section relationships \
  --entity resource:name:module \
  --entity relationship:name:atom \
  --opt validate:boolean:true
```

3. **Extension DSL:**
```bash
mix spark.gen.dsl MyApp.ValidationDsl \
  --extension \
  --section validations \
  --transformer MyApp.Transformers.ValidateFields
```

### spark.gen.extension

**Purpose:** Generate reusable DSL extensions.

**Usage:**
```bash
mix spark.gen.extension MODULE_NAME [options]
```

**Options:**
- `--section` / `-s` - Sections to include
- `--entity` / `-e` - Entities to define
- `--transformer` / `-t` - Transformers to add
- `--verifier` / `-v` - Verifiers to add
- `--examples` - Generate usage examples

**Common Patterns:**

1. **Validation Extension:**
```bash
mix spark.gen.extension MyApp.Validations \
  --section validations \
  --entity rule:name:module \
  --verifier MyApp.Verifiers.ValidateRules
```

2. **Feature Extension:**
```bash
mix spark.gen.extension MyApp.Features \
  --section features \
  --entity feature:name:atom \
  --transformer MyApp.Transformers.EnableFeatures
```

### spark.gen.entity

**Purpose:** Generate DSL entities with validation schemas.

**Usage:**
```bash
mix spark.gen.entity MODULE_NAME [options]
```

**Options:**
- `--identifier` - Identifier field as `name:type`
- `--args` - Positional arguments (comma-separated)
- `--schema` - Schema fields as `name:type:required/optional`
- `--examples` - Generate usage examples

**Schema Types:**
- `:atom`, `:string`, `:boolean`, `:integer`, `:pos_integer`
- `:module`, `:keyword_list`, `:map`
- `{:list, type}`, `{:one_of, [values]}`

**Examples:**

1. **Simple Entity:**
```bash
mix spark.gen.entity MyApp.Entities.User \
  --identifier name:atom \
  --args name \
  --schema name:atom:required,email:string:optional
```

2. **Complex Entity:**
```bash
mix spark.gen.entity MyApp.Entities.Resource \
  --identifier name:atom \
  --args name,type \
  --schema name:atom:required,type:module:required,options:keyword_list:optional
```

### spark.gen.transformer

**Purpose:** Generate compile-time transformers for DSL processing.

**Usage:**
```bash
mix spark.gen.transformer MODULE_NAME [options]
```

**Options:**
- `--dsl` / `-d` - Target DSL module
- `--before` / `-b` - Run before these transformers
- `--after` / `-a` - Run after these transformers
- `--persist` / `-p` - Keys to persist in DSL state
- `--examples` - Generate usage examples

**Transformer Patterns:**

1. **Data Enhancement:**
```bash
mix spark.gen.transformer MyApp.Transformers.AddTimestamps \
  --dsl MyApp.ResourceDsl \
  --persist timestamps \
  --examples
```

2. **Validation:**
```bash
mix spark.gen.transformer MyApp.Transformers.ValidateRelationships \
  --dsl MyApp.ResourceDsl \
  --after MyApp.Transformers.BuildSchema
```

### spark.gen.verifier

**Purpose:** Generate DSL verifiers for validation.

**Usage:**
```bash
mix spark.gen.verifier MODULE_NAME [options]
```

**Options:**
- `--dsl` / `-d` - Target DSL module
- `--sections` / `-s` - Sections to validate
- `--checks` / `-c` - Validation checks to implement
- `--error-module` - Custom error module
- `--examples` - Generate usage examples

**Verification Patterns:**

1. **Structure Validation:**
```bash
mix spark.gen.verifier MyApp.Verifiers.ValidateStructure \
  --dsl MyApp.ResourceDsl \
  --sections resources,relationships \
  --checks required_fields,valid_types
```

2. **Business Rules:**
```bash
mix spark.gen.verifier MyApp.Verifiers.ValidateBusinessRules \
  --dsl MyApp.ResourceDsl \
  --checks unique_names,valid_relationships
```

### spark.gen.info

**Purpose:** Generate info modules for runtime DSL introspection.

**Usage:**
```bash
mix spark.gen.info MODULE_NAME [options]
```

**Options:**
- `--extension` / `-e` - DSL extension to introspect
- `--sections` / `-s` - Sections to include
- `--functions` / `-f` - Custom functions to generate
- `--examples` - Generate usage examples

**Info Module Patterns:**

1. **Basic Introspection:**
```bash
mix spark.gen.info MyApp.ResourceDsl.Info \
  --extension MyApp.ResourceDsl \
  --sections resources,relationships
```

2. **Custom Functions:**
```bash
mix spark.gen.info MyApp.ResourceDsl.Info \
  --extension MyApp.ResourceDsl \
  --sections resources \
  --functions find_resource,get_primary_key
```

## Common Workflows

### Building a Complete DSL System

1. **Start with the DSL module:**
```bash
mix spark.gen.dsl MyApp.ResourceDsl \
  --section resources \
  --entity resource:name:module
```

2. **Add transformers for processing:**
```bash
mix spark.gen.transformer MyApp.Transformers.BuildSchema \
  --dsl MyApp.ResourceDsl \
  --persist schema
```

3. **Add verifiers for validation:**
```bash
mix spark.gen.verifier MyApp.Verifiers.ValidateSchema \
  --dsl MyApp.ResourceDsl \
  --sections resources
```

4. **Create info module for introspection:**
```bash
mix spark.gen.info MyApp.ResourceDsl.Info \
  --extension MyApp.ResourceDsl \
  --sections resources
```

### Extending Existing DSLs

1. **Create extension:**
```bash
mix spark.gen.extension MyApp.CachingExtension \
  --section caching \
  --entity cache:name:module \
  --transformer MyApp.Transformers.AddCaching
```

2. **Add to existing DSL:**
```elixir
# In your existing DSL
use Spark.Dsl.Extension,
  extensions: [MyApp.CachingExtension]
```

## Best Practices

### Generator Usage
- **Use `--examples`** to generate comprehensive documentation
- **Start simple** and add complexity incrementally
- **Run tests** after generating to ensure integration
- **Use descriptive names** for modules and components

### DSL Design
- **Keep sections focused** - each should have a clear purpose
- **Design entities carefully** - they're the core building blocks
- **Add transformers sparingly** - only when needed for processing
- **Verify extensively** - catch configuration errors early

### Code Organization
```
lib/
├── my_app/
│   ├── dsl.ex                    # Main DSL module
│   ├── entities/                 # Entity definitions
│   ├── transformers/             # Compile-time processors
│   ├── verifiers/               # Validation logic
│   └── info.ex                  # Runtime introspection
```

## Integration Examples

### Using Generated DSL

```elixir
defmodule MyApp.UserResource do
  use MyApp.ResourceDsl

  resource :users do
    field :name, :string
    field :email, :string
    
    validate :name, required: true
    validate :email, format: ~r/@/
  end
end
```

### Runtime Introspection

```elixir
# Using generated info module
fields = MyApp.ResourceDsl.Info.get_fields(MyApp.UserResource)
validations = MyApp.ResourceDsl.Info.get_validations(MyApp.UserResource)

# Check configuration
has_email? = MyApp.ResourceDsl.Info.has_field?(MyApp.UserResource, :email)
```

### Testing Generated DSLs

```elixir
defmodule MyApp.ResourceDslTest do
  use ExUnit.Case
  
  test "generates correct schema" do
    fields = MyApp.ResourceDsl.Info.get_fields(MyApp.UserResource)
    assert length(fields) == 2
    assert Enum.any?(fields, & &1.name == :name)
  end
end
```

## Troubleshooting

### Common Issues

1. **Module already exists**
   - Use `--ignore-if-exists` to skip existing modules
   - Or delete the existing module first

2. **Invalid schema types**
   - Ensure types are valid Spark DSL types
   - Check the entity schema documentation

3. **Transformer dependencies**
   - Use `--before` and `--after` to control execution order
   - Check that referenced transformers exist

4. **Missing Igniter**
   - Install igniter: `{:igniter, "~> 0.6.6", only: [:dev]}`
   - Run `mix deps.get`

### Getting Help

- Run `mix help TASK_NAME` for detailed help
- Check the [Spark documentation](https://hexdocs.pm/spark)
- Review generated examples with `--examples`

## Advanced Usage

### Custom Types

Define custom types in your entities:

```bash
mix spark.gen.entity MyApp.Entities.Field \
  --schema type:custom_type \
  --examples
```

Then implement validation in your schema:

```elixir
# In the generated entity
schema: [
  type: [
    type: {:one_of, [:string, :integer, :boolean]},
    required: true
  ]
]
```

### Complex Transformers

Generate transformers that depend on multiple others:

```bash
mix spark.gen.transformer MyApp.Transformers.FinalizeSchema \
  --dsl MyApp.ResourceDsl \
  --after MyApp.Transformers.BuildFields,MyApp.Transformers.BuildRelations \
  --persist final_schema
```

### Extension Composition

Create extensions that build on each other:

```bash
# Base extension
mix spark.gen.extension MyApp.BaseExtension \
  --section base

# Feature extension that extends base
mix spark.gen.extension MyApp.FeatureExtension \
  --section features \
  --transformer MyApp.Transformers.ExtendBase
```

This guide provides everything needed to effectively use all Spark DSL generators. Start with the examples that match your use case and build from there!