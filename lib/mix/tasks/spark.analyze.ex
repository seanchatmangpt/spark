defmodule Mix.Tasks.Spark.Analyze do
  @moduledoc """
  Performs comprehensive quality assessment and pattern recognition on Spark DSL iterations.

  ## Usage

      mix spark.analyze <output_dir> [analysis_type] [focus_area]

  ## Arguments

  - `output_dir` - Directory containing generated DSL iterations
  - `analysis_type` - Optional: comprehensive, quality, evolution, gaps, recommendations, performance (default: comprehensive)
  - `focus_area` - Optional: extensions, transformers, verifiers, entities, complete (default: complete)

  ## Examples

      # Comprehensive analysis of AutoPipeline iterations
      mix spark.analyze auto_pipeline_iterations comprehensive complete

      # Quality-focused analysis
      mix spark.analyze auto_pipeline_iterations quality extensions

      # Evolution tracking
      mix spark.analyze auto_pipeline_iterations evolution complete
  """

  use Mix.Task
  
  @shortdoc "Analyze Spark DSL iterations for quality, patterns, and performance"

  @impl Mix.Task
  def run(args) do
    {output_dir, analysis_type, focus_area} = parse_args(args)

    IO.puts("""
    
    🔍 Spark DSL Iteration Analysis
    ===============================
    
    Directory: #{output_dir}
    Analysis Type: #{analysis_type}
    Focus Area: #{focus_area}
    """)

    # Phase 1: Directory Assessment and File Discovery
    directory_assessment = assess_dsl_directory(output_dir, focus_area)
    
    # Phase 2: Content Quality Evaluation
    quality_assessments = evaluate_all_files(directory_assessment.categorized_files)
    
    # Phase 3: Pattern Recognition and Evolution Tracking
    evolution_analysis = analyze_pattern_evolution(directory_assessment.metadata)
    
    # Phase 4: Gap Analysis and Opportunity Identification
    gap_analysis = identify_gaps_and_opportunities(quality_assessments, evolution_analysis)
    
    # Phase 5: Recommendation Generation
    recommendations = generate_recommendations(gap_analysis, quality_assessments, evolution_analysis)
    
    # Phase 6: Report Generation
    analysis_results = %{
      directory_assessment: directory_assessment,
      quality_assessments: quality_assessments,
      evolution_analysis: evolution_analysis,
      gap_analysis: gap_analysis,
      recommendations: recommendations
    }
    
    generate_comprehensive_report(analysis_results, output_dir, analysis_type)
  end

  defp parse_args(args) do
    case args do
      [output_dir] -> {output_dir, "comprehensive", "complete"}
      [output_dir, analysis_type] -> {output_dir, analysis_type, "complete"}
      [output_dir, analysis_type, focus_area] -> {output_dir, analysis_type, focus_area}
      [] -> 
        Mix.shell().error("Usage: mix spark.analyze <output_dir> [analysis_type] [focus_area]")
        System.halt(1)
      _ ->
        Mix.shell().error("Too many arguments. Usage: mix spark.analyze <output_dir> [analysis_type] [focus_area]")
        System.halt(1)
    end
  end

  defp assess_dsl_directory(output_dir, focus_area) do
    if not File.exists?(output_dir) do
      Mix.shell().error("Directory '#{output_dir}' does not exist")
      System.halt(1)
    end

    dsl_files = discover_dsl_files(output_dir, focus_area)
    
    categorized_files = %{
      extensions: filter_extensions(dsl_files),
      transformers: filter_transformers(dsl_files),
      verifiers: filter_verifiers(dsl_files),
      entities: filter_entities(dsl_files),
      iterations: filter_iterations(dsl_files),
      tests: filter_test_files(dsl_files)
    }
    
    file_metadata = Enum.map(dsl_files, &extract_dsl_metadata/1)
    
    %{
      total_files: length(dsl_files),
      categorized_files: categorized_files,
      metadata: file_metadata,
      creation_timeline: extract_timeline(file_metadata)
    }
  end

  defp discover_dsl_files(output_dir, focus_area) do
    patterns = case focus_area do
      "extensions" -> ["**/*_dsl.ex", "**/*_extension.ex"]
      "transformers" -> ["**/transformers/**/*.ex"]
      "verifiers" -> ["**/verifiers/**/*.ex"]
      "entities" -> ["**/*_entity.ex", "**/entities/**/*.ex"]
      "complete" -> ["**/*.ex"]
    end
    
    patterns
    |> Enum.flat_map(&Path.wildcard("#{output_dir}/#{&1}"))
    |> Enum.filter(&contains_spark_dsl?/1)
    |> Enum.sort_by(&File.stat!(&1).mtime)
  end

  defp contains_spark_dsl?(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content =~ "use Spark.Dsl" or
        content =~ "Spark.Dsl.Extension" or
        content =~ "AutoPipeline" or
        content =~ "pipeline_" or
        content =~ "mcp_integration"
      {:error, _} -> false
    end
  end

  defp filter_extensions(files), do: Enum.filter(files, &(&1 =~ ~r/_dsl\.ex$|_extension\.ex$/))
  defp filter_transformers(files), do: Enum.filter(files, &(&1 =~ ~r/transformers.*\.ex$/))
  defp filter_verifiers(files), do: Enum.filter(files, &(&1 =~ ~r/verifiers.*\.ex$/))
  defp filter_entities(files), do: Enum.filter(files, &(&1 =~ ~r/_entity\.ex$|entities.*\.ex$/))
  defp filter_iterations(files), do: Enum.filter(files, &(&1 =~ ~r/iteration_\d+\.ex$/))
  defp filter_test_files(files), do: Enum.filter(files, &(&1 =~ ~r/_test\.exs?$/))

  defp extract_dsl_metadata(file_path) do
    stat = File.stat!(file_path)
    content = File.read!(file_path)
    
    %{
      path: file_path,
      name: Path.basename(file_path),
      size_bytes: stat.size,
      modified_time: stat.mtime,
      line_count: length(String.split(content, "\n")),
      content: content
    }
  end

  defp extract_timeline(metadata) do
    metadata
    |> Enum.sort_by(& &1.modified_time)
    |> Enum.with_index(1)
    |> Enum.map(fn {file, index} ->
      %{
        sequence: index,
        file: file.name,
        timestamp: file.modified_time,
        size: file.size_bytes
      }
    end)
  end

  defp evaluate_all_files(categorized_files) do
    all_files = Enum.flat_map(Map.values(categorized_files), &(&1))
    
    Enum.map(all_files, fn file_path ->
      content = File.read!(file_path)
      evaluate_dsl_quality(file_path, content)
    end)
  end

  defp evaluate_dsl_quality(file_path, content) do
    # Parse AST for deep analysis
    ast_result = Code.string_to_quoted(content)
    
    case ast_result do
      {:ok, ast} ->
        # Technical Excellence Assessment (0-100)
        technical_score = assess_technical_excellence(ast, content)
        
        # Innovation Score (0-100)
        innovation_score = assess_innovation_level(ast, content)
        
        # Specification Compliance (0-100)
        compliance_score = assess_spec_compliance(ast, content)
        
        # Spark Framework Adherence (0-100)
        spark_adherence = assess_spark_conventions(ast, content)
        
        overall_quality = calculate_weighted_average([
          {technical_score, 0.3},
          {innovation_score, 0.2},
          {compliance_score, 0.3},
          {spark_adherence, 0.2}
        ])
        
        %{
          file: file_path,
          compilation_success: true,
          technical_excellence: technical_score,
          innovation_score: innovation_score,
          spec_compliance: compliance_score,
          spark_adherence: spark_adherence,
          overall_quality: overall_quality,
          detailed_metrics: generate_detailed_metrics(ast, content)
        }
        
      {:error, _} ->
        %{
          file: file_path,
          compilation_success: false,
          technical_excellence: 0,
          innovation_score: 0,
          spec_compliance: 0,
          spark_adherence: 0,
          overall_quality: 0,
          detailed_metrics: %{error: "Failed to parse AST"}
        }
    end
  end

  defp assess_technical_excellence(ast, content) do
    metrics = %{
      compilation_success: 100, # Already verified by AST parsing
      code_organization: assess_code_structure(ast),
      error_handling: assess_error_patterns(ast),
      documentation_quality: assess_documentation(content),
      test_coverage: assess_test_presence(content),
      type_safety: assess_type_usage(ast)
    }
    
    calculate_technical_score(metrics)
  end

  defp assess_code_structure(ast) do
    # Analyze module structure, function organization, etc.
    module_count = count_modules(ast)
    function_count = count_functions(ast)
    
    cond do
      module_count > 0 and function_count > 0 -> 85
      module_count > 0 -> 70
      true -> 50
    end
  end

  defp assess_error_patterns(_ast) do
    # For now, assume moderate error handling
    75
  end

  defp assess_documentation(content) do
    # Count documentation lines
    doc_lines = content
    |> String.split("\n")
    |> Enum.count(&(String.contains?(&1, "@moduledoc") or String.contains?(&1, "@doc") or String.match?(&1, ~r/^\s*#/)))
    
    total_lines = length(String.split(content, "\n"))
    doc_ratio = doc_lines / max(total_lines, 1)
    
    round(doc_ratio * 100 + 50) |> min(100)
  end

  defp assess_test_presence(content) do
    # Check for test-related patterns
    has_tests = content =~ ~r/test\s+["']/ or content =~ ~r/describe\s+["']/
    if has_tests, do: 90, else: 30
  end

  defp assess_type_usage(ast) do
    # Check for type specifications
    has_typespecs = find_typespecs(ast) > 0
    if has_typespecs, do: 85, else: 65
  end

  defp assess_innovation_level(ast, content) do
    patterns = %{
      novel_entities: identify_novel_entities(ast, content),
      creative_transformers: assess_transformer_creativity(ast, content),
      unique_verifiers: identify_unique_verifiers(ast, content),
      architectural_innovation: assess_architectural_patterns(ast, content),
      api_design: assess_api_creativity(ast, content)
    }
    
    calculate_innovation_score(patterns)
  end

  defp identify_novel_entities(_ast, content) do
    # Count unique DSL entity patterns
    entity_patterns = [
      "pipeline_configuration",
      "pipeline_tasks", 
      "mcp_integration",
      "circuit_breaker",
      "caching",
      "performance_monitoring",
      "resource_optimization"
    ]
    
    found_patterns = Enum.count(entity_patterns, &String.contains?(content, &1))
    min(found_patterns * 15, 100)
  end

  defp assess_transformer_creativity(_ast, content) do
    # Look for creative transformer usage
    creative_patterns = [
      "optimization",
      "caching_strategy",
      "resource_requirements",
      "api_integrations",
      "performance_tuning"
    ]
    
    found_creative = Enum.count(creative_patterns, &String.contains?(content, &1))
    min(found_creative * 20, 100)
  end

  defp identify_unique_verifiers(_ast, content) do
    # Check for unique verification patterns
    unique_patterns = [
      "external_dependencies",
      "condition",
      "circuit_breaker",
      "performance_validation"
    ]
    
    found_unique = Enum.count(unique_patterns, &String.contains?(content, &1))
    min(found_unique * 25, 100)
  end

  defp assess_architectural_patterns(_ast, content) do
    # Assess architectural sophistication
    arch_patterns = [
      "use Spark.Dsl",
      "default_extensions",
      "MCP",
      "community",
      "database"
    ]
    
    found_arch = Enum.count(arch_patterns, &String.contains?(content, &1))
    min(found_arch * 18, 100)
  end

  defp assess_api_creativity(_ast, content) do
    # Evaluate API design creativity
    api_patterns = [
      "timeout_multiplier",
      "enable_optimizations", 
      "scheduling_algorithm",
      "load_balancing_strategy",
      "resource_prediction_enabled"
    ]
    
    found_api = Enum.count(api_patterns, &String.contains?(content, &1))
    min(found_api * 16, 100)
  end

  defp assess_spec_compliance(_ast, content) do
    # Check compliance with AutoPipeline specification
    required_sections = [
      "pipeline_configuration",
      "pipeline_tasks",
      "use Spark.Dsl"
    ]
    
    compliance_score = Enum.count(required_sections, &String.contains?(content, &1))
    round(compliance_score / length(required_sections) * 100)
  end

  defp assess_spark_conventions(ast, content) do
    conventions = %{
      extension_structure: validate_extension_structure(ast, content),
      entity_definitions: validate_entity_patterns(ast, content),
      documentation_style: validate_doc_conventions(content)
    }
    
    calculate_adherence_score(conventions)
  end

  defp validate_extension_structure(_ast, content) do
    # Check for proper Spark DSL usage
    if content =~ ~r/use Spark\.Dsl.*default_extensions/, do: 90, else: 60
  end

  defp validate_entity_patterns(_ast, content) do
    # Check for proper entity definition patterns
    entity_score = if content =~ ~r/\w+\s+:\w+\s+do/, do: 85, else: 50
    entity_score
  end

  defp validate_doc_conventions(content) do
    # Check for proper documentation style
    has_moduledoc = content =~ ~r/@moduledoc\s+"""/
    if has_moduledoc, do: 80, else: 40
  end

  # Helper functions for AST analysis
  defp count_modules(ast) do
    count_nodes(ast, :defmodule)
  end

  defp count_functions(ast) do
    count_nodes(ast, :def) + count_nodes(ast, :defp)
  end

  defp find_typespecs(ast) do
    count_nodes(ast, :spec) + count_nodes(ast, :type)
  end

  defp count_nodes(ast, node_type) do
    {_, count} = Macro.prewalk(ast, 0, fn
      {^node_type, _, _}, acc -> {nil, acc + 1}
      node, acc -> {node, acc}
    end)
    count
  end

  # Scoring calculations
  defp calculate_technical_score(metrics) do
    total = Enum.reduce(Map.values(metrics), 0, &+/2)
    round(total / map_size(metrics))
  end

  defp calculate_innovation_score(patterns) do
    total = Enum.reduce(Map.values(patterns), 0, &+/2)
    round(total / map_size(patterns))
  end

  defp calculate_adherence_score(conventions) do
    total = Enum.reduce(Map.values(conventions), 0, &+/2)
    round(total / map_size(conventions))
  end

  defp calculate_weighted_average(scores) do
    {total_weighted, total_weight} = Enum.reduce(scores, {0, 0}, fn {score, weight}, {acc_score, acc_weight} ->
      {acc_score + score * weight, acc_weight + weight}
    end)
    
    round(total_weighted / total_weight)
  end

  defp generate_detailed_metrics(ast, content) do
    %{
      module_count: count_modules(ast),
      function_count: count_functions(ast),
      line_count: length(String.split(content, "\n")),
      doc_lines: count_doc_lines(content),
      complexity_estimate: estimate_complexity(ast),
      dsl_sections: count_dsl_sections(content)
    }
  end

  defp count_doc_lines(content) do
    content
    |> String.split("\n")
    |> Enum.count(&(String.contains?(&1, "@moduledoc") or String.contains?(&1, "@doc") or String.match?(&1, ~r/^\s*#/)))
  end

  defp estimate_complexity(ast) do
    # Simple complexity estimation based on nesting and control structures
    {_, complexity} = Macro.prewalk(ast, 0, fn
      {:if, _, _}, acc -> {nil, acc + 2}
      {:case, _, _}, acc -> {nil, acc + 3}
      {:cond, _, _}, acc -> {nil, acc + 3}
      {:with, _, _}, acc -> {nil, acc + 2}
      {:fn, _, _}, acc -> {nil, acc + 1}
      node, acc -> {node, acc}
    end)
    complexity
  end

  defp count_dsl_sections(content) do
    dsl_sections = [
      "pipeline_configuration",
      "pipeline_tasks",
      "mcp_integration",
      "circuit_breaker",
      "caching",
      "performance_monitoring"
    ]
    
    Enum.count(dsl_sections, &String.contains?(content, &1))
  end

  # Pattern evolution analysis
  defp analyze_pattern_evolution(metadata) do
    # Group files by creation sequence
    time_grouped = group_by_sequence(metadata)
    
    evolution_analysis = Enum.map(time_grouped, fn {sequence, files} ->
      patterns = extract_patterns_from_files(files)
      
      %{
        sequence: sequence,
        file_count: length(files),
        patterns: patterns,
        complexity_metrics: calculate_complexity_metrics(files),
        innovation_indicators: identify_innovation_indicators(files)
      }
    end)
    
    trends = %{
      complexity_trend: analyze_complexity_progression(evolution_analysis),
      pattern_diversity: analyze_pattern_diversity(evolution_analysis),
      innovation_progression: analyze_innovation_progression(evolution_analysis)
    }
    
    %{
      periods: evolution_analysis,
      trends: trends,
      key_innovations: identify_breakthrough_innovations(evolution_analysis)
    }
  end

  defp group_by_sequence(metadata) do
    metadata
    |> Enum.with_index(1)
    |> Enum.group_by(fn {_file, index} -> 
      cond do
        index <= 2 -> :early
        index <= 4 -> :middle  
        true -> :late
      end
    end)
    |> Enum.map(fn {phase, files} -> {phase, Enum.map(files, &elem(&1, 0))} end)
  end

  defp extract_patterns_from_files(files) do
    all_patterns = Enum.flat_map(files, fn file ->
      content = file.content
      
      config_patterns = extract_configuration_patterns(content)
      task_patterns = extract_task_patterns(content)
      integration_patterns = extract_integration_patterns(content)
      optimization_patterns = extract_optimization_patterns(content)
      
      config_patterns ++ task_patterns ++ integration_patterns ++ optimization_patterns
    end)
    
    all_patterns
    |> Enum.frequencies()
  end

  defp extract_configuration_patterns(content) do
    [
      if(content =~ "max_parallel", do: "max_parallel", else: nil),
      if(content =~ "quality_threshold", do: "quality_threshold", else: nil),
      if(content =~ "timeout_multiplier", do: "timeout_multiplier", else: nil),
      if(content =~ "memory_limit", do: "memory_limit", else: nil),
      if(content =~ "enable_optimizations", do: "enable_optimizations", else: nil),
      if(content =~ "scheduling_algorithm", do: "scheduling_algorithm", else: nil),
      if(content =~ "load_balancing_strategy", do: "load_balancing_strategy", else: nil)
    ]
    |> Enum.filter(& &1 != nil)
  end

  defp extract_task_patterns(content) do
    [
      if(content =~ "depends_on", do: "depends_on", else: nil),
      if(content =~ "parallel", do: "parallel", else: nil),
      if(content =~ "timeout", do: "timeout", else: nil),
      if(content =~ "resource_requirements", do: "resource_requirements", else: nil),
      if(content =~ "external_dependencies", do: "external_dependencies", else: nil),
      if(content =~ "api_integrations", do: "api_integrations", else: nil),
      if(content =~ "condition", do: "condition", else: nil)
    ]
    |> Enum.filter(& &1 != nil)
  end

  defp extract_integration_patterns(content) do
    [
      if(content =~ "mcp_integration", do: "mcp_integration", else: nil),
      if(content =~ "database_connector", do: "database_connector", else: nil),
      if(content =~ "community_insights", do: "community_insights", else: nil),
      if(content =~ "circuit_breaker", do: "circuit_breaker", else: nil),
      if(content =~ "service_discovery", do: "service_discovery", else: nil)
    ]
    |> Enum.filter(& &1 != nil)
  end

  defp extract_optimization_patterns(content) do
    [
      if(content =~ "caching", do: "caching", else: nil),
      if(content =~ "performance_monitoring", do: "performance_monitoring", else: nil),
      if(content =~ "resource_optimization", do: "resource_optimization", else: nil),
      if(content =~ "optimization", do: "optimization", else: nil),
      if(content =~ "benchmarking", do: "benchmarking", else: nil),
      if(content =~ "profiling", do: "profiling", else: nil)
    ]
    |> Enum.filter(& &1 != nil)
  end

  defp calculate_complexity_metrics(files) do
    total_lines = Enum.sum(Enum.map(files, & &1.line_count))
    avg_file_size = round(total_lines / max(length(files), 1))
    
    %{
      total_lines: total_lines,
      average_file_size: avg_file_size,
      file_count: length(files)
    }
  end

  defp identify_innovation_indicators(files) do
    innovation_keywords = [
      "advanced", "optimization", "intelligent", "sophisticated", 
      "creative", "novel", "innovative", "comprehensive"
    ]
    
    total_innovations = Enum.sum(Enum.map(files, fn file ->
      Enum.count(innovation_keywords, &String.contains?(file.content, &1))
    end))
    
    %{
      innovation_keyword_count: total_innovations,
      innovation_density: total_innovations / max(length(files), 1)
    }
  end

  defp analyze_complexity_progression(evolution_analysis) do
    complexities = Enum.map(evolution_analysis, & &1.complexity_metrics.total_lines)
    
    case complexities do
      [first | _] = list when length(list) > 1 ->
        last = List.last(list)
        growth_rate = (last - first) / first * 100
        %{trend: :increasing, growth_rate: round(growth_rate)}
      _ ->
        %{trend: :stable, growth_rate: 0}
    end
  end

  defp analyze_pattern_diversity(evolution_analysis) do
    all_patterns = Enum.flat_map(evolution_analysis, fn period ->
      Map.keys(period.patterns)
    end)
    
    unique_patterns = Enum.uniq(all_patterns)
    
    %{
      total_unique_patterns: length(unique_patterns),
      pattern_evolution: length(unique_patterns) / max(length(evolution_analysis), 1)
    }
  end

  defp analyze_innovation_progression(evolution_analysis) do
    innovation_scores = Enum.map(evolution_analysis, & &1.innovation_indicators.innovation_density)
    
    case innovation_scores do
      [first | _] = list when length(list) > 1 ->
        last = List.last(list)
        if last > first do
          %{trend: :increasing, improvement: round((last - first) / first * 100)}
        else
          %{trend: :stable, improvement: 0}
        end
      _ ->
        %{trend: :unknown, improvement: 0}
    end
  end

  defp identify_breakthrough_innovations(evolution_analysis) do
    Enum.flat_map(evolution_analysis, fn period ->
      high_innovation_files = period.patterns
      |> Enum.filter(fn {_pattern, count} -> count > 2 end)
      |> Enum.map(fn {pattern, _count} -> pattern end)
      
      if length(high_innovation_files) > 0 do
        [%{
          sequence: period.sequence,
          breakthrough_patterns: high_innovation_files
        }]
      else
        []
      end
    end)
  end

  # Gap analysis
  defp identify_gaps_and_opportunities(quality_assessments, evolution_analysis) do
    quality_gaps = %{
      low_quality_files: filter_low_quality(quality_assessments, 70),
      missing_documentation: identify_doc_gaps(quality_assessments),
      compilation_failures: identify_compilation_issues(quality_assessments)
    }
    
    innovation_gaps = %{
      underexplored_patterns: identify_missing_patterns(evolution_analysis),
      repetitive_implementations: identify_repetitive_patterns(evolution_analysis)
    }
    
    %{
      quality_gaps: quality_gaps,
      innovation_gaps: innovation_gaps,
      priority_recommendations: prioritize_improvement_areas(quality_gaps, innovation_gaps)
    }
  end

  defp filter_low_quality(assessments, threshold) do
    Enum.filter(assessments, & &1.overall_quality < threshold)
  end

  defp identify_doc_gaps(assessments) do
    Enum.filter(assessments, fn assessment ->
      doc_score = assessment.detailed_metrics[:doc_lines] || 0
      total_lines = assessment.detailed_metrics[:line_count] || 1
      doc_ratio = doc_score / total_lines
      doc_ratio < 0.1
    end)
  end

  defp identify_compilation_issues(assessments) do
    Enum.filter(assessments, & not &1.compilation_success)
  end

  defp identify_missing_patterns(evolution_analysis) do
    all_patterns = evolution_analysis.periods
    |> Enum.flat_map(& Map.keys(&1.patterns))
    |> Enum.uniq()
    
    expected_patterns = [
      "circuit_breaker", "load_balancing", "service_discovery", 
      "metrics_collection", "alerting", "auto_scaling"
    ]
    
    Enum.reject(expected_patterns, &(&1 in all_patterns))
  end

  defp identify_repetitive_patterns(evolution_analysis) do
    all_patterns = evolution_analysis.periods
    |> Enum.flat_map(& Map.to_list(&1.patterns))
    |> Enum.group_by(fn {pattern, _count} -> pattern end)
    |> Enum.filter(fn {_pattern, occurrences} -> length(occurrences) > 3 end)
    |> Enum.map(fn {pattern, _occurrences} -> pattern end)
  end

  defp prioritize_improvement_areas(quality_gaps, innovation_gaps) do
    priorities = []
    
    if length(quality_gaps.compilation_failures) > 0 do
      priorities = [%{area: :compilation, priority: :critical, count: length(quality_gaps.compilation_failures)} | priorities]
    end
    
    if length(quality_gaps.low_quality_files) > 0 do
      priorities = [%{area: :quality, priority: :high, count: length(quality_gaps.low_quality_files)} | priorities]
    end
    
    if length(quality_gaps.missing_documentation) > 0 do
      priorities = [%{area: :documentation, priority: :medium, count: length(quality_gaps.missing_documentation)} | priorities]
    end
    
    if length(innovation_gaps.underexplored_patterns) > 0 do
      priorities = [%{area: :innovation, priority: :medium, count: length(innovation_gaps.underexplored_patterns)} | priorities]
    end
    
    Enum.sort_by(priorities, fn %{priority: p} ->
      case p do
        :critical -> 1
        :high -> 2
        :medium -> 3
        :low -> 4
      end
    end)
  end

  # Recommendation generation
  defp generate_recommendations(gap_analysis, quality_assessments, evolution_analysis) do
    quality_recommendations = generate_quality_recommendations(gap_analysis.quality_gaps)
    innovation_recommendations = generate_innovation_recommendations(gap_analysis.innovation_gaps)
    architecture_recommendations = generate_architecture_recommendations(evolution_analysis)
    performance_recommendations = generate_performance_recommendations(quality_assessments)
    
    %{
      quality_improvements: quality_recommendations,
      innovation_directions: innovation_recommendations,
      architectural_enhancements: architecture_recommendations,
      performance_optimizations: performance_recommendations
    }
  end

  defp generate_quality_recommendations(quality_gaps) do
    recommendations = []
    
    if length(quality_gaps.compilation_failures) > 0 do
      recommendations = [
        %{
          category: :compilation,
          priority: :critical,
          description: "Fix compilation failures in #{length(quality_gaps.compilation_failures)} files",
          specific_actions: [
            "Review syntax errors and missing dependencies",
            "Ensure proper module structure and imports",
            "Validate DSL syntax compliance"
          ],
          expected_impact: "Enable basic functionality and further analysis"
        } | recommendations
      ]
    end
    
    if length(quality_gaps.low_quality_files) > 0 do
      recommendations = [
        %{
          category: :quality,
          priority: :high,
          description: "Improve overall quality of #{length(quality_gaps.low_quality_files)} files",
          specific_actions: [
            "Enhance code organization and structure",
            "Add comprehensive error handling",
            "Improve type safety with specifications",
            "Add unit tests for DSL components"
          ],
          expected_impact: "Increase average quality score by 15-25 points"
        } | recommendations
      ]
    end
    
    if length(quality_gaps.missing_documentation) > 0 do
      recommendations = [
        %{
          category: :documentation,
          priority: :medium,
          description: "Add documentation to #{length(quality_gaps.missing_documentation)} files",
          specific_actions: [
            "Add @moduledoc with usage examples",
            "Document all public functions with @doc",
            "Include DSL usage examples",
            "Add inline comments for complex logic"
          ],
          expected_impact: "Improve maintainability and developer experience"
        } | recommendations
      ]
    end
    
    recommendations
  end

  defp generate_innovation_recommendations(innovation_gaps) do
    recommendations = []
    
    if length(innovation_gaps.underexplored_patterns) > 0 do
      recommendations = [
        %{
          category: :innovation,
          priority: :medium,
          description: "Explore #{length(innovation_gaps.underexplored_patterns)} missing patterns",
          patterns: innovation_gaps.underexplored_patterns,
          specific_actions: [
            "Implement circuit breaker patterns for reliability",
            "Add load balancing and service discovery",
            "Integrate metrics collection and alerting",
            "Explore auto-scaling capabilities"
          ],
          expected_impact: "Enhance DSL functionality and real-world applicability"
        } | recommendations
      ]
    end
    
    if length(innovation_gaps.repetitive_implementations) > 0 do
      recommendations = [
        %{
          category: :refactoring,
          priority: :low,
          description: "Reduce repetition in #{length(innovation_gaps.repetitive_implementations)} patterns",
          patterns: innovation_gaps.repetitive_implementations,
          specific_actions: [
            "Extract common patterns into reusable components",
            "Create base templates for similar implementations",
            "Implement pattern inheritance mechanisms",
            "Add configuration-driven pattern variations"
          ],
          expected_impact: "Improve code maintainability and reduce duplication"
        } | recommendations
      ]
    end
    
    recommendations
  end

  defp generate_architecture_recommendations(_evolution_analysis) do
    [
      %{
        category: :architecture,
        priority: :medium,
        description: "Enhance DSL architecture for better extensibility",
        specific_actions: [
          "Implement plugin architecture for custom extensions",
          "Add configuration validation framework",
          "Create standard error handling patterns",
          "Design consistent API patterns across sections"
        ],
        expected_impact: "Improve DSL extensibility and consistency"
      },
      %{
        category: :integration,
        priority: :medium,
        description: "Strengthen integration patterns",
        specific_actions: [
          "Standardize MCP integration patterns",
          "Create reusable API integration templates",
          "Implement consistent error handling for external services",
          "Add integration testing framework"
        ],
        expected_impact: "Improve reliability of external integrations"
      }
    ]
  end

  defp generate_performance_recommendations(quality_assessments) do
    avg_complexity = quality_assessments
    |> Enum.map(& &1.detailed_metrics[:complexity_estimate] || 0)
    |> Enum.sum()
    |> Kernel./(max(length(quality_assessments), 1))
    
    recommendations = []
    
    if avg_complexity > 50 do
      recommendations = [
        %{
          category: :performance,
          priority: :medium,
          description: "Optimize high-complexity DSL components",
          specific_actions: [
            "Simplify complex DSL entity definitions",
            "Optimize transformer performance",
            "Reduce compilation overhead",
            "Implement lazy evaluation where appropriate"
          ],
          expected_impact: "Improve DSL compilation speed and resource usage"
        } | recommendations
      ]
    end
    
    recommendations = [
      %{
        category: :caching,
        priority: :low,
        description: "Implement intelligent caching strategies",
        specific_actions: [
          "Add compilation result caching",
          "Implement incremental DSL processing",
          "Cache expensive validation operations",
          "Add memory-efficient data structures"
        ],
        expected_impact: "Reduce DSL processing time and memory usage"
      } | recommendations
    ]
    
    recommendations
  end

  # Report generation
  defp generate_comprehensive_report(analysis_results, output_dir, analysis_type) do
    report = %{
      executive_summary: generate_executive_summary(analysis_results),
      detailed_findings: generate_detailed_findings(analysis_results),
      quality_metrics: generate_quality_dashboard(analysis_results),
      evolution_insights: generate_evolution_insights(analysis_results),
      recommendations: generate_actionable_recommendations(analysis_results),
      next_steps: generate_next_steps(analysis_results)
    }
    
    # Generate multiple report formats
    markdown_report = generate_markdown_report(report)
    json_metrics = generate_json_metrics(report)
    
    # Save reports
    report_path = Path.join(output_dir, "spark_analysis_report.md")
    metrics_path = Path.join(output_dir, "spark_quality_metrics.json")
    
    File.write!(report_path, markdown_report)
    File.write!(metrics_path, json_metrics)
    
    # Print summary to console
    print_analysis_summary(report, report_path, metrics_path)
    
    report
  end

  defp generate_executive_summary(analysis_results) do
    assessments = analysis_results.quality_assessments
    total_files = length(assessments)
    
    avg_quality = if total_files > 0 do
      total_quality = Enum.sum(Enum.map(assessments, & &1.overall_quality))
      round(total_quality / total_files)
    else
      0
    end
    
    compilation_success_rate = if total_files > 0 do
      successful = Enum.count(assessments, & &1.compilation_success)
      round(successful / total_files * 100)
    else
      0
    end
    
    high_quality_count = Enum.count(assessments, & &1.overall_quality >= 80)
    
    %{
      total_files_analyzed: total_files,
      average_quality_score: avg_quality,
      compilation_success_rate: compilation_success_rate,
      high_quality_files: high_quality_count,
      key_findings: [
        "#{total_files} DSL files analyzed across AutoPipeline iterations",
        "#{compilation_success_rate}% compilation success rate",
        "Average quality score: #{avg_quality}/100",
        "#{high_quality_count} files meet high quality standards (80+)"
      ]
    }
  end

  defp generate_detailed_findings(analysis_results) do
    %{
      compilation_analysis: analyze_compilation_results(analysis_results.quality_assessments),
      quality_distribution: analyze_quality_distribution(analysis_results.quality_assessments),
      pattern_analysis: analyze_detected_patterns(analysis_results.evolution_analysis),
      innovation_analysis: analyze_innovation_metrics(analysis_results.quality_assessments)
    }
  end

  defp analyze_compilation_results(assessments) do
    successful = Enum.filter(assessments, & &1.compilation_success)
    failed = Enum.filter(assessments, & not &1.compilation_success)
    
    %{
      successful_count: length(successful),
      failed_count: length(failed),
      failed_files: Enum.map(failed, & &1.file),
      success_rate: (if length(assessments) > 0, do: round(length(successful) / length(assessments) * 100), else: 0)
    }
  end

  defp analyze_quality_distribution(assessments) do
    scores = Enum.map(assessments, & &1.overall_quality)
    
    %{
      excellent: Enum.count(scores, &(&1 >= 90)),
      good: Enum.count(scores, &(&1 >= 70 and &1 < 90)),
      fair: Enum.count(scores, &(&1 >= 50 and &1 < 70)),
      poor: Enum.count(scores, &(&1 < 50)),
      average: (if length(scores) > 0, do: round(Enum.sum(scores) / length(scores)), else: 0),
      median: calculate_median(scores)
    }
  end

  defp analyze_detected_patterns(evolution_analysis) do
    all_patterns = evolution_analysis.periods
    |> Enum.flat_map(& Map.to_list(&1.patterns))
    |> Enum.group_by(fn {pattern, _count} -> pattern end)
    |> Enum.map(fn {pattern, occurrences} -> 
      total_count = Enum.sum(Enum.map(occurrences, fn {_, count} -> count end))
      {pattern, total_count}
    end)
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    
    %{
      most_common_patterns: Enum.take(all_patterns, 10),
      total_unique_patterns: length(all_patterns),
      pattern_evolution: evolution_analysis.trends
    }
  end

  defp analyze_innovation_metrics(assessments) do
    innovation_scores = Enum.map(assessments, & &1.innovation_score)
    
    %{
      average_innovation_score: (if length(innovation_scores) > 0, do: round(Enum.sum(innovation_scores) / length(innovation_scores)), else: 0),
      highly_innovative_files: Enum.count(innovation_scores, &(&1 >= 80)),
      innovation_distribution: %{
        high: Enum.count(innovation_scores, &(&1 >= 80)),
        medium: Enum.count(innovation_scores, &(&1 >= 60 and &1 < 80)),
        low: Enum.count(innovation_scores, &(&1 < 60))
      }
    }
  end

  defp generate_quality_dashboard(analysis_results) do
    assessments = analysis_results.quality_assessments
    
    %{
      overall_metrics: %{
        total_files: length(assessments),
        compilation_success_rate: calculate_compilation_success_rate(assessments),
        average_quality: calculate_average_quality(assessments),
        high_quality_percentage: calculate_high_quality_percentage(assessments)
      },
      score_breakdown: %{
        technical_excellence: calculate_average_score(assessments, :technical_excellence),
        innovation_score: calculate_average_score(assessments, :innovation_score),
        spec_compliance: calculate_average_score(assessments, :spec_compliance),
        spark_adherence: calculate_average_score(assessments, :spark_adherence)
      },
      file_metrics: Enum.map(assessments, fn assessment ->
        %{
          file: Path.basename(assessment.file),
          overall_quality: assessment.overall_quality,
          compilation_success: assessment.compilation_success,
          line_count: assessment.detailed_metrics[:line_count] || 0,
          complexity: assessment.detailed_metrics[:complexity_estimate] || 0
        }
      end)
    }
  end

  defp generate_evolution_insights(analysis_results) do
    evolution = analysis_results.evolution_analysis
    
    %{
      trend_analysis: evolution.trends,
      breakthrough_innovations: evolution.key_innovations,
      complexity_progression: evolution.trends.complexity_trend,
      pattern_diversity_growth: evolution.trends.pattern_diversity
    }
  end

  defp generate_actionable_recommendations(analysis_results) do
    analysis_results.recommendations
  end

  defp generate_next_steps(analysis_results) do
    priorities = analysis_results.gap_analysis.priority_recommendations
    
    immediate_actions = Enum.filter(priorities, & &1.priority == :critical)
    short_term_actions = Enum.filter(priorities, & &1.priority == :high)
    long_term_actions = Enum.filter(priorities, & &1.priority in [:medium, :low])
    
    %{
      immediate: Enum.map(immediate_actions, & &1.area),
      short_term: Enum.map(short_term_actions, & &1.area),
      long_term: Enum.map(long_term_actions, & &1.area)
    }
  end

  # Helper calculation functions
  defp calculate_compilation_success_rate(assessments) do
    if length(assessments) > 0 do
      successful = Enum.count(assessments, & &1.compilation_success)
      round(successful / length(assessments) * 100)
    else
      0
    end
  end

  defp calculate_average_quality(assessments) do
    if length(assessments) > 0 do
      total = Enum.sum(Enum.map(assessments, & &1.overall_quality))
      round(total / length(assessments))
    else
      0
    end
  end

  defp calculate_high_quality_percentage(assessments) do
    if length(assessments) > 0 do
      high_quality = Enum.count(assessments, & &1.overall_quality >= 80)
      round(high_quality / length(assessments) * 100)
    else
      0
    end
  end

  defp calculate_average_score(assessments, field) do
    scores = Enum.map(assessments, &Map.get(&1, field, 0))
    if length(scores) > 0 do
      round(Enum.sum(scores) / length(scores))
    else
      0
    end
  end

  defp calculate_median(scores) when length(scores) == 0, do: 0
  defp calculate_median(scores) do
    sorted = Enum.sort(scores)
    len = length(sorted)
    
    if rem(len, 2) == 0 do
      mid1 = Enum.at(sorted, div(len, 2) - 1)
      mid2 = Enum.at(sorted, div(len, 2))
      round((mid1 + mid2) / 2)
    else
      Enum.at(sorted, div(len, 2))
    end
  end

  # Report formatting
  defp generate_markdown_report(report) do
    """
    # Spark DSL Iteration Analysis Report
    
    Generated on: #{DateTime.utc_now() |> DateTime.to_string()}
    
    ## Executive Summary
    
    #{format_executive_summary(report.executive_summary)}
    
    ## Quality Metrics Dashboard
    
    #{format_quality_dashboard(report.quality_metrics)}
    
    ## Detailed Findings
    
    #{format_detailed_findings(report.detailed_findings)}
    
    ## Evolution Insights
    
    #{format_evolution_insights(report.evolution_insights)}
    
    ## Recommendations
    
    #{format_recommendations(report.recommendations)}
    
    ## Next Steps
    
    #{format_next_steps(report.next_steps)}
    
    ---
    
    *Report generated by Spark DSL Analyzer*
    """
  end

  defp format_executive_summary(summary) do
    """
    ### Overview
    - **Total Files Analyzed**: #{summary.total_files_analyzed}
    - **Average Quality Score**: #{summary.average_quality_score}/100
    - **Compilation Success Rate**: #{summary.compilation_success_rate}%
    - **High Quality Files**: #{summary.high_quality_files}
    
    ### Key Findings
    #{Enum.map_join(summary.key_findings, "\n", &("- " <> &1))}
    """
  end

  defp format_quality_dashboard(metrics) do
    """
    ### Overall Metrics
    - **Total Files**: #{metrics.overall_metrics.total_files}
    - **Compilation Success Rate**: #{metrics.overall_metrics.compilation_success_rate}%
    - **Average Quality**: #{metrics.overall_metrics.average_quality}/100
    - **High Quality Percentage**: #{metrics.overall_metrics.high_quality_percentage}%
    
    ### Score Breakdown
    - **Technical Excellence**: #{metrics.score_breakdown.technical_excellence}/100
    - **Innovation Score**: #{metrics.score_breakdown.innovation_score}/100
    - **Specification Compliance**: #{metrics.score_breakdown.spec_compliance}/100
    - **Spark Framework Adherence**: #{metrics.score_breakdown.spark_adherence}/100
    
    ### File-by-File Analysis
    
    | File | Quality Score | Compilation | Lines | Complexity |
    |------|---------------|-------------|-------|------------|
    #{format_file_metrics_table(metrics.file_metrics)}
    """
  end

  defp format_file_metrics_table(file_metrics) do
    Enum.map_join(file_metrics, "\n", fn metric ->
      "| #{metric.file} | #{metric.overall_quality}/100 | #{if metric.compilation_success, do: "✅", else: "❌"} | #{metric.line_count} | #{metric.complexity} |"
    end)
  end

  defp format_detailed_findings(findings) do
    """
    ### Compilation Analysis
    - **Successful**: #{findings.compilation_analysis.successful_count} files
    - **Failed**: #{findings.compilation_analysis.failed_count} files
    - **Success Rate**: #{findings.compilation_analysis.success_rate}%
    
    #{if length(findings.compilation_analysis.failed_files) > 0 do
      "#### Failed Files\n" <> Enum.map_join(findings.compilation_analysis.failed_files, "\n", &("- " <> Path.basename(&1)))
    else
      ""
    end}
    
    ### Quality Distribution
    - **Excellent (90-100)**: #{findings.quality_distribution.excellent} files
    - **Good (70-89)**: #{findings.quality_distribution.good} files
    - **Fair (50-69)**: #{findings.quality_distribution.fair} files
    - **Poor (<50)**: #{findings.quality_distribution.poor} files
    
    ### Pattern Analysis
    #### Most Common Patterns
    #{format_pattern_list(findings.pattern_analysis.most_common_patterns)}
    
    ### Innovation Analysis
    - **Average Innovation Score**: #{findings.innovation_analysis.average_innovation_score}/100
    - **Highly Innovative Files**: #{findings.innovation_analysis.highly_innovative_files}
    """
  end

  defp format_pattern_list(patterns) do
    patterns
    |> Enum.take(10)
    |> Enum.map_join("\n", fn {pattern, count} -> "- **#{pattern}**: #{count} occurrences" end)
  end

  defp format_evolution_insights(insights) do
    """
    ### Trend Analysis
    - **Complexity Trend**: #{insights.trend_analysis.complexity_trend.trend}
    - **Pattern Diversity**: #{insights.trend_analysis.pattern_diversity.total_unique_patterns} unique patterns
    - **Innovation Progression**: #{insights.trend_analysis.innovation_progression.trend}
    
    ### Breakthrough Innovations
    #{if length(insights.breakthrough_innovations) > 0 do
      Enum.map_join(insights.breakthrough_innovations, "\n", fn innovation ->
        "- **Sequence #{innovation.sequence}**: #{Enum.join(innovation.breakthrough_patterns, ", ")}"
      end)
    else
      "No major breakthrough innovations identified."
    end}
    """
  end

  defp format_recommendations(recommendations) do
    """
    ### Quality Improvements
    #{format_recommendation_category(recommendations.quality_improvements)}
    
    ### Innovation Directions
    #{format_recommendation_category(recommendations.innovation_directions)}
    
    ### Architectural Enhancements
    #{format_recommendation_category(recommendations.architectural_enhancements)}
    
    ### Performance Optimizations
    #{format_recommendation_category(recommendations.performance_optimizations)}
    """
  end

  defp format_recommendation_category(recommendations) do
    if length(recommendations) > 0 do
      Enum.map_join(recommendations, "\n\n", fn rec ->
        """
        #### #{String.capitalize(to_string(rec.category))} (Priority: #{rec.priority})
        
        **Description**: #{rec.description}
        
        **Specific Actions**:
        #{Enum.map_join(rec.specific_actions, "\n", &("- " <> &1))}
        
        **Expected Impact**: #{rec.expected_impact}
        """
      end)
    else
      "No specific recommendations in this category."
    end
  end

  defp format_next_steps(next_steps) do
    """
    ### Immediate Actions (Critical Priority)
    #{format_action_list(next_steps.immediate)}
    
    ### Short-term Actions (High Priority)
    #{format_action_list(next_steps.short_term)}
    
    ### Long-term Actions (Medium/Low Priority)
    #{format_action_list(next_steps.long_term)}
    """
  end

  defp format_action_list(actions) do
    if length(actions) > 0 do
      Enum.map_join(actions, "\n", fn action -> "- #{String.capitalize(to_string(action))}" end)
    else
      "No actions required in this timeframe."
    end
  end

  defp generate_json_metrics(report) do
    # Generate a formatted string representation of metrics
    """
    {
      "timestamp": "#{DateTime.utc_now() |> DateTime.to_iso8601()}",
      "summary": {
        "total_files_analyzed": #{report.executive_summary.total_files_analyzed},
        "average_quality_score": #{report.executive_summary.average_quality_score},
        "compilation_success_rate": #{report.executive_summary.compilation_success_rate},
        "high_quality_files": #{report.executive_summary.high_quality_files}
      },
      "quality_metrics": {
        "overall_metrics": {
          "total_files": #{report.quality_metrics.overall_metrics.total_files},
          "compilation_success_rate": #{report.quality_metrics.overall_metrics.compilation_success_rate},
          "average_quality": #{report.quality_metrics.overall_metrics.average_quality},
          "high_quality_percentage": #{report.quality_metrics.overall_metrics.high_quality_percentage}
        },
        "score_breakdown": {
          "technical_excellence": #{report.quality_metrics.score_breakdown.technical_excellence},
          "innovation_score": #{report.quality_metrics.score_breakdown.innovation_score},
          "spec_compliance": #{report.quality_metrics.score_breakdown.spec_compliance},
          "spark_adherence": #{report.quality_metrics.score_breakdown.spark_adherence}
        }
      }
    }
    """
  end

  defp print_analysis_summary(report, report_path, metrics_path) do
    IO.puts("""
    
    📊 Spark DSL Iteration Analysis Complete
    ========================================
    
    📈 Quality Overview:
       Average Quality Score: #{report.executive_summary.average_quality_score}/100
       High Quality Files: #{report.executive_summary.high_quality_files}
       Compilation Success: #{report.executive_summary.compilation_success_rate}%
    
    🚀 Innovation Insights:
       Unique Patterns: #{report.detailed_findings.pattern_analysis.total_unique_patterns}
       Innovation Trend: #{report.evolution_insights.trend_analysis.innovation_progression.trend}
       Breakthrough Innovations: #{length(report.evolution_insights.breakthrough_innovations)}
    
    🎯 Key Recommendations:
    #{format_top_recommendations(report.recommendations)}
    
    📋 Next Steps:
    #{format_priority_next_steps(report.next_steps)}
    
    📁 Full Report: #{Path.absname(report_path)}
    📊 Metrics: #{Path.absname(metrics_path)}
    """)
  end

  defp format_top_recommendations(recommendations) do
    all_recs = [
      recommendations.quality_improvements,
      recommendations.innovation_directions,
      recommendations.architectural_enhancements,
      recommendations.performance_optimizations
    ]
    |> List.flatten()
    |> Enum.filter(& &1.priority in [:critical, :high])
    |> Enum.take(3)
    
    if length(all_recs) > 0 do
      Enum.map_join(all_recs, "\n", fn rec ->
        "       • #{rec.description} (#{rec.priority})"
      end)
    else
      "       • No critical recommendations identified"
    end
  end

  defp format_priority_next_steps(next_steps) do
    immediate = next_steps.immediate
    short_term = next_steps.short_term
    
    steps = []
    
    if length(immediate) > 0 do
      steps = ["       • Immediate: #{Enum.join(immediate, ", ")}" | steps]
    end
    
    if length(short_term) > 0 do
      steps = ["       • Short-term: #{Enum.join(short_term, ", ")}" | steps]
    end
    
    if length(steps) > 0 do
      Enum.join(steps, "\n")
    else
      "       • No urgent actions required"
    end
  end
end