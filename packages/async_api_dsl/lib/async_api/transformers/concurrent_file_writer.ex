defmodule AsyncApi.Transformers.ConcurrentFileWriter do
  @moduledoc """
  Final transformer that executes all file write operations concurrently.
  
  This transformer takes the write operations prepared by previous transformers
  and executes them all simultaneously for maximum performance.
  """
  
  use Spark.Dsl.Transformer
  alias Spark.Dsl.Transformer

  def transform(dsl_state) do
    write_operations = Transformer.get_option(dsl_state, [:write_operations])
    
    if write_operations && length(write_operations) > 0 do
      execute_concurrent_writes(write_operations, dsl_state)
    else
      {:ok, dsl_state}
    end
  end

  defp execute_concurrent_writes(write_operations, dsl_state) do
    # Create all directory structures first
    create_directories(write_operations)
    
    # Execute all file writes concurrently
    write_tasks = Enum.map(write_operations, fn {file_path, source_type, source_key} ->
      Task.async(fn ->
        content = get_content(dsl_state, source_type, source_key)
        write_file_safe(file_path, content)
      end)
    end)
    
    # Wait for all writes to complete
    results = Task.await_many(write_tasks, :infinity)
    
    # Check for any errors
    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> 
        # All writes successful
        IO.puts("✅ Successfully generated #{length(write_operations)} files concurrently")
        {:ok, dsl_state}
      
      {:error, reason} ->
        {:error, "File write failed: #{reason}"}
    end
  end

  defp create_directories(write_operations) do
    write_operations
    |> Enum.map(fn {file_path, _, _} -> Path.dirname(file_path) end)
    |> Enum.uniq()
    |> Enum.each(&File.mkdir_p!/1)
  end

  defp get_content(dsl_state, source_type, source_key) do
    case source_type do
      :capnproto ->
        Transformer.get_option(dsl_state, [:capnproto, source_key])
      
      :clients ->
        Transformer.get_option(dsl_state, [:clients, source_key])
      
      :static ->
        # For static content generators (functions)
        api_info = Transformer.get_option(dsl_state, [:capnproto, :api_info])
        source_key.(api_info)
      
      _ ->
        ""
    end
  end

  defp write_file_safe(file_path, content) do
    try do
      File.write!(file_path, content)
      {:ok, file_path}
    rescue
      e ->
        {:error, "Failed to write #{file_path}: #{Exception.message(e)}"}
    end
  end
end