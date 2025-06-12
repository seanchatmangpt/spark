defmodule AutoPipeline.Verifiers.EnsureTasksExecutable do
  @moduledoc """
  Verifier that ensures all tasks have valid, executable configurations.

  REFACTOR: This verifier should become Reactor middleware.
  Instead of compile-time validation, these checks would run
  during step execution as part of the command step implementation.
  
  Migration approach:
  1. Move command validation to AutoPipeline.Reactor.Step.Command.run/3
  2. Environment validation happens when building shell command
  3. Timeout is handled by Reactor's timeout middleware
  4. Retry validation is handled by Reactor's max_retries

  This verifier checks that:
  1. All tasks have valid commands
  2. Task configurations are internally consistent
  3. Environment variables are properly formatted
  4. Timeouts and retry counts are reasonable
  """

  use Spark.Dsl.Verifier

  @impl Spark.Dsl.Verifier
  def verify(dsl_state) do
    # REFACTOR: In Reactor implementation, this validation moves to:
    # 1. Step implementation (runtime validation)
    # 2. ConvertToReactor transformer (compile-time checks)
    # 3. Reactor middleware (configurable validation)
    
    tasks = Spark.Dsl.Transformer.get_entities(dsl_state, [:pipeline_tasks])
    module = Spark.Dsl.Transformer.get_persisted(dsl_state, :module)
    
    case validate_all_tasks(tasks) do
      :ok -> 
        :ok
      {:error, errors} ->
        {:error, 
         Spark.Error.DslError.exception(
           module: module,
           message: "Task validation failed: #{Enum.join(errors, ", ")}",
           path: [:pipeline_tasks]
         )}
    end
  end

  defp validate_all_tasks(tasks) do
    errors = 
      tasks
      |> Enum.flat_map(&validate_task/1)
      |> Enum.reject(&is_nil/1)
    
    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  defp validate_task(task) do
    [
      validate_command(task),
      validate_timeout(task),
      validate_retry_count(task),
      validate_environment(task),
      validate_working_directory(task),
      validate_condition(task)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp validate_command(%{name: name, command: command}) do
    cond do
      is_nil(command) or command == "" ->
        "Task '#{name}' has empty or missing command"
      
      not is_binary(command) ->
        "Task '#{name}' command must be a string"
      
      String.length(command) > 1000 ->
        "Task '#{name}' command is excessively long (>1000 characters)"
      
      true ->
        nil
    end
  end

  # REFACTOR: Reactor handles timeout via middleware or step options
  # No need for custom validation
  defp validate_timeout(%{name: name, timeout: timeout}) do
    cond do
      not is_integer(timeout) ->
        "Task '#{name}' timeout must be an integer"
      
      timeout <= 0 ->
        "Task '#{name}' timeout must be positive"
      
      timeout > 24 * 60 * 60 * 1000 ->
        "Task '#{name}' timeout is excessively long (>24 hours)"
      
      true ->
        nil
    end
  end

  # REFACTOR: Use Reactor's max_retries validation instead
  defp validate_retry_count(%{name: name, retry_count: count}) do
    cond do
      not is_integer(count) ->
        "Task '#{name}' retry_count must be an integer"
      
      count < 0 ->
        "Task '#{name}' retry_count must be non-negative"
      
      count > 10 ->
        "Task '#{name}' retry_count is excessively high (>10)"
      
      true ->
        nil
    end
  end

  defp validate_environment(%{name: name, environment: env}) do
    cond do
      not is_map(env) ->
        "Task '#{name}' environment must be a map"
      
      not all_string_keys_and_values?(env) ->
        "Task '#{name}' environment must have string keys and values"
      
      true ->
        nil
    end
  end

  defp validate_working_directory(%{name: name, working_directory: nil}), do: nil
  defp validate_working_directory(%{name: name, working_directory: dir}) do
    cond do
      not is_binary(dir) ->
        "Task '#{name}' working_directory must be a string"
      
      String.contains?(dir, ["\n", "\r"]) ->
        "Task '#{name}' working_directory cannot contain newlines"
      
      true ->
        nil
    end
  end

  defp validate_condition(%{name: name, condition: nil}), do: nil
  defp validate_condition(%{name: name, condition: condition}) do
    cond do
      is_binary(condition) and String.length(condition) == 0 ->
        "Task '#{name}' condition cannot be empty string"
      
      is_binary(condition) ->
        nil
      
      is_function(condition, 0) ->
        nil
      
      true ->
        "Task '#{name}' condition must be a string or 0-arity function"
    end
  end

  defp all_string_keys_and_values?(map) do
    Enum.all?(map, fn {key, value} ->
      is_binary(key) and is_binary(value)
    end)
  end
end