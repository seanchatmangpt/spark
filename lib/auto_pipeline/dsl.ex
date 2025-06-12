defmodule AutoPipeline.Dsl do
  @moduledoc """
  Enhanced DSL extension for AutoPipeline with comprehensive task definitions, 
  configuration management, and advanced pipeline optimization capabilities.

  This DSL provides a complete framework for defining automated pipelines with:
  - Task definitions with dependency management
  - Pipeline configuration with resource management
  - Automatic task optimization and metadata generation
  - Resource conflict detection and validation
  - Quality assurance and monitoring integration
  
  REFACTOR: This entire DSL should be reimplemented as a Reactor extension.
  Instead of custom task entities, use Reactor.Step with a custom implementation.
  The DSL would become a thin layer that compiles to Reactor steps.
  """

  # REFACTOR: Replace with Reactor step definition that includes:
  # - Use Reactor.Step as the base with custom AutoPipeline.Step.Command implementation
  # - Map 'depends_on' to Reactor step arguments
  # - Map 'parallel' to Reactor's 'async?' field
  # - Map 'retry_count' to Reactor's 'max_retries'
  # - Use Reactor's compensation/undo for rollback support
  @task %Spark.Dsl.Entity{
    name: :task,
    args: [:name],
    target: AutoPipeline.Task,
    identifier: :name,
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The unique name of the task"
      ],
      description: [
        type: :string,
        doc: "A human-readable description of what this task does"
      ],
      command: [
        type: :string,
        required: true,
        doc: "The shell command to execute"
      ],
      timeout: [
        type: :pos_integer,
        default: 30_000,
        doc: "Maximum time in milliseconds for task execution"
        # REFACTOR: Reactor handles timeouts via middleware
      ],
      retry_count: [
        type: :non_neg_integer,
        default: 0,
        doc: "Number of times to retry the task on failure"
        # REFACTOR: Use Reactor's max_retries option
      ],
      depends_on: [
        type: {:list, :atom},
        default: [],
        doc: "List of task names that must complete before this task"
        # REFACTOR: Convert to Reactor step arguments like {:result, :task_name}
      ],
      environment: [
        type: {:map, :string, :string},
        default: %{},
        doc: "Environment variables to set for this task"
      ],
      working_directory: [
        type: :string,
        doc: "Working directory for command execution"
      ],
      parallel: [
        type: :boolean,
        default: false,
        doc: "Whether this task can run in parallel with others"
        # REFACTOR: Map to Reactor's async? field
      ],
      condition: [
        type: {:or, [:string, {:fun, 0}]},
        doc: "Condition that must be met for task to execute"
      ]
    ]
  }

  @configuration %Spark.Dsl.Entity{
    name: :configuration,
    args: [:name],
    target: AutoPipeline.Configuration,
    identifier: :name,
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: "The unique name of the configuration"
      ],
      max_parallel: [
        type: :pos_integer,
        default: 4,
        doc: "Maximum number of tasks to run in parallel"
      ],
      quality_threshold: [
        type: {:in, 0..100},
        default: 80,
        doc: "Quality threshold percentage for pipeline success"
      ],
      timeout_multiplier: [
        type: :float,
        default: 1.0,
        doc: "Multiplier applied to all task timeouts"
      ],
      memory_limit: [
        type: :pos_integer,
        default: 8192,
        doc: "Maximum memory limit in MB for the entire pipeline"
      ],
      enable_optimizations: [
        type: :boolean,
        default: true,
        doc: "Whether to enable automatic pipeline optimizations"
      ]
    ]
  }

  @pipeline_tasks %Spark.Dsl.Section{
    name: :pipeline_tasks,
    describe: "Define tasks for the automated pipeline",
    entities: [@task],
    examples: [
      """
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

        task :dialyzer do
          description "Run static analysis"
          command "mix dialyzer"
          depends_on [:build]
          timeout 120_000
          parallel true
        end
      end
      """
    ]
  }

  # REFACTOR: Configuration should map to Reactor options:
  # - max_parallel -> max_concurrency
  # - Use Reactor.Executor.ConcurrencyTracker for resource pooling
  # - quality_threshold could be middleware configuration
  @pipeline_configuration %Spark.Dsl.Section{
    name: :pipeline_configuration,
    describe: "Configure pipeline behavior and resource management",
    entities: [@configuration],
    examples: [
      """
      pipeline_configuration do
        configuration :development do
          max_parallel 2
          quality_threshold 75
          timeout_multiplier 1.0
          memory_limit 4096
          enable_optimizations false
        end

        configuration :production do
          max_parallel 8
          quality_threshold 95
          timeout_multiplier 2.0
          memory_limit 16384
          enable_optimizations true
        end
      end
      """
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@pipeline_tasks, @pipeline_configuration],
    transformers: [
      # REFACTOR: Replace with single transformer that converts tasks to Reactor steps
      # AutoPipeline.Transformers.ConvertToReactor - builds Reactor struct
      
      # First, validate basic structure and dependencies
      AutoPipeline.Transformers.ValidateDependencies,
      # REFACTOR: Remove - Reactor handles dependency validation automatically
      
      # Then, generate comprehensive metadata for all tasks
      AutoPipeline.Transformers.GenerateTaskMetadata,
      # REFACTOR: Metadata can be stored in Reactor step context
      
      # Finally, optimize execution order based on dependencies and metadata
      AutoPipeline.Transformers.OptimizeExecutionOrder
      # REFACTOR: Remove - Reactor's DAG resolution handles optimal execution
    ],
    verifiers: [
      # Verify basic task executability
      AutoPipeline.Verifiers.EnsureTasksExecutable,
      # REFACTOR: Convert to Reactor.Middleware for runtime validation
      
      # Validate resource requirements and detect conflicts
      AutoPipeline.Verifiers.ValidateResourceRequirements
      # REFACTOR: Implement as Reactor.Middleware.ResourceManager
    ]
end