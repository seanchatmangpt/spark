# Core Principles

> *"Simplicity is the ultimate sophistication."* - Leonardo da Vinci

The principles underlying Spark represent more than technical decisions—they embody a philosophy of software design that prioritizes human understanding, long-term maintainability, and the joy of creation. Understanding these principles deeply will guide you toward creating DSLs that are not just functional, but elegant.

## The Principle of Declarative Expression

### What Over How

The foundational principle of Spark is declarative expression: describing *what* you want rather than *how* to achieve it. This principle manifests at every level of DSL design.

**In Entity Definition**:
```elixir
# Declarative: What you want
@field %Spark.Dsl.Entity{
  name: :field,
  args: [:name, :type],
  schema: [
    name: [type: :atom, required: true],
    type: [type: {:one_of, [:string, :integer]}, required: true]
  ]
}

# Not: How to implement it
defmacro field(name, type) do
  quote do
    # Implementation details...
  end
end
```

**In DSL Usage**:
```elixir
# Declarative: What the API should be
api do
  resource :users do
    endpoint :list, method: :get
    endpoint :create, method: :post
  end
end

# Not: How to implement the API
def setup_api do
  Router.get("/users", UserController, :list)
  Router.post("/users", UserController, :create)
end
```

### Benefits of Declarative Design

**Clarity of Intent**: Declarative code reads like documentation of what the system should do.

**Separation of Concerns**: Domain logic remains separate from implementation details.

**Testability**: You can test what the DSL declares independently of how it's implemented.

**Optimization Opportunities**: The framework can optimize implementations without changing declarations.

**Evolution Path**: New features can enhance existing declarations without breaking changes.

## The Principle of Data-Driven Architecture

### Structure as Data

Spark's revolutionary insight is treating DSL structure as data rather than code. This principle has profound implications for how DSLs are designed, tested, and maintained.

**Traditional Code-Driven Approach**:
```elixir
# Structure embedded in code
defmacro resource(name, do: block) do
  quote do
    @resource_name unquote(name)
    unquote(block)
    # Structure lost in implementation
  end
end
```

**Spark Data-Driven Approach**:
```elixir
# Structure preserved as data
@resource %Spark.Dsl.Entity{
  name: :resource,
  args: [:name],
  entities: [@field, @action],
  # Structure queryable at runtime
}
```

### Implications of Data-Driven Design

**Runtime Introspection**: DSL structure can be queried and analyzed at runtime.

**Automatic Tooling**: Documentation, validation, and IDE support can be generated automatically.

**Composability**: Data structures compose more naturally than code structures.

**Debugging**: DSL behavior can be inspected and debugged independently of implementation.

**Testing**: You can test DSL structure separately from DSL behavior.

## The Principle of Composable Abstractions

### Building Blocks Over Monoliths

Spark embraces composability at every level. Rather than creating monolithic DSL structures, Spark encourages building small, composable pieces that combine to create rich expressions.

**Entity Composition**:
```elixir
# Small, focused entities
@field %Spark.Dsl.Entity{name: :field, /* ... */}
@validation %Spark.Dsl.Entity{name: :validation, /* ... */}
@action %Spark.Dsl.Entity{name: :action, /* ... */}

# Composed into larger structures
@resource %Spark.Dsl.Entity{
  name: :resource,
  entities: [@field, @validation, @action]
}
```

**Extension Composition**:
```elixir
# Multiple extensions can be combined
use MyDsl, extensions: [
  MyApp.Core,
  MyApp.Validation,
  MyApp.Authentication,
  MyApp.Caching
]
```

**Section Composition**:
```elixir
# Sections compose naturally
defmodule MyApi do
  use ApiDsl
  
  authentication do
    # Auth configuration
  end
  
  resources do
    # Resource definitions
  end
  
  middleware do
    # Middleware configuration
  end
end
```

### Benefits of Composability

**Incremental Complexity**: Start simple and add features as needed.

**Reusability**: Components can be reused across different DSLs.

**Maintainability**: Small pieces are easier to understand and modify.

**Testing**: Individual components can be tested in isolation.

**Community Development**: Different people can contribute different pieces.

## The Principle of Progressive Enhancement

### Layered Capabilities

Spark DSLs should follow the principle of progressive enhancement—they should work at a basic level immediately, with optional features that add capability without complexity for those who don't need them.

**Basic Level**:
```elixir
# Minimal viable DSL
resource :users do
  field :name, :string
  field :email, :string
end
```

**Enhanced Level**:
```elixir
# Additional features for those who need them
resource :users do
  field :name, :string do
    required true
    min_length 2
    max_length 50
  end
  
  field :email, :string do
    required true
    format :email
    unique true
  end
  
  validations do
    validate :email_format
  end
  
  lifecycle do
    after_create &send_welcome_email/1
  end
end
```

### Implementation of Progressive Enhancement

**Default Behaviors**: Sensible defaults that work for most cases.

**Optional Configuration**: Additional options for specialized needs.

**Graceful Degradation**: Features work even when optional components are missing.

**Additive Changes**: New features add capability without breaking existing usage.

## The Principle of Explicit Boundaries

### Clear Interfaces

Spark DSLs should have clear, explicit boundaries between different concerns. This principle prevents the common problem of DSLs that try to do everything and end up doing nothing well.

**Good Boundary Definition**:
```elixir
# Clear separation of concerns
api do
  # API-level concerns only
  base_url "/api/v1"
  version "1.0"
  
  authentication do
    # Auth concerns only
    type :bearer_token
    required true
  end
end

resource :users do
  # Resource concerns only
  field :name, :string
  field :email, :string
end
```

**Poor Boundary Definition**:
```elixir
# Mixed concerns
resource :users do
  field :name, :string
  field :email, :string
  
  # Database concerns mixed with domain logic
  table "users"
  primary_key :id
  
  # HTTP concerns mixed with domain logic
  endpoint :list, "/users"
  authentication :required
  
  # Validation mixed with everything else
  validates :email, format: :email
end
```

### Benefits of Explicit Boundaries

**Cognitive Load Reduction**: Each DSL section focuses on one type of concern.

**Maintainability**: Changes to one concern don't affect others.

**Reusability**: Well-bounded components can be reused in different contexts.

**Testing**: Each boundary can be tested independently.

**Team Development**: Different team members can work on different boundaries.

## The Principle of Convention Over Configuration

### Sensible Defaults

Spark embraces convention over configuration, providing sensible defaults that work for most cases while allowing customization when needed.

**Default Conventions**:
```elixir
# Info modules follow naming conventions
MyApp.MyDsl -> MyApp.MyDsl.Info

# Entity names map to function names
field :name -> MyDsl.Info.field(module, :name)

# Schema validation follows NimbleOptions patterns
required: true, type: :string

# Documentation follows ExDoc conventions
@doc "Field definition"
```

**Customization Points**:
```elixir
# Custom info module location
use Spark.InfoGenerator, 
  extension: MyDsl,
  module: MyApp.CustomInfo

# Custom function names
use Spark.InfoGenerator,
  functions: [
    fields: :get_all_fields,
    field: :find_field
  ]
```

### Benefits of Convention Over Configuration

**Reduced Cognitive Load**: Developers don't need to make decisions about common cases.

**Consistency**: Similar DSLs behave similarly across the ecosystem.

**Onboarding**: New developers can predict behavior based on conventions.

**Productivity**: Less time spent on configuration, more time on domain logic.

## The Principle of Fail-Fast Validation

### Compile-Time Safety

Spark embraces compile-time validation wherever possible. Errors should be caught as early in the development cycle as possible, with clear error messages that guide developers toward solutions.

**Compile-Time Validation**:
```elixir
# This fails at compile time with a clear error
resource :users do
  field :name, :invalid_type  # Error: Type must be one of [...]
  required_field :nonexistent # Error: Field :nonexistent not defined
end
```

**Clear Error Messages**:
```
** (Spark.Error.DslError) [MyApp.UserResource]
fields -> field -> type:
  Expected one of [:string, :integer, :boolean], got: :invalid_type
    lib/my_app/user_resource.ex:4
```

### Validation Strategy

**Schema Validation**: All entity options are validated against schemas.

**Cross-Reference Validation**: References between entities are verified.

**Business Rule Validation**: Domain-specific rules are checked by verifiers.

**Performance Validation**: Resource usage and complexity are monitored.

### Benefits of Fail-Fast Validation

**Developer Productivity**: Errors are caught immediately during development.

**System Reliability**: Invalid configurations never reach production.

**Debugging Efficiency**: Problems are identified at their source.

**Team Confidence**: Developers trust that compilation means correctness.

## The Principle of Extensible Architecture

### Open for Extension, Closed for Modification

Spark DSLs should be designed for extension without modification. This classic principle from object-oriented design applies beautifully to DSL architecture.

**Extension Points**:
```elixir
# Core DSL defines extension points
use Spark.Dsl.Extension,
  sections: [@resources],
  transformers: [GenerateDefaults],
  verifiers: [ValidateReferences]

# Users can add their own extensions
use MyDsl, extensions: [
  MyApp.Caching,      # Adds caching capabilities
  MyApp.Monitoring,   # Adds observability
  MyApp.Security      # Adds security rules
]
```

**Extension Implementation**:
```elixir
# Extensions are self-contained
defmodule MyApp.Caching do
  use Spark.Dsl.Extension,
    sections: [@cache_config],
    transformers: [AddCacheLayer]
end
```

### Benefits of Extensible Architecture

**Community Development**: Others can extend your DSL without modifying core code.

**Evolution**: New features can be added as extensions rather than core changes.

**Customization**: Organizations can create private extensions for their specific needs.

**Experimentation**: New ideas can be prototyped as extensions before core integration.

## Living the Principles

### In Design Decisions

Every design decision in a Spark DSL should be evaluated against these principles:

- Does this preserve declarative expression?
- Does this maintain data-driven architecture?
- Does this support composability?
- Does this enable progressive enhancement?
- Does this respect clear boundaries?
- Does this follow established conventions?
- Does this provide fail-fast validation?
- Does this enable future extension?

### In Implementation Choices

The principles guide implementation at every level:

**Entity Design**: Keep entities focused and composable.

**Schema Definition**: Provide validation that catches errors early.

**Transformer Logic**: Maintain the declarative nature of the DSL.

**Verifier Rules**: Enforce domain constraints clearly.

**Documentation**: Make the DSL self-explanatory.

### In Community Interaction

The principles extend beyond code to community interaction:

**Contribution Guidelines**: New features should align with core principles.

**Extension Development**: Community extensions should follow the same principles.

**Teaching and Learning**: The principles provide a framework for understanding DSL design.

**Code Review**: Use the principles as criteria for evaluating changes.

## The Emergent Way

When these principles are followed consistently, they create emergent properties that transcend their individual benefits:

**Intuitive Design**: DSLs that follow these principles feel natural to use.

**Sustainable Growth**: Systems can evolve without accumulating technical debt.

**Community Momentum**: Clear principles enable distributed development.

**Joyful Development**: Working with well-principled DSLs is inherently satisfying.

The principles of Spark are not rules to be followed mechanically, but guidelines that, when understood deeply and applied thoughtfully, lead to DSLs that are powerful, maintainable, and delightful to use.

*Principles are not destinations but compasses—they point the way toward better DSLs and better software.*