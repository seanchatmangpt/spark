defmodule DslAssistant.Preparations do
  @moduledoc """
  Ash preparation modules for DSL Assistant domain.
  
  These preparations modify queries before they are executed,
  typically for filtering, sorting, or adding context.
  """
end

defmodule DslAssistant.Preparations.FilterRecentAnalyses do
  use Ash.Resource.Preparation
  
  def prepare(query, opts, _context) do
    days_back = opts[:days_back] || 30
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    Ash.Query.filter(query, analysis_timestamp >= ^cutoff_date)
  end
end

defmodule DslAssistant.Preparations.FilterRecentPatterns do
  use Ash.Resource.Preparation
  
  def prepare(query, opts, _context) do
    days_back = opts[:days_back] || 30
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    Ash.Query.filter(query, last_observed >= ^cutoff_date)
  end
end

defmodule DslAssistant.Preparations.FilterRecentResults do
  use Ash.Resource.Preparation
  
  def prepare(query, opts, _context) do
    days_back = opts[:days_back] || 30
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_back, :day)
    
    Ash.Query.filter(query, measured_at >= ^cutoff_date)
  end
end

defmodule DslAssistant.Preparations.LoadRelatedData do
  use Ash.Resource.Preparation
  
  def prepare(query, opts, _context) do
    relationships = opts[:relationships] || []
    
    Enum.reduce(relationships, query, fn relationship, acc ->
      Ash.Query.load(acc, relationship)
    end)
  end
end

defmodule DslAssistant.Preparations.SortByPriority do
  use Ash.Resource.Preparation
  
  def prepare(query, _opts, _context) do
    query
    |> Ash.Query.sort([priority_score: :desc, impact_score: :desc])
  end
end

defmodule DslAssistant.Preparations.FilterByConfidence do
  use Ash.Resource.Preparation
  
  def prepare(query, opts, _context) do
    min_confidence = opts[:min_confidence] || 0.7
    
    # This would work for resources that have a confidence_score field
    case Ash.Query.get_filter(query) do
      nil -> Ash.Query.filter(query, confidence_score >= ^min_confidence)
      _ -> query  # Don't override existing filters
    end
  end
end