defmodule AutoPipeline.Configuration do
  @moduledoc """
  Entity representing pipeline configuration settings in the DSL.

  REFACTOR: This configuration should map to Reactor options:
  - max_parallel -> Reactor max_concurrency
  - quality_threshold -> Reactor middleware configuration
  - timeout_multiplier -> Reactor middleware for timeout adjustment
  - memory_limit -> Reactor.Executor.ConcurrencyTracker configuration
  - enable_optimizations -> Reactor executor options
  
  Migration: Pass these as options to Reactor.run/4 or store in context.

  This entity defines global pipeline configuration that affects how tasks
  are executed, optimized, and managed. It provides control over:

  - Maximum parallel task execution
  - Quality thresholds for pipeline success
  - Timeout multipliers for all tasks
  - Memory limits for resource management
  - Optimization feature toggles

  ## Usage

  This entity is used in DSL configurations:

  ```elixir
  pipeline_configuration :production do
    max_parallel 4
    quality_threshold 90
    timeout_multiplier 1.5
    memory_limit 8192
    enable_optimizations true
  end
  ```

  ## Examples

  ```elixir
  # Development configuration - fast feedback
  pipeline_configuration :development do
    max_parallel 2
    quality_threshold 75
    timeout_multiplier 1.0
    memory_limit 4096
    enable_optimizations false
  end

  # Production configuration - high quality
  pipeline_configuration :production do
    max_parallel 8
    quality_threshold 95
    timeout_multiplier 2.0
    memory_limit 16384
    enable_optimizations true
  end

  # CI configuration - balanced
  pipeline_configuration :ci do
    max_parallel 4
    quality_threshold 85
    timeout_multiplier 1.5
    memory_limit 8192
    enable_optimizations true
  end
  ```
  """


  # REFACTOR: These fields map to Reactor configuration:
  # - max_parallel -> max_concurrency option
  # - timeout_multiplier -> middleware context
  # - memory_limit -> concurrency tracker pool configuration
  defstruct [
    :name,
    max_parallel: 4,
    quality_threshold: 80,
    timeout_multiplier: 1.0,
    memory_limit: 8192,
    enable_optimizations: true
  ]

  @type t :: %__MODULE__{
          name: atom(),
          max_parallel: pos_integer(),
          quality_threshold: 0..100,
          timeout_multiplier: float(),
          memory_limit: pos_integer(),
          enable_optimizations: boolean()
        }

  # Configuration presets
  @development_preset %{
    max_parallel: 2,
    quality_threshold: 75,
    timeout_multiplier: 1.0,
    memory_limit: 4096,
    enable_optimizations: false
  }

  @production_preset %{
    max_parallel: 8,
    quality_threshold: 95,
    timeout_multiplier: 2.0,
    memory_limit: 16384,
    enable_optimizations: true
  }

  @ci_preset %{
    max_parallel: 4,
    quality_threshold: 85,
    timeout_multiplier: 1.5,
    memory_limit: 8192,
    enable_optimizations: true
  }

  @doc false
  def transform(entity_struct) do
    # REFACTOR: In Reactor implementation, these would become
    # options passed to Reactor.run/4 or stored in context
    # Apply any configuration-specific transformations
    {:ok, transformed} = apply_preset_if_matching(entity_struct)
    {:ok, transformed}
  end

  @doc """
  Create a new configuration entity.
  """
  @spec new(Keyword.t()) :: {:ok, t()} | {:error, term()}
  def new(opts) do
    # Build the entity with defaults
    entity = struct(__MODULE__, opts)

    # Validate the configuration
    case validate(entity) do
      :ok -> {:ok, entity}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Get a preset configuration by name.
  """
  @spec get_preset(atom()) :: {:ok, map()} | {:error, term()}
  def get_preset(:development), do: {:ok, @development_preset}
  def get_preset(:production), do: {:ok, @production_preset}
  def get_preset(:ci), do: {:ok, @ci_preset}
  def get_preset(name), do: {:error, "Unknown preset: #{name}"}

  @doc """
  Apply a preset to an entity.
  """
  @spec apply_preset(t(), atom()) :: {:ok, t()} | {:error, term()}
  def apply_preset(entity, preset_name) do
    case get_preset(preset_name) do
      {:ok, preset} ->
        updated_entity = struct(entity, preset)
        {:ok, updated_entity}
      error ->
        error
    end
  end

  @doc """
  Validate the configuration entity.
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{} = entity) do
    with :ok <- validate_name(entity.name),
         :ok <- validate_max_parallel(entity.max_parallel),
         :ok <- validate_quality_threshold(entity.quality_threshold),
         :ok <- validate_timeout_multiplier(entity.timeout_multiplier),
         :ok <- validate_memory_limit(entity.memory_limit),
         :ok <- validate_enable_optimizations(entity.enable_optimizations) do
      :ok
    end
  end

  @doc """
  Check if the configuration is suitable for production use.
  """
  @spec production_ready?(t()) :: boolean()
  def production_ready?(entity) do
    entity.quality_threshold >= 90 and
      entity.memory_limit >= 4096 and
      entity.timeout_multiplier >= 1.0
  end

  @doc """
  Get estimated resource usage for this configuration.
  """
  @spec estimated_resource_usage(t()) :: %{
          memory: pos_integer(),
          cpu_cores: pos_integer(),
          quality_overhead: float()
        }
  def estimated_resource_usage(entity) do
    %{
      memory: entity.memory_limit,
      cpu_cores: entity.max_parallel,
      quality_overhead: (entity.quality_threshold / 100.0) * 0.2
    }
  end

  # Private validation functions

  defp validate_name(nil), do: {:error, "Configuration name is required"}
  defp validate_name(name) when is_atom(name), do: :ok
  defp validate_name(_), do: {:error, "Configuration name must be an atom"}

  # REFACTOR: Reactor's max_concurrency handles this validation
  defp validate_max_parallel(value) when is_integer(value) and value > 0 and value <= 32 do
    :ok
  end

  defp validate_max_parallel(value) when is_integer(value) and value <= 0 do
    {:error, "max_parallel must be positive"}
  end

  defp validate_max_parallel(value) when is_integer(value) and value > 32 do
    {:error, "max_parallel cannot exceed 32 (system limit)"}
  end

  defp validate_max_parallel(_) do
    {:error, "max_parallel must be a positive integer"}
  end

  defp validate_quality_threshold(value) when is_integer(value) and value >= 0 and value <= 100 do
    :ok
  end

  defp validate_quality_threshold(value) when is_integer(value) do
    {:error, "quality_threshold must be between 0 and 100"}
  end

  defp validate_quality_threshold(_) do
    {:error, "quality_threshold must be an integer between 0 and 100"}
  end

  defp validate_timeout_multiplier(value) when is_float(value) and value > 0.0 and value <= 10.0 do
    :ok
  end

  defp validate_timeout_multiplier(value) when is_number(value) and value <= 0.0 do
    {:error, "timeout_multiplier must be positive"}
  end

  defp validate_timeout_multiplier(value) when is_number(value) and value > 10.0 do
    {:error, "timeout_multiplier cannot exceed 10.0 (reasonableness limit)"}
  end

  defp validate_timeout_multiplier(_) do
    {:error, "timeout_multiplier must be a positive float"}
  end

  defp validate_memory_limit(value) when is_integer(value) and value >= 512 and value <= 131_072 do
    :ok
  end

  defp validate_memory_limit(value) when is_integer(value) and value < 512 do
    {:error, "memory_limit must be at least 512 MB"}
  end

  defp validate_memory_limit(value) when is_integer(value) and value > 131_072 do
    {:error, "memory_limit cannot exceed 128 GB"}
  end

  defp validate_memory_limit(_) do
    {:error, "memory_limit must be an integer (MB)"}
  end

  defp validate_enable_optimizations(value) when is_boolean(value), do: :ok
  defp validate_enable_optimizations(_) do
    {:error, "enable_optimizations must be a boolean"}
  end

  # Apply preset if entity name matches a known preset
  defp apply_preset_if_matching(%__MODULE__{name: name} = entity) do
    case get_preset(name) do
      {:ok, preset} ->
        # Only apply preset values that weren't explicitly set
        updated_entity = 
          preset
          |> Enum.reduce(entity, fn {key, value}, acc ->
            if Map.get(entity, key) == Map.get(%__MODULE__{}, key) do
              Map.put(acc, key, value)
            else
              acc
            end
          end)
        
        {:ok, updated_entity}
      
      {:error, _} ->
        # Not a preset name, just return entity as-is
        {:ok, entity}
    end
  end
end
