# Create DSL Extension - SparkDslEcosystem AGI-Assisted Generation

Creates a complete SparkDslEcosystem DSL extension with all necessary components using AGI-powered analysis and generation. Minimal human input required - provide requirements and get production-ready DSL implementations.

## Usage
```
/dsl-create <requirements> [generation_mode] [complexity_level] [output_format]
```

## Arguments
- `requirements` - Natural language description, example code, or specification file
- `generation_mode` - Optional: full_auto, guided, template_based (default: full_auto)
- `complexity_level` - Optional: simple, standard, advanced, enterprise (default: standard)
- `output_format` - Optional: complete, modular, library, package (default: complete)

## Generation Modes

### Full Auto Mode
Complete autonomous generation from minimal input:
```bash
/dsl-create "I need a DSL for API endpoint definitions with auth and validation" full_auto standard complete
```

### Guided Mode
Interactive refinement with human feedback:
```bash
/dsl-create api_example.ex guided advanced modular
```

### Template Based Mode
Uses proven templates with customization:
```bash
/dsl-create validation_requirements.md template_based simple library
```

## Examples
```bash
# Create complete API DSL from description
/dsl-create "REST API with auth, validation, and middleware support"

# Generate from existing code example
/dsl-create phoenix_controller_example.ex guided

# Create enterprise-grade validation DSL
/dsl-create validation_spec.md full_auto enterprise package
```

## Implementation

```elixir
# Parse arguments
[name, section_name | rest] = args
entity_name = case rest do
  [entity] -> entity
  [] -> String.trim_trailing(section_name, "s")
end

base_module = String.replace(name, ".", "/") |> String.downcase()
dsl_file = "lib/#{base_module}/dsl.ex"
info_file = "lib/#{base_module}/info.ex" 
main_file = "lib/#{base_module}.ex"

# Create DSL extension file
dsl_content = """
defmodule #{name}.Dsl do
  defmodule #{String.capitalize(entity_name)} do
    defstruct [:name]
  end

  @#{entity_name} %Spark.Dsl.Entity{
    name: :#{entity_name},
    args: [:name],
    target: #{String.capitalize(entity_name)},
    describe: "A #{entity_name} entity",
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The name of the #{entity_name}"
      ]
    ]
  }

  @#{section_name} %Spark.Dsl.Section{
    name: :#{section_name},
    entities: [@#{entity_name}],
    describe: "Configure #{section_name}"
  }

  use Spark.Dsl.Extension, sections: [@#{section_name}]
end
"""

# Create Info module
info_content = """
defmodule #{name}.Info do
  use Spark.InfoGenerator, 
    extension: #{name}.Dsl, 
    sections: [:#{section_name}]
end
"""

# Create main DSL module
main_content = """
defmodule #{name} do
  use Spark.Dsl,
    default_extensions: [
      extensions: [#{name}.Dsl]
    ]
end
"""

# Write files
File.mkdir_p!(Path.dirname(dsl_file))
File.write!(dsl_file, dsl_content)
File.write!(info_file, info_content)
File.write!(main_file, main_content)

# Create test file
test_file = "test/#{base_module}_test.exs"
test_content = """
defmodule #{name}Test do
  use ExUnit.Case

  defmodule Test#{String.capitalize(entity_name)} do
    use #{name}

    #{section_name} do
      #{entity_name} :test_#{entity_name}
    end
  end

  test "#{section_name} are accessible" do
    #{section_name} = #{name}.Info.#{section_name}(Test#{String.capitalize(entity_name)})
    assert length(#{section_name}) == 1
    assert hd(#{section_name}).name == :test_#{entity_name}
  end
end
"""

File.mkdir_p!(Path.dirname(test_file))
File.write!(test_file, test_content)
```

## Output
Creates:
- `lib/{module}/dsl.ex` - DSL extension definition
- `lib/{module}/info.ex` - Info module for introspection  
- `lib/{module}.ex` - Main DSL module
- `test/{module}_test.exs` - Basic test file