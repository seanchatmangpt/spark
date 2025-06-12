# Spark Generators Examples

This guide provides working, tested examples for each Spark generator. Every example includes the exact commands to run and the expected results.

## Prerequisites

Ensure you have the required dependencies:

```elixir
# In mix.exs
defp deps do
  [
    {:spark, "~> 2.2.65"},
    {:igniter, "~> 0.6.6", only: [:dev]}
  ]
end
```

## DSL Generator Examples

### Basic DSL

```bash
# Create a simple DSL with one section
mix spark.gen.dsl MyApp.SimpleDsl --section config --examples
```

**Generated Usage:**
```elixir
defmodule MyApp.Config do
  use MyApp.SimpleDsl

  config do
    # Configuration here
  end
end
```

### Resource Management DSL

```bash
# Create a DSL for managing resources
mix spark.gen.dsl MyApp.ResourceDsl \
  --section resources \
  --section relationships \
  --entity resource:name:module \
  --entity relationship:name:atom \
  --arg timeout:pos_integer:5000 \
  --opt debug:boolean:false \
  --examples
```

**Generated Usage:**
```elixir
defmodule MyApp.UserResource do
  use MyApp.ResourceDsl

  resource :users do
    field :name, :string
    field :email, :string
  end

  relationship :has_many_posts do
    target :posts
    foreign_key :user_id
  end
end
```

### API Definition DSL

```bash
# Create a DSL for defining APIs
mix spark.gen.dsl MyApp.ApiDsl \
  --section routes \
  --section middleware \
  --entity route:path:string \
  --entity middleware:name:atom \
  --opt base_url:string:/api/v1 \
  --examples
```

**Generated Usage:**
```elixir
defmodule MyApp.API do
  use MyApp.ApiDsl

  middleware :cors do
    origins ["https://myapp.com"]
  end

  route "/users" do
    method :get
    controller MyApp.UserController
    action :index
  end
end
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

**Generated Usage:**
```elixir
defmodule MyApp.Config do
  use MyApp.ConfigDsl

  environment :production do
    database_url "postgresql://prod:5432/app"
    log_level :info
  end

  service :payment_processor do
    url "https://api.stripe.com"
    timeout 10_000
  end
end
```

## Extension Generator Examples

### Validation Extension

```bash
# Create a reusable validation extension
mix spark.gen.extension MyApp.ValidationExtension \
  --section validations \
  --entity rule:name:module \
  --verifier MyApp.Verifiers.ValidateRules \
  --examples
```

**Generated Usage:**
```elixir
defmodule MyApp.UserDsl do
  use Spark.Dsl.Extension,
    extensions: [MyApp.ValidationExtension]

  validations do
    rule :email_format do
      validator &valid_email?/1
      message "Must be a valid email"
    end
  end
end
```

### Caching Extension

```bash
# Create a caching extension
mix spark.gen.extension MyApp.CachingExtension \
  --section caching \
  --entity cache:name:atom \
  --transformer MyApp.Transformers.AddCaching \
  --examples
```

**Generated Usage:**
```elixir
defmodule MyApp.MyResource do
  use MyApp.ResourceDsl
  use MyApp.CachingExtension

  caching do
    cache :user_data do
      ttl :timer.minutes(5)
      key &generate_cache_key/1
    end
  end
end
```

## Entity Generator Examples

### User Entity

```bash
# Create a user entity
mix spark.gen.entity MyApp.Entities.User \
  --identifier email:string \
  --args email,name \
  --examples
```

**Generated Structure:**
```elixir
defmodule MyApp.Entities.User do
  defstruct [:email, :name, :created_at, :updated_at]

  # Validation schema and helper functions generated
end
```

### Field Entity

```bash
# Create a field entity with detailed schema
mix spark.gen.entity MyApp.Entities.Field \
  --identifier name:atom \
  --args name,type \
  --examples
```

**Generated Usage in DSL:**
```elixir
field :email do
  type :string
  required true
  unique true
end
```

## Transformer Generator Examples

### Add Defaults Transformer

```bash
# Create a transformer that adds default values
mix spark.gen.transformer MyApp.Transformers.AddDefaults \
  --dsl MyApp.ResourceDsl \
  --persist defaults \
  --examples
```

**What it does:**
- Runs at compile time
- Adds default timestamps to resources
- Persists default values for runtime access

### Build Schema Transformer

```bash
# Create a transformer that builds schemas
mix spark.gen.transformer MyApp.Transformers.BuildSchema \
  --dsl MyApp.ResourceDsl \
  --after MyApp.Transformers.AddDefaults \
  --persist resource_schemas \
  --examples
```

**What it does:**
- Runs after AddDefaults transformer
- Builds database schemas from DSL definitions
- Validates field types and relationships

## Verifier Generator Examples

### Structure Verifier

```bash
# Create a verifier for structural validation
mix spark.gen.verifier MyApp.Verifiers.ValidateStructure \
  --dsl MyApp.ResourceDsl \
  --sections resources,relationships \
  --checks required_fields,valid_types \
  --examples
```

**What it validates:**
- Required fields are present
- Field types are valid
- Relationships point to existing resources

### Business Rules Verifier

```bash
# Create a verifier for business rules
mix spark.gen.verifier MyApp.Verifiers.ValidateBusinessRules \
  --dsl MyApp.ResourceDsl \
  --checks unique_names,valid_relationships \
  --examples
```

**What it validates:**
- Resource names are unique
- Relationships are bidirectional
- Business constraints are met

## Info Generator Examples

### Basic Info Module

```bash
# Create an info module for introspection
mix spark.gen.info MyApp.ResourceDsl.Info \
  --extension MyApp.ResourceDsl \
  --sections resources,relationships \
  --examples
```

**Generated Functions:**
```elixir
# Get all resources
resources = MyApp.ResourceDsl.Info.get_resources(MyModule)

# Get specific resource
user_resource = MyApp.ResourceDsl.Info.get_resource(MyModule, :users)

# Get relationships
relationships = MyApp.ResourceDsl.Info.get_relationships(MyModule)
```

### Advanced Info Module

```bash
# Create info module with custom helper functions
mix spark.gen.info MyApp.ResourceDsl.Info \
  --extension MyApp.ResourceDsl \
  --sections resources \
  --functions get_primary_key,find_resource \
  --examples
```

**Generated Custom Functions:**
```elixir
# Custom functions
primary_key = MyApp.ResourceDsl.Info.get_primary_key(MyModule)
resource = MyApp.ResourceDsl.Info.find_resource(MyModule, :users)
```

## Section Generator Examples

### Configuration Section

```bash
# Create a section for configuration
mix spark.gen.section MyApp.Sections.Config \
  --examples
```

### Resources Section

```bash
# Create a section that contains entities
mix spark.gen.section MyApp.Sections.Resources \
  --entity resource:name:module \
  --examples
```

## Complete Workflow Examples

### Building a Blog DSL System

```bash
# Step 1: Create the main DSL
mix spark.gen.dsl MyApp.BlogDsl \
  --section posts \
  --section authors \
  --entity post:title:string \
  --entity author:name:string \
  --examples

# Step 2: Add data processing
mix spark.gen.transformer MyApp.Transformers.ProcessPosts \
  --dsl MyApp.BlogDsl \
  --persist processed_posts \
  --examples

# Step 3: Add validation
mix spark.gen.verifier MyApp.Verifiers.ValidateBlog \
  --dsl MyApp.BlogDsl \
  --sections posts,authors \
  --checks required_title,valid_author \
  --examples

# Step 4: Add runtime introspection
mix spark.gen.info MyApp.BlogDsl.Info \
  --extension MyApp.BlogDsl \
  --sections posts,authors \
  --functions get_published_posts,find_author \
  --examples
```

**Complete Usage:**
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
    published true
  end
end

# Runtime usage
published_posts = MyApp.BlogDsl.Info.get_published_posts(MyApp.Blog)
john = MyApp.BlogDsl.Info.find_author(MyApp.Blog, :john)
```

### Building an E-commerce DSL

```bash
# Create the main e-commerce DSL
mix spark.gen.dsl MyApp.EcommerceDsl \
  --section products \
  --section categories \
  --section orders \
  --entity product:sku:string \
  --entity category:name:atom \
  --entity order:number:string \
  --examples

# Add pricing transformer
mix spark.gen.transformer MyApp.Transformers.CalculatePricing \
  --dsl MyApp.EcommerceDsl \
  --persist pricing_data \
  --examples

# Add inventory verifier
mix spark.gen.verifier MyApp.Verifiers.ValidateInventory \
  --dsl MyApp.EcommerceDsl \
  --sections products,orders \
  --checks stock_availability,valid_pricing \
  --examples
```

**Usage:**
```elixir
defmodule MyApp.Store do
  use MyApp.EcommerceDsl

  category :electronics do
    name "Electronics"
    description "Electronic devices and accessories"
  end

  product "LAPTOP-123" do
    name "Gaming Laptop"
    category :electronics
    price 1299.99
    stock 50
  end

  order "ORD-001" do
    customer_id "CUST-123"
    items [
      %{sku: "LAPTOP-123", quantity: 1, price: 1299.99}
    ]
    total 1299.99
  end
end
```

## Testing Generated DSLs

### Basic Test Pattern

```elixir
defmodule MyApp.BlogDslTest do
  use ExUnit.Case

  defmodule TestBlog do
    use MyApp.BlogDsl

    author :test_author do
      name "Test Author"
      email "test@example.com"
    end

    post :test_post do
      title "Test Post"
      author :test_author
      content "Test content"
    end
  end

  test "DSL generates correct structure" do
    posts = MyApp.BlogDsl.Info.get_posts(TestBlog)
    assert length(posts) == 1
    assert hd(posts).title == "Test Post"
  end

  test "runtime introspection works" do
    author = MyApp.BlogDsl.Info.find_author(TestBlog, :test_author)
    assert author.name == "Test Author"
    assert author.email == "test@example.com"
  end
end
```

### Integration Test Pattern

```elixir
defmodule MyApp.DSLIntegrationTest do
  use ExUnit.Case

  test "complete DSL compilation workflow" do
    # Test that DSL compiles without errors
    assert Code.ensure_loaded?(MyApp.BlogDsl)
    
    # Test that generated functions work
    assert function_exported?(MyApp.BlogDsl.Info, :get_posts, 1)
    assert function_exported?(MyApp.BlogDsl.Info, :find_author, 2)
    
    # Test actual usage
    posts = MyApp.BlogDsl.Info.get_posts(TestBlog)
    assert is_list(posts)
  end
end
```

## Common Usage Patterns

### Progressive Enhancement

```elixir
# Start simple
resource :users

# Add more configuration
resource :users do
  field :name, :string
  field :email, :string
end

# Add advanced features via transformers
resource :users do
  field :name, :string
  field :email, :string
  timestamps true
  soft_delete true
  auditing enabled: true
end
```

### Conditional Configuration

```elixir
# Environment-aware configuration
config do
  if Mix.env() == :test do
    database :memory
    external_apis :mock
  else
    database :postgres
    external_apis :live
  end
end
```

### DSL Composition

```elixir
defmodule MyApp.BaseResource do
  use MyApp.ResourceDsl

  # Common configuration
  resource do
    timestamps true
    soft_delete true
  end
end

defmodule MyApp.UserResource do
  use MyApp.ResourceDsl
  # Inherits from BaseResource configuration
  
  resource do
    field :email, :string, unique: true
    field :name, :string
  end
end
```

## Best Practices from Examples

### 1. Use `--examples` Always

```bash
# Good - includes comprehensive documentation
mix spark.gen.dsl MyApp.MyDsl --section items --examples

# Less helpful - minimal documentation
mix spark.gen.dsl MyApp.MyDsl --section items
```

### 2. Start Simple, Add Complexity

```bash
# Start with basic structure
mix spark.gen.dsl MyApp.SimpleDsl --section config

# Add processing later
mix spark.gen.transformer MyApp.Transformers.ProcessConfig --dsl MyApp.SimpleDsl

# Add validation when needed
mix spark.gen.verifier MyApp.Verifiers.ValidateConfig --dsl MyApp.SimpleDsl
```

### 3. Test Early and Often

Create tests immediately after generating DSL components to catch issues early.

### 4. Use Consistent Naming

- DSL modules: `MyApp.FeatureDsl`
- Info modules: `MyApp.FeatureDsl.Info`
- Transformers: `MyApp.Transformers.TransformerName`
- Verifiers: `MyApp.Verifiers.VerifierName`

### 5. Document Your Specific Use Cases

Use the generated documentation as a foundation and add your specific business context.

## Next Steps

1. **Pick an example** that's close to your use case
2. **Run the exact commands** to see how it works
3. **Modify incrementally** to fit your specific needs
4. **Add tests** to ensure your customizations work
5. **Document your patterns** for your team

For complete, step-by-step recipes, see the [Generators Cookbook](generators-cookbook.html).
For detailed option reference, see [Using Generators](../how_to/using-generators.html).