# AutoPipeline DSL - Quick Reference & Cheat Sheet

## Basic DSL Structure

```elixir
defmodule MyPipeline do
  use Spark.Dsl, default_extensions: [extensions: [AutoPipeline.Dsl]]

  pipeline_tasks do
    # Define tasks here
  end

  pipeline_configuration do
    # Define configurations here
  end
end
```

## Task Definition - Quick Reference

### Basic Task
```elixir
task :task_name do
  command "shell command"
end
```

### Complete Task with All Options
```elixir
task :comprehensive_task do
  description "What this task does"
  command "shell command to execute"
  timeout 30_000                      # milliseconds
  retry_count 2                       # number of retries
  depends_on [:other_task]            # dependencies
  parallel true                       # parallel execution
  working_directory "/path/to/dir"    # working directory
  environment %{"VAR" => "value"}     # environment variables
  condition "File.exists?('file')"   # execution condition
end
```

### Task Schema Quick Reference
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | `:atom` | **required** | Unique task identifier |
| `description` | `String.t()` | `nil` | Human-readable description |
| `command` | `String.t()` | **required** | Shell command to execute |
| `timeout` | `pos_integer()` | `30_000` | Timeout in milliseconds |
| `retry_count` | `non_neg_integer()` | `0` | Number of retries on failure |
| `depends_on` | `[atom()]` | `[]` | List of dependency task names |
| `environment` | `%{String.t() => String.t()}` | `%{}` | Environment variables |
| `working_directory` | `String.t()` | `nil` | Working directory for execution |
| `parallel` | `boolean()` | `false` | Can run in parallel with others |
| `condition` | `String.t() \| (() -> boolean())` | `nil` | Execution condition |

## Configuration Definition - Quick Reference

### Basic Configuration
```elixir
configuration :config_name do
  max_parallel 4
  quality_threshold 80
end
```

### Complete Configuration with All Options
```elixir
configuration :comprehensive_config do
  max_parallel 8                      # max parallel tasks
  quality_threshold 85                # quality threshold (0-100)
  timeout_multiplier 1.5              # timeout multiplier
  memory_limit 8192                   # memory limit in MB
  enable_optimizations true           # enable optimizations
end
```

### Configuration Schema Quick Reference
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | `:atom` | **required** | Configuration identifier |
| `max_parallel` | `pos_integer()` | `4` | Maximum parallel tasks |
| `quality_threshold` | `0..100` | `80` | Quality threshold percentage |
| `timeout_multiplier` | `float()` | `1.0` | Multiplier for task timeouts |
| `memory_limit` | `pos_integer()` | `8192` | Memory limit in MB |
| `enable_optimizations` | `boolean()` | `true` | Enable pipeline optimizations |

## Execution Commands - Quick Reference

### Basic Execution
```elixir
# Run with defaults
AutoPipeline.run()

# Run with arguments
AutoPipeline.run(["scope", "mode", "threshold", "parallel"])
```

### Convenience Functions
```elixir
AutoPipeline.run_full_pipeline(75)           # Complete pipeline
AutoPipeline.run_dsl_development(80)         # DSL development focus
AutoPipeline.run_quality_analysis(85)        # Quality analysis
AutoPipeline.run_documentation_pipeline(70)  # Documentation focus
AutoPipeline.run_production_pipeline(90)     # Production deployment

AutoPipeline.dry_run()                       # Simulate execution
AutoPipeline.list_available_commands()       # List commands
```

### Execution Parameters
| Parameter | Values | Description |
|-----------|--------|-------------|
| **Scope** | `"full"`, `"dsl-only"`, `"analysis-only"`, `"docs-only"` | Pipeline scope |
| **Mode** | `"development"`, `"production"`, `"research"`, `"maintenance"` | Execution mode |
| **Threshold** | `"0"` to `"100"` | Quality threshold |
| **Parallel** | `"1"` to `"N"` | Max parallel tasks |

## Introspection Functions - Quick Reference

### Basic Introspection
```elixir
# Get all tasks
MyPipeline.Info.tasks(MyPipeline)

# Get specific task
MyPipeline.Info.task(MyPipeline, :task_name)

# Get root tasks (no dependencies)
MyPipeline.Info.root_tasks(MyPipeline)

# Get dependent tasks
MyPipeline.Info.dependent_tasks(MyPipeline, :task_name)

# Get parallel tasks
MyPipeline.Info.parallel_tasks(MyPipeline)

# Validate pipeline
MyPipeline.Info.validate_pipeline(MyPipeline)
```

## Common Patterns - Quick Reference

### Sequential Tasks
```elixir
task :step1, do: command("first command")
task :step2, do: command("second command"), depends_on: [:step1]
task :step3, do: command("third command"), depends_on: [:step2]
```

### Parallel Tasks
```elixir
task :compile, do: command("mix compile")
task :test1, do: command("mix test test/unit"), depends_on: [:compile], parallel: true
task :test2, do: command("mix test test/integration"), depends_on: [:compile], parallel: true
```

### Diamond Dependency
```elixir
task :setup, do: command("mix setup")
task :build, do: command("mix compile"), depends_on: [:setup]
task :test, do: command("mix test"), depends_on: [:setup]
task :deploy, do: command("mix deploy"), depends_on: [:build, :test]
```

### Conditional Execution
```elixir
# String condition
task :docker_task do
  command "docker build ."
  condition "File.exists?('Dockerfile')"
end

# Function condition
task :prod_task do
  command "mix release"
  condition fn -> Mix.env() == :prod end
end

# Environment condition
task :ci_task do
  command "mix ci_suite"
  condition "System.get_env('CI') == 'true'"
end
```

## Environment-Specific Examples

### Development Environment
```elixir
configuration :development do
  max_parallel 2
  quality_threshold 70
  timeout_multiplier 1.0
  memory_limit 4096
  enable_optimizations false
end
```

### CI Environment
```elixir
configuration :ci do
  max_parallel 4
  quality_threshold 85
  timeout_multiplier 1.5
  memory_limit 8192
  enable_optimizations true
end
```

### Production Environment
```elixir
configuration :production do
  max_parallel 8
  quality_threshold 95
  timeout_multiplier 2.0
  memory_limit 16384
  enable_optimizations true
end
```

## Common Task Types - Quick Reference

### Build Tasks
```elixir
task :deps_get, do: command("mix deps.get"), timeout: 300_000
task :compile, do: command("mix compile"), depends_on: [:deps_get]
task :release, do: command("mix release"), depends_on: [:compile]
```

### Test Tasks
```elixir
task :unit_tests, do: command("mix test test/unit"), parallel: true
task :integration_tests, do: command("mix test test/integration"), parallel: true
task :e2e_tests, do: command("mix test test/e2e"), timeout: 1_800_000
```

### Quality Tasks
```elixir
task :format_check, do: command("mix format --check-formatted"), parallel: true
task :credo, do: command("mix credo --strict"), parallel: true
task :dialyzer, do: command("mix dialyzer"), parallel: true, timeout: 600_000
```

### Documentation Tasks
```elixir
task :docs, do: command("mix docs"), parallel: true
task :hex_docs, do: command("mix hex.publish docs"), depends_on: [:docs]
```

### Deployment Tasks
```elixir
task :docker_build, do: command("docker build -t app ."), timeout: 600_000
task :k8s_deploy, do: command("kubectl apply -f k8s/"), depends_on: [:docker_build]
```

## Error Handling - Quick Reference

### Retry Configuration
```elixir
task :flaky_task do
  command "external_api_call"
  retry_count 3
  timeout 60_000
end
```

### Timeout Configuration
```elixir
# Short timeout for quick tasks
task :quick_check, do: command("mix check"), timeout: 10_000

# Long timeout for slow tasks
task :integration_test, do: command("mix test --slow"), timeout: 1_800_000
```

### Environment Variables
```elixir
task :env_specific do
  command "deploy_script"
  environment %{
    "DEPLOY_ENV" => "staging",
    "API_KEY" => System.get_env("STAGING_API_KEY")
  }
end
```

## Debugging - Quick Reference

### Validation
```elixir
# Check pipeline validity
case MyPipeline.Info.validate_pipeline(MyPipeline) do
  :ok -> IO.puts("Pipeline is valid")
  {:error, reason} -> IO.puts("Error: #{reason}")
end
```

### Dry Run
```elixir
# Test pipeline without execution
AutoPipeline.dry_run(["full", "development"])
```

### Task Inspection
```elixir
# List all tasks
MyPipeline.Info.tasks(MyPipeline)
|> Enum.map(& &1.name)

# Check dependencies
MyPipeline.Info.tasks(MyPipeline)
|> Enum.map(&{&1.name, &1.depends_on})
```

## Performance Tips - Quick Reference

### Optimize Parallelism
```elixir
# CPU-intensive: sequential
task :heavy_compile, do: command("mix compile --all"), parallel: false

# I/O-intensive: parallel
task :file_processing, do: command("process_files"), parallel: true
```

### Resource Management
```elixir
configuration :optimized do
  max_parallel 6  # Based on CPU cores
  memory_limit 16384  # Based on available RAM
  timeout_multiplier 1.5  # Account for system load
end
```

### Conditional Tasks
```elixir
# Skip unnecessary work
task :frontend_build do
  command "npm run build"
  condition "File.exists?('package.json')"
end
```

## Common Pitfalls - Quick Reference

### ❌ Avoid These
```elixir
# Circular dependencies
task :a, depends_on: [:b]
task :b, depends_on: [:a]  # ❌ Circular!

# Non-existent dependencies
task :test, depends_on: [:nonexistent]  # ❌ Will fail!

# Overly complex dependencies
task :final, depends_on: [:a, :b, :c, :d, :e]  # ❌ Too complex!
```

### ✅ Best Practices
```elixir
# Clear dependency chains
task :build, do: command("mix compile")
task :test, depends_on: [:build]
task :deploy, depends_on: [:test]

# Parallel where possible
task :unit_tests, depends_on: [:build], parallel: true
task :lint, depends_on: [:build], parallel: true

# Descriptive names and descriptions
task :run_integration_tests do
  description "Run integration tests against staging environment"
  command "mix test test/integration"
  depends_on: [:build]
  timeout 600_000
end
```

## Quick Setup Template

```elixir
defmodule MyProject.Pipeline do
  use Spark.Dsl, default_extensions: [extensions: [AutoPipeline.Dsl]]

  pipeline_tasks do
    # 1. Dependencies
    task :deps_get do
      description "Fetch dependencies"
      command "mix deps.get"
      timeout 300_000
    end

    # 2. Build
    task :compile do
      description "Compile application"
      command "mix compile"
      depends_on [:deps_get]
    end

    # 3. Test (parallel)
    task :test do
      description "Run tests"
      command "mix test"
      depends_on [:compile]
      parallel true
    end

    # 4. Quality (parallel)
    task :quality do
      description "Run quality checks"
      command "mix credo"
      depends_on [:compile]
      parallel true
    end

    # 5. Deploy
    task :deploy do
      description "Deploy application"
      command "mix deploy"
      depends_on [:test, :quality]
    end
  end

  pipeline_configuration do
    configuration :development do
      max_parallel 2
      quality_threshold 75
    end

    configuration :production do
      max_parallel 6
      quality_threshold 90
    end
  end
end
```

## Usage Examples

```elixir
# Run the pipeline
AutoPipeline.run(["full", "development", "75", "2"])

# Or use convenience functions
AutoPipeline.run_dsl_development(80)

# Check what would run
AutoPipeline.dry_run()

# Inspect the pipeline
MyProject.Pipeline.Info.validate_pipeline(MyProject.Pipeline)
```

This quick reference provides all the essential information needed to effectively use the AutoPipeline DSL system.