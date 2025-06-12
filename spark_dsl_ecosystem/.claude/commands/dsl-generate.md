# Generate DSL Components - SparkDslEcosystem Component Factory

Generates SparkDslEcosystem transformers, verifiers, and other DSL components with proper boilerplate using autonomous code generation and best practices.

## Usage
```
/dsl-generate <component_type> <module_name> [options]
```

## Component Types
- `transformer` - Compile-time DSL transformations
- `verifier` - DSL validation logic  
- `extension` - Complete DSL extension
- `info` - Info module for introspection
- `test` - Comprehensive test suite

## Arguments
- `component_type` - Type of component to generate
- `module_name` - Full module name (e.g., "MyLibrary.Validator.Transformers.AddId")
- `options` - Component-specific options

## Examples
```
/dsl-generate transformer MyLibrary.Validator.Transformers.AddId
/dsl-generate verifier MyLibrary.Validator.Verifiers.CheckRequired
/dsl-generate test MyLibrary.Validator
```

## Implementation

```elixir
[component_type, module_name | options] = args

case component_type do
  "transformer" ->
    generate_transformer(module_name, options)
  "verifier" ->  
    generate_verifier(module_name, options)
  "extension" ->
    generate_extension(module_name, options) 
  "info" ->
    generate_info(module_name, options)
  "test" ->
    generate_test_suite(module_name, options)
end

def generate_transformer(module_name, _options) do
  file_path = module_to_path(module_name)
  
  content = """
  defmodule #{module_name} do
    @moduledoc \"\"\"
    Transformer for #{module_name |> String.split(".") |> List.last()}.
    
    This transformer modifies the DSL structure at compile time.
    \"\"\"
    
    use Spark.Dsl.Transformer
    
    @doc \"\"\"
    Transforms the DSL state.
    
    ## Parameters
    - dsl_state: The current DSL state map
    
    ## Returns
    - {:ok, transformed_dsl_state} | {:error, error}
    \"\"\"
    def transform(dsl_state) do
      # TODO: Implement transformation logic
      # Example: Add entity, modify section, etc.
      
      {:ok, dsl_state}
    end
    
    @doc \"\"\"
    Runs after all other transformers.
    Override if this transformer needs to run last.
    \"\"\"
    def after?(_other_transformer), do: false
    
    @doc \"\"\"
    Runs before specific transformers.
    Override to control transformer ordering.
    \"\"\"  
    def before?(_other_transformer), do: false
  end
  """
  
  write_file(file_path, content)
end

def generate_verifier(module_name, _options) do
  file_path = module_to_path(module_name)
  
  content = """
  defmodule #{module_name} do
    @moduledoc \"\"\"
    Verifier for #{module_name |> String.split(".") |> List.last()}.
    
    This verifier validates the final DSL structure.
    \"\"\"
    
    use Spark.Dsl.Verifier
    
    @doc \"\"\"
    Verifies the DSL state is valid.
    
    ## Parameters  
    - dsl_state: The final DSL state map
    
    ## Returns
    - :ok | {:error, Spark.Error.DslError.t()}
    \"\"\"
    def verify(dsl_state) do
      # TODO: Implement verification logic
      # Example: Check required fields, validate relationships, etc.
      
      :ok
    end
    
    # Helper function to create DSL errors
    defp dsl_error(message, path) do
      {:error,
       Spark.Error.DslError.exception(
         message: message,
         path: path,
         module: Spark.Dsl.Verifier.get_persisted(dsl_state, :module)
       )}
    end
  end
  """
  
  write_file(file_path, content)
end

def generate_test_suite(module_name, _options) do
  base_name = module_name |> String.split(".") |> List.last()
  test_path = "test/#{module_to_path(module_name, "test")}"
  
  content = """
  defmodule #{module_name}Test do
    use ExUnit.Case
    
    describe "#{base_name} DSL" do
      defmodule TestDsl do
        use #{module_name}
        
        # TODO: Add test DSL configuration
      end
      
      test "compiles successfully" do
        assert Code.ensure_loaded?(TestDsl)
      end
      
      test "provides expected info functions" do
        # TODO: Test info module functions
        assert function_exported?(#{module_name}.Info, :sections, 1)
      end
    end
    
    describe "validation" do
      test "validates required fields" do
        # TODO: Test validation logic
      end
      
      test "handles invalid configurations" do
        # TODO: Test error cases
      end
    end
    
    describe "transformations" do  
      test "applies transformers correctly" do
        # TODO: Test transformer behavior
      end
    end
  end
  """
  
  write_file(test_path, content)
end

defp module_to_path(module_name, prefix \\ "lib") do
  path = module_name
    |> String.replace(".", "/")
    |> String.downcase()
    
  "#{prefix}/#{path}.ex"
end

defp write_file(path, content) do
  File.mkdir_p!(Path.dirname(path))
  File.write!(path, content)
  IO.puts("Generated: #{path}")
end
```

## Output
Creates properly structured Spark DSL components with:
- Complete module documentation
- Proper error handling patterns  
- TODO comments for implementation guidance
- Standard Spark conventions and patterns