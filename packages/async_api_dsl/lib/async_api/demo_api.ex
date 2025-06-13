defmodule AsyncApi.DemoApi do
  @moduledoc """
  Demo AsyncAPI implementation showcasing all framework features.
  
  This module demonstrates:
  - Complete AsyncAPI 3.0 specification
  - Real-time monitoring and observability
  - Security and authentication
  - Schema registry integration
  - Gateway integration
  - Protocol bindings
  - Code generation capabilities
  """

  use AsyncApi
  use AsyncApi.Monitoring
  use AsyncApi.SchemaRegistry
  use AsyncApi.Gateway
  use GenServer

  require Logger

  # AsyncAPI Specification
  info do
    title "AsyncAPI DSL Demo API"
    version "1.0.0"
    description """
    Comprehensive demonstration of AsyncAPI DSL framework capabilities including
    real-time event processing, monitoring, security, and multi-protocol support.
    """
    
    contact do
      name "AsyncAPI Team"
      email "demo@asyncapi.example.com"
      url "https://github.com/asyncapi/asyncapi-dsl"
    end
    
    license do
      name "MIT"
      url "https://opensource.org/licenses/MIT"
    end
  end

  servers do
    server :websocket_server, "ws://localhost:4000/socket" do
      protocol :websockets
      description "WebSocket server for real-time events"
    end
    
    server :nats_server, "nats://localhost:4222" do
      protocol :nats
      description "NATS server for message streaming"
      
      bindings [
        nats: [
          jetstream_enabled: true,
          max_reconnects: 10
        ]
      ]
    end
    
    server :redis_server, "redis://localhost:6379" do
      protocol :redis
      description "Redis server for stream processing"
      
      bindings [
        redis: [
          database: 0,
          connection_pool_size: 10
        ]
      ]
    end
  end

  channels do
    channel "user.events" do
      description "User activity event stream"
      
      bindings [
        nats: [
          subject: "user.events.>",
          jetstream: %{
            stream: "USER_EVENTS",
            durable_name: "user-event-processor"
          }
        ],
        redis: [
          stream_key: "user:events",
          consumer_group: "user-processors"
        ]
      ]
    end
    
    channel "notifications" do
      description "Real-time notification channel"
      
      bindings [
        websockets: [
          query: %{
            token: %{
              description: "Authentication token",
              type: :string
            }
          }
        ]
      ]
    end
    
    channel "system.metrics" do
      description "System monitoring metrics"
      
      bindings [
        nats: [
          subject: "system.metrics",
          jetstream: %{
            stream: "SYSTEM_METRICS",
            retention: :limits,
            max_age: 86400000  # 24 hours
          }
        ]
      ]
    end
  end

  # Component schemas
  components do
    schemas do
      schema :user_event do
        type :object
        description "User activity event"
        
        property :user_id, :string do
          description "Unique user identifier"
          format "uuid"
        end
        
        property :event_type, :string do
          description "Type of user event"
          enum ["login", "logout", "purchase", "view"]
        end
        
        property :timestamp, :string do
          description "Event timestamp"
          format "date-time"
        end
        
        property :metadata, :object do
          description "Additional event data"
          additional_properties true
        end
        
        required [:user_id, :event_type, :timestamp]
      end
      
      schema :notification do
        type :object
        description "Real-time notification"
        
        property :id, :string do
          description "Notification ID"
          format "uuid"
        end
        
        property :recipient_id, :string do
          description "Recipient user ID"
          format "uuid"
        end
        
        property :type, :string do
          description "Notification type"
          enum ["info", "warning", "error", "success"]
        end
        
        property :title, :string do
          description "Notification title"
          max_length 100
        end
        
        property :message, :string do
          description "Notification message"
          max_length 500
        end
        
        property :created_at, :string do
          description "Creation timestamp"
          format "date-time"
        end
        
        required [:id, :recipient_id, :type, :title, :message, :created_at]
      end
      
      schema :metric do
        type :object
        description "System metric data point"
        
        property :name, :string do
          description "Metric name"
        end
        
        property :value, :number do
          description "Metric value"
        end
        
        property :unit, :string do
          description "Metric unit"
          enum ["count", "rate", "gauge", "histogram"]
        end
        
        property :tags, :object do
          description "Metric tags/labels"
          additional_properties true
        end
        
        property :timestamp, :string do
          description "Metric timestamp"
          format "date-time"
        end
        
        required [:name, :value, :timestamp]
      end
    end

    messages do
      message :user_event do
        title "User Activity Event"
        summary "Event representing user activity"
        content_type "application/json"
        payload :user_event
      end
      
      message :notification do
        title "Real-time Notification"
        summary "Real-time notification to users"
        content_type "application/json"
        payload :notification
      end
      
      message :metric do
        title "System Monitoring Metric"
        summary "System performance and health metric"
        content_type "application/json"
        payload :metric
      end
    end
  end

  operations do
    operation :publishUserEvent do
      action :send
      channel "user.events"
      message :user_event
      summary "Publish user activity event"
      description "Publish a user activity event to the event stream"
    end
    
    operation :receiveUserEvent do
      action :receive
      channel "user.events"
      message :user_event
      summary "Receive user activity event"
      description "Subscribe to user activity events"
    end
    
    operation :sendNotification do
      action :send
      channel "notifications"
      message :notification
      summary "Send real-time notification"
      description "Send notification to connected users"
    end
    
    operation :receiveNotification do
      action :receive
      channel "notifications"
      message :notification
      summary "Receive real-time notification"
      description "Subscribe to real-time notifications"
    end
    
    operation :publishMetric do
      action :send
      channel "system.metrics"
      message :metric
      summary "Publish system metric"
      description "Publish system monitoring metric"
    end
    
    operation :receiveMetric do
      action :receive
      channel "system.metrics"
      message :metric
      summary "Receive system metric"
      description "Subscribe to system metrics"
    end
  end

  # GenServer implementation for demo purposes
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Starting AsyncAPI Demo API...")
    
    state = %{
      opts: opts,
      connections: %{},
      message_count: 0,
      start_time: System.system_time(:millisecond)
    }
    
    # Start periodic demo activities
    schedule_demo_activities()
    
    {:ok, state}
  end

  @impl true
  def handle_info(:demo_activity, state) do
    # Simulate some API activity for monitoring
    simulate_user_event(state)
    simulate_notification(state)
    simulate_metric(state)
    
    # Schedule next activity
    schedule_demo_activities()
    
    updated_state = %{state | message_count: state.message_count + 3}
    {:noreply, updated_state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      uptime: System.system_time(:millisecond) - state.start_time,
      message_count: state.message_count,
      active_connections: map_size(state.connections)
    }
    
    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:user_event, event}, state) do
    Logger.debug("Processing user event: #{inspect(event)}")
    
    # Record metrics if monitoring is available
    AsyncApi.Monitoring.increment_counter(:user_events_processed)
    
    {:noreply, state}
  end

  @impl true
  def handle_cast({:notification, notification}, state) do
    Logger.debug("Sending notification: #{inspect(notification)}")
    
    # Record metrics if monitoring is available
    AsyncApi.Monitoring.increment_counter(:notifications_sent)
    
    {:noreply, state}
  end

  # Public API functions
  def publish_user_event(event) do
    GenServer.cast(__MODULE__, {:user_event, event})
  end

  def send_notification(notification) do
    GenServer.cast(__MODULE__, {:notification, notification})
  end

  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Private helper functions
  defp schedule_demo_activities do
    # Schedule next demo activity in 5-15 seconds
    delay = 5000 + :rand.uniform(10000)
    Process.send_after(self(), :demo_activity, delay)
  end

  defp simulate_user_event(state) do
    event = %{
      user_id: "user_#{:rand.uniform(1000)}",
      event_type: Enum.random(["login", "logout", "purchase", "view"]),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      metadata: %{
        source: "demo_api",
        session_id: "session_#{:rand.uniform(10000)}"
      }
    }
    
    publish_user_event(event)
  end

  defp simulate_notification(state) do
    notification = %{
      id: "notif_#{:rand.uniform(100000)}",
      recipient_id: "user_#{:rand.uniform(1000)}",
      type: Enum.random(["info", "warning", "success"]),
      title: "Demo Notification",
      message: "This is a simulated notification from the demo API",
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    send_notification(notification)
  end

  defp simulate_metric(state) do
    metric = %{
      name: Enum.random(["cpu_usage", "memory_usage", "request_count", "response_time"]),
      value: :rand.uniform() * 100,
      unit: "gauge",
      tags: %{
        service: "demo_api",
        environment: "development"
      },
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }
    
    Logger.debug("Generated metric: #{inspect(metric)}")
  end
end