defmodule RequirementsParser do
  @moduledoc """
  RequirementsParser - Natural Language to DSL Specification Domain
  
  This Ash domain handles the parsing and analysis of natural language
  requirements into structured DSL specifications that can be used by
  the DSL generation pipeline.
  
  ## Architecture
  
  The domain manages:
  - Specifications (parsed requirements with structured data)
  - ParsedEntities (individual entities extracted from requirements)
  - FeatureExtractions (identified features and their metadata)
  - DomainMappings (mapping requirements to known domains)
  
  ## Usage
  
      # Parse natural language requirements
      {:ok, spec} = RequirementsParser.create!(RequirementsParser.Resources.Specification, %{
        original_text: "I need an API DSL with authentication and validation"
      })
      
      # Get parsed entities
      entities = RequirementsParser.read!(RequirementsParser.Resources.ParsedEntity, 
        :by_specification, %{specification_id: spec.id})
  """
  
  use Ash.Domain

  resources do
    resource RequirementsParser.Resources.Specification
    resource RequirementsParser.Resources.ParsedEntity
    resource RequirementsParser.Resources.FeatureExtraction
    resource RequirementsParser.Resources.DomainMapping
  end

  authorization do
    authorize :by_default
    require_actor? false
  end

  @doc """
  Parses natural language requirements into a structured specification.
  """
  def parse_requirements(text, opts \\ []) do
    case create!(RequirementsParser.Resources.Specification, %{
      original_text: text,
      parsing_options: Map.new(opts)
    }) do
      {:ok, specification} ->
        # The parsing happens automatically through Ash actions
        {:ok, specification}
        
      {:error, reason} ->
        {:error, {:parsing_failed, reason}}
    end
  end

  @doc """
  Analyzes code examples to extract DSL patterns.
  """
  def analyze_code_example(code, language \\ :elixir) do
    create!(RequirementsParser.Resources.Specification, %{
      original_text: code,
      input_type: :code_example,
      language: language
    })
  end

  @doc """
  Refines an existing specification with additional context.
  """
  def refine_specification(specification_id, refinements) do
    specification = get!(RequirementsParser.Resources.Specification, specification_id)
    
    update!(specification, :refine_with_context, %{
      refinements: refinements
    })
  end

  @doc """
  Gets all features extracted from a specification.
  """
  def get_extracted_features(specification_id) do
    read!(RequirementsParser.Resources.FeatureExtraction, 
      :by_specification, %{specification_id: specification_id})
  end

  @doc """
  Gets all entities parsed from a specification.
  """
  def get_parsed_entities(specification_id) do
    read!(RequirementsParser.Resources.ParsedEntity, 
      :by_specification, %{specification_id: specification_id})
  end

  @doc """
  Analyzes parsing patterns across multiple specifications.
  """
  def analyze_parsing_patterns(opts \\ []) do
    timeframe = Keyword.get(opts, :timeframe, "30d")
    
    specifications = read!(RequirementsParser.Resources.Specification, 
      :recent, %{timeframe: timeframe})
    
    %{
      total_parsed: length(specifications),
      success_rate: calculate_success_rate(specifications),
      common_domains: extract_common_domains(specifications),
      feature_frequency: analyze_feature_frequency(specifications),
      complexity_distribution: analyze_complexity_distribution(specifications),
      parsing_performance: analyze_parsing_performance(specifications)
    }
  end

  @doc """
  Gets parsing statistics for monitoring and optimization.
  """
  def get_parsing_statistics do
    specifications = read!(RequirementsParser.Resources.Specification)
    feature_extractions = read!(RequirementsParser.Resources.FeatureExtraction)
    entities = read!(RequirementsParser.Resources.ParsedEntity)
    
    %{
      total_specifications: length(specifications),
      total_features: length(feature_extractions),
      total_entities: length(entities),
      average_confidence: calculate_average_confidence(specifications),
      success_rate: calculate_success_rate(specifications),
      processing_speed: calculate_processing_speed(specifications),
      domain_coverage: analyze_domain_coverage(specifications)
    }
  end

  # Private helper functions

  defp calculate_success_rate(specifications) do
    if length(specifications) == 0 do
      0.0
    else
      successful = Enum.count(specifications, &(&1.confidence_score && &1.confidence_score > 0.7))
      successful / length(specifications)
    end
  end

  defp extract_common_domains(specifications) do
    specifications
    |> Enum.map(& &1.domain)
    |> Enum.filter(& &1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_domain, count} -> count end, :desc)
    |> Enum.take(10)
  end

  defp analyze_feature_frequency(specifications) do
    specifications
    |> Enum.flat_map(& &1.features || [])
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_feature, count} -> count end, :desc)
    |> Enum.take(20)
  end

  defp analyze_complexity_distribution(specifications) do
    complexities = Enum.map(specifications, & &1.complexity)
    
    %{
      simple: Enum.count(complexities, &(&1 == :simple)),
      standard: Enum.count(complexities, &(&1 == :standard)),
      advanced: Enum.count(complexities, &(&1 == :advanced)),
      enterprise: Enum.count(complexities, &(&1 == :enterprise))
    }
  end

  defp analyze_parsing_performance(specifications) do
    processing_times = specifications
                      |> Enum.map(& &1.processing_time_ms)
                      |> Enum.filter(& &1)
    
    if length(processing_times) > 0 do
      %{
        average_ms: Enum.sum(processing_times) / length(processing_times),
        fastest_ms: Enum.min(processing_times),
        slowest_ms: Enum.max(processing_times),
        median_ms: calculate_median(processing_times)
      }
    else
      %{average_ms: 0, fastest_ms: 0, slowest_ms: 0, median_ms: 0}
    end
  end

  defp calculate_average_confidence(specifications) do
    confidence_scores = specifications
                       |> Enum.map(& &1.confidence_score)
                       |> Enum.filter(& &1)
    
    if length(confidence_scores) > 0 do
      Enum.sum(confidence_scores) / length(confidence_scores)
    else
      0.0
    end
  end

  defp calculate_processing_speed(specifications) do
    recent_specs = specifications
                  |> Enum.filter(&(&1.inserted_at && DateTime.diff(DateTime.utc_now(), &1.inserted_at, :day) <= 7))
    
    analyze_parsing_performance(recent_specs).average_ms
  end

  defp analyze_domain_coverage(specifications) do
    domains = specifications
             |> Enum.map(& &1.domain)
             |> Enum.filter(& &1)
             |> Enum.uniq()
    
    %{
      total_domains: length(domains),
      covered_domains: domains,
      domain_distribution: extract_common_domains(specifications)
    }
  end

  defp calculate_median(numbers) do
    sorted = Enum.sort(numbers)
    length = length(sorted)
    
    if rem(length, 2) == 0 do
      # Even number of elements
      middle1 = Enum.at(sorted, div(length, 2) - 1)
      middle2 = Enum.at(sorted, div(length, 2))
      (middle1 + middle2) / 2
    else
      # Odd number of elements
      Enum.at(sorted, div(length, 2))
    end
  end
end