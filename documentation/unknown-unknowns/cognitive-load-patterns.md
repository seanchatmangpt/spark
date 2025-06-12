# Cognitive Load Patterns: The Mental Models You Don't Know You Need

## Executive Summary

This document maps the hidden cognitive complexity of working with Spark DSL - the mental models, thinking patterns, and conceptual frameworks that experienced developers internalize but are never explicitly documented. Understanding these cognitive patterns is essential for team adoption and reducing the learning curve.

## The Core Mental Model Problem

### What Experts Take for Granted
Experienced Spark DSL developers operate with multiple simultaneous mental models:

1. **The Compile-Time vs Runtime Model**: Understanding when code executes
2. **The Entity Lifecycle Model**: How DSL entities transform through compilation
3. **The Information Flow Model**: How data moves between DSL layers
4. **The Error Attribution Model**: Mapping failures to actual causes
5. **The Performance Mental Model**: Predicting performance implications

**The Problem**: These models are implicit and take months to develop through trial and error.

## Mental Model 1: The DSL Compilation Timeline

### What Beginners Think Happens
```elixir
defmodule MyConfig do
  use ClaudeConfig  # ← "This sets up the DSL"
  
  project do         # ← "This defines project info"
    name "My App"
  end
  
  permissions do     # ← "This defines permissions"
    allow_tool "Read(**/*)"
  end
end

# "Then I can use MyConfig.project_info() to get the data"
```

### What Actually Happens (The Hidden Timeline)
```elixir
# PHASE 1: Module attribute collection (compile time)
defmodule MyConfig do
  use ClaudeConfig    # ← Injects macros, sets up module attributes
  
  # PHASE 2: DSL macro expansion (compile time)
  project do          # ← Macro captures AST, stores in module attributes
    name "My App"     # ← Becomes @spark_dsl_config data structure
  end
  
  permissions do      # ← More macro expansion, attribute accumulation
    allow_tool "Read(**/*)"  # ← Stored as entity structs
  end
  
  # PHASE 3: Transformer pipeline (compile time)
  # - ValidateConfig transformer runs
  # - Entity relationships validated
  # - Cross-references resolved
  # - Errors can happen here with confusing stack traces
  
  # PHASE 4: Info module generation (compile time)
  # - Functions like project_info() are generated
  # - InfoGenerator creates accessor functions
  # - Function names based on section names, not entity names
  
  # PHASE 5: Runtime usage
  # - Generated functions access pre-computed data
  # - No dynamic resolution
end
```

**Cognitive Load**: Beginners try to debug runtime behavior when the problem is in compile-time phases.

## Mental Model 2: The Entity Transformation Pipeline

### The Hidden Data Flow
```elixir
# What you write in DSL:
project do
  name "My App"
  language "Elixir"
end

# Becomes this entity struct (Phase 1):
%ClaudeConfig.Dsl.Project{
  name: "My App",
  language: "Elixir",
  description: nil,  # ← Default values filled in
  framework: nil,
  version: nil
}

# Gets processed by transformers (Phase 2):
# - Validation transformers check required fields
# - Default value transformers fill in missing data
# - Relationship transformers connect entities

# Ends up in module attributes (Phase 3):
@spark_dsl_config %{
  project: [%ClaudeConfig.Dsl.Project{...}],
  permissions: [...],
  commands: [...]
}

# Accessible via generated functions (Phase 4):
def project_info(_), do: @spark_dsl_config.project |> List.first()
```

**Cognitive Load**: Beginners don't understand why their DSL changes don't show up at runtime or why validation errors happen "randomly."

## Mental Model 3: The Information Access Patterns

### The Function Generation Mystery
```elixir
# DSL with sections:
defmodule MyConfig do
  use ClaudeConfig
  
  project do ... end          # ← Creates project() function
  permissions do ... end      # ← Creates permissions() function  
  commands do ... end         # ← Creates commands() function
end

# Generated functions (what InfoGenerator actually creates):
def project(MyConfig), do: [%Project{...}]           # List of project entities
def permissions(MyConfig), do: [%AllowTool{}, ...]   # List of ALL permission entities
def commands(MyConfig), do: [%Command{}, ...]        # List of command entities

# What beginners expect but doesn't exist:
def project_info(MyConfig)      # ← Doesn't exist by default
def allow_tools(MyConfig)       # ← Doesn't exist by default
def allow_bash(MyConfig)        # ← Doesn't exist by default
```

**The Pattern**: Info modules must implement convenience functions that filter and transform the raw section data:

```elixir
defmodule ClaudeConfig.Info do
  use Spark.InfoGenerator, sections: [:project, :permissions, :commands]
  
  # Custom convenience functions
  def project_info(resource) do
    case project(resource) do
      [project] -> project
      [] -> nil
    end
  end
  
  def get_permissions(resource) do
    all_perms = permissions(resource)
    %{
      allow_tools: Enum.filter(all_perms, &(&1.__struct__ == AllowTool)),
      deny_tools: Enum.filter(all_perms, &(&1.__struct__ == DenyTool)),
      # ...
    }
  end
end
```

**Cognitive Load**: Beginners spend hours debugging "undefined function" errors because they assume functions exist that don't.

## Mental Model 4: The Error Attribution Framework

### The Debugging Mental Map
```elixir
# When this fails:
permissions do
  allow_tool "Read(**/*)"
end

# Error could be in any of these layers:
# 1. DSL syntax error → Macro expansion failure
# 2. Entity validation error → Transformer failure  
# 3. Schema validation error → Type checking failure
# 4. Info generation error → Function generation failure
# 5. Runtime access error → Missing function error
```

**The Mental Framework Experts Use**:
```
Error Message Analysis:
├── "undefined function" → Info layer problem
├── "module not available" → Compilation order problem
├── Spark.Error.DslError → Transformer validation problem
├── "function clause" → Entity schema problem
└── Macro error → DSL syntax problem

Stack Trace Analysis:
├── spark/dsl/extension.ex → DSL definition problem
├── spark/info_generator.ex → Function generation problem  
├── your_module/transformers/ → Custom validation problem
└── your_module.ex → DSL usage problem
```

**Cognitive Load**: Beginners can't map error messages to actual problems, leading to random trial-and-error debugging.

## Mental Model 5: The Performance Intuition Model

### Hidden Performance Characteristics
```elixir
# This looks innocent but is expensive:
permissions do
  # Each line triggers:
  # - Macro expansion
  # - AST manipulation
  # - Module attribute update
  # - Validation pipeline
  allow_tool "Read(file1.ex)"
  allow_tool "Read(file2.ex)"
  # ... 100+ lines = 100x compilation cost
end

# This is much faster:
@file_patterns ~w[
  Read(file1.ex)
  Read(file2.ex)
  # ... 100+ patterns
]

permissions do
  # Single macro expansion, batch processing
  for pattern <- @file_patterns do
    allow_tool pattern
  end
end
```

**The Performance Mental Model**:
- **Compilation cost**: O(n) where n = number of DSL statements
- **Memory cost**: O(entities) - all entities stored in module attributes
- **Runtime cost**: O(1) - pre-computed lookups
- **Hot reloading cost**: O(full recompilation) - can't incrementally update

**Cognitive Load**: Beginners write DSL code that compiles slowly without understanding why.

## Mental Model 6: The Testing Strategy Framework

### The Test Classification Mental Model
```elixir
# Experts categorize DSL tests into distinct types:

# 1. DSL Syntax Tests (compile-time validation)
test "DSL compiles without errors" do
  # Tests that DSL structure is valid
  assert Code.ensure_compiled(MyConfig) == {:module, MyConfig}
end

# 2. Entity Generation Tests (transformation validation) 
test "entities are created correctly" do
  # Tests that DSL produces expected entity structures
  assert length(MyConfig.project()) == 1
end

# 3. Info Function Tests (convenience function validation)
test "info functions work" do
  # Tests the convenience layer
  assert MyConfig.Info.project_info().name == "My App"
end

# 4. Generation Tests (output validation)
test "generates correct files" do
  # Tests that DSL produces correct external artifacts
  result = ClaudeConfig.generate_claude_directory(MyConfig)
  # Validate generated files
end

# 5. Integration Tests (end-to-end validation)
test "works with external systems" do
  # Tests that generated artifacts work with target systems
end
```

**Cognitive Load**: Beginners write tests at the wrong abstraction level and can't isolate failures.

## Mental Model 7: The Abstraction Layer Navigation

### The Stack Mental Model
```
User DSL Code
    ↓ (macro expansion)
Raw Entities  
    ↓ (transformers)
Validated Entities
    ↓ (info generator)
Accessor Functions
    ↓ (generation)
External Artifacts
    ↓ (runtime)
System Integration
```

**Each layer has different debugging approaches**:
- **DSL Layer**: Check macro definitions, syntax errors
- **Entity Layer**: Inspect @spark_dsl_config module attributes
- **Transform Layer**: Add debug prints in transformers
- **Info Layer**: Test generated functions directly
- **Generation Layer**: Validate output artifacts
- **Integration Layer**: Test end-to-end workflows

**Cognitive Load**: Beginners debug at the wrong layer and waste hours.

## Mental Model 8: The Schema Evolution Strategy

### The Versioning Mental Framework
```elixir
# Version 1 - Initial schema
@project %Spark.Dsl.Entity{
  schema: [
    name: [type: :string, required: true],
    language: [type: :string, required: true]
  ]
}

# Version 2 - Adding optional field (safe)
@project %Spark.Dsl.Entity{
  schema: [
    name: [type: :string, required: true],
    language: [type: :string, required: true],
    framework: [type: :string]  # ← Safe addition
  ]
}

# Version 3 - Adding required field (breaking)
@project %Spark.Dsl.Entity{
  schema: [
    name: [type: :string, required: true],
    language: [type: :string, required: true],
    framework: [type: :string],
    version: [type: :string, required: true]  # ← BREAKING CHANGE
  ]
}
```

**The Evolution Strategy**:
1. **Additive changes**: Add optional fields with sensible defaults
2. **Migration transformers**: Convert old formats to new formats
3. **Deprecation warnings**: Warn about old patterns before removing
4. **Version detection**: Detect schema version and handle appropriately

**Cognitive Load**: Beginners break existing configurations when evolving schemas.

## The Meta-Cognitive Load: Context Switching

### The Mental Context Switching Cost
When working with DSL code, experts maintain multiple simultaneous contexts:

```elixir
# Context 1: DSL semantics (what the DSL means)
project do
  name "My App"  # ← Business logic context
end

# Context 2: Implementation details (how it works)
# - This becomes a Project entity
# - Gets stored in module attributes  
# - Validated by transformers
# - Accessible via generated functions

# Context 3: Target system context (what it generates)
# - Produces .claude/config.json
# - With specific JSON structure
# - That Claude Code expects
# - With particular field requirements

# Context 4: Debugging context (when it breaks)
# - Error could be in any layer
# - Stack traces point to framework code
# - Need to understand compilation pipeline
# - Must test at correct abstraction level
```

**The Switching Cost**: Each context switch requires rebuilding mental models, leading to developer fatigue.

## Reducing Cognitive Load: Design Patterns

### Pattern 1: The Progressive Disclosure Pattern
```elixir
# Start with minimal complexity
defmodule BeginnerConfig do
  use ClaudeConfig
  
  project do
    name "My App"
    language "Elixir"
  end
end

# Gradually add complexity
defmodule IntermediateConfig do
  use ClaudeConfig
  
  project do
    name "My App"
    language "Elixir"
    framework "Phoenix"
  end
  
  permissions do
    allow_tool "Read(**/*)"
  end
end

# Advanced patterns only when needed
defmodule AdvancedConfig do
  use ClaudeConfig
  
  # Complex configuration with custom transformers
end
```

### Pattern 2: The Mental Model Documentation Pattern
```elixir
defmodule WellDocumentedConfig do
  @moduledoc """
  This DSL configuration follows these mental models:
  
  1. Compilation happens in phases (see compile-time vs runtime)
  2. Entities are validated by transformers (see validation pipeline)
  3. Info functions provide convenient access (see accessor patterns)
  4. Generation creates external artifacts (see output validation)
  
  Common debugging patterns:
  - Undefined function errors → Check Info module
  - Validation errors → Check entity schemas
  - Compilation errors → Check DSL syntax
  """
  
  use ClaudeConfig
  
  # ... configuration
end
```

### Pattern 3: The Guided Discovery Pattern
```elixir
# Provide scaffolding that teaches the mental models
mix spark.gen.config --guided
# Asks questions that reveal the compilation pipeline
# Explains why certain choices matter
# Shows the generated code at each step
# Provides debugging guidance
```

## Measurement: Cognitive Load Metrics

### Tracking Mental Model Acquisition
```elixir
defmodule CognitiveLoadMetrics do
  # Track common failure patterns
  def track_error_pattern(error_type, resolution_time) do
    # undefined_function errors should decrease over time
    # compilation_error resolution time should improve
    # debugging_efficiency should increase
  end
  
  # Measure context switching frequency
  def track_context_switches(developer_id, session) do
    # How often do developers switch between:
    # - DSL code
    # - Generated functions  
    # - Output artifacts
    # - External documentation
  end
end
```

### Success Indicators
- **Reduced debugging time**: Developers can map errors to causes quickly
- **Faster feature implementation**: Less time spent on cognitive overhead
- **Fewer "random" fixes**: Developers understand why solutions work
- **Better architectural decisions**: Developers predict performance implications
- **Smoother knowledge transfer**: New team members onboard faster

## Conclusion: The Hidden Curriculum

The biggest insight is that **DSL development requires a hidden curriculum** - a set of mental models and thinking patterns that aren't taught explicitly. This cognitive load is why:

1. **Adoption is slow**: Even experienced developers struggle initially
2. **Knowledge transfer is hard**: Experts can't articulate what they know
3. **Debugging is frustrating**: Error messages don't map to mental models
4. **Performance surprises occur**: Intuitions from regular code don't apply
5. **Architecture mistakes happen**: Mental models predict different outcomes

**The Solution**: Make the implicit mental models explicit through:
- **Progressive disclosure** of complexity
- **Mental model documentation** alongside code examples  
- **Guided learning paths** that build correct intuitions
- **Error message improvements** that map to mental models
- **Debugging guides** that teach the attribution framework

By surfacing these cognitive patterns, teams can reduce the learning curve from months to weeks and build more robust DSL-based systems with confidence.