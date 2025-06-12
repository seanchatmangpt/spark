# AutoPipeline DSL - Complete Documentation & Cheat Sheet

## Table of Contents
1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [DSL Cheat Sheet](#dsl-cheat-sheet)
4. [API Reference](#api-reference)
5. [Advanced Usage](#advanced-usage)
6. [Integration Examples](#integration-examples)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

## Overview

The AutoPipeline DSL is a comprehensive framework for defining automated development pipelines with intelligent task scheduling, dependency management, and quality assurance. Built on the Spark DSL framework, it provides a declarative way to orchestrate complex development workflows.

### Key Features

- **Declarative Task Definition**: Define tasks with dependencies, timeouts, and resource requirements
- **Pipeline Configuration**: Flexible configuration management for different environments
- **Automatic Optimization**: Intelligent task ordering and parallelization
- **Quality Assurance**: Built-in quality monitoring and validation
- **Resource Management**: Memory and CPU resource allocation and monitoring
- **Introspection**: Runtime pipeline analysis and debugging capabilities

## Quick Start

### 1. Define Your Pipeline Module

```elixir
defmodule MyProject.Pipeline do
  use Spark.Dsl, default_extensions: [extensions: [AutoPipeline.Dsl]]

  pipeline_tasks do
    task :build do
      description "Build the application"
      command "mix compile"
      timeout 60_000
      parallel false
    end

    task :test do
      description "Run tests"
      command "mix test"
      depends_on [:build]
      parallel true
    end

    task :quality_check do
      description "Run code quality checks"
      command "mix credo --strict"
      depends_on [:build]
      parallel true
    end
  end

  pipeline_configuration do
    configuration :development do
      max_parallel 2
      quality_threshold 75
      memory_limit 4096
    end

    configuration :production do
      max_parallel 8
      quality_threshold 95
      memory_limit 16384
    end
  end
end
```

### 2. Execute Your Pipeline

```elixir
# Run the full pipeline
AutoPipeline.run()

# Run with specific configuration
AutoPipeline.run(["full", "production", "90", "8"])

# Use convenience functions
AutoPipeline.run_dsl_development(85)
```

### 3. Inspect Your Pipeline

```elixir
# Get all tasks
MyProject.Pipeline.Info.tasks(MyProject.Pipeline)

# Get root tasks (no dependencies)
MyProject.Pipeline.Info.root_tasks(MyProject.Pipeline)

# Validate pipeline
MyProject.Pipeline.Info.validate_pipeline(MyProject.Pipeline)
```

## DSL Cheat Sheet

### Pipeline Tasks Section

```elixir
pipeline_tasks do
  task :task_name do
    # Required fields
    command "shell command to execute"
    
    # Optional fields
    description "Human-readable description of the task"
    timeout 30_000                      # milliseconds (default: 30_000)
    retry_count 2                       # number of retries (default: 0)
    depends_on [:other_task]            # task dependencies (default: [])
    parallel true                       # can run in parallel (default: false)
    working_directory "/path/to/dir"    # working directory
    environment %{"VAR" => "value"}     # environment variables (default: %{})
    condition "file_exists('mix.exs')"  # execution condition
  end
end
```

### Pipeline Configuration Section

```elixir
pipeline_configuration do
  configuration :config_name do
    max_parallel 4                      # max parallel tasks (default: 4)
    quality_threshold 80                # quality threshold 0-100 (default: 80)
    timeout_multiplier 1.5              # timeout multiplier (default: 1.0)
    memory_limit 8192                   # memory limit in MB (default: 8192)
    enable_optimizations true           # enable optimizations (default: true)
  end
end
```

## API Reference

### AutoPipeline Module

The main entry point for pipeline execution.

#### Functions

| Function | Description | Example |
|----------|-------------|---------|
| `run/1` | Execute pipeline with arguments | `AutoPipeline.run(["full", "development"])` |
| `run_full_pipeline/1` | Run complete pipeline | `AutoPipeline.run_full_pipeline(75)` |
| `run_dsl_development/1` | DSL-focused development | `AutoPipeline.run_dsl_development(80)` |
| `run_quality_analysis/1` | Quality analysis pipeline | `AutoPipeline.run_quality_analysis(85)` |
| `run_documentation_pipeline/1` | Documentation pipeline | `AutoPipeline.run_documentation_pipeline(70)` |
| `run_production_pipeline/1` | Production-ready pipeline | `AutoPipeline.run_production_pipeline(90)` |
| `dry_run/1` | Simulate pipeline execution | `AutoPipeline.dry_run()` |
| `list_available_commands/0` | List available commands | `AutoPipeline.list_available_commands()` |

### AutoPipeline.Info Module

Provides introspection capabilities for defined pipelines.

#### Functions

| Function | Description | Return Type |
|----------|-------------|-------------|
| `tasks/1` | Get all tasks | `[%AutoPipeline.Task{}]` |
| `task/2` | Get specific task by name | `%AutoPipeline.Task{} \| nil` |
| `root_tasks/1` | Get tasks with no dependencies | `[%AutoPipeline.Task{}]` |
| `dependent_tasks/2` | Get tasks that depend on given task | `[%AutoPipeline.Task{}]` |
| `parallel_tasks/1` | Get tasks that can run in parallel | `[%AutoPipeline.Task{}]` |
| `validate_pipeline/1` | Validate pipeline configuration | `:ok \| {:error, String.t()}` |

### Task Entity Schema

```elixir
%AutoPipeline.Task{
  name: :atom,                          # Required: unique task identifier
  description: String.t(),              # Optional: human-readable description
  command: String.t(),                  # Required: shell command to execute
  timeout: pos_integer(),               # Optional: timeout in milliseconds
  retry_count: non_neg_integer(),       # Optional: number of retries
  depends_on: [atom()],                 # Optional: list of dependency task names
  environment: %{String.t() => String.t()}, # Optional: environment variables
  working_directory: String.t(),        # Optional: working directory
  parallel: boolean(),                  # Optional: can run in parallel
  condition: String.t() | (() -> boolean()) # Optional: execution condition
}
```

### Configuration Entity Schema

```elixir
%AutoPipeline.Configuration{
  name: :atom,                          # Required: configuration identifier
  max_parallel: pos_integer(),          # Optional: max parallel tasks
  quality_threshold: 0..100,            # Optional: quality threshold percentage
  timeout_multiplier: float(),          # Optional: timeout multiplier
  memory_limit: pos_integer(),          # Optional: memory limit in MB
  enable_optimizations: boolean()       # Optional: enable optimizations
}
```

## Advanced Usage

### Complex Dependency Management

```elixir
pipeline_tasks do
  # Database tasks
  task :db_setup do
    command "mix ecto.setup"
    timeout 120_000
  end

  task :db_migrate do
    command "mix ecto.migrate"
    depends_on [:db_setup]
  end

  # Build tasks
  task :deps_get do
    command "mix deps.get"
    parallel true
  end

  task :compile do
    command "mix compile"
    depends_on [:deps_get]
  end

  # Test tasks
  task :unit_tests do
    command "mix test test/unit"
    depends_on [:compile, :db_migrate]
    parallel true
  end

  task :integration_tests do
    command "mix test test/integration"
    depends_on [:compile, :db_migrate]
    parallel true
    timeout 300_000
  end

  # Quality tasks
  task :credo do
    command "mix credo --strict"
    depends_on [:compile]
    parallel true
  end

  task :dialyzer do
    command "mix dialyzer"
    depends_on [:compile]
    parallel true
    timeout 600_000
  end

  # Documentation
  task :docs do
    command "mix docs"
    depends_on [:compile]
    parallel true
  end

  # Final validation
  task :final_check do
    command "mix validate_project"
    depends_on [:unit_tests, :integration_tests, :credo, :dialyzer, :docs]
  end
end
```

### Environment-Specific Configuration

```elixir
pipeline_configuration do
  configuration :development do
    max_parallel 2
    quality_threshold 70
    timeout_multiplier 1.0
    memory_limit 4096
    enable_optimizations false
  end

  configuration :ci do
    max_parallel 4
    quality_threshold 85
    timeout_multiplier 1.5
    memory_limit 8192
    enable_optimizations true
  end

  configuration :production do
    max_parallel 8
    quality_threshold 95
    timeout_multiplier 2.0
    memory_limit 16384
    enable_optimizations true
  end

  configuration :performance_testing do
    max_parallel 1
    quality_threshold 90
    timeout_multiplier 3.0
    memory_limit 32768
    enable_optimizations true
  end
end
```

### Conditional Task Execution

```elixir
pipeline_tasks do
  task :check_docker do
    command "docker --version"
    condition "System.find_executable('docker')"
  end

  task :docker_build do
    command "docker build -t myapp ."
    depends_on [:check_docker]
    condition fn -> File.exists?("Dockerfile") end
  end

  task :security_scan do
    command "mix deps.audit"
    condition "File.exists?('mix.lock')"
  end
end
```

## Integration Examples

### Phoenix Application Pipeline

```elixir
defmodule MyPhoenixApp.Pipeline do
  use Spark.Dsl, default_extensions: [extensions: [AutoPipeline.Dsl]]

  pipeline_tasks do
    # Dependencies
    task :deps_get do
      description "Fetch dependencies"
      command "mix deps.get"
      timeout 120_000
    end

    # Compilation
    task :compile do
      description "Compile application"
      command "mix compile"
      depends_on [:deps_get]
      timeout 90_000
    end

    # Database
    task :db_create do
      description "Create database"
      command "mix ecto.create"
      depends_on [:compile]
      condition "Mix.env() == :test"
    end

    task :db_migrate do
      description "Run database migrations"
      command "mix ecto.migrate"
      depends_on [:db_create]
    end

    # Assets
    task :assets_deploy do
      description "Deploy assets"
      command "mix assets.deploy"
      depends_on [:compile]
      parallel true
    end

    # Tests
    task :test do
      description "Run tests"
      command "mix test"
      depends_on [:compile, :db_migrate]
      parallel true
      timeout 300_000
    end

    # Quality checks
    task :format_check do
      description "Check code formatting"
      command "mix format --check-formatted"
      depends_on [:compile]
      parallel true
    end

    task :credo do
      description "Run static code analysis"
      command "mix credo --strict"
      depends_on [:compile]
      parallel true
    end

    # Documentation
    task :docs do
      description "Generate documentation"
      command "mix docs"
      depends_on [:compile]
      parallel true
    end

    # Final deployment
    task :release do
      description "Create release"
      command "mix release"
      depends_on [:test, :format_check, :credo, :assets_deploy]
    end
  end

  pipeline_configuration do
    configuration :development do
      max_parallel 2
      quality_threshold 75
      memory_limit 4096
    end

    configuration :production do
      max_parallel 6
      quality_threshold 90
      memory_limit 12288
    end
  end
end
```

### Library Development Pipeline

```elixir
defmodule MyLibrary.Pipeline do
  use Spark.Dsl, default_extensions: [extensions: [AutoPipeline.Dsl]]

  pipeline_tasks do
    task :deps_get do
      command "mix deps.get"
    end

    task :compile do
      command "mix compile"
      depends_on [:deps_get]
    end

    task :test do
      command "mix test"
      depends_on [:compile]
      parallel true
    end

    task :property_test do
      command "mix test --only property"
      depends_on [:compile]
      parallel true
      timeout 600_000
    end

    task :dialyzer do
      command "mix dialyzer"
      depends_on [:compile]
      parallel true
      timeout 300_000
    end

    task :credo do
      command "mix credo --strict"
      depends_on [:compile]
      parallel true
    end

    task :docs do
      command "mix docs"
      depends_on [:compile]
      parallel true
    end

    task :hex_audit do
      command "mix hex.audit"
      depends_on [:deps_get]
      parallel true
    end

    task :format_check do
      command "mix format --check-formatted"
      parallel true
    end

    task :package do
      command "mix hex.build"
      depends_on [:test, :property_test, :dialyzer, :credo, :docs, :hex_audit, :format_check]
    end
  end
end
```

## Best Practices

### 1. Task Organization

**Group Related Tasks**
```elixir
# Group by functionality
pipeline_tasks do
  # Build phase
  task :deps_get, do: command("mix deps.get")
  task :compile, do: command("mix compile")
  
  # Test phase
  task :unit_tests, do: command("mix test test/unit")
  task :integration_tests, do: command("mix test test/integration")
  
  # Quality phase
  task :credo, do: command("mix credo")
  task :dialyzer, do: command("mix dialyzer")
end
```

**Use Descriptive Names**
```elixir
# Good
task :run_unit_tests do
  command "mix test test/unit"
end

# Avoid
task :t1 do
  command "mix test test/unit"
end
```

### 2. Dependency Management

**Minimize Dependencies**
```elixir
# Good - minimal dependencies
task :test do
  depends_on [:compile]
end

# Avoid - unnecessary dependencies
task :test do
  depends_on [:deps_get, :compile, :format]
end
```

**Use Parallel Execution**
```elixir
# Independent tasks can run in parallel
task :credo do
  depends_on [:compile]
  parallel true
end

task :dialyzer do
  depends_on [:compile]
  parallel true
end
```

### 3. Configuration Management

**Environment-Specific Settings**
```elixir
pipeline_configuration do
  configuration :development do
    max_parallel 2          # Limited resources
    quality_threshold 70    # Relaxed standards
  end

  configuration :ci do
    max_parallel 4          # CI resources
    quality_threshold 85    # Stricter standards
  end
end
```

### 4. Error Handling

**Use Appropriate Timeouts**
```elixir
task :quick_test do
  command "mix test test/unit"
  timeout 60_000      # 1 minute
end

task :integration_test do
  command "mix test test/integration"
  timeout 600_000     # 10 minutes
end
```

**Configure Retries for Flaky Tasks**
```elixir
task :external_service_test do
  command "mix test test/external"
  retry_count 2       # Retry twice on failure
  timeout 120_000     # Allow extra time
end
```

### 5. Resource Management

**Monitor Memory Usage**
```elixir
pipeline_configuration do
  configuration :memory_intensive do
    max_parallel 2          # Reduce parallelism
    memory_limit 16384      # Increase memory limit
    timeout_multiplier 2.0  # Allow more time
  end
end
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Circular Dependencies

**Problem**: Tasks have circular dependencies
```
{:error, "Circular dependency detected: [:task_a, :task_b, :task_a]"}
```

**Solution**: Review and simplify dependencies
```elixir
# Before (circular)
task :task_a, depends_on: [:task_b]
task :task_b, depends_on: [:task_a]

# After (fixed)
task :shared_setup, command: "mix setup"
task :task_a, depends_on: [:shared_setup]
task :task_b, depends_on: [:shared_setup]
```

#### 2. Missing Dependencies

**Problem**: Task depends on non-existent task
```
{:error, "Invalid dependencies found: [{:task_a, :nonexistent_task}]"}
```

**Solution**: Ensure all dependencies exist
```elixir
# Add the missing task or remove the dependency
task :nonexistent_task do
  command "echo 'Task exists now'"
end
```

#### 3. Memory Limit Exceeded

**Problem**: Pipeline exceeds memory limits

**Solution**: Adjust configuration
```elixir
pipeline_configuration do
  configuration :high_memory do
    max_parallel 1          # Reduce parallelism
    memory_limit 32768      # Increase limit
  end
end
```

#### 4. Task Timeouts

**Problem**: Tasks timing out frequently

**Solution**: Increase timeouts or optimize commands
```elixir
task :slow_task do
  command "mix slow_operation"
  timeout 1_800_000       # 30 minutes
  retry_count 1           # One retry
end
```

### Debugging Tips

#### 1. Use Dry Run
```elixir
# Preview pipeline execution without running
AutoPipeline.dry_run(["full", "development"])
```

#### 2. Validate Pipeline
```elixir
# Check for configuration issues
case MyProject.Pipeline.Info.validate_pipeline(MyProject.Pipeline) do
  :ok -> IO.puts("Pipeline is valid")
  {:error, reason} -> IO.puts("Pipeline error: #{reason}")
end
```

#### 3. Inspect Task Dependencies
```elixir
# Check task relationships
tasks = MyProject.Pipeline.Info.tasks(MyProject.Pipeline)
Enum.each(tasks, fn task ->
  IO.puts("#{task.name} depends on: #{inspect(task.depends_on)}")
end)
```

#### 4. Monitor Execution
```elixir
# Enable verbose logging
Application.put_env(:auto_pipeline, :log_level, :debug)
```

## Transformers and Verifiers

### Available Transformers

1. **ValidateDependencies**: Ensures task dependencies are valid and acyclic
2. **GenerateTaskMetadata**: Adds metadata to tasks for optimization
3. **OptimizeExecutionOrder**: Optimizes task execution order for efficiency

### Available Verifiers

1. **EnsureTasksExecutable**: Validates that all tasks can be executed
2. **ValidateResourceRequirements**: Checks resource allocation and constraints

### Custom Transformers

You can create custom transformers to modify the DSL at compile time:

```elixir
defmodule MyProject.CustomTransformer do
  use Spark.Dsl.Transformer

  def transform(dsl_state) do
    # Your transformation logic here
    {:ok, dsl_state}
  end
end
```

## Integration with Existing Tools

### CI/CD Integration

```yaml
# GitHub Actions example
- name: Run AutoPipeline
  run: mix run -e "AutoPipeline.run(['full', 'ci', '85', '4'])"
```

### Docker Integration

```dockerfile
# Add to Dockerfile
RUN mix run -e "AutoPipeline.run(['full', 'production', '90', '8'])"
```

### IDE Integration

Configure your IDE to use AutoPipeline for project tasks:

```json
{
  "tasks": [
    {
      "label": "AutoPipeline Development",
      "command": "mix",
      "args": ["run", "-e", "AutoPipeline.run_dsl_development(80)"]
    }
  ]
}
```

This comprehensive documentation provides everything needed to effectively use the AutoPipeline DSL system, from basic usage to advanced integration patterns and troubleshooting guidance.