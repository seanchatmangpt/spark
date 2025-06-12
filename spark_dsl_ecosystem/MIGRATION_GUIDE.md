# AutoPipeline → SparkDslEcosystem Migration Guide

This guide documents the migration of AutoPipeline components from the Spark project into the SparkDslEcosystem umbrella project.

## Overview

AutoPipeline was initially conceived as a DevOps orchestration tool but evolved into a near-AGI DSL generation platform. This migration separates the AGI capabilities into SparkDslEcosystem to avoid circular dependencies with Spark.

## Migration Map

| AutoPipeline Component | Target App | New Module | Purpose |
|------------------------|------------|------------|----------|
| `AutoPipeline` | `agi_factory` | `AgiFactory` | Main orchestration |
| `AutoPipeline.CommandDiscovery` | `requirements_parser` | `RequirementsParser.CommandParser` | Parse commands → requirements |
| `AutoPipeline.ExecutionEngine` | `agi_factory` | `AgiFactory.Orchestrator` | Reactor-based orchestration |
| `AutoPipeline.QualityAssurance` | `agi_factory` | `AgiFactory.QualityAssurance` | Quality monitoring |
| `AutoPipeline.Transformers.*` | `dsl_synthesizer` | `DslSynthesizer.Generators.*` | DSL generation logic |
| `AutoPipeline.Verifiers.*` | `dsl_synthesizer` | `DslSynthesizer.Validators.*` | DSL validation |
| `AutoPipeline.Info` | `spark_core` | `SparkCore.Introspection` | DSL introspection |
| Pattern Analysis | `usage_analyzer` | `UsageAnalyzer.PatternExtractor` | Code pattern analysis |
| SPR Operations | `knowledge_engine` | `KnowledgeEngine.SPR` | Knowledge compression |

## Porting Steps

### 1. AGI Factory Setup

The AGI Factory becomes the main orchestrator, using Reactor for workflow management:

```elixir
# apps/agi_factory/lib/agi_factory/orchestrator.ex
defmodule AgiFactory.Orchestrator do
  use Reactor
  
  # Define the DSL creation workflow
  step :parse_requirements do
    impl {RequirementsParser, :parse}
    argument :input, from: :requirements
  end
  
  step :analyze_patterns do
    impl {UsageAnalyzer, :analyze_codebase}
    argument :spec, from: {:result, :parse_requirements}
    async? true
  end
  
  step :synthesize_dsl do
    impl {DslSynthesizer, :generate}
    argument :spec, from: {:result, :parse_requirements}
    argument :patterns, from: {:result, :analyze_patterns}
  end
end
```

### 2. Requirements Parser

Convert command discovery to requirement parsing:

```elixir
# From: lib/auto_pipeline/command_discovery.ex
# To: apps/requirements_parser/lib/requirements_parser/command_parser.ex

# Key changes:
# 1. Remove Spark dependencies
# 2. Parse commands into neutral specification format
# 3. Add natural language processing capabilities
```

### 3. DSL Synthesizer

Move transformers and verifiers to synthesizer:

```elixir
# From: lib/auto_pipeline/transformers/*.ex
# To: apps/dsl_synthesizer/lib/dsl_synthesizer/generators/*.ex

# Key changes:
# 1. Convert from Spark transformers to standalone generators
# 2. Generate AST instead of modifying DSL state
# 3. Add multiple generation strategies
```

### 4. Usage Analyzer

Extract pattern analysis capabilities:

```elixir
# From: lib/auto_pipeline/transformers/generate_task_metadata.ex
# To: apps/usage_analyzer/lib/usage_analyzer/pattern_extractor.ex

# Key changes:
# 1. Focus on pattern recognition
# 2. Add ML/statistical analysis
# 3. Track usage over time
```

### 5. Evolution Engine

Implement continuous improvement:

```elixir
# New implementation in: apps/evolution_engine/lib/evolution_engine/continuous_improvement.ex
# Based on: AutoPipeline's quality assurance concepts

# Features:
# 1. A/B testing of DSL variations
# 2. Performance tracking
# 3. Automatic optimization
```

### 6. Knowledge Engine

Integrate SPR operations:

```elixir
# From: .claude/commands/spr-compress.md and spr-decompress.md concepts
# To: apps/knowledge_engine/lib/knowledge_engine/spr.ex

# Implementation:
# 1. Compress DSL patterns
# 2. Store in knowledge base
# 3. Expand for new contexts
```

## Dependency Updates

### Root mix.exs
```elixir
defp deps do
  [
    # Core dependencies
    {:spark, "~> 2.2"},
    {:reactor, "~> 0.15"},
    
    # AI/ML capabilities
    {:nx, "~> 0.7"},
    {:axon, "~> 0.6"},
    
    # Code analysis
    {:sourceror, "~> 1.0"},
    {:nimble_parsec, "~> 1.4"}
  ]
end
```

### App-specific dependencies

Each app should declare its dependencies:

```elixir
# apps/agi_factory/mix.exs
defp deps do
  [
    {:reactor, "~> 0.15"},
    # Internal apps
    {:requirements_parser, in_umbrella: true},
    {:dsl_synthesizer, in_umbrella: true},
    {:evolution_engine, in_umbrella: true},
    {:usage_analyzer, in_umbrella: true},
    {:knowledge_engine, in_umbrella: true},
    {:spark_core, in_umbrella: true}
  ]
end
```

## Breaking Changes

### API Changes

```elixir
# Old (AutoPipeline in Spark)
AutoPipeline.run(["full", "development", "80", "8"])

# New (SparkDslEcosystem)
AgiFactory.create_dsl("I need an API DSL with auth", mode: :development)
```

### DSL Syntax Changes

```elixir
# Old (AutoPipeline DSL)
pipeline_tasks do
  task :build do
    command "mix compile"
  end
end

# New (Generated by SparkDslEcosystem)
# No manual DSL writing - it's generated from requirements!
```

## Testing Strategy

1. **Unit Tests**: Test each app independently
2. **Integration Tests**: Test the full workflow
3. **Property Tests**: Test DSL generation properties
4. **Performance Tests**: Ensure AGI operations are efficient

## Rollout Plan

1. **Phase 1**: Set up basic structure (Week 1)
2. **Phase 2**: Port core functionality (Week 2-3)
3. **Phase 3**: Implement AGI features (Week 4-5)
4. **Phase 4**: Testing and documentation (Week 6)
5. **Phase 5**: Remove from Spark (Week 7)

## Future Enhancements

After migration, these AGI features can be added:

1. **Natural Language Processing**: Better requirement understanding
2. **Machine Learning**: Pattern recognition and prediction
3. **Autonomous Evolution**: Self-improving DSLs
4. **Cross-Project Learning**: Learn from ecosystem usage

## Support

For questions about the migration:
- Discord: [Ash Framework Discord](https://discord.gg/HTHRaaVPUc)
- GitHub Issues: [spark_dsl_ecosystem/issues](https://github.com/ash-project/spark_dsl_ecosystem/issues)
