defmodule UsageAnalyzer.Resources.AnalysisReport do
  use Ash.Resource,
    extensions: [AshPostgres.DataLayer],
    data_layer: AshPostgres.DataLayer

  postgres do
    table "analysis_reports"
    repo UsageAnalyzer.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :target_dsl, :string, allow_nil?: false
    attribute :analysis_type, :atom, constraints: [one_of: [:patterns, :performance, :pain_points, :evolution, :introspection]]
    attribute :time_window, :string
    attribute :data_sources, {:array, :atom}, default: []
    attribute :findings, :map, default: %{}
    attribute :recommendations, {:array, :string}, default: []
    attribute :confidence, :decimal, constraints: [min: 0.0, max: 1.0]
    attribute :sample_size, :integer
    attribute :analysis_depth, :atom, constraints: [one_of: [:surface, :moderate, :deep, :comprehensive]]
    attribute :status, :atom, constraints: [one_of: [:pending, :analyzing, :completed, :failed]], default: :pending
    timestamps()
  end

  relationships do
    has_many :pattern_detections, UsageAnalyzer.Resources.PatternDetection
    has_many :performance_metrics, UsageAnalyzer.Resources.PerformanceMetric
    has_many :usage_insights, UsageAnalyzer.Resources.UsageInsight
  end

  actions do
    defaults [:create, :read, :update, :destroy]
    
    create :analyze_dsl_usage do
      accept [:target_dsl, :analysis_type, :time_window, :data_sources, :analysis_depth]
      
      change UsageAnalyzer.Changes.ValidateDataSources
      change UsageAnalyzer.Changes.CollectUsageData
      change UsageAnalyzer.Changes.AnalyzePatterns
      change UsageAnalyzer.Changes.GenerateInsights
      change UsageAnalyzer.Changes.CreateRecommendations
      change set_attribute(:status, :analyzing)
      
      after_action UsageAnalyzer.AfterActions.StartAnalysis
    end
    
    create :introspect_ash_resource do
      accept [:target_dsl]
      argument :resource_module, :atom, allow_nil?: false
      
      change UsageAnalyzer.Changes.IntrospectAshResource
      change UsageAnalyzer.Changes.AnalyzeResourceComplexity
      change UsageAnalyzer.Changes.ExtractUsagePatterns
      
      after_action UsageAnalyzer.AfterActions.CreateIntrospectionInsights
    end
    
    update :complete_analysis do
      accept [:findings, :recommendations, :confidence, :sample_size]
      
      change set_attribute(:status, :completed)
      change UsageAnalyzer.Changes.CalculateFinalScore
    end
    
    update :mark_failed do
      accept []
      argument :error_reason, :string
      
      change set_attribute(:status, :failed)
      change UsageAnalyzer.Changes.LogFailureReason
    end
  end

  validations do
    validate {UsageAnalyzer.Validations.ValidTimeWindow, []}
    validate {UsageAnalyzer.Validations.SufficientDataSources, minimum: 1}
  end

  calculations do
    calculate :actionability_score, :decimal do
      calculation UsageAnalyzer.Calculations.ActionabilityScore
    end
    
    calculate :pattern_strength, :decimal do
      calculation UsageAnalyzer.Calculations.PatternStrength
    end
    
    calculate :recommendation_priority, :atom do
      calculation UsageAnalyzer.Calculations.RecommendationPriority
    end
  end

  def analyze_ash_resource(resource) when is_atom(resource) do
    %{
      structure: %{
        attributes: Ash.Resource.Info.attributes(resource),
        actions: Ash.Resource.Info.actions(resource),
        relationships: Ash.Resource.Info.relationships(resource),
        calculations: Ash.Resource.Info.calculations(resource),
        validations: Ash.Resource.Info.validations(resource)
      },
      usage_patterns: extract_action_patterns(resource),
      complexity_metrics: calculate_resource_complexity(resource),
      extension_usage: analyze_extension_usage(resource)
    }
  end

  defp extract_action_patterns(resource) do
    actions = Ash.Resource.Info.actions(resource)
    
    %{
      create_actions: Enum.filter(actions, &(&1.type == :create)) |> length(),
      read_actions: Enum.filter(actions, &(&1.type == :read)) |> length(),
      update_actions: Enum.filter(actions, &(&1.type == :update)) |> length(),
      destroy_actions: Enum.filter(actions, &(&1.type == :destroy)) |> length(),
      custom_patterns: analyze_custom_action_patterns(actions)
    }
  end

  defp calculate_resource_complexity(resource) do
    attributes = Ash.Resource.Info.attributes(resource)
    relationships = Ash.Resource.Info.relationships(resource)
    
    %{
      attribute_count: length(attributes),
      relationship_count: length(relationships),
      complexity_score: (length(attributes) + length(relationships) * 2) / 10
    }
  end

  defp analyze_extension_usage(resource) do
    extensions = Ash.Resource.Info.extensions(resource)
    
    %{
      extensions: extensions,
      data_layer: extract_data_layer(extensions),
      api_layers: extract_api_layers(extensions)
    }
  end

  defp analyze_custom_action_patterns(actions) do
    custom_actions = Enum.reject(actions, &(&1.name in [:create, :read, :update, :destroy]))
    
    %{
      count: length(custom_actions),
      naming_patterns: extract_naming_patterns(custom_actions),
      argument_patterns: extract_argument_patterns(custom_actions)
    }
  end

  defp extract_data_layer(extensions) do
    Enum.find_value(extensions, fn ext ->
      if String.contains?(to_string(ext), "DataLayer"), do: ext
    end)
  end

  defp extract_api_layers(extensions) do
    Enum.filter(extensions, fn ext ->
      ext_string = to_string(ext)
      String.contains?(ext_string, "JsonApi") or String.contains?(ext_string, "Graphql")
    end)
  end

  defp extract_naming_patterns(actions) do
    actions
    |> Enum.map(& &1.name)
    |> Enum.group_by(&extract_verb/1)
  end

  defp extract_argument_patterns(actions) do
    actions
    |> Enum.flat_map(& &1.arguments)
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, args} -> {type, length(args)} end)
    |> Map.new()
  end

  defp extract_verb(action_name) do
    action_string = to_string(action_name)
    cond do
      String.starts_with?(action_string, "create") -> :create_pattern
      String.starts_with?(action_string, "update") -> :update_pattern
      String.starts_with?(action_string, "delete") -> :delete_pattern
      String.starts_with?(action_string, "get") -> :get_pattern
      String.starts_with?(action_string, "list") -> :list_pattern
      true -> :other_pattern
    end
  end
end