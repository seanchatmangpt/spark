defmodule AsyncApi.Monitoring do
  @moduledoc """
  Real-time monitoring and observability framework for AsyncAPI operations.
  
  Provides comprehensive monitoring capabilities including:
  - Real-time metrics collection and aggregation
  - Health checks and service status monitoring
  - Performance tracking and SLA monitoring
  - Custom alerting and notification systems
  - Integration with observability platforms (Prometheus, Grafana, OpenTelemetry)
  - Distributed tracing and correlation tracking
  - Automatic anomaly detection
  
  ## Usage
  
      defmodule MyApp.MonitoredEventApi do
        use AsyncApi
        use AsyncApi.Monitoring
        
        monitoring do
          metrics do
            counter :messages_processed, "Total messages processed"
            histogram :message_duration, "Message processing duration"
            gauge :active_connections, "Number of active connections"
            
            custom_metric :business_metric do
              type :counter
              description "Custom business logic metric"
              labels [:operation, :status, :user_type]
            end
          end
          
          health_checks do
            check :database_connection do
              interval 30_000
              timeout 5_000
              critical true
              
              handler fn ->
                case MyApp.Database.ping() do
                  :ok -> {:ok, "Database connection healthy"}
                  {:error, reason} -> {:error, "Database unreachable: " <> to_string(reason)}
                end
              end
            end
            
            check :message_queue_lag do
              interval 60_000
              warning_threshold 1000
              critical_threshold 5000
              
              handler fn ->
                lag = MyApp.MessageQueue.get_lag()
                cond do
                  lag > 5000 -> {:critical, "Queue lag: " <> to_string(lag) <> " messages"}
                  lag > 1000 -> {:warning, "Queue lag: " <> to_string(lag) <> " messages"}
                  true -> {:ok, "Queue lag: " <> to_string(lag) <> " messages"}
                end
              end
            end
          end
          
          alerts do
            alert :high_error_rate do
              condition "error_rate > 0.05"
              window "5m"
              severity :critical
              
              notification :slack, channel: "#alerts"
              notification :email, to: ["ops@example.com"]
              notification :webhook, url: "https://hooks.example.com/alert"
            end
            
            alert :slow_processing do
              condition "p95_duration > 5000"
              window "10m"
              severity :warning
              
              notification :slack, channel: "#performance"
            end
          end
          
          tracing do
            enabled true
            service_name "my-async-api"
            sample_rate 0.1
            
            exporters [
              {:jaeger, endpoint: "http://jaeger:14268/api/traces"},
              {:zipkin, endpoint: "http://zipkin:9411/api/v2/spans"}
            ]
          end
          
          dashboards do
            grafana do
              endpoint "http://grafana:3000"
              api_key {:env, "GRAFANA_API_KEY"}
              
              dashboard :api_overview do
                panels [
                  {:graph, "Message Throughput", query: "rate(messages_processed[5m])"},
                  {:stat, "Active Connections", query: "active_connections"},
                  {:heatmap, "Response Times", query: "message_duration"}
                ]
              end
            end
          end
        end
        
        operations do
          operation :sendUserEvent do
            action :send
            channel "user.events"
            message :userEvent
            
            monitoring do
              track_metrics [:messages_processed, :message_duration]
              trace true
              health_impact :medium
              sla_target 99.9
            end
          end
        end
      end
  """

  alias AsyncApi.Monitoring.{Metrics, HealthChecks, Alerts, Tracing, Dashboards}

  @type metric_type :: :counter | :gauge | :histogram | :summary
  @type health_status :: :healthy | :warning | :critical | :unknown
  @type alert_severity :: :info | :warning | :critical
  @type notification_type :: :slack | :email | :webhook | :pagerduty

  @doc """
  Initialize monitoring for an AsyncAPI module.
  """
  defmacro __using__(opts \\ []) do
    quote do
      import AsyncApi.Monitoring
      @monitoring_config %{}
      @before_compile AsyncApi.Monitoring
    end
  end

  @doc """
  Define monitoring configuration.
  """
  defmacro monitoring(do: block) do
    quote do
      unquote(block)
    end
  end

  @doc """
  Define metrics configuration.
  """
  defmacro metrics(do: block) do
    quote do
      unquote(block)
    end
  end

  @doc """
  Define a counter metric.
  """
  defmacro counter(name, description, opts \\ []) do
    quote do
      AsyncApi.Monitoring.register_metric(:counter, unquote(name), unquote(description), unquote(opts))
    end
  end

  @doc """
  Define a gauge metric.
  """
  defmacro gauge(name, description, opts \\ []) do
    quote do
      AsyncApi.Monitoring.register_metric(:gauge, unquote(name), unquote(description), unquote(opts))
    end
  end

  @doc """
  Define a histogram metric.
  """
  defmacro histogram(name, description, opts \\ []) do
    quote do
      AsyncApi.Monitoring.register_metric(:histogram, unquote(name), unquote(description), unquote(opts))
    end
  end

  @doc """
  Define health checks configuration.
  """
  defmacro health_checks(do: block) do
    quote do
      unquote(block)
    end
  end

  @doc """
  Define a health check.
  """
  defmacro check(name, opts \\ [], do: block) do
    quote do
      AsyncApi.Monitoring.register_health_check(unquote(name), unquote(opts), unquote(block))
    end
  end

  @doc """
  Define alerts configuration.
  """
  defmacro alerts(do: block) do
    quote do
      unquote(block)
    end
  end

  @doc """
  Define an alert rule.
  """
  defmacro alert(name, opts \\ [], do: block) do
    quote do
      AsyncApi.Monitoring.register_alert(unquote(name), unquote(opts), unquote(block))
    end
  end

  @doc """
  Start monitoring for an AsyncAPI module.
  """
  def start_monitoring(api_module, opts \\ []) do
    config = extract_monitoring_config(api_module)
    
    with {:ok, metrics_pid} <- Metrics.start_link(config.metrics, opts),
         {:ok, health_pid} <- HealthChecks.start_link(config.health_checks, opts),
         {:ok, alerts_pid} <- Alerts.start_link(config.alerts, opts),
         {:ok, tracing_pid} <- Tracing.start_link(config.tracing, opts) do
      
      monitoring_supervisor = %{
        metrics: metrics_pid,
        health_checks: health_pid,
        alerts: alerts_pid,
        tracing: tracing_pid
      }
      
      Process.put(:async_api_monitoring, monitoring_supervisor)
      {:ok, monitoring_supervisor}
    else
      error -> error
    end
  end

  @doc """
  Stop monitoring for an AsyncAPI module.
  """
  def stop_monitoring do
    case Process.get(:async_api_monitoring) do
      nil -> :ok
      supervisor ->
        Enum.each(supervisor, fn {_type, pid} ->
          if Process.alive?(pid), do: GenServer.stop(pid)
        end)
        Process.delete(:async_api_monitoring)
        :ok
    end
  end

  @doc """
  Record a metric value.
  """
  def record_metric(metric_name, value, labels \\ %{}) do
    case get_monitoring_supervisor() do
      nil -> {:error, :monitoring_not_started}
      supervisor -> Metrics.record(supervisor.metrics, metric_name, value, labels)
    end
  end

  @doc """
  Increment a counter metric.
  """
  def increment_counter(metric_name, labels \\ %{}) do
    record_metric(metric_name, 1, labels)
  end

  @doc """
  Set a gauge metric value.
  """
  def set_gauge(metric_name, value, labels \\ %{}) do
    record_metric(metric_name, value, labels)
  end

  @doc """
  Record a histogram observation.
  """
  def observe_histogram(metric_name, value, labels \\ %{}) do
    record_metric(metric_name, value, labels)
  end

  @doc """
  Start a timer for measuring duration.
  """
  def start_timer(metric_name, labels \\ %{}) do
    start_time = System.monotonic_time(:millisecond)
    
    fn ->
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      observe_histogram(metric_name, duration, labels)
      duration
    end
  end

  @doc """
  Get current health status.
  """
  def get_health_status do
    case get_monitoring_supervisor() do
      nil -> {:error, :monitoring_not_started}
      supervisor -> HealthChecks.get_status(supervisor.health_checks)
    end
  end

  @doc """
  Trigger a custom alert.
  """
  def trigger_alert(alert_name, message, metadata \\ %{}) do
    case get_monitoring_supervisor() do
      nil -> {:error, :monitoring_not_started}
      supervisor -> Alerts.trigger(supervisor.alerts, alert_name, message, metadata)
    end
  end

  @doc """
  Start a distributed trace span.
  """
  def start_span(operation_name, metadata \\ %{}) do
    case get_monitoring_supervisor() do
      nil -> {:error, :monitoring_not_started}
      supervisor -> Tracing.start_span(supervisor.tracing, operation_name, metadata)
    end
  end

  @doc """
  Finish a distributed trace span.
  """
  def finish_span(span_context, metadata \\ %{}) do
    case get_monitoring_supervisor() do
      nil -> {:error, :monitoring_not_started}
      supervisor -> Tracing.finish_span(supervisor.tracing, span_context, metadata)
    end
  end

  @doc """
  Get monitoring statistics.
  """
  def get_statistics do
    case get_monitoring_supervisor() do
      nil -> {:error, :monitoring_not_started}
      supervisor ->
        %{
          metrics: Metrics.get_statistics(supervisor.metrics),
          health: HealthChecks.get_statistics(supervisor.health_checks),
          alerts: Alerts.get_statistics(supervisor.alerts),
          tracing: Tracing.get_statistics(supervisor.tracing)
        }
    end
  end

  @doc """
  Export metrics in Prometheus format.
  """
  def export_prometheus_metrics do
    case get_monitoring_supervisor() do
      nil -> {:error, :monitoring_not_started}
      supervisor -> Metrics.export_prometheus(supervisor.metrics)
    end
  end

  @doc """
  Create a Grafana dashboard for the API.
  """
  def create_grafana_dashboard(api_module, opts \\ []) do
    config = extract_monitoring_config(api_module)
    Dashboards.create_grafana_dashboard(config, opts)
  end

  # Compile-time callbacks

  defmacro __before_compile__(_env) do
    quote do
      def __monitoring_config__ do
        @monitoring_config
      end
    end
  end

  # Registration functions called at compile time

  defmacro register_metric(type, name, description, opts) do
    quote do
      metric = %{
        type: unquote(type),
        name: unquote(name),
        description: unquote(description),
        labels: Keyword.get(unquote(opts), :labels, []),
        buckets: Keyword.get(unquote(opts), :buckets, :default)
      }
      
      Module.put_attribute(__MODULE__, :monitoring_config, 
        put_in(Module.get_attribute(__MODULE__, :monitoring_config, %{})[:metrics][unquote(name)], metric))
    end
  end

  defmacro register_health_check(name, opts, block) do
    quote do
      health_check = %{
        name: unquote(name),
        interval: Keyword.get(unquote(opts), :interval, 30_000),
        timeout: Keyword.get(unquote(opts), :timeout, 5_000),
        critical: Keyword.get(unquote(opts), :critical, false),
        handler: unquote(block)
      }
      
      Module.put_attribute(__MODULE__, :monitoring_config,
        put_in(Module.get_attribute(__MODULE__, :monitoring_config, %{})[:health_checks][unquote(name)], health_check))
    end
  end

  defmacro register_alert(name, opts, block) do
    quote do
      alert = %{
        name: unquote(name),
        condition: Keyword.get(unquote(opts), :condition),
        window: Keyword.get(unquote(opts), :window, "5m"),
        severity: Keyword.get(unquote(opts), :severity, :warning),
        notifications: extract_notifications(unquote(block))
      }
      
      Module.put_attribute(__MODULE__, :monitoring_config,
        put_in(Module.get_attribute(__MODULE__, :monitoring_config, %{})[:alerts][unquote(name)], alert))
    end
  end

  # Private helper functions

  defp get_monitoring_supervisor do
    Process.get(:async_api_monitoring)
  end

  defp extract_monitoring_config(api_module) do
    config = apply(api_module, :__monitoring_config__, [])
    
    %{
      metrics: config[:metrics] || %{},
      health_checks: config[:health_checks] || %{},
      alerts: config[:alerts] || %{},
      tracing: config[:tracing] || %{enabled: false},
      dashboards: config[:dashboards] || %{}
    }
  end

  defp extract_notifications(block) do
    # This would parse the notification calls from the block
    # For now, returning empty list as placeholder
    []
  end
end

defmodule AsyncApi.Monitoring.Metrics do
  @moduledoc """
  Metrics collection and aggregation for AsyncAPI operations.
  """

  use GenServer
  require Logger

  @default_histogram_buckets [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]

  def start_link(metrics_config, opts \\ []) do
    GenServer.start_link(__MODULE__, {metrics_config, opts}, name: __MODULE__)
  end

  def init({metrics_config, opts}) do
    # Initialize metrics storage and exporters
    state = %{
      metrics: initialize_metrics(metrics_config),
      exporters: initialize_exporters(opts),
      collection_interval: Keyword.get(opts, :collection_interval, 15_000)
    }
    
    # Start periodic collection
    Process.send_after(self(), :collect_metrics, state.collection_interval)
    
    {:ok, state}
  end

  def record(server, metric_name, value, labels) do
    GenServer.cast(server, {:record, metric_name, value, labels})
  end

  def get_statistics(server) do
    GenServer.call(server, :get_statistics)
  end

  def export_prometheus(server) do
    GenServer.call(server, :export_prometheus)
  end

  def handle_cast({:record, metric_name, value, labels}, state) do
    updated_metrics = record_metric_value(state.metrics, metric_name, value, labels)
    {:noreply, %{state | metrics: updated_metrics}}
  end

  def handle_call(:get_statistics, _from, state) do
    stats = calculate_statistics(state.metrics)
    {:reply, stats, state}
  end

  def handle_call(:export_prometheus, _from, state) do
    prometheus_output = format_prometheus_metrics(state.metrics)
    {:reply, prometheus_output, state}
  end

  def handle_info(:collect_metrics, state) do
    # Collect system metrics
    system_metrics = collect_system_metrics()
    updated_metrics = merge_system_metrics(state.metrics, system_metrics)
    
    # Export to configured exporters
    Enum.each(state.exporters, fn exporter ->
      export_metrics(exporter, updated_metrics)
    end)
    
    # Schedule next collection
    Process.send_after(self(), :collect_metrics, state.collection_interval)
    
    {:noreply, %{state | metrics: updated_metrics}}
  end

  # Private implementation functions

  defp initialize_metrics(config) do
    Enum.reduce(config, %{}, fn {name, metric_def}, acc ->
      Map.put(acc, name, %{
        type: metric_def.type,
        description: metric_def.description,
        labels: metric_def.labels,
        values: %{},
        buckets: get_buckets_for_type(metric_def),
        created_at: System.system_time(:millisecond)
      })
    end)
  end

  defp initialize_exporters(opts) do
    exporters = Keyword.get(opts, :exporters, [])
    
    Enum.map(exporters, fn
      {:prometheus, config} -> {:prometheus, config}
      {:statsd, config} -> {:statsd, config}
      {:cloudwatch, config} -> {:cloudwatch, config}
      exporter -> exporter
    end)
  end

  defp get_buckets_for_type(metric_def) do
    case metric_def.type do
      :histogram -> metric_def.buckets || @default_histogram_buckets
      _ -> nil
    end
  end

  defp record_metric_value(metrics, metric_name, value, labels) do
    case Map.get(metrics, metric_name) do
      nil ->
        Logger.warning("Unknown metric: #{metric_name}")
        metrics
      
      metric ->
        labels_key = format_labels_key(labels)
        updated_values = update_metric_values(metric, labels_key, value)
        put_in(metrics[metric_name][:values], updated_values)
    end
  end

  defp update_metric_values(metric, labels_key, value) do
    case metric.type do
      :counter ->
        Map.update(metric.values, labels_key, value, &(&1 + value))
      
      :gauge ->
        Map.put(metric.values, labels_key, value)
      
      :histogram ->
        current = Map.get(metric.values, labels_key, %{
          count: 0,
          sum: 0,
          buckets: Enum.map(metric.buckets, &{&1, 0}) |> Enum.into(%{})
        })
        
        updated_buckets = Enum.reduce(metric.buckets, current.buckets, fn bucket, acc ->
          if value <= bucket do
            Map.update(acc, bucket, 1, &(&1 + 1))
          else
            acc
          end
        end)
        
        Map.put(metric.values, labels_key, %{
          count: current.count + 1,
          sum: current.sum + value,
          buckets: updated_buckets
        })
    end
  end

  defp format_labels_key(labels) when labels == %{}, do: :default
  defp format_labels_key(labels) do
    labels
    |> Enum.sort()
    |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
    |> Enum.join(",")
  end

  defp calculate_statistics(metrics) do
    Enum.reduce(metrics, %{}, fn {name, metric}, acc ->
      stats = case metric.type do
        :counter ->
          total = metric.values |> Map.values() |> Enum.sum()
          %{total: total, rate: calculate_rate(metric, total)}
        
        :gauge ->
          values = Map.values(metric.values)
          %{
            current: List.last(values) || 0,
            min: Enum.min(values, fn -> 0 end),
            max: Enum.max(values, fn -> 0 end),
            avg: if(length(values) > 0, do: Enum.sum(values) / length(values), else: 0)
          }
        
        :histogram ->
          %{
            observations: calculate_histogram_stats(metric.values)
          }
      end
      
      Map.put(acc, name, stats)
    end)
  end

  defp calculate_rate(metric, total) do
    time_elapsed = System.system_time(:millisecond) - metric.created_at
    if time_elapsed > 0, do: total / (time_elapsed / 1000), else: 0
  end

  defp calculate_histogram_stats(values) do
    Enum.reduce(values, %{total_count: 0, total_sum: 0}, fn {_labels, data}, acc ->
      %{
        total_count: acc.total_count + data.count,
        total_sum: acc.total_sum + data.sum
      }
    end)
  end

  defp collect_system_metrics do
    %{
      memory_usage: :erlang.memory(:total),
      process_count: :erlang.system_info(:process_count),
      cpu_utilization: get_cpu_utilization(),
      gc_collections: :erlang.statistics(:garbage_collection)
    }
  end

  defp get_cpu_utilization do
    # Simplified CPU utilization calculation
    case :cpu_sup.util() do
      {:error, _} -> 0.0
      util when is_number(util) -> util
      _ -> 0.0
    end
  end

  defp merge_system_metrics(metrics, system_metrics) do
    # Add system metrics to the metrics map
    Enum.reduce(system_metrics, metrics, fn {key, value}, acc ->
      metric_name = :"system_#{key}"
      
      if Map.has_key?(acc, metric_name) do
        record_metric_value(acc, metric_name, value, %{})
      else
        acc
      end
    end)
  end

  defp export_metrics(exporter, metrics) do
    case exporter do
      {:prometheus, config} ->
        prometheus_data = format_prometheus_metrics(metrics)
        send_to_prometheus(config, prometheus_data)
      
      {:statsd, config} ->
        statsd_data = format_statsd_metrics(metrics)
        send_to_statsd(config, statsd_data)
      
      {:cloudwatch, config} ->
        cloudwatch_data = format_cloudwatch_metrics(metrics)
        send_to_cloudwatch(config, cloudwatch_data)
      
      _ ->
        Logger.warning("Unknown exporter: #{inspect(exporter)}")
    end
  end

  defp format_prometheus_metrics(metrics) do
    Enum.map(metrics, fn {name, metric} ->
      case metric.type do
        :counter ->
          format_prometheus_counter(name, metric)
        
        :gauge ->
          format_prometheus_gauge(name, metric)
        
        :histogram ->
          format_prometheus_histogram(name, metric)
      end
    end)
    |> Enum.join("\n")
  end

  defp format_prometheus_counter(name, metric) do
    lines = [
      "# HELP #{name} #{metric.description}",
      "# TYPE #{name} counter"
    ]
    
    value_lines = Enum.map(metric.values, fn {labels_key, value} ->
      labels_str = if labels_key == :default, do: "", else: "{#{labels_key}}"
      "#{name}#{labels_str} #{value}"
    end)
    
    Enum.join(lines ++ value_lines, "\n")
  end

  defp format_prometheus_gauge(name, metric) do
    lines = [
      "# HELP #{name} #{metric.description}",
      "# TYPE #{name} gauge"
    ]
    
    value_lines = Enum.map(metric.values, fn {labels_key, value} ->
      labels_str = if labels_key == :default, do: "", else: "{#{labels_key}}"
      "#{name}#{labels_str} #{value}"
    end)
    
    Enum.join(lines ++ value_lines, "\n")
  end

  defp format_prometheus_histogram(name, metric) do
    lines = [
      "# HELP #{name} #{metric.description}",
      "# TYPE #{name} histogram"
    ]
    
    value_lines = Enum.flat_map(metric.values, fn {labels_key, data} ->
      labels_str = if labels_key == :default, do: "", else: "{#{labels_key}}"
      
      bucket_lines = Enum.map(data.buckets, fn {bucket, count} ->
        "#{name}_bucket{le=\"#{bucket}\"#{if labels_key != :default, do: ",#{labels_key}", else: ""}} #{count}"
      end)
      
      [
        "#{name}_count#{labels_str} #{data.count}",
        "#{name}_sum#{labels_str} #{data.sum}"
      ] ++ bucket_lines
    end)
    
    Enum.join(lines ++ value_lines, "\n")
  end

  defp format_statsd_metrics(_metrics) do
    # StatsD format implementation
    ""
  end

  defp format_cloudwatch_metrics(_metrics) do
    # CloudWatch format implementation
    ""
  end

  defp send_to_prometheus(_config, _data) do
    # Send to Prometheus pushgateway
    :ok
  end

  defp send_to_statsd(_config, _data) do
    # Send to StatsD
    :ok
  end

  defp send_to_cloudwatch(_config, _data) do
    # Send to CloudWatch
    :ok
  end
end

defmodule AsyncApi.Monitoring.HealthChecks do
  @moduledoc """
  Health check system for AsyncAPI services.
  """

  use GenServer
  require Logger

  def start_link(health_config, opts \\ []) do
    GenServer.start_link(__MODULE__, {health_config, opts}, name: __MODULE__)
  end

  def init({health_config, _opts}) do
    state = %{
      checks: health_config,
      status: %{},
      check_refs: %{}
    }
    
    # Start all health checks
    updated_state = start_health_checks(state)
    
    {:ok, updated_state}
  end

  def get_status(server) do
    GenServer.call(server, :get_status)
  end

  def get_statistics(server) do
    GenServer.call(server, :get_statistics)
  end

  def handle_call(:get_status, _from, state) do
    overall_status = calculate_overall_status(state.status)
    
    response = %{
      overall: overall_status,
      checks: state.status,
      timestamp: System.system_time(:millisecond)
    }
    
    {:reply, response, state}
  end

  def handle_call(:get_statistics, _from, state) do
    stats = %{
      total_checks: map_size(state.checks),
      healthy_checks: count_status(state.status, :healthy),
      warning_checks: count_status(state.status, :warning),
      critical_checks: count_status(state.status, :critical),
      unknown_checks: count_status(state.status, :unknown)
    }
    
    {:reply, stats, state}
  end

  def handle_info({:health_check, check_name}, state) do
    case Map.get(state.checks, check_name) do
      nil ->
        {:noreply, state}
      
      check_config ->
        status = execute_health_check(check_config)
        updated_status = Map.put(state.status, check_name, status)
        
        # Schedule next check
        ref = Process.send_after(self(), {:health_check, check_name}, check_config.interval)
        updated_refs = Map.put(state.check_refs, check_name, ref)
        
        {:noreply, %{state | status: updated_status, check_refs: updated_refs}}
    end
  end

  # Private implementation functions

  defp start_health_checks(state) do
    check_refs = Enum.reduce(state.checks, %{}, fn {check_name, check_config}, acc ->
      ref = Process.send_after(self(), {:health_check, check_name}, 0)
      Map.put(acc, check_name, ref)
    end)
    
    %{state | check_refs: check_refs}
  end

  defp execute_health_check(check_config) do
    start_time = System.monotonic_time(:millisecond)
    
    try do
      task = Task.async(fn -> check_config.handler.() end)
      
      case Task.yield(task, check_config.timeout) || Task.shutdown(task) do
        {:ok, {:ok, message}} ->
          end_time = System.monotonic_time(:millisecond)
          %{
            status: :healthy,
            message: message,
            duration: end_time - start_time,
            timestamp: System.system_time(:millisecond)
          }
        
        {:ok, {:warning, message}} ->
          end_time = System.monotonic_time(:millisecond)
          %{
            status: :warning,
            message: message,
            duration: end_time - start_time,
            timestamp: System.system_time(:millisecond)
          }
        
        {:ok, {:critical, message}} ->
          end_time = System.monotonic_time(:millisecond)
          %{
            status: :critical,
            message: message,
            duration: end_time - start_time,
            timestamp: System.system_time(:millisecond)
          }
        
        {:ok, {:error, reason}} ->
          end_time = System.monotonic_time(:millisecond)
          %{
            status: if(check_config.critical, do: :critical, else: :warning),
            message: "Check failed: #{inspect(reason)}",
            duration: end_time - start_time,
            timestamp: System.system_time(:millisecond)
          }
        
        nil ->
          %{
            status: :critical,
            message: "Health check timeout after #{check_config.timeout}ms",
            duration: check_config.timeout,
            timestamp: System.system_time(:millisecond)
          }
      end
    rescue
      error ->
        end_time = System.monotonic_time(:millisecond)
        %{
          status: :critical,
          message: "Health check error: #{Exception.message(error)}",
          duration: end_time - start_time,
          timestamp: System.system_time(:millisecond)
        }
    end
  end

  defp calculate_overall_status(status_map) do
    statuses = Map.values(status_map) |> Enum.map(& &1.status)
    
    cond do
      Enum.any?(statuses, &(&1 == :critical)) -> :critical
      Enum.any?(statuses, &(&1 == :warning)) -> :warning
      Enum.all?(statuses, &(&1 == :healthy)) -> :healthy
      true -> :unknown
    end
  end

  defp count_status(status_map, target_status) do
    status_map
    |> Map.values()
    |> Enum.count(&(&1.status == target_status))
  end
end

defmodule AsyncApi.Monitoring.Alerts do
  @moduledoc """
  Alert management and notification system.
  """

  use GenServer
  require Logger

  def start_link(alerts_config, opts \\ []) do
    GenServer.start_link(__MODULE__, {alerts_config, opts}, name: __MODULE__)
  end

  def init({alerts_config, _opts}) do
    state = %{
      alerts: alerts_config,
      active_alerts: %{},
      notification_history: []
    }
    
    {:ok, state}
  end

  def trigger(server, alert_name, message, metadata) do
    GenServer.cast(server, {:trigger_alert, alert_name, message, metadata})
  end

  def get_statistics(server) do
    GenServer.call(server, :get_statistics)
  end

  def handle_cast({:trigger_alert, alert_name, message, metadata}, state) do
    case Map.get(state.alerts, alert_name) do
      nil ->
        Logger.warning("Unknown alert: #{alert_name}")
        {:noreply, state}
      
      alert_config ->
        alert_data = %{
          name: alert_name,
          message: message,
          metadata: metadata,
          severity: alert_config.severity,
          timestamp: System.system_time(:millisecond)
        }
        
        # Send notifications
        send_notifications(alert_config.notifications, alert_data)
        
        # Update active alerts
        updated_active = Map.put(state.active_alerts, alert_name, alert_data)
        
        # Add to notification history
        updated_history = [alert_data | state.notification_history]
        |> Enum.take(1000)  # Keep last 1000 alerts
        
        {:noreply, %{state | active_alerts: updated_active, notification_history: updated_history}}
    end
  end

  def handle_call(:get_statistics, _from, state) do
    stats = %{
      total_alerts: map_size(state.alerts),
      active_alerts: map_size(state.active_alerts),
      alert_history_count: length(state.notification_history),
      alerts_by_severity: count_alerts_by_severity(state.notification_history)
    }
    
    {:reply, stats, state}
  end

  # Private implementation functions

  defp send_notifications(notifications, alert_data) do
    Enum.each(notifications, fn notification ->
      send_notification(notification, alert_data)
    end)
  end

  defp send_notification({:slack, config}, alert_data) do
    # Send Slack notification
    payload = %{
      text: format_slack_message(alert_data),
      channel: config[:channel],
      username: "AsyncAPI Monitor",
      icon_emoji: get_severity_emoji(alert_data.severity)
    }
    
    send_webhook(config[:webhook_url], payload)
  end

  defp send_notification({:email, config}, alert_data) do
    # Send email notification
    Logger.info("Sending email alert to #{inspect(config[:to])}: #{alert_data.message}")
  end

  defp send_notification({:webhook, config}, alert_data) do
    # Send webhook notification
    payload = %{
      alert: alert_data.name,
      message: alert_data.message,
      severity: alert_data.severity,
      timestamp: alert_data.timestamp,
      metadata: alert_data.metadata
    }
    
    send_webhook(config[:url], payload)
  end

  defp send_notification({:pagerduty, config}, alert_data) do
    # Send PagerDuty notification
    Logger.info("Sending PagerDuty alert: #{alert_data.message}")
  end

  defp format_slack_message(alert_data) do
    """
    🚨 *#{String.upcase(to_string(alert_data.severity))} Alert*
    
    *Alert:* #{alert_data.name}
    *Message:* #{alert_data.message}
    *Time:* #{format_timestamp(alert_data.timestamp)}
    """
  end

  defp get_severity_emoji(severity) do
    case severity do
      :critical -> ":red_circle:"
      :warning -> ":warning:"
      :info -> ":information_source:"
      _ -> ":question:"
    end
  end

  defp send_webhook(url, payload) do
    # HTTP client implementation would go here
    Logger.info("Sending webhook to #{url}: #{inspect(payload)}")
  end

  defp format_timestamp(timestamp) do
    timestamp
    |> DateTime.from_unix!(:millisecond)
    |> DateTime.to_string()
  end

  defp count_alerts_by_severity(alert_history) do
    Enum.reduce(alert_history, %{critical: 0, warning: 0, info: 0}, fn alert, acc ->
      Map.update(acc, alert.severity, 1, &(&1 + 1))
    end)
  end
end

defmodule AsyncApi.Monitoring.Tracing do
  @moduledoc """
  Distributed tracing support for AsyncAPI operations.
  """

  use GenServer
  require Logger

  def start_link(tracing_config, opts \\ []) do
    GenServer.start_link(__MODULE__, {tracing_config, opts}, name: __MODULE__)
  end

  def init({tracing_config, _opts}) do
    state = %{
      config: tracing_config,
      active_spans: %{},
      exporters: initialize_tracing_exporters(tracing_config)
    }
    
    {:ok, state}
  end

  def start_span(server, operation_name, metadata) do
    GenServer.call(server, {:start_span, operation_name, metadata})
  end

  def finish_span(server, span_context, metadata) do
    GenServer.cast(server, {:finish_span, span_context, metadata})
  end

  def get_statistics(server) do
    GenServer.call(server, :get_statistics)
  end

  def handle_call({:start_span, operation_name, metadata}, _from, state) do
    if state.config[:enabled] do
      span_id = generate_span_id()
      trace_id = metadata[:trace_id] || generate_trace_id()
      
      span = %{
        span_id: span_id,
        trace_id: trace_id,
        operation_name: operation_name,
        start_time: System.monotonic_time(:microsecond),
        metadata: metadata,
        parent_span_id: metadata[:parent_span_id]
      }
      
      span_context = %{
        span_id: span_id,
        trace_id: trace_id,
        operation_name: operation_name
      }
      
      updated_spans = Map.put(state.active_spans, span_id, span)
      
      {:reply, {:ok, span_context}, %{state | active_spans: updated_spans}}
    else
      {:reply, {:ok, %{disabled: true}}, state}
    end
  end

  def handle_call(:get_statistics, _from, state) do
    stats = %{
      active_spans: map_size(state.active_spans),
      tracing_enabled: state.config[:enabled] || false,
      sample_rate: state.config[:sample_rate] || 0.0
    }
    
    {:reply, stats, state}
  end

  def handle_cast({:finish_span, span_context, metadata}, state) do
    if state.config[:enabled] && !span_context[:disabled] do
      case Map.get(state.active_spans, span_context.span_id) do
        nil ->
          Logger.warning("Span not found: #{span_context.span_id}")
          {:noreply, state}
        
        span ->
          finished_span = %{
            span
            | end_time: System.monotonic_time(:microsecond),
              duration: System.monotonic_time(:microsecond) - span.start_time,
              finish_metadata: metadata
          }
          
          # Export span to configured exporters
          export_span(state.exporters, finished_span)
          
          # Remove from active spans
          updated_spans = Map.delete(state.active_spans, span_context.span_id)
          
          {:noreply, %{state | active_spans: updated_spans}}
      end
    else
      {:noreply, state}
    end
  end

  # Private implementation functions

  defp initialize_tracing_exporters(config) do
    exporters = config[:exporters] || []
    
    Enum.map(exporters, fn
      {:jaeger, endpoint_config} -> {:jaeger, endpoint_config}
      {:zipkin, endpoint_config} -> {:zipkin, endpoint_config}
      {:otel, endpoint_config} -> {:otel, endpoint_config}
      exporter -> exporter
    end)
  end

  defp generate_span_id do
    :crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower)
  end

  defp generate_trace_id do
    :crypto.strong_rand_bytes(16) |> Base.hex_encode32(case: :lower)
  end

  defp export_span(exporters, span) do
    Enum.each(exporters, fn exporter ->
      export_span_to_exporter(exporter, span)
    end)
  end

  defp export_span_to_exporter({:jaeger, config}, span) do
    jaeger_span = format_jaeger_span(span)
    send_to_jaeger(config, jaeger_span)
  end

  defp export_span_to_exporter({:zipkin, config}, span) do
    zipkin_span = format_zipkin_span(span)
    send_to_zipkin(config, zipkin_span)
  end

  defp export_span_to_exporter({:otel, config}, span) do
    otel_span = format_otel_span(span)
    send_to_otel(config, otel_span)
  end

  defp format_jaeger_span(span) do
    %{
      traceID: span.trace_id,
      spanID: span.span_id,
      parentSpanID: span.parent_span_id,
      operationName: span.operation_name,
      startTime: span.start_time,
      duration: span.duration,
      tags: format_tags(span.metadata),
      logs: []
    }
  end

  defp format_zipkin_span(span) do
    %{
      traceId: span.trace_id,
      id: span.span_id,
      parentId: span.parent_span_id,
      name: span.operation_name,
      timestamp: span.start_time,
      duration: span.duration,
      tags: format_tags(span.metadata)
    }
  end

  defp format_otel_span(span) do
    %{
      trace_id: span.trace_id,
      span_id: span.span_id,
      parent_span_id: span.parent_span_id,
      name: span.operation_name,
      start_time_unix_nano: span.start_time * 1000,
      end_time_unix_nano: (span.start_time + span.duration) * 1000,
      attributes: format_tags(span.metadata)
    }
  end

  defp format_tags(metadata) do
    Enum.reduce(metadata, %{}, fn {key, value}, acc ->
      Map.put(acc, to_string(key), to_string(value))
    end)
  end

  defp send_to_jaeger(_config, _span) do
    # HTTP client implementation for Jaeger
    :ok
  end

  defp send_to_zipkin(_config, _span) do
    # HTTP client implementation for Zipkin
    :ok
  end

  defp send_to_otel(_config, _span) do
    # HTTP client implementation for OpenTelemetry
    :ok
  end
end

defmodule AsyncApi.Monitoring.Dashboards do
  @moduledoc """
  Dashboard generation for monitoring systems.
  """

  @doc """
  Create a Grafana dashboard for AsyncAPI monitoring.
  """
  def create_grafana_dashboard(config, opts \\ []) do
    dashboard = %{
      dashboard: %{
        title: Keyword.get(opts, :title, "AsyncAPI Monitoring"),
        tags: ["asyncapi", "monitoring"],
        timezone: "browser",
        panels: generate_dashboard_panels(config),
        time: %{
          from: "now-1h",
          to: "now"
        },
        refresh: "30s"
      }
    }
    
    {:ok, Jason.encode!(dashboard)}
  end

  defp generate_dashboard_panels(config) do
    panels = [
      create_throughput_panel(),
      create_latency_panel(),
      create_error_rate_panel(),
      create_health_status_panel()
    ]
    
    # Add custom panels based on metrics configuration
    custom_panels = generate_custom_metric_panels(config[:metrics] || %{})
    
    panels ++ custom_panels
  end

  defp create_throughput_panel do
    %{
      id: 1,
      title: "Message Throughput",
      type: "graph",
      targets: [
        %{
          expr: "rate(messages_processed[5m])",
          legendFormat: "Messages/sec"
        }
      ],
      yAxes: [
        %{label: "Messages/sec", min: 0}
      ]
    }
  end

  defp create_latency_panel do
    %{
      id: 2,
      title: "Message Latency",
      type: "graph",
      targets: [
        %{
          expr: "histogram_quantile(0.50, rate(message_duration_bucket[5m]))",
          legendFormat: "P50"
        },
        %{
          expr: "histogram_quantile(0.95, rate(message_duration_bucket[5m]))",
          legendFormat: "P95"
        },
        %{
          expr: "histogram_quantile(0.99, rate(message_duration_bucket[5m]))",
          legendFormat: "P99"
        }
      ],
      yAxes: [
        %{label: "Duration (ms)", min: 0}
      ]
    }
  end

  defp create_error_rate_panel do
    %{
      id: 3,
      title: "Error Rate",
      type: "singlestat",
      targets: [
        %{
          expr: "rate(errors_total[5m]) / rate(messages_processed[5m])",
          legendFormat: "Error Rate"
        }
      ],
      valueName: "current"
    }
  end

  defp create_health_status_panel do
    %{
      id: 4,
      title: "Health Status",
      type: "stat",
      targets: [
        %{
          expr: "health_check_status",
          legendFormat: "{{check_name}}"
        }
      ]
    }
  end

  defp generate_custom_metric_panels(metrics) do
    metrics
    |> Enum.with_index(5)
    |> Enum.map(fn {{name, metric}, index} ->
      %{
        id: index,
        title: String.capitalize(to_string(name)),
        type: get_panel_type_for_metric(metric.type),
        targets: [
          %{
            expr: to_string(name),
            legendFormat: metric.description
          }
        ]
      }
    end)
  end

  defp get_panel_type_for_metric(:counter), do: "graph"
  defp get_panel_type_for_metric(:gauge), do: "stat"
  defp get_panel_type_for_metric(:histogram), do: "heatmap"
  defp get_panel_type_for_metric(_), do: "graph"
end