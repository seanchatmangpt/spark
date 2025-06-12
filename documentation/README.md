# Spark Documentation Portal

> **The Complete Guide to Building DSLs with Spark** - Your single source of truth for everything Spark

[![Version](https://img.shields.io/hexpm/v/spark.svg)](https://hex.pm/packages/spark)
[![Documentation](https://img.shields.io/badge/docs-hexdocs-blue.svg)](https://hexdocs.pm/spark)
[![License](https://img.shields.io/hexpm/l/spark.svg)](LICENSE)

## 🎯 Choose Your Path

### 🚀 **New to Spark? Start Here**
- **[5-Minute Quick Start](tutorials/quick-start.md)** - Get a working DSL in 5 minutes
- **[What is Spark?](concepts/overview.md)** - Understand the core concepts
- **[Why Use Spark?](concepts/benefits.md)** - See the advantages over manual DSLs

### 🛠️ **Ready to Build? Pick Your Tool**
- **[Use Generators](tutorials/generators/)** - Build DSLs in seconds with generators
- **[Manual DSL Creation](tutorials/manual/)** - Build from scratch with full control
- **[Migrate Existing DSLs](tutorials/migration/)** - Convert existing DSLs to Spark

### 📚 **Need Reference? Find It Here**
- **[API Reference](https://hexdocs.pm/spark)** - Complete function documentation
- **[DSL Cheat Sheets](reference/cheat-sheets/)** - Quick syntax reference
- **[Generator Commands](reference/generators/)** - All available generator options

### 🎓 **Want to Master Spark?**
- **[Advanced Patterns](tutorials/advanced/)** - Enterprise-level DSL patterns
- **[Performance Optimization](guides/performance/)** - Optimize your DSLs
- **[Testing Strategies](guides/testing/)** - Comprehensive testing approaches

## 📖 Documentation Structure

```
documentation/
├── README.md                    # This portal (you are here)
├── concepts/                    # Core concepts and theory
│   ├── overview.md             # What is Spark?
│   ├── benefits.md             # Why use Spark?
│   └── architecture.md         # How Spark works
├── tutorials/                   # Step-by-step learning
│   ├── quick-start.md          # 5-minute introduction
│   ├── generators/             # Generator-based tutorials
│   ├── manual/                 # Manual DSL creation
│   ├── migration/              # Migration guides
│   └── advanced/               # Advanced patterns
├── guides/                      # Practical guides
│   ├── performance/            # Performance optimization
│   ├── testing/                # Testing strategies
│   ├── deployment/             # Production deployment
│   └── troubleshooting/        # Common issues and solutions
├── reference/                   # Reference documentation
│   ├── cheat-sheets/           # Quick reference guides
│   ├── generators/             # Generator documentation
│   └── api/                    # API reference links
└── examples/                    # Real-world examples
    ├── simple/                 # Basic examples
    ├── intermediate/           # Medium complexity
    └── advanced/               # Complex, production-ready
```

## 🎯 Learning Paths

### **Beginner Path** (30 minutes to first success)
1. [What is Spark?](concepts/overview.md) (5 min)
2. [5-Minute Quick Start](tutorials/quick-start.md) (5 min)
3. [Your First DSL with Generators](tutorials/generators/first-dsl.md) (20 min)

### **Developer Path** (2 hours to proficiency)
1. [Generator Fundamentals](tutorials/generators/fundamentals.md) (30 min)
2. [Building Real DSLs](tutorials/generators/real-world.md) (45 min)
3. [Testing Your DSLs](guides/testing/basics.md) (30 min)
4. [Performance Best Practices](guides/performance/basics.md) (15 min)

### **Architect Path** (1 day to mastery)
1. [Advanced DSL Patterns](tutorials/advanced/patterns.md) (2 hours)
2. [Enterprise Integration](tutorials/advanced/enterprise.md) (2 hours)
3. [Production Deployment](guides/deployment/production.md) (1 hour)
4. [Custom Extensions](tutorials/advanced/extensions.md) (2 hours)

## 🔍 Quick Navigation

### **By Use Case**
- **API Definition** → [API DSL Tutorial](tutorials/generators/api-dsl.md)
- **Configuration Management** → [Config DSL Tutorial](tutorials/generators/config-dsl.md)
- **Data Validation** → [Validation DSL Tutorial](tutorials/generators/validation-dsl.md)
- **Workflow Definition** → [Workflow DSL Tutorial](tutorials/generators/workflow-dsl.md)

### **By Experience Level**
- **Never used DSLs** → [Beginner Path](#beginner-path-30-minutes-to-first-success)
- **Familiar with DSLs** → [Developer Path](#developer-path-2-hours-to-proficiency)
- **DSL Expert** → [Architect Path](#architect-path-1-day-to-mastery)

### **By Problem**
- **Getting Started** → [Quick Start](tutorials/quick-start.md)
- **Troubleshooting** → [Common Issues](guides/troubleshooting/common.md)
- **Performance Issues** → [Performance Guide](guides/performance/)
- **Testing Problems** → [Testing Guide](guides/testing/)

## 🚀 Quick Commands

### **Most Common Workflows**
```bash
# Create your first DSL
mix spark.gen.dsl MyApp.MyDsl --section config --examples

# Add processing to your DSL
mix spark.gen.transformer MyApp.Process --dsl MyApp.MyDsl

# Add validation to your DSL
mix spark.gen.verifier MyApp.Validate --dsl MyApp.MyDsl

# Generate documentation
mix spark.docs MyApp.MyDsl
```

### **Get Help**
```bash
# Generator help
mix help spark.gen.dsl
mix help spark.gen.transformer
mix help spark.gen.verifier

# Documentation generation
mix help spark.docs
mix help spark.cheat_sheets
```

## 📊 Success Metrics

Our documentation aims to achieve:
- **90% success rate** for users following tutorials exactly
- **< 5 minutes** time to first working DSL
- **< 30 minutes** time to understanding core concepts
- **95% information density** (vs 30% for typical docs)

## 🤝 Contributing

Found an issue or want to improve the documentation?

1. **Report Issues** → [GitHub Issues](https://github.com/ash-project/spark/issues)
2. **Suggest Improvements** → [GitHub Discussions](https://github.com/ash-project/spark/discussions)
3. **Submit PRs** → [Contributing Guide](CONTRIBUTING.md)

## 📞 Support

- **Community** → [Elixir Forum](https://elixirforum.com/c/ash-framework)
- **Chat** → [Discord](https://discord.gg/DQHqJ8k)
- **Email** → [Support](mailto:support@ash-hq.org)

---

**Ready to build amazing DSLs?** [Start with the 5-Minute Quick Start →](tutorials/quick-start.md) 