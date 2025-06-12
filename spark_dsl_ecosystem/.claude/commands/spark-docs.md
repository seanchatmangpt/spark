# Generate SparkDslEcosystem Documentation

Generates comprehensive documentation for SparkDslEcosystem DSL extensions including cheat sheets, API docs, and interactive tutorials using autonomous documentation generation.

## Usage
```
/spark-docs [module_name] [doc_type]
```

## Arguments
- `module_name` - Optional specific DSL module (generates for all if omitted)
- `doc_type` - Optional: api, cheat, tutorial, all (default: all)

## Examples
```
/spark-docs MyLibrary.Validator cheat
/spark-docs "" api  
/spark-docs
```

## Implementation

```elixir
[module_filter, doc_type] = case args do
  [] -> ["", "all"]
  [module] -> [module, "all"]
  [module, type] -> [module, type]
end

case doc_type do
  "api" ->
    generate_api_docs(module_filter)
  "cheat" ->
    generate_cheat_sheets(module_filter)  
  "tutorial" ->
    generate_tutorials(module_filter)
  "all" ->
    generate_api_docs(module_filter)
    generate_cheat_sheets(module_filter)
    generate_tutorials(module_filter)
end

def generate_api_docs(module_filter) do
  IO.puts("=== Generating API Documentation ===")
  
  # Generate standard ExDoc documentation
  {output, exit_code} = System.cmd("mix", ["docs"])
  
  if exit_code == 0 do
    IO.puts("✅ API documentation generated successfully")
    IO.puts("📖 Open doc/index.html to view")
  else
    IO.puts("❌ API documentation generation failed:")
    IO.puts(output)
  end
end

def generate_cheat_sheets(module_filter) do
  IO.puts("=== Generating DSL Cheat Sheets ===")
  
  # Generate Spark DSL cheat sheets
  args = if module_filter != "" do
    ["spark.cheat_sheets", "--module", module_filter]
  else
    ["spark.cheat_sheets"]
  end
  
  {output, exit_code} = System.cmd("mix", args)
  
  if exit_code == 0 do
    IO.puts("✅ DSL cheat sheets generated successfully")
    IO.puts(output)
  else
    IO.puts("❌ Cheat sheet generation failed:")
    IO.puts(output)
  end
end

def generate_tutorials(module_filter) do
  IO.puts("=== Generating Tutorial Documentation ===")
  
  # Find all DSL modules
  dsl_modules = if module_filter != "" do
    [module_filter]
  else
    find_dsl_modules()
  end
  
  Enum.each(dsl_modules, &generate_module_tutorial/1)
end

def find_dsl_modules() do
  # Scan for modules using Spark.Dsl
  Path.wildcard("lib/**/*.ex")
  |> Enum.map(&File.read!/1)
  |> Enum.with_index()
  |> Enum.filter(fn {content, _} ->
    String.contains?(content, "use Spark.Dsl")
  end)
  |> Enum.map(fn {content, index} ->
    # Extract module name from file content
    case Regex.run(~r/defmodule\s+([A-Za-z0-9.]+)/, content) do
      [_, module_name] -> module_name
      _ -> "UnknownModule#{index}"
    end
  end)
end

def generate_module_tutorial(module_name) do
  tutorial_path = "documentation/tutorials/#{module_name |> String.downcase() |> String.replace(".", "_")}.md"
  
  content = """
  # #{module_name} Tutorial
  
  This tutorial covers how to use the #{module_name} DSL.
  
  ## Overview
  
  #{module_name} provides a declarative way to...
  
  ## Basic Usage
  
  ```elixir
  defmodule MyApp.Example do
    use #{module_name}
    
    # TODO: Add example DSL usage
  end
  ```
  
  ## Advanced Features
  
  ### Custom Transformers
  
  You can extend #{module_name} with custom transformers:
  
  ```elixir  
  defmodule MyApp.CustomTransformer do
    use Spark.Dsl.Transformer
    
    def transform(dsl_state) do
      # Custom transformation logic
      {:ok, dsl_state}
    end
  end
  ```
  
  ### Custom Verifiers
  
  Add validation with custom verifiers:
  
  ```elixir
  defmodule MyApp.CustomVerifier do
    use Spark.Dsl.Verifier
    
    def verify(dsl_state) do
      # Custom validation logic
      :ok
    end
  end
  ```
  
  ## API Reference
  
  See the [API documentation](../api/#{module_name}.html) for complete function reference.
  
  ## Examples
  
  Check the [examples directory](../../examples/#{module_name |> String.downcase()}) for more usage patterns.
  """
  
  File.mkdir_p!(Path.dirname(tutorial_path))
  File.write!(tutorial_path, content)
  IO.puts("📝 Generated tutorial: #{tutorial_path}")
end
```

## Features

### API Documentation
- Complete module and function documentation
- Interactive examples with IEx sessions  
- Cross-referenced type specifications
- Automatic linking between modules

### DSL Cheat Sheets
- Available DSL sections and entities
- Schema definitions and validation rules
- Usage examples for each DSL construct
- Quick reference format

### Tutorial Generation
- Step-by-step usage guides
- Basic to advanced examples
- Extension patterns and best practices
- Integration with existing documentation

## Output
- `doc/` - Complete API documentation
- `documentation/cheat_sheets/` - DSL quick references  
- `documentation/tutorials/` - Tutorial guides
- Console output with generation status and links