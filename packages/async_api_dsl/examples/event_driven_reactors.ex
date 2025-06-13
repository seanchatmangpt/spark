defmodule OmniRepo.EventDrivenReactors do
  @moduledoc """
  Demonstration of integrating AsyncAPI-generated clients with Reactor for
  event-driven reactive programming patterns.
  
  This module shows how to automatically generate Reactor steps from AsyncAPI
  operation definitions, creating type-safe, reactive event processing pipelines.
  """

  use Reactor
  
  # Import the generated event API
  alias OmniRepo.Events.Api
  alias OmniRepo.Events.EventBus

  # Automatically generate Reactor steps from AsyncAPI operations
  for operation <- Api.operations() do
    case operation.action do
      :send ->
        # Generate publishing steps for send operations
        step_name = :"publish_#{operation.operation_id}"
        
        step step_name do
          argument :payload, :map
          argument :correlation_id, :string, optional: true
          
          run fn args ->
            correlation_id = args[:correlation_id] || UUID.uuid4()
            
            case EventBus.call(operation.operation_id, args.payload, correlation_id) do
              :ok -> {:ok, %{published: true, correlation_id: correlation_id}}
              {:error, reason} -> {:error, reason}
            end
          end
        end
        
      :receive ->
        # Generate subscription steps for receive operations  
        step_name = :"subscribe_#{operation.operation_id}"
        
        step step_name do
          argument :handler, :function
          argument :options, :map, default: %{}
          
          run fn args ->
            subscription_id = UUID.uuid4()
            
            case EventBus.subscribe(operation.operation_id, args.handler, args.options) do
              {:ok, pid} -> {:ok, %{subscription_id: subscription_id, pid: pid}}
              {:error, reason} -> {:error, reason}
            end
          end
        end
    end
  end

  # High-level reactive patterns
  
  @doc """
  Repository indexing and analysis pipeline.
  
  This reactor orchestrates the complete flow from indexing trigger to
  analysis completion, with automatic error handling and retry logic.
  """
  step :repository_processing_pipeline do
    argument :repository_id, :string
    argument :indexing_options, :map, default: %{}
    argument :analysis_options, :map, default: %{}
    
    # Step 1: Trigger repository indexing
    step :trigger_indexing do
      argument :repository_id, from_input()
      argument :options, from_input(:indexing_options)
      
      run fn args ->
        payload = %{
          repository_id: args.repository_id,
          priority: args.options[:priority] || "normal",
          full_reindex: args.options[:full_reindex] || false,
          requested_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }
        
        EventBus.publish_indexing_request(payload)
      end
    end
    
    # Step 2: Wait for indexing completion
    step :wait_for_indexing do
      argument :repository_id, from_input()
      argument :timeout, from_input(:indexing_options), path: [:timeout], default: 300_000
      
      run fn args ->
        correlation_id = UUID.uuid4()
        
        # Set up subscription with timeout
        receive_task = Task.async(fn ->
          EventBus.subscribe(:receive_repository_indexed, fn event ->
            if event.payload.repository_id == args.repository_id do
              send(self(), {:indexing_complete, event})
            end
          end)
          
          receive do
            {:indexing_complete, event} -> {:ok, event}
          after
            args.timeout -> {:error, :indexing_timeout}
          end
        end)
        
        case Task.await(receive_task, args.timeout + 1000) do
          {:ok, event} -> {:ok, %{indexed_event: event}}
          {:error, reason} -> {:error, reason}
        end
      end
    end
    
    # Step 3: Trigger analysis pipeline
    step :trigger_analysis do
      argument :indexed_event, from_result(:wait_for_indexing, path: [:indexed_event])
      argument :analysis_options, from_input()
      
      run fn args ->
        payload = %{
          repository_id: args.indexed_event.payload.repository_id,
          index_version: args.indexed_event.payload.version,
          analysis_types: args.analysis_options[:types] || ["quality", "security", "performance"],
          priority: args.analysis_options[:priority] || "normal",
          requested_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }
        
        EventBus.publish_analysis_request(payload)
      end
    end
    
    # Step 4: Collect analysis results
    step :collect_analysis_results do
      argument :repository_id, from_input()
      argument :analysis_types, from_input(:analysis_options), path: [:types], default: ["quality", "security", "performance"]
      argument :timeout, from_input(:analysis_options), path: [:timeout], default: 600_000
      
      run fn args ->
        results = %{}
        remaining_types = MapSet.new(args.analysis_types)
        
        correlation_id = UUID.uuid4()
        
        receive_task = Task.async(fn ->
          EventBus.subscribe(:receive_analysis_results, fn event ->
            if event.payload.repository_id == args.repository_id and
               event.payload.analysis_type in args.analysis_types do
              send(self(), {:analysis_result, event})
            end
          end)
          
          collect_results(args.repository_id, remaining_types, %{}, args.timeout)
        end)
        
        case Task.await(receive_task, args.timeout + 1000) do
          {:ok, results} -> {:ok, %{analysis_results: results}}
          {:error, reason} -> {:error, reason}
        end
      end
    end
    
    # Step 5: Generate summary report
    step :generate_summary do
      argument :indexed_event, from_result(:wait_for_indexing, path: [:indexed_event])
      argument :analysis_results, from_result(:collect_analysis_results, path: [:analysis_results])
      
      run fn args ->
        summary = %{
          repository_id: args.indexed_event.payload.repository_id,
          processing_completed_at: DateTime.utc_now() |> DateTime.to_iso8601(),
          indexing: %{
            completed_at: args.indexed_event.payload.indexed_at,
            statistics: args.indexed_event.payload.statistics,
            duration_ms: args.indexed_event.payload.duration_ms
          },
          analysis: args.analysis_results,
          overall_score: calculate_overall_score(args.analysis_results)
        }
        
        # Publish summary event
        EventBus.publish_processing_summary(summary)
        
        {:ok, summary}
      end
    end
  end

  @doc """
  Real-time file change processing reactor.
  
  Processes file changes in real-time, triggering incremental updates
  to search indices and analysis results.
  """
  step :file_change_processor do
    argument :repository_id, :string
    argument :change_event, :map
    
    # Step 1: Validate change event
    step :validate_change do
      argument :change_event, from_input()
      
      run fn args ->
        case validate_file_change(args.change_event) do
          {:ok, validated} -> {:ok, validated}
          {:error, reason} -> {:error, {:validation_failed, reason}}
        end
      end
    end
    
    # Step 2: Determine impact scope
    step :analyze_impact do
      argument :change_event, from_result(:validate_change)
      
      run fn args ->
        impact = %{
          affected_files: determine_affected_files(args.change_event),
          requires_reindexing: requires_reindexing?(args.change_event),
          requires_analysis: requires_analysis?(args.change_event),
          dependency_updates: find_dependency_updates(args.change_event)
        }
        
        {:ok, impact}
      end
    end
    
    # Step 3: Trigger incremental updates
    step :trigger_updates do
      argument :repository_id, from_input()
      argument :change_event, from_result(:validate_change)
      argument :impact, from_result(:analyze_impact)
      
      run fn args ->
        updates = []
        
        # Trigger incremental indexing if needed
        if args.impact.requires_reindexing do
          indexing_payload = %{
            repository_id: args.repository_id,
            incremental: true,
            affected_files: args.impact.affected_files,
            change_id: args.change_event.change_id
          }
          
          EventBus.publish_incremental_indexing_request(indexing_payload)
          updates = [:indexing | updates]
        end
        
        # Trigger incremental analysis if needed
        if args.impact.requires_analysis do
          analysis_payload = %{
            repository_id: args.repository_id,
            incremental: true,
            affected_files: args.impact.affected_files,
            analysis_types: ["quality", "security"],
            change_id: args.change_event.change_id
          }
          
          EventBus.publish_incremental_analysis_request(analysis_payload)
          updates = [:analysis | updates]
        end
        
        # Update dependency graph if needed
        if not Enum.empty?(args.impact.dependency_updates) do
          dependency_payload = %{
            repository_id: args.repository_id,
            updates: args.impact.dependency_updates,
            change_id: args.change_event.change_id
          }
          
          EventBus.publish_dependency_graph_update(dependency_payload)
          updates = [:dependencies | updates]
        end
        
        {:ok, %{triggered_updates: updates}}
      end
    end
  end

  @doc """
  Performance monitoring and alerting reactor.
  
  Processes performance metrics in real-time and triggers alerts
  when thresholds are exceeded.
  """
  step :performance_monitor do
    argument :metrics_stream, :stream
    argument :alert_thresholds, :map
    
    # Step 1: Process metrics stream
    step :process_metrics do
      argument :metrics_stream, from_input()
      
      run fn args ->
        # Set up stream processing
        processed_metrics = args.metrics_stream
        |> Stream.map(&parse_performance_metric/1)
        |> Stream.filter(&valid_metric?/1)
        |> Stream.map(&enrich_metric/1)
        |> Enum.to_list()
        
        {:ok, %{processed_metrics: processed_metrics}}
      end
    end
    
    # Step 2: Check alert conditions
    step :check_alerts do
      argument :processed_metrics, from_result(:process_metrics, path: [:processed_metrics])
      argument :alert_thresholds, from_input()
      
      run fn args ->
        alerts = args.processed_metrics
        |> Enum.flat_map(fn metric ->
          check_metric_thresholds(metric, args.alert_thresholds)
        end)
        |> Enum.filter(& &1)
        
        {:ok, %{alerts: alerts}}
      end
    end
    
    # Step 3: Send alerts
    step :send_alerts do
      argument :alerts, from_result(:check_alerts, path: [:alerts])
      
      run fn args ->
        for alert <- args.alerts do
          alert_payload = %{
            alert_id: UUID.uuid4(),
            severity: alert.severity,
            source: alert.source,
            metric: alert.metric,
            current_value: alert.current_value,
            threshold: alert.threshold,
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
            description: alert.description
          }
          
          EventBus.publish_system_alert(alert_payload)
        end
        
        {:ok, %{alerts_sent: length(args.alerts)}}
      end
    end
  end

  # Helper functions

  defp collect_results(repository_id, remaining_types, results, timeout) do
    if MapSet.size(remaining_types) == 0 do
      {:ok, results}
    else
      receive do
        {:analysis_result, event} ->
          analysis_type = event.payload.analysis_type
          updated_results = Map.put(results, analysis_type, event.payload.results)
          updated_remaining = MapSet.delete(remaining_types, analysis_type)
          
          collect_results(repository_id, updated_remaining, updated_results, timeout)
      after
        timeout -> {:error, :analysis_timeout}
      end
    end
  end

  defp calculate_overall_score(analysis_results) do
    scores = analysis_results
    |> Enum.map(fn {_type, result} ->
      case result do
        %{code_quality: %{score: score}} -> score
        %{security_score: score} -> score
        _ -> 50  # Default neutral score
      end
    end)
    
    if Enum.empty?(scores) do
      0
    else
      Enum.sum(scores) / length(scores)
    end
  end

  defp validate_file_change(change_event) do
    required_fields = [:repository_id, :change_id, :change_type, :files, :timestamp]
    
    missing_fields = required_fields
    |> Enum.filter(fn field -> not Map.has_key?(change_event, field) end)
    
    if Enum.empty?(missing_fields) do
      {:ok, change_event}
    else
      {:error, {:missing_fields, missing_fields}}
    end
  end

  defp determine_affected_files(change_event) do
    # Extract file paths from the change event
    change_event.files
    |> Enum.map(& &1.path)
  end

  defp requires_reindexing?(change_event) do
    # Check if any changed files would affect the search index
    change_event.files
    |> Enum.any?(fn file ->
      file.change_type in ["created", "modified"] and
      file.language in ["elixir", "rust", "python", "typescript", "javascript"]
    end)
  end

  defp requires_analysis?(change_event) do
    # Check if changes warrant re-analysis
    change_event.files
    |> Enum.any?(fn file ->
      file.change_type in ["created", "modified"] and
      (file.lines_added > 10 or file.lines_removed > 10)
    end)
  end

  defp find_dependency_updates(change_event) do
    # Check for dependency file changes
    dependency_files = ["mix.exs", "Cargo.toml", "package.json", "requirements.txt", "Pipfile"]
    
    change_event.files
    |> Enum.filter(fn file ->
      Path.basename(file.path) in dependency_files and
      file.change_type in ["created", "modified"]
    end)
    |> Enum.map(fn file ->
      %{
        file: file.path,
        type: detect_dependency_type(file.path),
        change_type: file.change_type
      }
    end)
  end

  defp detect_dependency_type(file_path) do
    case Path.basename(file_path) do
      "mix.exs" -> :elixir
      "Cargo.toml" -> :rust
      "package.json" -> :javascript
      "requirements.txt" -> :python
      "Pipfile" -> :python
      _ -> :unknown
    end
  end

  defp parse_performance_metric(metric_data) do
    # Parse raw metric data into structured format
    %{
      source: metric_data.source,
      timestamp: DateTime.from_iso8601!(metric_data.timestamp),
      cpu_usage: metric_data.metrics.cpu.usage_percent,
      memory_usage: metric_data.metrics.memory.usage_percent,
      request_rate: metric_data.metrics.operations.requests_per_second,
      response_time: metric_data.metrics.operations.avg_response_time_ms,
      error_rate: metric_data.metrics.operations.error_rate
    }
  end

  defp valid_metric?(metric) do
    # Validate metric data quality
    not is_nil(metric.source) and
    not is_nil(metric.timestamp) and
    is_number(metric.cpu_usage) and
    metric.cpu_usage >= 0 and metric.cpu_usage <= 100
  end

  defp enrich_metric(metric) do
    # Add computed fields and context
    Map.merge(metric, %{
      health_score: calculate_health_score(metric),
      severity: determine_severity(metric),
      trends: calculate_trends(metric)
    })
  end

  defp calculate_health_score(metric) do
    # Simple health score calculation
    cpu_score = max(0, 100 - metric.cpu_usage)
    memory_score = max(0, 100 - metric.memory_usage)
    error_score = max(0, 100 - metric.error_rate)
    
    (cpu_score + memory_score + error_score) / 3
  end

  defp determine_severity(metric) do
    cond do
      metric.cpu_usage > 90 or metric.memory_usage > 90 or metric.error_rate > 10 ->
        :critical
      metric.cpu_usage > 80 or metric.memory_usage > 80 or metric.error_rate > 5 ->
        :high
      metric.cpu_usage > 70 or metric.memory_usage > 70 or metric.error_rate > 1 ->
        :medium
      true ->
        :low
    end
  end

  defp calculate_trends(_metric) do
    # Placeholder for trend calculation
    # In a real implementation, this would compare against historical data
    %{
      cpu_trend: :stable,
      memory_trend: :stable,
      error_trend: :stable
    }
  end

  defp check_metric_thresholds(metric, thresholds) do
    alerts = []
    
    # Check CPU threshold
    if metric.cpu_usage > thresholds[:cpu_usage] do
      alerts = [create_alert(metric, :cpu_usage, metric.cpu_usage, thresholds[:cpu_usage]) | alerts]
    end
    
    # Check memory threshold
    if metric.memory_usage > thresholds[:memory_usage] do
      alerts = [create_alert(metric, :memory_usage, metric.memory_usage, thresholds[:memory_usage]) | alerts]
    end
    
    # Check error rate threshold
    if metric.error_rate > thresholds[:error_rate] do
      alerts = [create_alert(metric, :error_rate, metric.error_rate, thresholds[:error_rate]) | alerts]
    end
    
    alerts
  end

  defp create_alert(metric, metric_type, current_value, threshold) do
    %{
      severity: metric.severity,
      source: metric.source,
      metric: metric_type,
      current_value: current_value,
      threshold: threshold,
      description: "#{metric_type} (#{current_value}) exceeded threshold (#{threshold}) for #{metric.source}"
    }
  end
end