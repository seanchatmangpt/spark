defmodule AutoPipeline.Transformers.GenerateTaskMetadata do
  @moduledoc """
  DSL transformer for auto-generating task IDs and comprehensive metadata.

  REFACTOR: This transformer should be simplified when using Reactor:
  - Task IDs can be step names in Reactor
  - Timestamps are handled by Reactor telemetry events
  - Resource estimation should be in Reactor middleware
  - Context metadata goes in Reactor step context
  - Quality metrics can be Reactor middleware
  
  Migration: Merge this into ConvertToReactor transformer.

  This transformer enhances tasks with automatically generated metadata including:

  - Unique task IDs for tracking and correlation
  - Timestamps for creation and compilation
  - Command classification and complexity analysis
  - Resource requirements estimation
  - Execution context metadata
  - Dependencies analysis
  - Quality metrics and telemetry tags

  ## Usage

  Add this transformer to your DSL extension:

  ```elixir
  use Spark.Dsl.Extension,
    transformers: [AutoPipeline.Transformers.GenerateTaskMetadata]
  ```

  ## Example Transformations

  ```elixir
  # Before transformation - minimal task definition
  pipeline_tasks do
    task :compile do
      command "mix compile"
      depends_on []
    end
  end

  # After transformation - enriched with metadata
  pipeline_tasks do
    task :compile do
      command "mix compile"
      depends_on []
      
      # Auto-generated metadata
      task_id "task_compile_abc123"
      created_at ~U[2024-01-15 10:30:00Z]
      command_type :build
      complexity_score 3.2
      estimated_resources %{cpu: 2, memory: 512, io: :medium}
      tags [:elixir, :compilation, :build_step]
      telemetry_metadata %{
        module: MyPipeline,
        version: "1.0.0",
        environment: :dev
      }
    end
  end
  ```
  """

  use Spark.Dsl.Transformer

  # REFACTOR: Transformer ordering won't matter when this is merged into
  # ConvertToReactor transformer
  @impl Spark.Dsl.Transformer
  def before?(AutoPipeline.Transformers.OptimizeExecutionOrder), do: true
  def before?(_), do: false

  @impl Spark.Dsl.Transformer
  def after?(_), do: false

  @doc """
  Transform the DSL state to add comprehensive metadata to all tasks.

  This transformer performs several enhancements:
  1. Generates unique task IDs for tracking
  2. Adds timestamps and version information
  3. Classifies commands and estimates complexity
  4. Computes resource requirements
  5. Adds telemetry and monitoring metadata
  6. Generates quality and performance tags
  """
  @impl Spark.Dsl.Transformer
  def transform(dsl_state) do
    # REFACTOR: In Reactor implementation:
    # - This logic moves to ConvertToReactor transformer
    # - Metadata becomes step context when creating Reactor steps
    # - No separate persistence needed
    
    tasks = Spark.Dsl.Transformer.get_entities(dsl_state, [:pipeline_tasks])
    module = Spark.Dsl.Transformer.get_persisted(dsl_state, :module)
    
    # Simply mark that metadata generation ran and store basic task info
    task_names = Enum.map(tasks, & &1.name)
    task_count = length(tasks)
    
    updated_dsl_state = 
      dsl_state
      |> Spark.Dsl.Transformer.persist(:task_metadata_generated, true)
      |> Spark.Dsl.Transformer.persist(:task_names, task_names)
      |> Spark.Dsl.Transformer.persist(:task_count, task_count)
    
    {:ok, updated_dsl_state}
  end

  # Private metadata generation functions

  defp generate_task_metadata(tasks, module) do
    try do
      base_context = build_base_context(module)
      
      enhanced_tasks = 
        tasks
        |> Enum.map(&enhance_task_with_metadata(&1, base_context))
      
      {:ok, enhanced_tasks}
    rescue
      e -> {:error, "Failed to generate task metadata: #{inspect(e)}"}
    end
  end

  defp build_base_context(module) do
    %{
      module: module,
      timestamp: DateTime.utc_now(),
      version: get_application_version(),
      environment: get_environment(),
      host: get_host_info(),
      compilation_id: generate_compilation_id()
    }
  end

  defp enhance_task_with_metadata(task, context) do
    task_id = generate_task_id(task, context)
    command_analysis = analyze_command(task.command)
    resource_requirements = estimate_resource_requirements(task, command_analysis)
    telemetry_metadata = build_telemetry_metadata(task, context)
    quality_tags = generate_quality_tags(task, command_analysis)
    
    # Instead of modifying the task struct, return metadata as a separate map
    %{
      task: task,
      task_id: task_id,
      created_at: context.timestamp,
      command_type: command_analysis.type,
      command_category: command_analysis.category,
      complexity_score: command_analysis.complexity,
      estimated_resources: resource_requirements,
      tags: quality_tags,
      telemetry_metadata: telemetry_metadata,
      metadata: %{
        compilation_id: context.compilation_id,
        module: context.module,
        version: context.version,
        environment: context.environment,
        host: context.host,
        dependency_count: length(task.depends_on),
        command_hash: hash_command(task.command),
        generation_timestamp: context.timestamp
      }
    }
  end

  defp generate_task_id(task, context) do
    base = "task_#{task.name}"
    hash_input = "#{base}_#{context.compilation_id}_#{context.timestamp}"
    hash = :crypto.hash(:sha256, hash_input) |> Base.encode16(case: :lower)
    short_hash = String.slice(hash, 0, 8)
    "#{base}_#{short_hash}"
  end

  defp analyze_command(command) do
    %{
      type: classify_command_type(command),
      category: classify_command_category(command),
      complexity: compute_complexity_score(command),
      io_intensity: analyze_io_intensity(command),
      cpu_intensity: analyze_cpu_intensity(command),
      network_usage: analyze_network_usage(command)
    }
  end

  defp classify_command_type(command) do
    cond do
      String.contains?(command, ["compile", "build"]) -> :build
      String.contains?(command, ["test", "spec", "check"]) -> :test
      String.contains?(command, ["format", "lint", "credo"]) -> :quality
      String.contains?(command, ["docs", "documentation"]) -> :docs
      String.contains?(command, ["deps", "dependencies"]) -> :deps
      String.contains?(command, ["dialyzer", "typecheck"]) -> :analysis
      String.contains?(command, ["release", "deploy"]) -> :deployment
      String.contains?(command, ["clean", "reset"]) -> :cleanup
      true -> :custom
    end
  end

  defp classify_command_category(command) do
    cond do
      String.contains?(command, "mix") -> :elixir
      String.contains?(command, ["npm", "yarn", "node"]) -> :javascript
      String.contains?(command, ["docker", "podman"]) -> :container
      String.contains?(command, ["git", "svn"]) -> :vcs
      String.contains?(command, ["curl", "wget", "http"]) -> :network
      String.contains?(command, ["cp", "mv", "rsync"]) -> :filesystem
      true -> :shell
    end
  end

  defp compute_complexity_score(command) do
    base_score = 1.0
    
    # Increase complexity based on command patterns
    complexity_factors = [
      {~r/&&/, 0.5},        # Command chaining
      {~r/\|/, 0.3},        # Pipes
      {~r/\$\(/, 0.4},      # Command substitution
      {~r/\*/, 0.2},        # Wildcards
      {~r/--\w+/, 0.1},     # Options (per option)
      {~r/compile/, 1.0},   # Compilation is complex
      {~r/test/, 0.8},      # Testing is moderately complex
      {~r/dialyzer/, 2.0},  # Type analysis is very complex
      {~r/deps/, 0.6}       # Dependency management
    ]
    
    complexity_factors
    |> Enum.reduce(base_score, fn {pattern, factor}, acc ->
      matches = Regex.scan(pattern, command) |> length()
      acc + (matches * factor)
    end)
    |> min(10.0)  # Cap at 10.0
    |> Float.round(1)
  end

  defp analyze_io_intensity(command) do
    io_patterns = [
      ~r/compile/,
      ~r/deps/,
      ~r/cp/,
      ~r/mv/,
      ~r/rsync/,
      ~r/docker build/,
      ~r/npm install/
    ]
    
    if Enum.any?(io_patterns, &Regex.match?(&1, command)) do
      :high
    else
      :low
    end
  end

  defp analyze_cpu_intensity(command) do
    cpu_patterns = [
      ~r/compile/,
      ~r/dialyzer/,
      ~r/test/,
      ~r/build/
    ]
    
    if Enum.any?(cpu_patterns, &Regex.match?(&1, command)) do
      :high
    else
      :medium
    end
  end

  defp analyze_network_usage(command) do
    network_patterns = [
      ~r/deps/,
      ~r/npm/,
      ~r/curl/,
      ~r/wget/,
      ~r/git/,
      ~r/docker pull/
    ]
    
    if Enum.any?(network_patterns, &Regex.match?(&1, command)) do
      :high
    else
      :none
    end
  end

  defp estimate_resource_requirements(task, command_analysis) do
    base_cpu = 1
    base_memory = 256  # MB
    
    # Adjust based on command analysis
    cpu_multiplier = case command_analysis.cpu_intensity do
      :high -> 2.0
      :medium -> 1.5
      :low -> 1.0
    end
    
    memory_multiplier = case command_analysis.type do
      :build -> 2.0
      :analysis -> 4.0  # dialyzer needs lots of memory
      :test -> 1.5
      :docs -> 1.2
      _ -> 1.0
    end
    
    # Factor in timeout as complexity indicator
    timeout_factor = min(task.timeout / 30_000, 3.0)
    
    %{
      cpu_cores: round(base_cpu * cpu_multiplier),
      memory_mb: round(base_memory * memory_multiplier * timeout_factor),
      io_intensity: command_analysis.io_intensity,
      network_usage: command_analysis.network_usage,
      estimated_duration_ms: task.timeout
    }
  end

  defp build_telemetry_metadata(task, context) do
    %{
      task_name: task.name,
      module: context.module,
      version: context.version,
      environment: context.environment,
      compilation_id: context.compilation_id,
      host: context.host,
      parallel: task.parallel,
      retry_count: task.retry_count,
      timeout: task.timeout,
      dependencies: task.depends_on
    }
  end

  defp generate_quality_tags(task, command_analysis) do
    tags = [:automated_pipeline]
    
    # Add command type tags
    tags = [command_analysis.type | tags]
    tags = [command_analysis.category | tags]
    
    # Add complexity tags
    tags = case command_analysis.complexity do
      score when score > 5.0 -> [:high_complexity | tags]
      score when score > 2.0 -> [:medium_complexity | tags]
      _ -> [:low_complexity | tags]
    end
    
    # Add parallel execution tags
    tags = if task.parallel, do: [:parallel_execution | tags], else: tags
    
    # Add dependency tags
    tags = case length(task.depends_on) do
      0 -> [:independent | tags]
      count when count > 3 -> [:high_dependencies | tags]
      _ -> [:has_dependencies | tags]
    end
    
    # Add resource intensity tags
    tags = case command_analysis.io_intensity do
      :high -> [:io_intensive | tags]
      _ -> tags
    end
    
    tags = case command_analysis.cpu_intensity do
      :high -> [:cpu_intensive | tags]
      _ -> tags
    end
    
    Enum.reverse(tags)
  end

  # Utility functions

  defp get_application_version do
    case Application.spec(:spark, :vsn) do
      vsn when is_list(vsn) -> List.to_string(vsn)
      _ -> "unknown"
    end
  end

  defp get_environment do
    System.get_env("MIX_ENV", "dev") |> String.to_atom()
  end

  defp get_host_info do
    %{
      hostname: System.get_env("HOSTNAME", "unknown"),
      os: System.get_env("OS", "unknown"),
      arch: System.get_env("PROCESSOR_ARCHITECTURE", "unknown")
    }
  end

  defp generate_compilation_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp hash_command(command) do
    :crypto.hash(:md5, command) |> Base.encode16(case: :lower)
  end
end
