# AutoPipeline DSL - Complete API Documentation

## Table of Contents
1. [Core Modules](#core-modules)
2. [DSL Extension](#dsl-extension)
3. [Entity Definitions](#entity-definitions)
4. [Transformers](#transformers)
5. [Verifiers](#verifiers)
6. [Info Module](#info-module)
7. [Configuration Management](#configuration-management)
8. [Execution Engine](#execution-engine)
9. [Quality Assurance](#quality-assurance)
10. [Utilities](#utilities)

## Core Modules

### AutoPipeline

The main entry point for the AutoPipeline DSL system.

**Module**: `AutoPipeline`
**File**: `/Users/sac/dev/spark/lib/auto_pipeline.ex`

#### Functions

##### `run/1`
Executes the pipeline with the given arguments.

```elixir
@spec run([String.t()]) :: {:ok, term()} | {:error, term()}
```

**Parameters:**
- `args` - List of string arguments `[scope, mode, quality_threshold, max_parallel]`

**Examples:**
```elixir
AutoPipeline.run(["full", "development", "75", "4"])
AutoPipeline.run(["dsl-only", "production", "90", "8"])
```

**Returns:**
- `{:ok, result}` - Success with execution result
- `{:error, reason}` - Failure with error reason

---

##### `run_full_pipeline/1`
Runs the complete automated development pipeline.

```elixir
@spec run_full_pipeline(integer()) :: {:ok, term()} | {:error, term()}
```

**Parameters:**
- `quality_threshold` - Quality threshold percentage (0-100), default: 75

**Example:**
```elixir
AutoPipeline.run_full_pipeline(85)
```

---

##### `run_dsl_development/1`
Runs DSL-focused development pipeline.

```elixir
@spec run_dsl_development(integer()) :: {:ok, term()} | {:error, term()}
```

**Parameters:**
- `quality_threshold` - Quality threshold percentage (0-100), default: 80

**Example:**
```elixir
AutoPipeline.run_dsl_development(80)
```

---

##### `run_quality_analysis/1`
Runs comprehensive quality analysis pipeline.

```elixir
@spec run_quality_analysis(integer()) :: {:ok, term()} | {:error, term()}
```

**Parameters:**
- `quality_threshold` - Quality threshold percentage (0-100), default: 85

---

##### `run_documentation_pipeline/1`
Runs documentation-focused pipeline.

```elixir
@spec run_documentation_pipeline(integer()) :: {:ok, term()} | {:error, term()}
```

**Parameters:**
- `quality_threshold` - Quality threshold percentage (0-100), default: 70

---

##### `run_production_pipeline/1`
Runs production-ready pipeline with high quality standards.

```elixir
@spec run_production_pipeline(integer()) :: {:ok, term()} | {:error, term()}
```

**Parameters:**
- `quality_threshold` - Quality threshold percentage (0-100), default: 90

---

##### `dry_run/1`
Simulates pipeline execution without actually running tasks.

```elixir
@spec dry_run([String.t()]) :: {:ok, term()}
```

**Parameters:**
- `args` - Same format as `run/1`

**Example:**
```elixir
AutoPipeline.dry_run(["full", "development"])
```

---

##### `list_available_commands/0`
Lists all available commands in the current environment.

```elixir
@spec list_available_commands() :: [String.t()]
```

**Returns:**
List of available command strings.

---

##### `show_help/0`
Displays help information for the AutoPipeline system.

```elixir
@spec show_help() :: :ok
```

## DSL Extension

### AutoPipeline.Dsl

The main DSL extension that defines the pipeline syntax.

**Module**: `AutoPipeline.Dsl`
**File**: `/Users/sac/dev/spark/lib/auto_pipeline/dsl.ex`

#### Sections

##### pipeline_tasks
Defines the section for pipeline task definitions.

**Entities:** `[:task]`

**Example:**
```elixir
pipeline_tasks do
  task :build do
    command "mix compile"
    timeout 60_000
  end
end
```

##### pipeline_configuration
Defines the section for pipeline configuration.

**Entities:** `[:configuration]`

**Example:**
```elixir
pipeline_configuration do
  configuration :development do
    max_parallel 4
    quality_threshold 80
  end
end
```

#### Transformers

The DSL includes these transformers in execution order:

1. `AutoPipeline.Transformers.ValidateDependencies`
2. `AutoPipeline.Transformers.GenerateTaskMetadata`
3. `AutoPipeline.Transformers.OptimizeExecutionOrder`

#### Verifiers

The DSL includes these verifiers:

1. `AutoPipeline.Verifiers.EnsureTasksExecutable`
2. `AutoPipeline.Verifiers.ValidateResourceRequirements`

## Entity Definitions

### AutoPipeline.Task

Represents a single task in the pipeline.

**Module**: `AutoPipeline.Task`
**File**: `/Users/sac/dev/spark/lib/auto_pipeline/task.ex`

#### Schema

```elixir
%AutoPipeline.Task{
  name: atom(),                          # Required: unique identifier
  description: String.t() | nil,         # Optional: human-readable description
  command: String.t(),                   # Required: shell command
  timeout: pos_integer(),                # Optional: timeout in ms (default: 30_000)
  retry_count: non_neg_integer(),        # Optional: retries (default: 0)
  depends_on: [atom()],                  # Optional: dependencies (default: [])
  environment: %{String.t() => String.t()}, # Optional: env vars (default: %{})
  working_directory: String.t() | nil,   # Optional: working directory
  parallel: boolean(),                   # Optional: parallel execution (default: false)
  condition: String.t() | (() -> boolean()) | nil # Optional: execution condition
}
```

#### Field Descriptions

| Field | Type | Default | Validation | Description |
|-------|------|---------|------------|-------------|
| `name` | `:atom` | **required** | Must be unique | Task identifier |
| `description` | `String.t()` | `nil` | - | Human-readable description |
| `command` | `String.t()` | **required** | Non-empty string | Shell command to execute |
| `timeout` | `pos_integer()` | `30_000` | > 0 | Timeout in milliseconds |
| `retry_count` | `non_neg_integer()` | `0` | >= 0 | Number of retries on failure |
| `depends_on` | `[atom()]` | `[]` | Valid task names | Task dependencies |
| `environment` | `%{String.t() => String.t()}` | `%{}` | String keys and values | Environment variables |
| `working_directory` | `String.t()` | `nil` | Valid directory path | Working directory |
| `parallel` | `boolean()` | `false` | true/false | Can run in parallel |
| `condition` | `String.t() \| (() -> boolean())` | `nil` | Valid expression/function | Execution condition |

---

### AutoPipeline.Configuration

Represents pipeline configuration settings.

**Module**: `AutoPipeline.Configuration`
**File**: `/Users/sac/dev/spark/lib/auto_pipeline/configuration.ex`

#### Schema

```elixir
%AutoPipeline.Configuration{
  name: atom(),                    # Required: configuration identifier
  max_parallel: pos_integer(),     # Optional: max parallel tasks (default: 4)
  quality_threshold: 0..100,       # Optional: quality threshold (default: 80)
  timeout_multiplier: float(),     # Optional: timeout multiplier (default: 1.0)
  memory_limit: pos_integer(),     # Optional: memory limit MB (default: 8192)
  enable_optimizations: boolean()  # Optional: enable optimizations (default: true)
}
```

#### Field Descriptions

| Field | Type | Default | Range | Description |
|-------|------|---------|--------|-------------|
| `name` | `:atom` | **required** | - | Configuration identifier |
| `max_parallel` | `pos_integer()` | `4` | 1-∞ | Maximum parallel tasks |
| `quality_threshold` | `integer()` | `80` | 0-100 | Quality threshold percentage |
| `timeout_multiplier` | `float()` | `1.0` | > 0.0 | Multiplier for task timeouts |
| `memory_limit` | `pos_integer()` | `8192` | 1-∞ | Memory limit in MB |
| `enable_optimizations` | `boolean()` | `true` | true/false | Enable pipeline optimizations |

## Transformers

Transformers modify the DSL at compile time to add functionality and optimize execution.

### AutoPipeline.Transformers.ValidateDependencies

Validates task dependencies and detects circular dependencies.

**Module**: `AutoPipeline.Transformers.ValidateDependencies`
**File**: `/Users/sac/dev/spark/lib/auto_pipeline/transformers/validate_dependencies.ex`

#### Functions

##### `transform/1`
Validates the dependency graph of all tasks.

```elixir
@spec transform(Spark.Dsl.t()) :: {:ok, Spark.Dsl.t()} | {:error, term()}
```

**Validations:**
- Checks for circular dependencies
- Ensures all dependencies reference existing tasks
- Validates dependency graph completeness

**Errors:**
- `{:error, "Circular dependency detected: [...]"}`
- `{:error, "Unknown dependency: task_name -> unknown_task"}`

---

### AutoPipeline.Transformers.GenerateTaskMetadata

Generates metadata for tasks to enable optimization and monitoring.

**Module**: `AutoPipeline.Transformers.GenerateTaskMetadata`
**File**: `/Users/sac/dev/spark/lib/auto_pipeline/transformers/generate_task_metadata.ex`

#### Functions

##### `transform/1`
Adds metadata to tasks for optimization purposes.

```elixir
@spec transform(Spark.Dsl.t()) :: {:ok, Spark.Dsl.t()}
```

**Generated Metadata:**
- Task execution estimates
- Resource requirements
- Command complexity analysis
- Performance characteristics

---

### AutoPipeline.Transformers.OptimizeExecutionOrder

Optimizes the execution order of tasks based on dependencies and resource requirements.

**Module**: `AutoPipeline.Transformers.OptimizeExecutionOrder`
**File**: `/Users/sac/dev/spark/lib/auto_pipeline/transformers/optimize_execution_order.ex`

#### Functions

##### `transform/1`
Optimizes task execution order for performance.

```elixir
@spec transform(Spark.Dsl.t()) :: {:ok, Spark.Dsl.t()}
```

**Optimizations:**
- Topological sorting of dependencies
- Resource-aware scheduling
- Parallel execution planning
- Critical path analysis

## Verifiers

Verifiers validate the final DSL structure to ensure correctness and executability.

### AutoPipeline.Verifiers.EnsureTasksExecutable

Ensures all tasks can be executed in the current environment.

**Module**: `AutoPipeline.Verifiers.EnsureTasksExecutable`
**File**: `/Users/sac/dev/spark/lib/auto_pipeline/verifiers/ensure_tasks_executable.ex`

#### Functions

##### `verify/1`
Validates that all tasks are executable.

```elixir
@spec verify(Spark.Dsl.t()) :: :ok | {:error, term()}
```

**Validations:**
- Command availability in PATH
- Working directory existence
- Environment variable validity
- Condition syntax validation

**Errors:**
- `{:error, "Command not found: command_name"}`
- `{:error, "Working directory does not exist: /path"}`
- `{:error, "Invalid condition syntax: condition_string"}`

---

### AutoPipeline.Verifiers.ValidateResourceRequirements

Validates resource allocation and detects potential conflicts.

**Module**: `AutoPipeline.Verifiers.ValidateResourceRequirements`
**File**: `/Users/sac/dev/spark/lib/auto_pipeline/verifiers/validate_resource_requirements.ex`

#### Functions

##### `verify/1`
Validates resource requirements across all tasks.

```elixir
@spec verify(Spark.Dsl.t()) :: :ok | {:error, term()}
```

**Validations:**
- Memory allocation within limits
- Resource conflict detection
- Parallel execution feasibility
- System resource availability

**Errors:**
- `{:error, "Memory limit exceeded: required X MB, limit Y MB"}`
- `{:error, "Resource conflict detected between tasks: [...]"}`

## Info Module

### AutoPipeline.Info

Provides introspection capabilities for defined pipelines.

**Module**: `AutoPipeline.Info`
**File**: `/Users/sac/dev/spark/lib/auto_pipeline/info.ex`

#### Functions

##### `tasks/1`
Returns all tasks defined in the pipeline.

```elixir
@spec tasks(module()) :: [%AutoPipeline.Task{}]
```

**Parameters:**
- `module` - The module containing the pipeline definition

**Returns:**
List of all task structs.

**Example:**
```elixir
tasks = MyPipeline.Info.tasks(MyPipeline)
```

---

##### `task/2`
Returns a specific task by name.

```elixir
@spec task(module(), atom()) :: %AutoPipeline.Task{} | nil
```

**Parameters:**
- `module` - The module containing the pipeline definition
- `name` - The task name to retrieve

**Returns:**
Task struct or `nil` if not found.

**Example:**
```elixir
build_task = MyPipeline.Info.task(MyPipeline, :build)
```

---

##### `root_tasks/1`
Returns tasks that have no dependencies.

```elixir
@spec root_tasks(module()) :: [%AutoPipeline.Task{}]
```

**Parameters:**
- `module` - The module containing the pipeline definition

**Returns:**
List of tasks with empty `depends_on` lists.

**Example:**
```elixir
root_tasks = MyPipeline.Info.root_tasks(MyPipeline)
```

---

##### `dependent_tasks/2`
Returns tasks that depend on the given task.

```elixir
@spec dependent_tasks(module(), atom()) :: [%AutoPipeline.Task{}]
```

**Parameters:**
- `module` - The module containing the pipeline definition
- `task_name` - The task name to find dependents for

**Returns:**
List of tasks that depend on the given task.

**Example:**
```elixir
dependents = MyPipeline.Info.dependent_tasks(MyPipeline, :compile)
```

---

##### `parallel_tasks/1`
Returns tasks that can run in parallel.

```elixir
@spec parallel_tasks(module()) :: [%AutoPipeline.Task{}]
```

**Parameters:**
- `module` - The module containing the pipeline definition

**Returns:**
List of tasks with `parallel: true`.

---

##### `validate_pipeline/1`
Validates the pipeline configuration and returns any errors.

```elixir
@spec validate_pipeline(module()) :: :ok | {:error, String.t()}
```

**Parameters:**
- `module` - The module containing the pipeline definition

**Returns:**
- `:ok` - Pipeline is valid
- `{:error, reason}` - Pipeline has errors

**Validations:**
- No circular dependencies
- All dependencies exist
- Task configuration validity

**Example:**
```elixir
case MyPipeline.Info.validate_pipeline(MyPipeline) do
  :ok -> IO.puts("Pipeline is valid")
  {:error, reason} -> IO.puts("Error: #{reason}")
end
```

## Configuration Management

### AutoPipeline.CommandInterface

Handles command-line interface and execution coordination.

**Module**: `AutoPipeline.CommandInterface`
**File**: `/Users/sac/dev/spark/lib/auto_pipeline/command_interface.ex`

#### Functions

##### `run/1`
Main execution entry point.

```elixir
@spec run([String.t()]) :: {:ok, term()} | {:error, term()}
```

##### `dry_run/1`
Simulates execution without running commands.

```elixir
@spec dry_run([String.t()]) :: {:ok, term()}
```

##### `list_available_commands/0`
Lists all available commands.

```elixir
@spec list_available_commands() :: [String.t()]
```

## Execution Engine

### AutoPipeline.ExecutionEngine

Core execution engine for running pipeline tasks.

**Module**: `AutoPipeline.ExecutionEngine`
**File**: `/Users/sac/dev/spark/lib/auto_pipeline/execution_engine.ex`

#### Functions

##### `execute_pipeline/2`
Executes a complete pipeline with the given configuration.

```elixir
@spec execute_pipeline([%AutoPipeline.Task{}], %AutoPipeline.Configuration{}) :: 
  {:ok, %AutoPipeline.ExecutionResult{}} | {:error, term()}
```

**Parameters:**
- `tasks` - List of tasks to execute
- `configuration` - Pipeline configuration

**Returns:**
- `{:ok, result}` - Successful execution with results
- `{:error, reason}` - Execution failure

---

##### `execute_task/2`
Executes a single task.

```elixir
@spec execute_task(%AutoPipeline.Task{}, map()) :: 
  {:ok, %AutoPipeline.ExecutionResult{}} | {:error, term()}
```

**Parameters:**
- `task` - Task to execute
- `context` - Execution context

## Quality Assurance

### AutoPipeline.QualityAssurance

Provides quality monitoring and validation capabilities.

**Module**: `AutoPipeline.QualityAssurance`
**File**: `/Users/sac/dev/spark/lib/auto_pipeline/quality_assurance.ex`

#### Functions

##### `perform_quality_checkpoint/2`
Performs a quality checkpoint during pipeline execution.

```elixir
@spec perform_quality_checkpoint(map(), %AutoPipeline.Configuration{}) :: 
  {:ok, map()} | {:error, term()}
```

**Parameters:**
- `metrics` - Current quality metrics
- `configuration` - Pipeline configuration

**Returns:**
- `{:ok, updated_metrics}` - Quality check passed
- `{:error, quality_issues}` - Quality check failed

---

##### `generate_quality_report/1`
Generates a comprehensive quality report.

```elixir
@spec generate_quality_report(map()) :: map()
```

**Parameters:**
- `execution_results` - Results from pipeline execution

**Returns:**
Quality report map with metrics and recommendations.

## Utilities

### AutoPipeline.CommandDiscovery

Discovers and analyzes available commands in the environment.

**Module**: `AutoPipeline.CommandDiscovery`
**File**: `/Users/sac/dev/spark/lib/auto_pipeline/command_discovery.ex`

#### Functions

##### `discover_available_commands/0`
Discovers all available commands in the current environment.

```elixir
@spec discover_available_commands() :: [map()]
```

**Returns:**
List of command maps with metadata.

---

##### `analyze_command_dependencies/1`
Analyzes dependencies between discovered commands.

```elixir
@spec analyze_command_dependencies([map()]) :: map()
```

**Parameters:**
- `commands` - List of command maps

**Returns:**
Dependency analysis map.

## Error Handling

### Common Error Types

#### DSL Validation Errors
```elixir
{:error, %Spark.Error.DslError{
  module: module(),
  message: String.t(),
  path: [atom()]
}}
```

#### Task Execution Errors
```elixir
{:error, %AutoPipeline.ExecutionError{
  task: atom(),
  command: String.t(),
  exit_code: integer(),
  output: String.t()
}}
```

#### Dependency Errors
```elixir
{:error, %AutoPipeline.DependencyError{
  task: atom(),
  missing_dependencies: [atom()],
  circular_dependencies: [atom()]
}}
```

## Usage Examples

### Basic Pipeline Definition
```elixir
defmodule MyApp.Pipeline do
  use Spark.Dsl, default_extensions: [extensions: [AutoPipeline.Dsl]]

  pipeline_tasks do
    task :compile do
      description "Compile the application"
      command "mix compile"
      timeout 90_000
    end

    task :test do
      description "Run tests"
      command "mix test"
      depends_on [:compile]
      parallel true
    end
  end

  pipeline_configuration do
    configuration :development do
      max_parallel 2
      quality_threshold 75
    end
  end
end
```

### Pipeline Execution
```elixir
# Execute the pipeline
{:ok, result} = AutoPipeline.run(["full", "development", "75", "2"])

# Inspect the pipeline
:ok = MyApp.Pipeline.Info.validate_pipeline(MyApp.Pipeline)
tasks = MyApp.Pipeline.Info.tasks(MyApp.Pipeline)
```

### Error Handling
```elixir
case AutoPipeline.run(["full", "production"]) do
  {:ok, result} -> 
    IO.puts("Pipeline completed successfully")
    
  {:error, %AutoPipeline.ExecutionError{task: task, exit_code: code}} ->
    IO.puts("Task #{task} failed with exit code #{code}")
    
  {:error, reason} ->
    IO.puts("Pipeline failed: #{inspect(reason)}")
end
```

This comprehensive API documentation provides complete coverage of all modules, functions, and capabilities in the AutoPipeline DSL system.