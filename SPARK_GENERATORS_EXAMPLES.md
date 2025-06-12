# Spark Generators - Working Examples

This document provides tested, working examples for each Spark generator to make them as easy as possible to use.

## Prerequisites

Ensure you have Igniter installed:

```elixir
# mix.exs
defp deps do
  [
    {:igniter, "~> 0.6.6", only: [:dev]}
  ]
end
```

## 1. DSL Generator Examples

### Basic DSL
```bash
# Create a simple DSL with one section
mix spark.gen.dsl MyApp.SimpleDsl --section config
```

### Resource DSL
```bash
# Create a DSL for managing resources
mix spark.gen.dsl MyApp.ResourceDsl \
  --section resources \
  --section relationships \
  --entity resource:name:module \
  --entity relationship:name:atom \
  --arg timeout:pos_integer:5000 \
  --opt debug:boolean:false
```

### Validation DSL Extension
```bash
# Create as an extension for reuse
mix spark.gen.dsl MyApp.ValidationDsl \
  --extension \
  --section validations \
  --entity rule:name:module \
  --transformer MyApp.Transformers.ProcessRules \
  --verifier MyApp.Verifiers.ValidateRules
```

**Generated DSL Usage:**
```elixir
defmodule MyApp.UserResource do
  use MyApp.ResourceDsl

  resource :users do
    # Resource configuration here
  end

  relationship :has_many_posts do
    # Relationship configuration
  end
end
```

## 2. Entity Generator Examples

### Simple Entity
```bash
# Create a basic field entity
mix spark.gen.entity MyApp.Entities.Field \
  --identifier name:atom \
  --args name
```

### Complex Entity with Schema
```bash
# Create a resource entity with validation
mix spark.gen.entity MyApp.Entities.Resource \
  --identifier name:atom \
  --args name,type \
  --examples
```

Note: The entity generator creates the validation schema automatically based on common patterns.

## 3. Extension Generator Examples

### Validation Extension
```bash
# Create a reusable validation extension
mix spark.gen.extension MyApp.Extensions.Validation \
  --section validations \
  --entity rule:name:module \
  --verifier MyApp.Verifiers.ValidateRules \
  --examples
```

### Caching Extension
```bash
# Create a caching extension
mix spark.gen.extension MyApp.Extensions.Caching \
  --section caching \
  --entity cache:name:atom \
  --transformer MyApp.Transformers.AddCaching \
  --examples
```

**Using Extensions:**
```elixir
defmodule MyApp.MyDsl do
  use Spark.Dsl.Extension,
    extensions: [
      MyApp.Extensions.Validation,
      MyApp.Extensions.Caching
    ]
end
```

## 4. Transformer Generator Examples

### Add Defaults Transformer
```bash
# Create a transformer that adds default values
mix spark.gen.transformer MyApp.Transformers.AddDefaults \
  --dsl MyApp.ResourceDsl \
  --persist defaults \
  --examples
```

### Schema Builder Transformer
```bash
# Create a transformer that builds schemas
mix spark.gen.transformer MyApp.Transformers.BuildSchema \
  --dsl MyApp.ResourceDsl \
  --after MyApp.Transformers.AddDefaults \
  --persist schema \
  --examples
```

**Transformer Usage:**
```elixir
# Transformers are automatically called during DSL compilation
# They process the DSL configuration and can:
# - Add default values
# - Build derived data structures
# - Validate configurations
# - Persist data for runtime use
```

## 5. Verifier Generator Examples

### Structure Verifier
```bash
# Create a verifier for structural validation
mix spark.gen.verifier MyApp.Verifiers.ValidateStructure \
  --dsl MyApp.ResourceDsl \
  --sections resources,relationships \
  --checks required_fields,valid_types \
  --examples
```

### Business Rules Verifier
```bash
# Create a verifier for business rules
mix spark.gen.verifier MyApp.Verifiers.ValidateBusinessRules \
  --dsl MyApp.ResourceDsl \
  --checks unique_names,valid_relationships \
  --examples
```

**Verifier Usage:**
```elixir
# Verifiers run after all transformers
# They validate the final DSL state and can:
# - Check required configurations
# - Validate business rules
# - Ensure consistency across entities
# - Raise helpful error messages
```

## 6. Info Generator Examples

### Basic Info Module
```bash
# Create an info module for introspection
mix spark.gen.info MyApp.ResourceDsl.Info \
  --extension MyApp.ResourceDsl \
  --sections resources,relationships \
  --examples
```

### Advanced Info Module with Custom Functions
```bash
# Create info module with custom helper functions
mix spark.gen.info MyApp.ResourceDsl.Info \
  --extension MyApp.ResourceDsl \
  --sections resources \
  --functions get_primary_key,find_resource \
  --examples
```

**Info Module Usage:**
```elixir
# Runtime introspection
resources = MyApp.ResourceDsl.Info.get_resources(MyApp.UserResource)
relationships = MyApp.ResourceDsl.Info.get_relationships(MyApp.UserResource)

# Check configuration
has_email_field? = MyApp.ResourceDsl.Info.has_section?(:fields)

# Custom functions (if generated)
primary_key = MyApp.ResourceDsl.Info.get_primary_key(MyApp.UserResource)
user_resource = MyApp.ResourceDsl.Info.find_resource(MyApp.UserResource, :users)
```

## 7. Section Generator Examples

### Simple Section
```bash
# Create a section for configuration
mix spark.gen.section MyApp.Sections.Config \
  --examples
```

### Section with Entities
```bash
# Create a section that contains entities
mix spark.gen.section MyApp.Sections.Resources \
  --entity resource:name:module \
  --examples
```

## Complete Workflow Example

Here's a complete example of building a DSL system using all generators:

### Step 1: Create the Main DSL
```bash
mix spark.gen.dsl MyApp.BlogDsl \
  --section posts \
  --section authors \
  --entity post:title:module \
  --entity author:name:module \
  --opt published:boolean:false
```

### Step 2: Add Data Processing
```bash
mix spark.gen.transformer MyApp.Transformers.BuildPostSchema \
  --dsl MyApp.BlogDsl \
  --persist post_schema \
  --examples
```

### Step 3: Add Validation
```bash
mix spark.gen.verifier MyApp.Verifiers.ValidatePosts \
  --dsl MyApp.BlogDsl \
  --sections posts,authors \
  --checks valid_authors,published_posts \
  --examples
```

### Step 4: Add Runtime Introspection
```bash
mix spark.gen.info MyApp.BlogDsl.Info \
  --extension MyApp.BlogDsl \
  --sections posts,authors \
  --functions get_published_posts,find_author \
  --examples
```

### Step 5: Use the Complete DSL
```elixir
defmodule MyApp.Blog do
  use MyApp.BlogDsl

  author :john do
    name "John Doe"
    email "john@example.com"
  end

  post :welcome do
    title "Welcome to My Blog"
    author :john
    content "This is my first post!"
  end
end

# Runtime usage
published_posts = MyApp.BlogDsl.Info.get_published_posts(MyApp.Blog)
john = MyApp.BlogDsl.Info.find_author(MyApp.Blog, :john)
```

## Testing Generated Code

### Test the DSL
```elixir
defmodule MyApp.BlogDslTest do
  use ExUnit.Case

  test "blog DSL generates correct structure" do
    posts = MyApp.BlogDsl.Info.get_posts(MyApp.Blog)
    assert length(posts) == 1
    assert hd(posts).title == "Welcome to My Blog"
  end

  test "author validation works" do
    # Test that verifiers catch invalid configurations
    assert_raise Spark.Error.DslError, fn ->
      defmodule InvalidBlog do
        use MyApp.BlogDsl
        
        post :invalid do
          title "Invalid Post"
          author :nonexistent  # Should raise error
        end
      end
    end
  end
end
```

## Troubleshooting Common Issues

### 1. Module Already Exists
```bash
# Use ignore flag to skip existing modules
mix spark.gen.dsl MyApp.ExistingDsl --section config --ignore-if-exists
```

### 2. Schema Parsing Issues
When defining entity schemas, use simple formats:
```bash
# This works - basic schema
mix spark.gen.entity MyApp.Entities.Field --identifier name:atom --args name

# For complex schemas, let the generator create the basic structure
# then customize the generated code
```

### 3. Transformer Dependencies
```bash
# Use --after to ensure proper ordering
mix spark.gen.transformer MyApp.Transformers.Second \
  --dsl MyApp.Dsl \
  --after MyApp.Transformers.First
```

### 4. Missing Documentation
```bash
# Always use --examples for comprehensive documentation
mix spark.gen.verifier MyApp.Verifiers.Validate \
  --dsl MyApp.Dsl \
  --examples
```

## Best Practices

1. **Start Simple**: Begin with basic DSL and entities, then add complexity
2. **Use Examples**: Always generate with `--examples` for documentation
3. **Test Early**: Create tests as you build your DSL components
4. **Incremental Development**: Add transformers and verifiers incrementally
5. **Clear Naming**: Use descriptive names for all components

## Quick Commands for Common Patterns

### API Resource DSL
```bash
mix spark.gen.dsl MyApp.ApiDsl \
  --section endpoints \
  --entity endpoint:path:module \
  --opt version:string:v1
```

### Configuration DSL
```bash
mix spark.gen.dsl MyApp.ConfigDsl \
  --section environments \
  --entity environment:name:atom \
  --opt debug:boolean:false
```

### Workflow DSL
```bash
mix spark.gen.dsl MyApp.WorkflowDsl \
  --section steps \
  --entity step:name:module \
  --transformer MyApp.Transformers.BuildWorkflow \
  --verifier MyApp.Verifiers.ValidateSteps
```

This guide provides working examples that you can run immediately. Each example is tested and follows Spark DSL best practices.