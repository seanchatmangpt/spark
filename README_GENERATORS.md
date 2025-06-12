# Spark DSL Generators Documentation

**Making Spark DSL generators as easy as possible to use.**

## 📚 Documentation Files

This documentation is organized into multiple files for different use cases:

| File | Purpose | When to Use |
|------|---------|-------------|
| **[SPARK_GENERATORS_QUICK_REFERENCE.md](SPARK_GENERATORS_QUICK_REFERENCE.md)** | Quick lookup reference | When you know what you want to do and need the exact command |
| **[SPARK_GENERATORS_GUIDE.md](SPARK_GENERATORS_GUIDE.md)** | Complete comprehensive guide | When learning or implementing complex DSL systems |
| **[SPARK_GENERATORS_EXAMPLES.md](SPARK_GENERATORS_EXAMPLES.md)** | Working, tested examples | When you want to copy-paste working commands |
| **This file** | Overview and navigation | Starting point to find what you need |

## 🚀 Quick Start

### 1. Install Prerequisites
```elixir
# Add to mix.exs
{:igniter, "~> 0.6.6", only: [:dev]}
```

### 2. Create Your First DSL
```bash
mix spark.gen.dsl MyApp.MyDsl --section items --entity item:name:module
```

### 3. Use Your DSL
```elixir
defmodule MyApp.MyResource do
  use MyApp.MyDsl
  
  item :user do
    # configuration here
  end
end
```

## 🛠️ Available Generators

| Generator | Command | Purpose |
|-----------|---------|---------|
| **DSL** | `mix spark.gen.dsl` | Complete DSL with sections, entities, args, options |
| **Extension** | `mix spark.gen.extension` | Reusable DSL extension |
| **Entity** | `mix spark.gen.entity` | DSL entities with validation |
| **Section** | `mix spark.gen.section` | DSL sections that contain entities |
| **Transformer** | `mix spark.gen.transformer` | Compile-time DSL processors |
| **Verifier** | `mix spark.gen.verifier` | DSL validation logic |
| **Info** | `mix spark.gen.info` | Runtime DSL introspection |

## 📖 Documentation Guide

### For Beginners
1. Start with **[SPARK_GENERATORS_EXAMPLES.md](SPARK_GENERATORS_EXAMPLES.md)** 
   - Copy working examples
   - Follow the complete workflow example
   - Learn by doing

### For Quick Tasks
1. Use **[SPARK_GENERATORS_QUICK_REFERENCE.md](SPARK_GENERATORS_QUICK_REFERENCE.md)**
   - Find the exact command you need
   - Look up option meanings
   - Reference types and patterns

### For Complex Projects
1. Read **[SPARK_GENERATORS_GUIDE.md](SPARK_GENERATORS_GUIDE.md)**
   - Understand all options and patterns
   - Learn best practices
   - Follow architectural guidance

## 🎯 Common Use Cases

### Simple Configuration DSL
```bash
mix spark.gen.dsl MyApp.Config --section settings --opt debug:boolean:false
```
**→ See**: [Examples](SPARK_GENERATORS_EXAMPLES.md#basic-dsl) | [Reference](SPARK_GENERATORS_QUICK_REFERENCE.md#create-simple-dsl)

### Resource Management DSL
```bash
mix spark.gen.dsl MyApp.Resources \
  --section resources \
  --entity resource:name:module \
  --transformer MyApp.Transformers.BuildSchema
```
**→ See**: [Examples](SPARK_GENERATORS_EXAMPLES.md#resource-dsl) | [Guide](SPARK_GENERATORS_GUIDE.md#building-a-complete-dsl-system)

### Validation Extension
```bash
mix spark.gen.extension MyApp.Validation \
  --section validations \
  --verifier MyApp.Verifiers.ValidateRules
```
**→ See**: [Examples](SPARK_GENERATORS_EXAMPLES.md#validation-extension) | [Guide](SPARK_GENERATORS_GUIDE.md#extending-existing-dsls)

## 🔧 Generator Features

### All Generators Support:
- ✅ **Igniter Integration** - Automatic file creation and project integration
- ✅ **Comprehensive Documentation** - Generated with `--examples` flag
- ✅ **Error Handling** - Validation and helpful error messages
- ✅ **Code Quality** - Follows Spark framework conventions
- ✅ **Testing Support** - Patterns for testing generated code

### Advanced Features:
- 🔄 **Transformer Composition** - Chain transformers with `--before`/`--after`
- 🔍 **Runtime Introspection** - Info modules for DSL state access
- 🧩 **Extension System** - Reusable DSL components
- 📊 **Validation Pipelines** - Multi-stage verification
- 🎨 **Flexible Schemas** - Rich type system for entities

## 📋 Quick Commands Reference

### Most Common Commands
```bash
# Basic DSL
mix spark.gen.dsl MyApp.Dsl --section items

# With entities
mix spark.gen.dsl MyApp.Dsl --section items --entity item:name:module

# Add processing
mix spark.gen.transformer MyApp.Process --dsl MyApp.Dsl

# Add validation  
mix spark.gen.verifier MyApp.Validate --dsl MyApp.Dsl --sections items

# Add introspection
mix spark.gen.info MyApp.Dsl.Info --extension MyApp.Dsl --sections items
```

### Get Help
```bash
mix help spark.gen.dsl         # Detailed help for any generator
mix help spark.gen.entity      # Entity-specific help
# ... etc for each generator
```

## 🎓 Learning Path

### 1. Beginner (30 minutes)
- Read this overview
- Follow [Quick Start](#-quick-start) above
- Try 2-3 examples from [SPARK_GENERATORS_EXAMPLES.md](SPARK_GENERATORS_EXAMPLES.md)

### 2. Intermediate (2 hours)
- Complete the [workflow example](SPARK_GENERATORS_EXAMPLES.md#complete-workflow-example)
- Read [best practices](SPARK_GENERATORS_GUIDE.md#best-practices)
- Create a DSL for your own use case

### 3. Advanced (1 day)
- Study [transformer patterns](SPARK_GENERATORS_GUIDE.md#transformer-patterns)
- Build [extension system](SPARK_GENERATORS_GUIDE.md#extending-existing-dsls)
- Implement comprehensive [testing strategy](SPARK_GENERATORS_GUIDE.md#testing-generated-dsls)

## 🚨 Troubleshooting

### Common Issues & Solutions

| Issue | Quick Fix | Documentation |
|-------|-----------|---------------|
| "Module already exists" | Add `--ignore-if-exists` | [Troubleshooting](SPARK_GENERATORS_GUIDE.md#troubleshooting) |
| "Igniter required" | Add igniter dependency | [Installation](SPARK_GENERATORS_GUIDE.md#installation--requirements) |
| "Invalid schema" | Check type reference | [Quick Reference](SPARK_GENERATORS_QUICK_REFERENCE.md#type-reference) |
| Complex transformers | Use `--before`/`--after` | [Guide](SPARK_GENERATORS_GUIDE.md#transformer-patterns) |

### Getting Help
1. **Check documentation** - Start with the appropriate file above
2. **Use built-in help** - `mix help spark.gen.GENERATOR`
3. **Review examples** - Working code in examples file
4. **Check Spark docs** - [hexdocs.pm/spark](https://hexdocs.pm/spark)

## 🎯 Next Steps

After reading this overview:

1. **Choose your path**:
   - **Quick task** → [Quick Reference](SPARK_GENERATORS_QUICK_REFERENCE.md)
   - **Learning** → [Examples](SPARK_GENERATORS_EXAMPLES.md)
   - **Complex project** → [Complete Guide](SPARK_GENERATORS_GUIDE.md)

2. **Try the [Quick Start](#-quick-start)** above

3. **Explore examples** that match your use case

4. **Build incrementally** - start simple, add complexity

---

## 📄 File Summary

- **📋 SPARK_GENERATORS_QUICK_REFERENCE.md** - Commands, options, types (1-page reference)
- **📚 SPARK_GENERATORS_GUIDE.md** - Complete guide with patterns and best practices
- **🔧 SPARK_GENERATORS_EXAMPLES.md** - Working examples you can copy and run
- **📖 README_GENERATORS.md** - This overview and navigation guide

**Goal achieved: Making Spark DSL generators as easy as possible to use! 🎉**