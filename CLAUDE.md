# Spark DSL Framework Project

## Overview
Spark is a powerful Elixir framework for building Domain Specific Languages (DSLs) with built-in extensibility, autocomplete, documentation generation, and tooling support. It powers all DSLs in the Ash Framework ecosystem.

## Key Features
- **Extensible DSLs**: Anyone can write extensions for your DSL
- **Developer Experience**: Autocomplete and inline documentation via elixir_sense plugin
- **Documentation Generation**: Automatic DSL documentation tools
- **Code Formatting**: Mix task for `locals_without_parens` configuration

## Project Structure
```
lib/
├── spark/
│   ├── dsl/
│   │   ├── extension.ex          # Core DSL extension framework
│   │   ├── section.ex           # DSL section definitions
│   │   ├── entity.ex            # DSL entity structures
│   │   ├── transformer.ex       # Compile-time transformations
│   │   └── verifier.ex          # DSL validation logic
│   ├── info_generator.ex        # Automatic info module generation
│   └── error/
│       └── dsl_error.ex         # DSL-specific error handling
test/
├── spark/
│   └── dsl/                     # DSL framework tests
documentation/
└── tutorials/
    └── get-started-with-spark.md # Complete tutorial
```

## Development Patterns

### DSL Extension Structure
```elixir
defmodule MyLibrary.Validator.Dsl do
  # 1. Define entity structs
  defmodule Field do
    defstruct [:name, :type, :transform, :check]
  end

  # 2. Define entities with validation schemas
  @field %Spark.Dsl.Entity{
    name: :field,
    args: [:name, :type],
    target: Field,
    schema: [
      name: [type: :atom, required: true],
      type: [type: {:one_of, [:integer, :string]}, required: true]
    ]
  }

  # 3. Define sections containing entities
  @fields %Spark.Dsl.Section{
    name: :fields,
    entities: [@field]
  }

  # 4. Create extension with transformers/verifiers
  use Spark.Dsl.Extension, 
    sections: [@fields],
    transformers: [MyLibrary.Transformers.AddId],
    verifiers: [MyLibrary.Verifiers.VerifyRequired]
end
```

### Info Module Pattern
```elixir
defmodule MyLibrary.Validator.Info do
  use Spark.InfoGenerator, 
    extension: MyLibrary.Validator.Dsl, 
    sections: [:fields]
end
```

### DSL Usage Pattern
```elixir
defmodule MyLibrary.Validator do
  use Spark.Dsl, default_extensions: [
    extensions: [MyLibrary.Validator.Dsl]
  ]
end
```

## Common Commands

### Development
- `mix test` - Run test suite
- `mix docs` - Generate documentation
- `mix format` - Format code
- `mix dialyzer` - Type checking
- `mix credo` - Code analysis

### DSL Tools
- `mix spark.formatter` - Add DSL keywords to `locals_without_parens`
- `mix spark.cheat_sheets` - Generate DSL cheat sheets

## Code Quality Standards
- Follow Elixir formatting conventions
- Use clear, descriptive module and function names
- Include comprehensive documentation with examples
- Write tests for all transformers and verifiers
- Validate DSL schemas thoroughly

## Dependencies
- Current version: `{:spark, "~> 2.2.65"}`
- Elixir: >= 1.11
- Required for Ash Framework ecosystem

## Testing Approach
- Unit tests for all DSL components
- Integration tests for complete DSL workflows
- Property-based testing for transformers
- Validation testing for verifiers

## Documentation Standards
- Module docs with usage examples
- Function docs with parameter descriptions
- Comprehensive tutorial coverage
- DSL syntax examples with expected outputs

## Performance Considerations
- Transformers run at compile time
- Verifiers validate final DSL structure
- Info modules provide runtime introspection
- Minimize runtime overhead through compile-time processing