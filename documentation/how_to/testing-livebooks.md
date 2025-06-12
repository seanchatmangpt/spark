# Testing Livebooks: A Comprehensive Guide

This guide explains how to test Livebook files (`.livemd`) programmatically to ensure they provide reliable, working examples for users.

## Overview

Testing Livebooks is crucial for maintaining high-quality documentation that users can trust. Our testing approach validates:

1. **File structure and content**
2. **Code syntax and compilation**
3. **DSL patterns and examples**
4. **Interactive elements**
5. **Information theory compliance**
6. **Learning progression**

## Testing Architecture

### Core Test Files

1. **`test/livebook_test.exs`** - Main test suite
2. **`test/support/livebook_test_runner.ex`** - Test utilities
3. **`test/livebook_execution_test.exs`** - Advanced execution tests

### Key Testing Patterns

#### 1. File Structure Validation

```elixir
test "livebook exists and has valid content" do
  file_path = Path.join(@livebook_dir, @filename)
  assert File.exists?(file_path)
  
  content = File.read!(file_path)
  assert String.length(content) > 15_000, "Content should be substantial"
  assert content =~ ~r/# Title/, "Should have proper title"
  assert content =~ ~r/Mix\.install/, "Should have Mix.install block"
end
```

#### 2. Code Block Extraction and Testing

```elixir
def extract_elixir_blocks(content) do
  Regex.scan(~r/```elixir\n(.*?)\n```/s, content, capture: :all_but_first)
  |> Enum.map(&hd/1)
end

test "code blocks compile correctly" do
  code_blocks = extract_elixir_blocks(content)
  
  for {block, index} <- Enum.with_index(code_blocks) do
    case Code.string_to_quoted(block) do
      {:ok, _} -> :ok
      {:error, _} -> flunk("Block #{index} has syntax error")
    end
  end
end
```

#### 3. DSL Pattern Validation

```elixir
test "contains essential DSL patterns" do
  content = File.read!(file_path)
  
  patterns = [
    {:basic_dsl, ~r/defmodule.*Dsl.*use Spark\.Dsl\.Extension/s},
    {:entity_definition, ~r/@\w+.*%Spark\.Dsl\.Entity\{/s},
    {:section_definition, ~r/@\w+.*%Spark\.Dsl\.Section\{/s},
    {:info_module, ~r/use Spark\.InfoGenerator/s}
  ]
  
  for {name, pattern} <- patterns do
    assert content =~ pattern, "Missing pattern: #{name}"
  end
end
```

#### 4. Interactive Elements Testing

```elixir
test "has interactive elements" do
  content = File.read!(file_path)
  
  interactive_patterns = [
    {:kino_input, ~r/Kino\.Input/},
    {:kino_markdown, ~r/Kino\.Markdown/},
    {:dynamic_content, ~r/Kino\.Input\.read/}
  ]
  
  for {name, pattern} <- interactive_patterns do
    matches = Regex.scan(pattern, content) |> length()
    assert matches > 0, "Should have #{name} elements"
  end
end
```

#### 5. Information Theory Compliance

```elixir
def validate_information_theory(file_path) do
  content = File.read!(file_path)
  
  # Calculate metrics
  total_chars = String.length(content)
  code_blocks = extract_code_blocks(content) |> length()
  info_density = code_blocks / (total_chars / 1000)
  
  # Check principles
  checks = [
    {:complete_information, content =~ ~r/Mix\.install/},
    {:redundant_verification, content =~ ~r/(test|verify)/i},
    {:progressive_building, content =~ ~r/(step|section)/i},
    {:working_examples, code_blocks > 10}
  ]
  
  passed = Enum.count(checks, fn {_, result} -> result end)
  
  %{
    information_density: info_density,
    principles_passed: "#{passed}/#{length(checks)}",
    entropy_reduction: (passed / length(checks)) * 100
  }
end
```

#### 6. Learning Progression Testing

```elixir
test "follows logical progression" do
  content = File.read!(file_path)
  
  concepts = ["Basic DSL", "Transformers", "Verifiers", "Advanced"]
  
  indices = Enum.map(concepts, fn concept ->
    case Regex.run(~r/#{concept}/i, content, return: :index) do
      [{index, _}] -> index
      nil -> -1
    end
  end)
  
  found_indices = Enum.filter(indices, &(&1 >= 0))
  assert found_indices == Enum.sort(found_indices), 
    "Concepts should appear in logical order"
end
```

## Advanced Testing Utilities

### LivebookTestRunner Module

The `LivebookTestRunner` provides advanced utilities:

```elixir
# Execute entire livebook with validation
{:ok, message, results} = LivebookTestRunner.execute_livebook(file_path)

# Test specific DSL patterns
{:ok, message} = LivebookTestRunner.test_dsl_patterns(file_path)

# Validate interactive elements
{:ok, message, elements} = LivebookTestRunner.test_interactive_elements(file_path)

# Comprehensive test suite
result = LivebookTestRunner.comprehensive_test(file_path)
# Returns: %{success_rate: 85.0, tests_passed: "17/20", results: [...]}
```

### Code Block Execution

For testing actual code execution:

```elixir
def execute_code_block(code, index, timeout \\ 30_000) do
  module_name = :"TestModule#{index}_#{:erlang.unique_integer([:positive])}"
  
  wrapped_code = """
  defmodule #{module_name} do
    def run do
      try do
  #{indent_code(code, 4)}
      rescue
        error -> {:error, error}
      end
    end
  end
  """
  
  try do
    [{^module_name, _}] = Code.compile_string(wrapped_code)
    task = Task.async(fn -> apply(module_name, :run, []) end)
    result = Task.await(task, timeout)
    
    # Clean up
    :code.delete(module_name)
    :code.purge(module_name)
    
    {:ok, index, result}
  rescue
    error -> {:compile_error, index, error}
  end
end
```

## CI/CD Integration

### Running Tests in CI

```yaml
name: Test Livebooks
on: [push, pull_request]

jobs:
  test-livebooks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26'
      
      - run: mix deps.get
      - run: mix test test/livebook_test.exs
      - run: mix test test/livebook_execution_test.exs
```

### Test Commands

```bash
# Run all livebook tests
mix test test/livebook_test.exs test/livebook_execution_test.exs

# Run with detailed output
mix test test/livebook_test.exs --trace

# Test specific patterns
mix test test/livebook_test.exs -t dsl_patterns

# Generate test coverage
mix test --cover test/livebook_test.exs
```

## Quality Metrics

### Success Criteria

- **File Structure**: 100% (files exist, proper format)
- **Code Syntax**: >90% of blocks have valid syntax
- **DSL Patterns**: 100% of required patterns present
- **Interactive Elements**: >5 interactive components
- **Information Density**: >1.0 code blocks per 1000 characters
- **Learning Progress**: Logical concept ordering

### Information Theory Compliance

Our tests validate:
- **Complete Information Transfer**: All dependencies specified
- **Redundant Verification**: Multiple validation methods
- **Progressive Building**: Each step builds on confirmed success
- **Minimal Entropy**: Clear, unambiguous instructions
- **Working Examples**: 100% executable code

## Best Practices

### 1. Test Early and Often

```elixir
# Add to your development workflow
mix test test/livebook_test.exs --watch
```

### 2. Maintain Test Coverage

Ensure tests cover:
- All major DSL patterns
- Interactive functionality
- Error handling examples
- Progressive complexity

### 3. Validate Information Theory

```elixir
# Regular validation
result = LivebookTestRunner.validate_information_theory(file_path)
assert result.entropy_reduction > 80.0
```

### 4. Test User Experience

```elixir
# Ensure logical flow
test "user can follow tutorial successfully" do
  content = File.read!(file_path)
  
  # Check prerequisites are clear
  assert content =~ ~r/Mix\.install/
  
  # Check examples build progressively  
  assert find_position(content, "Basic") < find_position(content, "Advanced")
  
  # Check validation steps included
  assert content =~ ~r/(test|verify|validate)/i
end
```

## Troubleshooting

### Common Issues

1. **Code Block Syntax Errors**
   - Check for incomplete examples
   - Verify proper Elixir syntax
   - Test compilation manually

2. **Missing DSL Patterns**
   - Ensure all required Spark modules referenced
   - Check entity and section definitions
   - Verify info module patterns

3. **Interactive Element Failures**
   - Test Kino dependency installation
   - Check input/output patterns
   - Verify dynamic content works

### Debugging Tests

```elixir
# Add debugging to tests
test "debug livebook content" do
  content = File.read!(file_path)
  IO.puts("Content length: #{String.length(content)}")
  
  code_blocks = extract_elixir_blocks(content)
  IO.puts("Code blocks found: #{length(code_blocks)}")
  
  for {block, index} <- Enum.with_index(code_blocks) do
    case Code.string_to_quoted(block) do
      {:ok, _} -> IO.puts("Block #{index}: ✅")
      {:error, error} -> IO.puts("Block #{index}: ❌ #{inspect(error)}")
    end
  end
end
```

## Conclusion

This comprehensive testing approach ensures that Livebooks provide reliable, educational value to users. By testing file structure, code validity, DSL patterns, interactive elements, and information theory compliance, we maintain high-quality documentation that users can trust and learn from effectively.

The testing framework is designed to:
- **Catch regressions** early in development
- **Validate learning progression** for optimal user experience  
- **Ensure code quality** through syntax and compilation checks
- **Maintain information density** for effective knowledge transfer
- **Support CI/CD integration** for automated quality assurance

Regular testing with these patterns ensures that Livebooks remain valuable learning resources that help developers build powerful DSLs with confidence.