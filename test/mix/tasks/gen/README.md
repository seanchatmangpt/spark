# Spark Generator Test Suite

This directory contains comprehensive test suites for all Spark Mix task generators.

## Test Files Overview

### Core Generator Tests

- **`dsl_test.exs`** - Tests for `mix spark.gen.dsl`
  - All option combinations (sections, entities, args, opts, transformers, verifiers)
  - Extension vs standalone DSL generation
  - Fragment support
  - Complex multi-component DSL creation
  - Error handling and validation

- **`entity_test.exs`** - Tests for `mix spark.gen.entity`
  - Schema and argument parsing
  - Validation generation
  - Type specifications
  - Example documentation
  - Spark.Dsl.Entity behavior compliance

- **`verifier_test.exs`** - Tests for `mix spark.gen.verifier`
  - Section-specific validation
  - Custom check generation
  - Error handling utilities
  - DSL introspection helpers
  - Example usage documentation

- **`section_test.exs`** - Tests for `mix spark.gen.section`
  - Entity integration
  - Option parsing and validation
  - Helper function generation
  - Example documentation
  - Spark.Dsl.Section compliance

### Integration and Quality Tests

- **`integration_test.exs`** - End-to-end workflow tests
  - Generator chaining and composition
  - Complete DSL ecosystem creation
  - Cross-generator compatibility
  - Performance with large configurations

- **`error_handling_test.exs`** - Comprehensive error scenarios
  - Input validation and boundary conditions
  - Malformed configuration handling
  - Memory and performance edge cases
  - Cross-generator error scenarios

### Utility Tests

- **`../formatter_test.exs`** - Tests for `mix spark.formatter`
  - Extension parsing
  - Entity builder extraction
  - `.formatter.exs` file handling
  - Check mode validation

## Test Support Files

- **`../support/generator_test_helpers.ex`** - Shared utilities
  - Mock Igniter structs
  - Code validation helpers
  - Fixture generation
  - Error assertion utilities

- **`../support/generator_test_case.ex`** - Base test case
  - Common setup and patterns
  - Shared assertion helpers
  - Test organization utilities

## Test Coverage Areas

### Functional Testing
- ✅ All generator options and combinations
- ✅ Code generation accuracy
- ✅ DSL compliance and structure
- ✅ Documentation generation
- ✅ Example creation

### Integration Testing
- ✅ Generator chaining workflows
- ✅ Module reference resolution
- ✅ Complete ecosystem creation
- ✅ Cross-component compatibility

### Error Handling
- ✅ Input validation
- ✅ Malformed configuration handling
- ✅ Boundary condition testing
- ✅ Error message clarity
- ✅ Graceful degradation

### Edge Cases
- ✅ Unicode and special characters
- ✅ Very large configurations
- ✅ Performance boundaries
- ✅ Memory usage patterns
- ✅ Circular dependencies

### Quality Assurance
- ✅ Generated code compilation
- ✅ Documentation completeness
- ✅ Type specification accuracy
- ✅ Function behavior compliance

## Running the Tests

### All Generator Tests
```bash
mix test test/mix/tasks/gen/
```

### Specific Generator
```bash
mix test test/mix/tasks/gen/dsl_test.exs
mix test test/mix/tasks/gen/entity_test.exs
mix test test/mix/tasks/gen/verifier_test.exs
mix test test/mix/tasks/gen/section_test.exs
```

### Integration and Error Tests
```bash
mix test test/mix/tasks/gen/integration_test.exs
mix test test/mix/tasks/gen/error_handling_test.exs
```

### Formatter Tests
```bash
mix test test/mix/tasks/formatter_test.exs
```

## Test Patterns and Conventions

### Mock Usage
Tests use `mock_igniter/2` to create test igniter structs without requiring actual file system operations.

### Assertion Patterns
- `assert_module_created/3` - Validates module creation with expected patterns
- `assert_code_compiles/1` - Ensures generated code is syntactically valid
- `assert_code_contains/2` - Checks for specific patterns in generated code

### Test Organization
- **Describe blocks** group related functionality
- **Comprehensive coverage** of all options and combinations
- **Edge case testing** for boundary conditions
- **Error scenario validation** for robustness

### Fixtures and Data
- Sample entity configurations
- Section definitions with various complexities
- Argument and option combinations
- Transformer and verifier references

## Test Dependencies

### Required
- **ExUnit** - Test framework
- **Igniter** - Required for all generators (tests include fallbacks)

### Optional
- **Sourceror** - Required for formatter tests
- **Compiled DSL modules** - For integration testing

## Maintenance Notes

### Adding New Generator Tests
1. Create new test file following naming convention
2. Use `Spark.Test.GeneratorTestCase` as base
3. Include comprehensive option coverage
4. Add integration scenarios to `integration_test.exs`
5. Add error cases to `error_handling_test.exs`

### Test Data Updates
- Update fixtures in `generator_test_helpers.ex` when adding new options
- Maintain example consistency across all tests
- Update integration scenarios for new features

### Performance Considerations
- Large configuration tests are limited to prevent slow test runs
- Memory-intensive tests use controlled data sizes
- Integration tests focus on representative scenarios

## Known Limitations

### Mock Limitations
- File system operations are mocked, not executed
- Actual code compilation is not tested (could be added)
- Igniter task composition is simulated

### Dependency Requirements
- Some tests require Igniter to be available
- Formatter tests need Sourceror dependency
- Integration tests need compiled DSL modules

### Performance Testing
- Memory usage is not precisely measured
- Compilation time is not tested
- Large-scale scenarios are representative, not exhaustive

## Future Enhancements

### Potential Additions
- **Actual file generation testing** with temporary directories
- **Generated code compilation and execution** verification
- **Performance benchmarking** for large configurations
- **Visual diff testing** for generated code changes
- **Property-based testing** for input validation

### Integration Improvements
- **Real DSL module compilation** in test environment
- **End-to-end workflow testing** with file system
- **Cross-project compatibility** testing
- **Version compatibility** testing across Elixir versions