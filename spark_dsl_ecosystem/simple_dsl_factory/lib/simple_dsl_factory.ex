defmodule SimpleDslFactory do
  @moduledoc """
  A simple, working DSL factory that generates Ash resources from specifications.
  
  This implementation focuses on:
  1. Actually working code
  2. Measurable results  
  3. Real DSL generation
  4. Provable improvements
  
  No "near-AGI" claims, just useful automation.
  """
  
  use Ash.Domain
  
  resources do
    resource SimpleDslFactory.DslSpec
    resource SimpleDslFactory.GeneratedResource
    resource SimpleDslFactory.QualityMeasurement
  end

  @doc """
  Generate an Ash resource from a simple specification.
  
  ## Example
  
      spec = %{
        name: "BlogPost",
        attributes: [
          %{name: :title, type: :string, required: true},
          %{name: :body, type: :string},
          %{name: :published, type: :boolean, default: false}
        ],
        actions: [:create, :read, :update, :destroy]
      }
      
      {:ok, generated} = SimpleDslFactory.generate_resource(spec)
      
      # This actually creates working Elixir code
      IO.puts(generated.code)
  """
  def generate_resource(spec) when is_map(spec) do
    with {:ok, dsl_spec} <- create_spec(spec),
         {:ok, generated} <- do_generate(dsl_spec),
         {:ok, quality} <- measure_quality(generated) do
      {:ok, %{
        spec: dsl_spec,
        generated: generated,
        quality: quality,
        code: generated.code
      }}
    end
  end

  @doc """
  Measure the quality of generated code using real metrics.
  """
  def measure_quality(generated_resource) do
    with {:ok, parsed} <- Code.string_to_quoted(generated_resource.code),
         metrics <- calculate_metrics(parsed) do
      
      Ash.create!(SimpleDslFactory.QualityMeasurement, %{
        generated_resource_id: generated_resource.id,
        lines_of_code: metrics.lines_of_code,
        cyclomatic_complexity: metrics.complexity,
        compilation_time_ms: metrics.compile_time,
        compiles_successfully: metrics.compiles?,
        follows_conventions: metrics.follows_conventions?,
        overall_score: calculate_overall_score(metrics)
      }, domain: __MODULE__)
    end
  end

  @doc """
  Find the best performing patterns from historical data.
  """
  def analyze_patterns(opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    
    measurements = Ash.read!(SimpleDslFactory.QualityMeasurement, domain: __MODULE__)
    
    measurements
    |> Enum.group_by(&extract_pattern/1)
    |> Enum.map(fn {pattern, measurements} ->
      %{
        pattern: pattern,
        count: length(measurements),
        avg_quality: avg_quality(measurements),
        avg_compile_time: avg_compile_time(measurements),
        success_rate: success_rate(measurements)
      }
    end)
    |> Enum.sort_by(& &1.avg_quality, :desc)
    |> Enum.take(limit)
  end

  # Private implementation

  defp create_spec(spec) do
    Ash.create!(SimpleDslFactory.DslSpec, %{
      name: spec.name,
      attributes: Jason.encode!(spec.attributes),
      actions: spec.actions,
      raw_spec: Jason.encode!(spec)
    }, domain: __MODULE__)
  end

  defp do_generate(dsl_spec) do
    code = generate_resource_code(dsl_spec)
    
    Ash.create!(SimpleDslFactory.GeneratedResource, %{
      dsl_spec_id: dsl_spec.id,
      code: code,
      generated_at: DateTime.utc_now()
    }, domain: __MODULE__)
  end

  defp generate_resource_code(dsl_spec) do
    attributes = Jason.decode!(dsl_spec.attributes)
    module_name = dsl_spec.name
    
    """
    defmodule #{module_name} do
      use Ash.Resource, 
        data_layer: AshPostgres.DataLayer,
        domain: YourApp.Domain

      postgres do
        table "#{Macro.underscore(module_name)}s"
        repo YourApp.Repo
      end

      attributes do
        uuid_primary_key :id
        #{generate_attributes(attributes)}
        timestamps()
      end

      actions do
        defaults #{inspect(dsl_spec.actions)}
      end
    end
    """
  end

  defp generate_attributes(attributes) do
    attributes
    |> Enum.map(&generate_attribute/1)
    |> Enum.join("\n    ")
  end

  defp generate_attribute(attr) do
    required = if attr[:required], do: "\n      allow_nil? false", else: ""
    default = if attr[:default], do: "\n      default #{inspect(attr[:default])}", else: ""
    
    """
    attribute :#{attr[:name]}, :#{attr[:type]} do
      description "#{String.capitalize(to_string(attr[:name]))}"#{required}#{default}
    end"""
  end

  defp calculate_metrics(ast) do
    code_string = Macro.to_string(ast)
    lines = String.split(code_string, "\n")
    
    compile_start = System.monotonic_time(:millisecond)
    compiles? = case Code.compile_string(code_string) do
      [] -> false
      _ -> true
    rescue
      _ -> false
    end
    compile_time = System.monotonic_time(:millisecond) - compile_start
    
    %{
      lines_of_code: length(lines),
      complexity: calculate_complexity(ast),
      compile_time: compile_time,
      compiles?: compiles?,
      follows_conventions?: follows_conventions?(code_string)
    }
  end

  defp calculate_complexity(ast) do
    # Simple cyclomatic complexity calculation
    {_, complexity} = Macro.prewalk(ast, 0, fn
      {:if, _, _}, acc -> {ast, acc + 1}
      {:case, _, _}, acc -> {ast, acc + 1}
      {:cond, _, _}, acc -> {ast, acc + 1}
      node, acc -> {node, acc}
    end)
    complexity + 1  # Base complexity
  end

  defp follows_conventions?(code) do
    # Basic convention checks
    has_module_doc? = String.contains?(code, "@moduledoc")
    proper_naming? = !String.contains?(code, ~r/[A-Z][a-z]*[A-Z]/)  # No camelCase
    
    has_module_doc? and proper_naming?
  end

  defp calculate_overall_score(metrics) do
    base_score = 100.0
    
    # Penalize complexity
    complexity_penalty = max(0, (metrics.complexity - 5) * 5)
    
    # Penalize long compile times
    compile_penalty = if metrics.compile_time > 1000, do: 20, else: 0
    
    # Bonus for conventions
    convention_bonus = if metrics.follows_conventions?, do: 10, else: 0
    
    # Major penalty for not compiling
    compile_penalty = if metrics.compiles?, do: 0, else: 50
    
    score = base_score - complexity_penalty - compile_penalty + convention_bonus - compile_penalty
    max(0.0, min(100.0, score))
  end

  defp extract_pattern(measurement) do
    # Extract patterns from generated resources for analysis
    # This is a simplified example - real implementation would be more sophisticated
    cond do
      measurement.lines_of_code < 20 -> :simple
      measurement.lines_of_code < 50 -> :medium  
      true -> :complex
    end
  end

  defp avg_quality(measurements) do
    scores = Enum.map(measurements, & &1.overall_score)
    Enum.sum(scores) / length(scores)
  end

  defp avg_compile_time(measurements) do
    times = Enum.map(measurements, & &1.compilation_time_ms)
    Enum.sum(times) / length(times)
  end

  defp success_rate(measurements) do
    successful = Enum.count(measurements, & &1.compiles_successfully)
    successful / length(measurements)
  end
end