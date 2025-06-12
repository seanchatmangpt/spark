defmodule AutoPipeline.Task do
  @moduledoc """
  Represents a single task in an automated pipeline.

  REFACTOR: This module becomes unnecessary with Reactor.
  Tasks would be represented as Reactor steps instead.
  The ConvertToReactor transformer would create Reactor.Step
  structs directly from the DSL entities.
  
  Migration: Remove this module after implementing ConvertToReactor.

  Tasks define units of work that can be executed as part of a pipeline,
  with support for dependencies, retries, environment configuration, and more.
  """

  # REFACTOR: Map to Reactor.Step fields:
  # - name -> Step.name
  # - command -> Step options
  # - timeout -> Step context or middleware
  # - retry_count -> Step.max_retries
  # - depends_on -> Step.arguments
  # - parallel -> Step.async?
  # - environment/working_directory -> Step context
  defstruct [
    :__identifier__,
    :name,
    :description,
    :command,
    :timeout,
    :retry_count,
    :depends_on,
    :environment,
    :working_directory,
    :parallel,
    :condition
  ]

  @type t :: %__MODULE__{
          name: atom(),
          description: String.t() | nil,
          command: String.t(),
          timeout: pos_integer(),
          retry_count: non_neg_integer(),
          depends_on: [atom()],
          environment: map(),
          working_directory: String.t() | nil,
          parallel: boolean(),
          condition: String.t() | (() -> boolean()) | nil
        }

  @doc """
  Creates a new task with the given attributes.
  """
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Validates that a task is properly configured.
  
  REFACTOR: Validation would happen in:
  1. ConvertToReactor transformer (compile-time)
  2. Reactor.Step implementation (runtime)
  3. Reactor middleware (configurable)
  """
  def validate(%__MODULE__{} = task) do
    with :ok <- validate_name(task.name),
         :ok <- validate_command(task.command),
         :ok <- validate_timeout(task.timeout),
         :ok <- validate_retry_count(task.retry_count),
         :ok <- validate_depends_on(task.depends_on),
         :ok <- validate_environment(task.environment) do
      {:ok, task}
    end
  end

  defp validate_name(nil), do: {:error, "Task name is required"}
  defp validate_name(name) when is_atom(name), do: :ok
  defp validate_name(_), do: {:error, "Task name must be an atom"}

  defp validate_command(nil), do: {:error, "Task command is required"}
  defp validate_command(command) when is_binary(command) and byte_size(command) > 0, do: :ok
  defp validate_command(_), do: {:error, "Task command must be a non-empty string"}

  defp validate_timeout(timeout) when is_integer(timeout) and timeout > 0, do: :ok
  defp validate_timeout(_), do: {:error, "Task timeout must be a positive integer"}

  defp validate_retry_count(count) when is_integer(count) and count >= 0, do: :ok
  defp validate_retry_count(_), do: {:error, "Retry count must be a non-negative integer"}

  defp validate_depends_on(deps) when is_list(deps) do
    if Enum.all?(deps, &is_atom/1) do
      :ok
    else
      {:error, "All dependencies must be atoms"}
    end
  end

  defp validate_depends_on(_), do: {:error, "Dependencies must be a list"}

  defp validate_environment(env) when is_map(env), do: :ok
  defp validate_environment(_), do: {:error, "Environment must be a map"}
end