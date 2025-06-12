# Test SparkDslEcosystem Components

Comprehensive autonomous testing suite for SparkDslEcosystem DSL components with validation, integration tests, and continuous quality assurance.

## Usage
```
/test-dsl [module_name] [test_type]
```

## Arguments
- `module_name` - Optional specific DSL module to test
- `test_type` - Optional: unit, integration, property, all (default: all)

## Example
```
/test-dsl MyLibrary.Validator unit
/test-dsl "" integration
/test-dsl
```

## Implementation

```elixir
# Parse arguments and determine test scope
[module_filter, test_type] = case args do
  [] -> ["", "all"]
  [module] -> [module, "all"] 
  [module, type] -> [module, type]
end

# Run appropriate test suites
case test_type do
  "unit" ->
    if module_filter != "" do
      System.cmd("mix", ["test", "--only", "unit", "test/**/#{module_filter |> String.downcase() |> String.replace(".", "_")}_test.exs"])
    else
      System.cmd("mix", ["test", "--only", "unit"])
    end
    
  "integration" ->
    System.cmd("mix", ["test", "--only", "integration"])
    
  "property" ->
    System.cmd("mix", ["test", "--only", "property"])
    
  "all" ->
    if module_filter != "" do
      filter_path = "test/**/#{module_filter |> String.downcase() |> String.replace(".", "_")}_test.exs"
      System.cmd("mix", ["test", filter_path])
    else
      # Run comprehensive test suite
      System.cmd("mix", ["test"])
      
      # Run additional quality checks
      IO.puts("\n=== Running Dialyzer ===")
      System.cmd("mix", ["dialyzer"])
      
      IO.puts("\n=== Running Credo ===") 
      System.cmd("mix", ["credo", "--strict"])
      
      IO.puts("\n=== Checking Documentation ===")
      System.cmd("mix", ["docs"])
    end
end

# Generate test coverage report
IO.puts("\n=== Generating Coverage Report ===")
System.cmd("mix", ["test", "--cover"])

# Validate DSL cheat sheets are up to date
IO.puts("\n=== Validating DSL Documentation ===")
System.cmd("mix", ["spark.cheat_sheets", "--check"])
```

## Test Categories

### Unit Tests
- Entity validation schemas
- Section configuration  
- Transformer logic
- Verifier validation rules
- Info module generation

### Integration Tests  
- Complete DSL compilation workflow
- Extension loading and configuration
- Cross-module DSL interactions
- Error handling and reporting

### Property Tests
- DSL schema validation with random inputs
- Transformer idempotency 
- Verifier consistency across valid/invalid DSLs

## Output
- Test results with coverage metrics
- Dialyzer type checking results  
- Credo code quality analysis
- Documentation generation status
- DSL cheat sheet validation