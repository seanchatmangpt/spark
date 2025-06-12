# Day 4: Production Deployment and CI/CD

> *"In theory, there is no difference between theory and practice. But in practice, there is."* - Jan L.A. van de Snepscheut

Welcome to Day 4! Today we bridge the gap between sophisticated DSL architecture and production-ready deployment. You'll build complete CI/CD pipelines, implement monitoring and observability, and create deployment DSLs that ensure reliable, automated releases.

## Daily Objectives

By the end of Day 4, you will:
- ✅ Deploy DSL-driven applications to production environments
- ✅ Build comprehensive CI/CD pipelines with DSL integration
- ✅ Implement monitoring and observability for DSL-based systems
- ✅ Create deployment pipeline DSLs with full automation
- ✅ Master operational excellence for production DSL systems

## Pre-Day Reflection

**Last Night's Assignment Review:**
- What deployment processes in your organization could benefit from DSL automation?
- What are the current pain points in your deployment pipeline?
- How could DSLs improve deployment reliability and consistency?
- What monitoring and observability gaps exist in your current systems?

---

## Morning Session (9:00-12:00)

### Opening Check-in (9:00-9:15)
**Pair Discussion (10 minutes):**
- Share your organization's current deployment process
- Describe the biggest deployment pain points you've experienced
- Explain what "production-ready" means in your context
- Discuss the monitoring and alerting challenges you face

**Group Insights (5 minutes):**
- Common deployment challenges across organizations
- Instructor highlights production readiness principles

### Production Readiness Fundamentals (9:15-10:15)

#### From Development to Production

**The Production Readiness Gap:**
```elixir
# Development Environment
defmodule DevConfig do
  use MyDsl
  
  service :api do
    base_url "http://localhost:4000"
    timeout 5_000
    retries 1
  end
end
```

**Production Requirements:**
```elixir
# Production Environment with Full Operational Support
defmodule ProdConfig do
  use MyDsl
  
  service :api do
    base_url {:system, "API_BASE_URL"}
    timeout {:system, "API_TIMEOUT", type: :integer, default: 30_000}
    retries {:system, "API_RETRIES", type: :integer, default: 3}
    
    # Production-specific concerns
    circuit_breaker do
      failure_threshold 5
      recovery_timeout 60_000
      half_open_max_calls 3
    end
    
    observability do
      metrics_enabled true
      tracing_enabled true
      health_check "/health"
      readiness_check "/ready"
    end
    
    security do
      tls_enabled true
      cert_path {:system, "TLS_CERT_PATH"}
      key_path {:system, "TLS_KEY_PATH"}
    end
    
    scaling do
      min_instances 2
      max_instances 10
      cpu_threshold 70
      memory_threshold 80
    end
  end
end
```

#### Production Readiness Checklist

**Infrastructure Concerns:**
- **Environment Configuration**: Secrets management, environment variables
- **Service Discovery**: Load balancing, health checks, service mesh
- **Scaling**: Auto-scaling policies, resource limits
- **Security**: TLS termination, authentication, authorization
- **Networking**: Firewall rules, ingress configuration

**Operational Concerns:**
- **Monitoring**: Metrics collection, alerting, dashboards
- **Logging**: Structured logging, log aggregation, retention
- **Tracing**: Distributed tracing, request correlation
- **Backup**: Data backup strategies, disaster recovery
- **Compliance**: Audit trails, regulatory requirements

#### DSL-Driven Production Configuration

**Environment-Aware DSL Pattern:**
```elixir
defmodule EnvironmentAwareDsl do
  defmacro __using__(_opts) do
    quote do
      @environment Application.get_env(:my_app, :environment, :dev)
      
      def config_for_environment(env \\ @environment) do
        apply(__MODULE__, :"#{env}_config", [])
      end
      
      defp dev_config, do: build_config(:dev)
      defp staging_config, do: build_config(:staging)  
      defp prod_config, do: build_config(:prod)
    end
  end
end

defmodule MyApp.Config do
  use MyDsl
  use EnvironmentAwareDsl
  
  defp build_config(:dev) do
    service :api do
      base_url "http://localhost:4000"
      timeout 5_000
      debug_mode true
    end
  end
  
  defp build_config(:staging) do
    service :api do
      base_url "https://api-staging.myapp.com"
      timeout 15_000
      circuit_breaker_enabled true
      metrics_enabled true
    end
  end
  
  defp build_config(:prod) do
    service :api do
      base_url "https://api.myapp.com"
      timeout 30_000
      circuit_breaker_enabled true
      metrics_enabled true
      tracing_enabled true
      security_enabled true
      auto_scaling_enabled true
    end
  end
end
```

**Configuration Validation for Production:**
```elixir
defmodule ProductionConfigVerifier do
  use Spark.Dsl.Verifier
  
  def verify(dsl_state) do
    environment = get_environment()
    
    case environment do
      :prod -> verify_production_config(dsl_state)
      :staging -> verify_staging_config(dsl_state)
      _ -> :ok
    end
  end
  
  defp verify_production_config(dsl_state) do
    services = Info.services(dsl_state)
    
    with :ok <- ensure_tls_enabled(services),
         :ok <- ensure_monitoring_enabled(services),
         :ok <- ensure_circuit_breakers(services),
         :ok <- ensure_resource_limits(services),
         :ok <- ensure_secrets_externalized(services) do
      :ok
    end
  end
  
  defp ensure_tls_enabled(services) do
    non_tls_services = 
      services
      |> Enum.filter(fn service -> 
        not service.security.tls_enabled
      end)
    
    case non_tls_services do
      [] -> :ok
      services -> 
        {:error, "Production services must have TLS enabled: #{inspect(Enum.map(services, & &1.name))}"}
    end
  end
  
  defp ensure_monitoring_enabled(services) do
    unmonitored_services = 
      services
      |> Enum.filter(fn service ->
        not service.observability.metrics_enabled
      end)
    
    case unmonitored_services do
      [] -> :ok
      services ->
        {:error, "Production services must have monitoring enabled: #{inspect(Enum.map(services, & &1.name))}"}
    end
  end
end
```

### Break (10:15-10:30)

### CI/CD Pipeline Integration (10:30-11:30)

#### DSL-Aware CI/CD Patterns

**Pipeline Configuration Validation:**
```bash
#!/bin/bash
# .github/workflows/dsl-validation.yml equivalent

# Validate DSL configurations
echo "Validating DSL configurations..."
mix compile --warnings-as-errors

# Run DSL-specific tests
echo "Running DSL tests..."
mix test --only dsl

# Validate production configuration
echo "Validating production readiness..."
MIX_ENV=prod mix run -e "
  try do
    MyApp.Config.config_for_environment(:prod)
    IO.puts('✅ Production configuration valid')
  rescue
    error -> 
      IO.puts('❌ Production configuration invalid: #{inspect(error)}')
      System.halt(1)
  end
"

# Generate configuration artifacts
echo "Generating configuration artifacts..."
mix run scripts/generate_k8s_configs.exs
mix run scripts/generate_terraform_configs.exs
```

**DSL-Driven Deployment Pipeline:**
```elixir
defmodule DeploymentPipeline do
  use PipelineDsl
  
  pipeline :production_deploy do
    trigger :git_tag do
      pattern "v*"
      branch "main"
    end
    
    environment_variables do
      var "DOCKER_REGISTRY", secret: "docker_registry_url"
      var "K8S_CLUSTER", secret: "kubernetes_cluster"
      var "DEPLOY_TOKEN", secret: "deployment_token"
    end
    
    stage :validation do
      parallel do
        job :lint_code do
          run "mix credo --strict"
          run "mix format --check-formatted"
        end
        
        job :test_suite do
          run "mix test --cover"
          artifacts ["cover/"]
        end
        
        job :validate_dsl do
          run "mix compile --warnings-as-errors"
          run "MIX_ENV=prod mix run scripts/validate_prod_config.exs"
        end
        
        job :security_scan do
          run "mix sobelow"
          run "mix audit"
        end
      end
    end
    
    stage :build do
      depends_on [:validation]
      
      job :docker_build do
        run "docker build -t ${DOCKER_REGISTRY}/myapp:${GITHUB_SHA} ."
        run "docker push ${DOCKER_REGISTRY}/myapp:${GITHUB_SHA}"
        
        cache do
          paths [".mix/", "deps/", "_build/"]
          key "mix-{{ checksum 'mix.lock' }}"
        end
      end
      
      job :generate_configs do
        run "mix run scripts/generate_k8s_configs.exs --tag=${GITHUB_SHA}"
        artifacts ["k8s/generated/"]
      end
    end
    
    stage :deploy_staging do
      depends_on [:build]
      environment :staging
      
      job :deploy do
        run "kubectl apply -f k8s/generated/staging/"
        run "kubectl rollout status deployment/myapp -n staging"
      end
      
      job :smoke_tests do
        run "mix run scripts/smoke_tests.exs --env=staging"
        retry_attempts 3
        timeout :timer.minutes(5)
      end
    end
    
    stage :deploy_production do
      depends_on [:deploy_staging]
      environment :production
      
      approval_required do
        approvers ["tech-lead", "platform-team"]
        timeout :timer.hours(4)
      end
      
      job :blue_green_deploy do
        run "mix run scripts/blue_green_deploy.exs --tag=${GITHUB_SHA}"
        
        rollback_on_failure do
          run "mix run scripts/rollback_deploy.exs"
        end
      end
      
      job :production_tests do
        run "mix run scripts/production_health_check.exs"
        run "mix run scripts/integration_tests.exs --env=production"
      end
    end
    
    stage :post_deploy do
      depends_on [:deploy_production]
      
      job :update_monitoring do
        run "mix run scripts/update_dashboards.exs --version=${GITHUB_SHA}"
      end
      
      job :notify_team do
        slack_notification do
          channel "#deployments"
          message "🚀 Production deployment successful: ${GITHUB_SHA}"
        end
      end
    end
  end
end
```

#### Configuration Generation for Infrastructure

**Kubernetes Manifest Generation:**
```elixir
defmodule K8sGenerator do
  def generate_deployment(service_config) do
    """
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: #{service_config.name}
      labels:
        app: #{service_config.name}
        version: #{service_config.version}
    spec:
      replicas: #{service_config.scaling.min_instances}
      selector:
        matchLabels:
          app: #{service_config.name}
      template:
        metadata:
          labels:
            app: #{service_config.name}
            version: #{service_config.version}
        spec:
          containers:
          - name: #{service_config.name}
            image: #{service_config.image}
            ports:
            - containerPort: #{service_config.port}
            env:
            #{generate_env_vars(service_config.environment)}
            resources:
              requests:
                memory: "#{service_config.resources.memory_request}"
                cpu: "#{service_config.resources.cpu_request}"
              limits:
                memory: "#{service_config.resources.memory_limit}"
                cpu: "#{service_config.resources.cpu_limit}"
            livenessProbe:
              httpGet:
                path: #{service_config.observability.health_check}
                port: #{service_config.port}
              initialDelaySeconds: 30
              periodSeconds: 10
            readinessProbe:
              httpGet:
                path: #{service_config.observability.readiness_check}
                port: #{service_config.port}
              initialDelaySeconds: 5
              periodSeconds: 5
    """
  end
  
  def generate_service(service_config) do
    """
    apiVersion: v1
    kind: Service
    metadata:
      name: #{service_config.name}-service
      labels:
        app: #{service_config.name}
    spec:
      selector:
        app: #{service_config.name}
      ports:
      - protocol: TCP
        port: 80
        targetPort: #{service_config.port}
      type: ClusterIP
    """
  end
  
  def generate_hpa(service_config) do
    if service_config.scaling.auto_scaling_enabled do
      """
      apiVersion: autoscaling/v2
      kind: HorizontalPodAutoscaler
      metadata:
        name: #{service_config.name}-hpa
      spec:
        scaleTargetRef:
          apiVersion: apps/v1
          kind: Deployment
          name: #{service_config.name}
        minReplicas: #{service_config.scaling.min_instances}
        maxReplicas: #{service_config.scaling.max_instances}
        metrics:
        - type: Resource
          resource:
            name: cpu
            target:
              type: Utilization
              averageUtilization: #{service_config.scaling.cpu_threshold}
        - type: Resource
          resource:
            name: memory
            target:
              type: Utilization
              averageUtilization: #{service_config.scaling.memory_threshold}
      """
    else
      ""
    end
  end
end
```

### Monitoring and Observability (11:30-12:00)

#### DSL-Driven Observability

**Metrics Configuration Generation:**
```elixir
defmodule ObservabilityGenerator do
  def generate_prometheus_config(services) do
    scrape_configs = 
      services
      |> Enum.filter(& &1.observability.metrics_enabled)
      |> Enum.map(&generate_scrape_config/1)
    
    """
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    scrape_configs:
    #{Enum.join(scrape_configs, "\n")}
    """
  end
  
  defp generate_scrape_config(service) do
    """
    - job_name: '#{service.name}'
      static_configs:
      - targets: ['#{service.name}-service:#{service.metrics_port || 9090}']
      scrape_interval: #{service.observability.scrape_interval || "30s"}
      metrics_path: #{service.observability.metrics_path || "/metrics"}
      scheme: #{if service.security.tls_enabled, do: "https", else: "http"}
    """
  end
  
  def generate_grafana_dashboard(services) do
    panels = 
      services
      |> Enum.with_index()
      |> Enum.flat_map(fn {service, index} ->
        generate_service_panels(service, index * 4)
      end)
    
    %{
      dashboard: %{
        id: nil,
        title: "Service Overview",
        tags: ["generated", "services"],
        timezone: "browser",
        panels: panels,
        time: %{
          from: "now-1h",
          to: "now"
        },
        refresh: "30s"
      }
    }
    |> Jason.encode!(pretty: true)
  end
  
  defp generate_service_panels(service, base_y) do
    [
      # Request rate panel
      %{
        id: service.name * 10 + 1,
        title: "#{service.name} - Request Rate",
        type: "graph",
        gridPos: %{h: 8, w: 12, x: 0, y: base_y},
        targets: [
          %{
            expr: "rate(http_requests_total{service=\"#{service.name}\"}[5m])",
            legendFormat: "{{method}} {{status}}"
          }
        ]
      },
      
      # Response time panel  
      %{
        id: service.name * 10 + 2,
        title: "#{service.name} - Response Time",
        type: "graph", 
        gridPos: %{h: 8, w: 12, x: 12, y: base_y},
        targets: [
          %{
            expr: "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{service=\"#{service.name}\"}[5m]))",
            legendFormat: "95th percentile"
          }
        ]
      },
      
      # Error rate panel
      %{
        id: service.name * 10 + 3,
        title: "#{service.name} - Error Rate",
        type: "singlestat",
        gridPos: %{h: 4, w: 6, x: 0, y: base_y + 8},
        targets: [
          %{
            expr: "rate(http_requests_total{service=\"#{service.name}\",status=~\"5..\"}[5m]) / rate(http_requests_total{service=\"#{service.name}\"}[5m]) * 100",
            legendFormat: "Error %"
          }
        ]
      },
      
      # CPU usage panel
      %{
        id: service.name * 10 + 4,
        title: "#{service.name} - CPU Usage",
        type: "singlestat",
        gridPos: %{h: 4, w: 6, x: 6, y: base_y + 8},
        targets: [
          %{
            expr: "rate(container_cpu_usage_seconds_total{pod=~\"#{service.name}.*\"}[5m]) * 100",
            legendFormat: "CPU %"
          }
        ]
      }
    ]
  end
end
```

#### Alerting Rules Generation

```elixir
defmodule AlertingGenerator do
  def generate_alerting_rules(services) do
    rules = 
      services
      |> Enum.flat_map(&generate_service_alerts/1)
    
    """
    groups:
    - name: service_alerts
      rules:
      #{Enum.join(rules, "\n")}
    """
  end
  
  defp generate_service_alerts(service) do
    base_alerts = [
      generate_high_error_rate_alert(service),
      generate_high_response_time_alert(service),
      generate_service_down_alert(service)
    ]
    
    scaling_alerts = 
      if service.scaling.auto_scaling_enabled do
        [generate_scaling_alert(service)]
      else
        []
      end
    
    circuit_breaker_alerts = 
      if service.circuit_breaker.enabled do
        [generate_circuit_breaker_alert(service)]
      else
        []
      end
    
    base_alerts ++ scaling_alerts ++ circuit_breaker_alerts
  end
  
  defp generate_high_error_rate_alert(service) do
    """
    - alert: #{service.name}_HighErrorRate
      expr: rate(http_requests_total{service="#{service.name}",status=~"5.."}[5m]) / rate(http_requests_total{service="#{service.name}"}[5m]) > 0.05
      for: 2m
      labels:
        severity: warning
        service: #{service.name}
      annotations:
        summary: "High error rate for #{service.name}"
        description: "#{service.name} has error rate above 5% for more than 2 minutes"
    """
  end
  
  defp generate_high_response_time_alert(service) do
    threshold = service.performance_thresholds.response_time_p95 || 1000
    
    """
    - alert: #{service.name}_HighResponseTime
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{service="#{service.name}"}[5m])) > #{threshold / 1000}
      for: 5m
      labels:
        severity: warning
        service: #{service.name}
      annotations:
        summary: "High response time for #{service.name}"
        description: "#{service.name} 95th percentile response time is above #{threshold}ms"
    """
  end
  
  defp generate_service_down_alert(service) do
    """
    - alert: #{service.name}_ServiceDown
      expr: up{service="#{service.name}"} == 0
      for: 1m
      labels:
        severity: critical
        service: #{service.name}
      annotations:
        summary: "#{service.name} is down"
        description: "#{service.name} has been down for more than 1 minute"
    """
  end
end
```

---

## Afternoon Lab Session (1:00-5:00)

### Lab 4.1: Complete Deployment Pipeline (1:00-3:30)

**Business Context:**
Your organization needs to deploy a microservices application with multiple environments, comprehensive monitoring, and zero-downtime deployments. The current deployment process is manual, error-prone, and inconsistent across teams.

Current challenges:
- **Manual deployments** lead to human errors and inconsistencies
- **No standardized monitoring** across services
- **Configuration drift** between environments
- **Slow rollback procedures** when issues occur
- **Poor visibility** into deployment status and health

**Your Mission:**
Build a complete deployment pipeline DSL that generates infrastructure configurations, CI/CD pipelines, monitoring dashboards, and alerting rules from a single source of truth.

#### Core Pipeline DSL (45 minutes)

**Step 1: Define the Deployment DSL**

```elixir
# lib/deployment_dsl/extension.ex
defmodule DeploymentDsl.Extension do
  alias DeploymentDsl.Entities
  
  @environment %Spark.Dsl.Entity{
    name: :environment,
    target: Entities.Environment,
    args: [:name],
    schema: [
      name: [type: :atom, required: true],
      cluster: [type: :string, required: true],
      namespace: [type: :string],
      domain: [type: :string],
      tls_enabled: [type: :boolean, default: true],
      monitoring_enabled: [type: :boolean, default: true],
      debug_mode: [type: :boolean, default: false]
    ]
  }
  
  @resource_limits %Spark.Dsl.Entity{
    name: :resource_limits,
    target: Entities.ResourceLimits,
    schema: [
      cpu_request: [type: :string, default: "100m"],
      cpu_limit: [type: :string, default: "500m"],
      memory_request: [type: :string, default: "128Mi"],
      memory_limit: [type: :string, default: "512Mi"]
    ]
  }
  
  @scaling_policy %Spark.Dsl.Entity{
    name: :scaling,
    target: Entities.ScalingPolicy,
    schema: [
      min_replicas: [type: :pos_integer, default: 1],
      max_replicas: [type: :pos_integer, default: 10],
      cpu_threshold: [type: :pos_integer, default: 70],
      memory_threshold: [type: :pos_integer, default: 80],
      scale_up_cooldown: [type: :pos_integer, default: 300],
      scale_down_cooldown: [type: :pos_integer, default: 300]
    ]
  }
  
  @health_check %Spark.Dsl.Entity{
    name: :health_check,
    target: Entities.HealthCheck,
    schema: [
      path: [type: :string, default: "/health"],
      port: [type: :pos_integer, default: 8080],
      initial_delay: [type: :pos_integer, default: 30],
      period: [type: :pos_integer, default: 10],
      timeout: [type: :pos_integer, default: 5],
      failure_threshold: [type: :pos_integer, default: 3]
    ]
  }
  
  @service %Spark.Dsl.Entity{
    name: :service,
    target: Entities.Service,
    args: [:name],
    entities: [
      resource_limits: @resource_limits,
      scaling: @scaling_policy,
      health_check: @health_check
    ],
    schema: [
      name: [type: :atom, required: true],
      image: [type: :string, required: true],
      port: [type: :pos_integer, default: 8080],
      environment_variables: [type: :keyword_list, default: []],
      secrets: [type: {:list, :string}, default: []],
      volumes: [type: :keyword_list, default: []],
      dependencies: [type: {:list, :atom}, default: []],
      public: [type: :boolean, default: false]
    ]
  }
  
  @deployment_strategy %Spark.Dsl.Entity{
    name: :deployment_strategy,
    target: Entities.DeploymentStrategy,
    schema: [
      type: [type: {:one_of, [:rolling, :blue_green, :canary]}, default: :rolling],
      max_unavailable: [type: :string, default: "1"],
      max_surge: [type: :string, default: "1"],
      canary_percentage: [type: :pos_integer, default: 10],
      canary_duration: [type: :pos_integer, default: 300],
      approval_required: [type: :boolean, default: false],
      rollback_on_failure: [type: :boolean, default: true]
    ]
  }
  
  @application %Spark.Dsl.Entity{
    name: :application,
    target: Entities.Application,
    args: [:name],
    entities: [
      service: @service,
      deployment_strategy: @deployment_strategy
    ],
    schema: [
      name: [type: :atom, required: true],
      version: [type: :string, required: true],
      description: [type: :string],
      repository: [type: :string],
      team: [type: :string],
      slack_channel: [type: :string]
    ]
  }
  
  @environments %Spark.Dsl.Section{
    name: :environments,
    entities: [@environment]
  }
  
  @applications %Spark.Dsl.Section{
    name: :applications,
    entities: [@application]
  }
  
  use Spark.Dsl.Extension,
    sections: [@environments, @applications],
    transformers: [
      DeploymentDsl.Transformers.ValidateEnvironments,
      DeploymentDsl.Transformers.GenerateK8sManifests,
      DeploymentDsl.Transformers.GenerateCicdPipelines,
      DeploymentDsl.Transformers.GenerateMonitoring
    ],
    verifiers: [
      DeploymentDsl.Verifiers.ValidateResourceLimits,
      DeploymentDsl.Verifiers.ValidateHealthChecks,
      DeploymentDsl.Verifiers.ValidateProductionReadiness
    ]
end
```

#### Production-Ready Configuration (45 minutes)

**Step 2: Complete Application Configuration**

```elixir
# lib/my_company/platform_config.ex
defmodule MyCompany.PlatformConfig do
  use DeploymentDsl
  
  environments do
    environment :development do
      cluster "dev-cluster"
      namespace "dev"
      domain "dev.mycompany.com"
      tls_enabled false
      debug_mode true
    end
    
    environment :staging do
      cluster "staging-cluster"
      namespace "staging"
      domain "staging.mycompany.com"
      tls_enabled true
      monitoring_enabled true
    end
    
    environment :production do
      cluster "prod-cluster"
      namespace "production"
      domain "api.mycompany.com"
      tls_enabled true
      monitoring_enabled true
    end
  end
  
  applications do
    application :user_service do
      version "1.2.3"
      description "User authentication and profile management"
      repository "https://github.com/mycompany/user-service"
      team "auth-team"
      slack_channel "#auth-team"
      
      service :api do
        image "user-service:{{version}}"
        port 8080
        public true
        
        environment_variables [
          DATABASE_URL: {:secret, "user-db-connection"},
          JWT_SECRET: {:secret, "jwt-signing-key"},
          REDIS_URL: {:secret, "redis-connection"},
          LOG_LEVEL: {:env, "LOG_LEVEL", default: "info"}
        ]
        
        secrets ["user-db-connection", "jwt-signing-key", "redis-connection"]
        
        dependencies [:database, :redis]
        
        resource_limits do
          cpu_request "200m"
          cpu_limit "1000m"
          memory_request "256Mi"
          memory_limit "1Gi"
        end
        
        scaling do
          min_replicas 2
          max_replicas 20
          cpu_threshold 70
          memory_threshold 80
        end
        
        health_check do
          path "/api/health"
          port 8080
          initial_delay 45
          period 15
          timeout 10
          failure_threshold 3
        end
      end
      
      service :worker do
        image "user-service:{{version}}"
        port 8081
        public false
        
        environment_variables [
          DATABASE_URL: {:secret, "user-db-connection"},
          QUEUE_URL: {:secret, "queue-connection"},
          WORKER_CONCURRENCY: {:env, "WORKER_CONCURRENCY", default: "5"}
        ]
        
        resource_limits do
          cpu_request "100m"
          cpu_limit "500m"
          memory_request "128Mi"
          memory_limit "512Mi"
        end
        
        scaling do
          min_replicas 1
          max_replicas 5
          cpu_threshold 80
        end
        
        health_check do
          path "/worker/health"
          port 8081
        end
      end
      
      deployment_strategy do
        type :blue_green
        approval_required true
        rollback_on_failure true
        canary_percentage 10
        canary_duration 600
      end
    end
    
    application :order_service do
      version "2.1.0"
      description "Order processing and fulfillment"
      repository "https://github.com/mycompany/order-service"
      team "commerce-team"
      slack_channel "#commerce-team"
      
      service :api do
        image "order-service:{{version}}"
        port 8080
        public true
        
        environment_variables [
          DATABASE_URL: {:secret, "order-db-connection"},
          PAYMENT_API_KEY: {:secret, "payment-api-key"},
          INVENTORY_SERVICE_URL: {:env, "INVENTORY_SERVICE_URL"},
          USER_SERVICE_URL: {:env, "USER_SERVICE_URL"}
        ]
        
        dependencies [:database, :user_service, :payment_gateway]
        
        resource_limits do
          cpu_request "300m"
          cpu_limit "1500m"
          memory_request "512Mi"
          memory_limit "2Gi"
        end
        
        scaling do
          min_replicas 3
          max_replicas 30
          cpu_threshold 65
          memory_threshold 75
        end
        
        health_check do
          path "/api/v1/health"
          port 8080
          initial_delay 60
          period 20
        end
      end
      
      deployment_strategy do
        type :canary
        canary_percentage 5
        canary_duration 900
        approval_required true
        rollback_on_failure true
      end
    end
  end
end
```

#### Infrastructure Generation (30 minutes)

**Step 3: Kubernetes Manifest Generation**

```elixir
# lib/deployment_dsl/generators/kubernetes.ex
defmodule DeploymentDsl.Generators.Kubernetes do
  def generate_all_manifests(module, environment) do
    applications = DeploymentDsl.Info.applications(module)
    env_config = DeploymentDsl.Info.environment(module, environment)
    
    manifests = 
      applications
      |> Enum.flat_map(fn app ->
        app.services
        |> Enum.flat_map(fn service ->
          [
            generate_deployment(app, service, env_config),
            generate_service(app, service, env_config),
            generate_hpa(app, service, env_config),
            generate_ingress(app, service, env_config)
          ]
          |> Enum.filter(& &1 != nil)
        end)
      end)
    
    namespace_manifest = generate_namespace(env_config)
    
    [namespace_manifest | manifests]
    |> Enum.join("\n---\n")
  end
  
  def generate_deployment(app, service, env_config) do
    """
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: #{app.name}-#{service.name}
      namespace: #{env_config.namespace}
      labels:
        app: #{app.name}
        service: #{service.name}
        version: #{app.version}
        team: #{app.team}
      annotations:
        deployment.kubernetes.io/revision: "1"
        app.mycompany.com/repository: #{app.repository}
        app.mycompany.com/slack-channel: #{app.slack_channel}
    spec:
      replicas: #{service.scaling.min_replicas}
      strategy:
        type: #{get_k8s_strategy_type(app.deployment_strategy.type)}
        #{generate_strategy_config(app.deployment_strategy)}
      selector:
        matchLabels:
          app: #{app.name}
          service: #{service.name}
      template:
        metadata:
          labels:
            app: #{app.name}
            service: #{service.name}
            version: #{app.version}
            team: #{app.team}
          annotations:
            prometheus.io/scrape: "true"
            prometheus.io/port: "#{service.port}"
            prometheus.io/path: "/metrics"
        spec:
          containers:
          - name: #{service.name}
            image: #{interpolate_image(service.image, app.version)}
            ports:
            - containerPort: #{service.port}
              name: http
              protocol: TCP
            env:
            #{generate_env_vars(service.environment_variables, env_config)}
            resources:
              requests:
                cpu: #{service.resource_limits.cpu_request}
                memory: #{service.resource_limits.memory_request}
              limits:
                cpu: #{service.resource_limits.cpu_limit}
                memory: #{service.resource_limits.memory_limit}
            livenessProbe:
              httpGet:
                path: #{service.health_check.path}
                port: #{service.health_check.port}
              initialDelaySeconds: #{service.health_check.initial_delay}
              periodSeconds: #{service.health_check.period}
              timeoutSeconds: #{service.health_check.timeout}
              failureThreshold: #{service.health_check.failure_threshold}
            readinessProbe:
              httpGet:
                path: #{service.health_check.path}
                port: #{service.health_check.port}
              initialDelaySeconds: 10
              periodSeconds: 5
              timeoutSeconds: #{service.health_check.timeout}
              failureThreshold: 3
          #{generate_volumes(service.volumes)}
          #{generate_image_pull_secrets(env_config)}
    """
  end
  
  def generate_hpa(app, service, env_config) do
    if service.scaling.max_replicas > service.scaling.min_replicas do
      """
      apiVersion: autoscaling/v2
      kind: HorizontalPodAutoscaler
      metadata:
        name: #{app.name}-#{service.name}-hpa
        namespace: #{env_config.namespace}
        labels:
          app: #{app.name}
          service: #{service.name}
      spec:
        scaleTargetRef:
          apiVersion: apps/v1
          kind: Deployment
          name: #{app.name}-#{service.name}
        minReplicas: #{service.scaling.min_replicas}
        maxReplicas: #{service.scaling.max_replicas}
        metrics:
        - type: Resource
          resource:
            name: cpu
            target:
              type: Utilization
              averageUtilization: #{service.scaling.cpu_threshold}
        - type: Resource
          resource:
            name: memory
            target:
              type: Utilization
              averageUtilization: #{service.scaling.memory_threshold}
        behavior:
          scaleUp:
            stabilizationWindowSeconds: #{service.scaling.scale_up_cooldown}
            policies:
            - type: Percent
              value: 100
              periodSeconds: 60
          scaleDown:
            stabilizationWindowSeconds: #{service.scaling.scale_down_cooldown}
            policies:
            - type: Percent
              value: 10
              periodSeconds: 60
      """
    else
      nil
    end
  end
  
  def generate_ingress(app, service, env_config) do
    if service.public and env_config.domain do
      """
      apiVersion: networking.k8s.io/v1
      kind: Ingress
      metadata:
        name: #{app.name}-#{service.name}-ingress
        namespace: #{env_config.namespace}
        labels:
          app: #{app.name}
          service: #{service.name}
        annotations:
          kubernetes.io/ingress.class: nginx
          nginx.ingress.kubernetes.io/ssl-redirect: "#{env_config.tls_enabled}"
          nginx.ingress.kubernetes.io/proxy-body-size: "10m"
          nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
          nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
      spec:
        #{generate_tls_config(app, service, env_config)}
        rules:
        - host: #{app.name}.#{env_config.domain}
          http:
            paths:
            - path: /
              pathType: Prefix
              backend:
                service:
                  name: #{app.name}-#{service.name}-service
                  port:
                    number: 80
      """
    else
      nil
    end
  end
end
```

#### CI/CD Pipeline Generation (30 minutes)

**Step 4: GitHub Actions Pipeline Generation**

```elixir
# lib/deployment_dsl/generators/github_actions.ex
defmodule DeploymentDsl.Generators.GithubActions do
  def generate_workflow(app, environments) do
    """
    name: Deploy #{app.name}
    
    on:
      push:
        branches: [main]
        paths: ['#{get_app_path(app)}/**']
      pull_request:
        branches: [main] 
        paths: ['#{get_app_path(app)}/**']
      workflow_dispatch:
        inputs:
          environment:
            description: 'Environment to deploy to'
            required: true
            default: 'staging'
            type: choice
            options: #{inspect(Enum.map(environments, &to_string/1))}
    
    env:
      REGISTRY: ghcr.io
      IMAGE_NAME: #{app.name}
    
    jobs:
      test:
        runs-on: ubuntu-latest
        steps:
        - uses: actions/checkout@v4
        
        - name: Setup Elixir
          uses: erlef/setup-beam@v1
          with:
            elixir-version: '1.16.1'
            otp-version: '26.2'
        
        - name: Restore dependencies cache
          uses: actions/cache@v3
          with:
            path: |
              deps
              _build
            key: deps-${{ runner.os }}-${{ hashFiles('**/mix.lock') }}
            restore-keys: deps-${{ runner.os }}-
        
        - name: Install dependencies
          run: mix deps.get
        
        - name: Check formatting
          run: mix format --check-formatted
        
        - name: Run Credo
          run: mix credo --strict
        
        - name: Run tests
          run: mix test --cover
        
        - name: Run security scan
          run: mix sobelow --config
        
        - name: Validate DSL configuration
          run: |
            mix compile --warnings-as-errors
            mix run -e "MyCompany.PlatformConfig.validate_all_environments()"
    
      build:
        needs: test
        runs-on: ubuntu-latest
        if: github.ref == 'refs/heads/main'
        outputs:
          image-tag: ${{ steps.meta.outputs.tags }}
          image-digest: ${{ steps.build.outputs.digest }}
        steps:
        - uses: actions/checkout@v4
        
        - name: Log in to Container Registry
          uses: docker/login-action@v3
          with:
            registry: ${{ env.REGISTRY }}
            username: ${{ github.actor }}
            password: ${{ secrets.GITHUB_TOKEN }}
        
        - name: Extract metadata
          id: meta
          uses: docker/metadata-action@v5
          with:
            images: ${{ env.REGISTRY }}/${{ github.repository }}/${{ env.IMAGE_NAME }}
            tags: |
              type=ref,event=branch
              type=ref,event=pr
              type=sha,prefix={{branch}}-
              type=raw,value=latest,enable={{is_default_branch}}
        
        - name: Build and push Docker image
          id: build
          uses: docker/build-push-action@v5
          with:
            context: .
            file: #{get_app_path(app)}/Dockerfile
            push: true
            tags: ${{ steps.meta.outputs.tags }}
            labels: ${{ steps.meta.outputs.labels }}
            cache-from: type=gha
            cache-to: type=gha,mode=max
    
      #{generate_deployment_jobs(app, environments)}
    """
  end
  
  defp generate_deployment_jobs(app, environments) do
    environments
    |> Enum.map(&generate_deployment_job(app, &1))
    |> Enum.join("\n\n  ")
  end
  
  defp generate_deployment_job(app, environment) do
    """
    deploy-#{environment}:
      needs: build
      runs-on: ubuntu-latest
      environment: #{environment}
      #{generate_condition(environment)}
      steps:
      - uses: actions/checkout@v4
      
      - name: Setup kubectl
        uses: azure/setup-kubectl@v3
        with:
          version: 'v1.28.0'
      
      - name: Configure kubectl
        run: |
          echo "${{ secrets.KUBECONFIG_#{String.upcase(to_string(environment))} }}" | base64 -d > kubeconfig
          export KUBECONFIG=kubeconfig
      
      - name: Generate Kubernetes manifests
        run: |
          mix run -e "
            manifests = DeploymentDsl.Generators.Kubernetes.generate_all_manifests(MyCompany.PlatformConfig, :#{environment})
            File.write!('k8s-manifests.yaml', manifests)
          "
      
      #{generate_deployment_strategy_steps(app, environment)}
      
      - name: Verify deployment
        run: |
          kubectl rollout status deployment/#{app.name}-api -n #{get_namespace(environment)} --timeout=300s
          kubectl get pods -n #{get_namespace(environment)} -l app=#{app.name}
      
      - name: Run smoke tests
        run: |
          mix run scripts/smoke_tests.exs --env=#{environment} --app=#{app.name}
      
      - name: Notify team
        if: always()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          channel: '#{app.slack_channel}'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
    """
  end
  
  defp generate_deployment_strategy_steps(app, environment) do
    case app.deployment_strategy.type do
      :rolling ->
        """
        - name: Apply manifests (Rolling Update)
          run: kubectl apply -f k8s-manifests.yaml
        """
      
      :blue_green ->
        """
        - name: Blue-Green Deployment
          run: |
            # Create new deployment with blue/green suffix
            sed 's/#{app.name}/#{app.name}-green/g' k8s-manifests.yaml | kubectl apply -f -
            
            # Wait for green deployment to be ready
            kubectl rollout status deployment/#{app.name}-green-api --timeout=300s
            
            # Run health checks against green deployment
            mix run scripts/health_check.exs --target=green --env=#{environment}
            
            # Switch traffic to green deployment
            kubectl patch service #{app.name}-api-service -p '{"spec":{"selector":{"version":"green"}}}'
            
            # Clean up blue deployment after success
            kubectl delete deployment #{app.name}-api || true
            kubectl patch deployment #{app.name}-green-api --type='merge' -p='{"metadata":{"name":"#{app.name}-api"}}'
        """
      
      :canary ->
        """
        - name: Canary Deployment
          run: |
            # Deploy canary version
            sed 's/#{app.name}/#{app.name}-canary/g' k8s-manifests.yaml | \\
            sed 's/replicas: [0-9]*/replicas: 1/g' | kubectl apply -f -
            
            # Wait for canary to be ready
            kubectl rollout status deployment/#{app.name}-canary-api --timeout=300s
            
            # Configure traffic split (#{app.deployment_strategy.canary_percentage}% to canary)
            kubectl apply -f - <<EOF
            apiVersion: networking.istio.io/v1alpha3
            kind: VirtualService
            metadata:
              name: #{app.name}-canary
            spec:
              hosts:
              - #{app.name}.#{get_domain(environment)}
              http:
              - match:
                - headers:
                    canary:
                      exact: "true"
                route:
                - destination:
                    host: #{app.name}-canary-api-service
              - route:
                - destination:
                    host: #{app.name}-api-service
                  weight: #{100 - app.deployment_strategy.canary_percentage}
                - destination:
                    host: #{app.name}-canary-api-service
                  weight: #{app.deployment_strategy.canary_percentage}
            EOF
            
            # Monitor canary for specified duration
            sleep #{app.deployment_strategy.canary_duration}
            
            # Check canary metrics
            if mix run scripts/canary_analysis.exs --env=#{environment} --duration=#{app.deployment_strategy.canary_duration}; then
              echo "Canary successful, promoting to full deployment"
              kubectl apply -f k8s-manifests.yaml
              kubectl delete deployment #{app.name}-canary-api
            else
              echo "Canary failed, rolling back"
              kubectl delete deployment #{app.name}-canary-api
              exit 1
            fi
        """
    end
  end
end
```

### Break (3:30-3:45)

### Lab 4.2: Monitoring and Alerting (3:45-4:45)

#### Comprehensive Monitoring Setup (30 minutes)

**Step 5: Monitoring Configuration Generation**

```elixir
# lib/deployment_dsl/generators/monitoring.ex
defmodule DeploymentDsl.Generators.Monitoring do
  def generate_prometheus_config(applications, environment) do
    scrape_configs = 
      applications
      |> Enum.flat_map(fn app ->
        app.services
        |> Enum.map(fn service ->
          generate_service_scrape_config(app, service, environment)
        end)
      end)
    
    """
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
      external_labels:
        cluster: #{get_cluster(environment)}
        environment: #{environment}
    
    rule_files:
    - "alerts/*.yml"
    
    alerting:
      alertmanagers:
      - static_configs:
        - targets:
          - alertmanager:9093
    
    scrape_configs:
    #{Enum.join(scrape_configs, "\n")}
    
    # Infrastructure monitoring
    - job_name: 'kubernetes-nodes'
      kubernetes_sd_configs:
      - role: node
      relabel_configs:
      - source_labels: [__address__]
        regex: '(.*):10250'
        target_label: __address__
        replacement: '${1}:9100'
    
    - job_name: 'kubernetes-pods'
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
    """
  end
  
  defp generate_service_scrape_config(app, service, environment) do
    """
    - job_name: '#{app.name}-#{service.name}'
      kubernetes_sd_configs:
      - role: pod
        namespaces:
          names:
          - #{get_namespace(environment)}
      relabel_configs:
      - source_labels: [__meta_kubernetes_pod_label_app]
        action: keep
        regex: #{app.name}
      - source_labels: [__meta_kubernetes_pod_label_service]
        action: keep
        regex: #{service.name}
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        target_label: __address__
        regex: ([^:]+)(?::[0-9]+)?;([0-9]+)
        replacement: $1:$2
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'go_.*'
        action: drop
    """
  end
  
  def generate_grafana_dashboard(applications) do
    panels = 
      applications
      |> Enum.with_index()
      |> Enum.flat_map(fn {app, app_index} ->
        app.services
        |> Enum.with_index()
        |> Enum.flat_map(fn {service, service_index} ->
          y_offset = (app_index * 2 + service_index) * 8
          generate_service_panels(app, service, y_offset)
        end)
      end)
    
    %{
      dashboard: %{
        id: nil,
        title: "Application Overview",
        tags: ["applications", "microservices"],
        timezone: "browser",
        panels: panels,
        time: %{
          from: "now-1h",
          to: "now"
        },
        refresh: "30s",
        templating: %{
          list: [
            %{
              name: "environment",
              type: "custom",
              options: ["development", "staging", "production"],
              current: %{value: "production", text: "production"}
            },
            %{
              name: "application",
              type: "query",
              query: "label_values(up{environment=\"$environment\"}, app)",
              current: %{value: "all", text: "All"}
            }
          ]
        }
      }
    }
    |> Jason.encode!(pretty: true)
  end
  
  defp generate_service_panels(app, service, y_offset) do
    panel_id_base = String.to_integer("#{String.to_charlist(to_string(app.name)) |> Enum.sum()}#{String.to_charlist(to_string(service.name)) |> Enum.sum()}")
    
    [
      # Request Rate Panel
      %{
        id: panel_id_base + 1,
        title: "#{app.name}/#{service.name} - Request Rate",
        type: "graph",
        gridPos: %{h: 8, w: 8, x: 0, y: y_offset},
        targets: [
          %{
            expr: "sum(rate(http_requests_total{app=\"#{app.name}\",service=\"#{service.name}\",environment=\"$environment\"}[5m])) by (method, status)",
            legendFormat: "{{method}} {{status}}",
            refId: "A"
          }
        ],
        yAxes: [
          %{unit: "reqps", label: "Requests/sec"},
          %{show: false}
        ],
        legend: %{show: true, rightSide: false}
      },
      
      # Response Time Panel
      %{
        id: panel_id_base + 2,
        title: "#{app.name}/#{service.name} - Response Time",
        type: "graph",
        gridPos: %{h: 8, w: 8, x: 8, y: y_offset},
        targets: [
          %{
            expr: "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{app=\"#{app.name}\",service=\"#{service.name}\",environment=\"$environment\"}[5m])) by (le))",
            legendFormat: "95th percentile",
            refId: "A"
          },
          %{
            expr: "histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket{app=\"#{app.name}\",service=\"#{service.name}\",environment=\"$environment\"}[5m])) by (le))",
            legendFormat: "50th percentile",
            refId: "B"
          }
        ],
        yAxes: [
          %{unit: "s", label: "Response Time"},
          %{show: false}
        ]
      },
      
      # Error Rate Panel
      %{
        id: panel_id_base + 3,
        title: "#{app.name}/#{service.name} - Error Rate",
        type: "singlestat",
        gridPos: %{h: 4, w: 4, x: 16, y: y_offset},
        targets: [
          %{
            expr: "sum(rate(http_requests_total{app=\"#{app.name}\",service=\"#{service.name}\",environment=\"$environment\",status=~\"5..\"}[5m])) / sum(rate(http_requests_total{app=\"#{app.name}\",service=\"#{service.name}\",environment=\"$environment\"}[5m])) * 100",
            refId: "A"
          }
        ],
        format: "percent",
        colorBackground: true,
        thresholds: "1,5",
        colors: ["green", "yellow", "red"]
      },
      
      # CPU Usage Panel
      %{
        id: panel_id_base + 4,
        title: "#{app.name}/#{service.name} - CPU Usage",
        type: "singlestat",
        gridPos: %{h: 4, w: 4, x: 20, y: y_offset},
        targets: [
          %{
            expr: "avg(rate(container_cpu_usage_seconds_total{pod=~\"#{app.name}-#{service.name}.*\",environment=\"$environment\"}[5m])) * 100",
            refId: "A"
          }
        ],
        format: "percent",
        colorBackground: true,
        thresholds: "70,90",
        colors: ["green", "yellow", "red"]
      }
    ]
  end
  
  def generate_alerting_rules(applications) do
    rules = 
      applications
      |> Enum.flat_map(fn app ->
        app.services
        |> Enum.flat_map(fn service ->
          generate_service_alerts(app, service)
        end)
      end)
    
    """
    groups:
    - name: application_alerts
      rules:
      #{Enum.join(rules, "\n")}
    """
  end
  
  defp generate_service_alerts(app, service) do
    service_identifier = "#{app.name}/#{service.name}"
    
    [
      # High Error Rate Alert
      """
      - alert: #{sanitize_alert_name(app.name)}_#{sanitize_alert_name(service.name)}_HighErrorRate
        expr: |
          (
            sum(rate(http_requests_total{app="#{app.name}",service="#{service.name}",status=~"5.."}[5m])) /
            sum(rate(http_requests_total{app="#{app.name}",service="#{service.name}"}[5m]))
          ) * 100 > 5
        for: 2m
        labels:
          severity: warning
          app: #{app.name}
          service: #{service.name}
          team: #{app.team}
        annotations:
          summary: "High error rate for #{service_identifier}"
          description: "#{service_identifier} has error rate {{ $value | humanize }}% for more than 2 minutes"
          runbook_url: "https://runbooks.mycompany.com/#{app.name}/#{service.name}/high-error-rate"
      """,
      
      # High Response Time Alert  
      """
      - alert: #{sanitize_alert_name(app.name)}_#{sanitize_alert_name(service.name)}_HighResponseTime
        expr: |
          histogram_quantile(0.95, 
            sum(rate(http_request_duration_seconds_bucket{app="#{app.name}",service="#{service.name}"}[5m])) by (le)
          ) > #{get_response_time_threshold(service)}
        for: 5m
        labels:
          severity: warning
          app: #{app.name}
          service: #{service.name}
          team: #{app.team}
        annotations:
          summary: "High response time for #{service_identifier}"
          description: "#{service_identifier} 95th percentile response time is {{ $value | humanize }}s"
          runbook_url: "https://runbooks.mycompany.com/#{app.name}/#{service.name}/high-response-time"
      """,
      
      # Service Down Alert
      """
      - alert: #{sanitize_alert_name(app.name)}_#{sanitize_alert_name(service.name)}_ServiceDown
        expr: up{app="#{app.name}",service="#{service.name}"} == 0
        for: 1m
        labels:
          severity: critical
          app: #{app.name}
          service: #{service.name}
          team: #{app.team}
        annotations:
          summary: "#{service_identifier} is down"
          description: "#{service_identifier} has been down for more than 1 minute"
          runbook_url: "https://runbooks.mycompany.com/#{app.name}/#{service.name}/service-down"
      """,
      
      # High CPU Usage Alert
      """
      - alert: #{sanitize_alert_name(app.name)}_#{sanitize_alert_name(service.name)}_HighCPU
        expr: |
          avg(rate(container_cpu_usage_seconds_total{pod=~"#{app.name}-#{service.name}.*"}[5m])) * 100 > #{service.scaling.cpu_threshold}
        for: 10m
        labels:
          severity: warning
          app: #{app.name}
          service: #{service.name}
          team: #{app.team}
        annotations:
          summary: "High CPU usage for #{service_identifier}"
          description: "#{service_identifier} CPU usage is {{ $value | humanize }}%"
          runbook_url: "https://runbooks.mycompany.com/#{app.name}/#{service.name}/high-cpu"
      """
    ]
  end
  
  defp sanitize_alert_name(name) do
    name
    |> to_string()
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
  end
  
  defp get_response_time_threshold(service) do
    # Default to 1 second, could be configurable per service
    service.performance_thresholds[:response_time_p95] || 1.0
  end
end
```

#### Operational Dashboards (30 minutes)

**Step 6: Complete Operational Setup**

```elixir
# lib/deployment_dsl/generators/operations.ex
defmodule DeploymentDsl.Generators.Operations do
  def generate_runbook_index(applications) do
    """
    # Runbook Index
    
    ## Applications
    
    #{generate_app_runbook_links(applications)}
    
    ## Common Procedures
    
    - [Emergency Response](./common/emergency-response.md)
    - [Incident Management](./common/incident-management.md)
    - [Deployment Rollback](./common/deployment-rollback.md)
    - [Database Recovery](./common/database-recovery.md)
    - [Security Incident Response](./common/security-incident.md)
    
    ## Escalation Contacts
    
    #{generate_escalation_contacts(applications)}
    """
  end
  
  defp generate_app_runbook_links(applications) do
    applications
    |> Enum.map(fn app ->
      """
      ### #{app.name}
      - **Team**: #{app.team}
      - **Slack**: #{app.slack_channel}
      - **Repository**: #{app.repository}
      
      **Service Runbooks**:
      #{Enum.map(app.services, fn service ->
        "- [#{service.name}](./#{app.name}/#{service.name}/README.md)"
      end) |> Enum.join("\n")}
      """
    end)
    |> Enum.join("\n\n")
  end
  
  def generate_service_runbook(app, service) do
    """
    # #{app.name}/#{service.name} Runbook
    
    ## Service Overview
    
    - **Application**: #{app.name}
    - **Service**: #{service.name}
    - **Team**: #{app.team}
    - **Slack**: #{app.slack_channel}
    - **Repository**: #{app.repository}
    
    ## Architecture
    
    - **Port**: #{service.port}
    - **Dependencies**: #{inspect(service.dependencies)}
    - **Resource Limits**: 
      - CPU: #{service.resource_limits.cpu_request} - #{service.resource_limits.cpu_limit}
      - Memory: #{service.resource_limits.memory_request} - #{service.resource_limits.memory_limit}
    
    ## Health Checks
    
    - **Health Endpoint**: #{service.health_check.path}
    - **Readiness**: #{service.health_check.path}
    
    ## Common Issues
    
    ### High Error Rate
    
    **Symptoms**: Error rate above 5%
    **Causes**: 
    - Database connection issues
    - Downstream service failures
    - Invalid input data
    
    **Investigation Steps**:
    1. Check service logs: `kubectl logs -l app=#{app.name},service=#{service.name} -n production --tail=100`
    2. Check dependencies health
    3. Review recent deployments
    4. Check database connection pool
    
    **Resolution**:
    - If database issue: Check connection strings and pool settings
    - If downstream issue: Contact owning team via #{app.slack_channel}
    - If recent deployment: Consider rollback
    
    ### High Response Time
    
    **Symptoms**: 95th percentile response time > #{get_response_time_threshold(service)}s
    **Causes**:
    - High CPU/memory usage
    - Database slow queries
    - Network latency
    
    **Investigation Steps**:
    1. Check resource usage metrics
    2. Review database query performance
    3. Check network connectivity
    4. Review application performance metrics
    
    **Resolution**:
    - Scale up if CPU/memory constrained
    - Optimize slow queries
    - Contact platform team for network issues
    
    ### Service Down
    
    **Symptoms**: Service not responding to health checks
    **Immediate Actions**:
    1. Check pod status: `kubectl get pods -l app=#{app.name},service=#{service.name} -n production`
    2. Check recent events: `kubectl get events -n production --sort-by='.lastTimestamp' | grep #{service.name}`
    3. Check logs: `kubectl logs -l app=#{app.name},service=#{service.name} -n production --tail=50`
    
    **Resolution Steps**:
    1. If pods are crashing: Check application logs for errors
    2. If pods are pending: Check resource availability
    3. If networking issue: Contact platform team
    4. If data corruption: Initiate data recovery procedure
    
    ## Deployment Procedures
    
    ### Normal Deployment
    #{generate_deployment_procedure(app, service)}
    
    ### Emergency Rollback
    ```bash
    # Get current deployment
    kubectl get deployment #{app.name}-#{service.name} -n production -o yaml > current-deployment.yaml
    
    # Get previous revision
    kubectl rollout history deployment/#{app.name}-#{service.name} -n production
    
    # Rollback to previous version
    kubectl rollout undo deployment/#{app.name}-#{service.name} -n production
    
    # Verify rollback
    kubectl rollout status deployment/#{app.name}-#{service.name} -n production
    ```
    
    ## Monitoring
    
    - **Grafana Dashboard**: [#{app.name}/#{service.name} Dashboard](https://grafana.mycompany.com/d/#{app.name}-#{service.name})
    - **Logs**: [#{app.name}/#{service.name} Logs](https://logs.mycompany.com/app/#{app.name}/service/#{service.name})
    - **Traces**: [#{app.name}/#{service.name} Traces](https://jaeger.mycompany.com/search?service=#{app.name}-#{service.name})
    
    ## Escalation
    
    1. **First Response**: #{app.team} team via #{app.slack_channel}
    2. **After Hours**: On-call engineer via PagerDuty
    3. **Critical Issues**: Tech Lead + Platform Team
    4. **Security Issues**: Security team via #security-incidents
    
    ## Related Documentation
    
    - [Application Architecture](#{app.repository}/docs/architecture.md)
    - [API Documentation](#{app.repository}/docs/api.md)
    - [Database Schema](#{app.repository}/docs/database.md)
    - [Configuration Guide](#{app.repository}/docs/configuration.md)
    """
  end
  
  def generate_deployment_checklist(app) do
    """
    # #{app.name} Deployment Checklist
    
    ## Pre-Deployment
    
    - [ ] All tests passing in CI
    - [ ] Security scan completed successfully  
    - [ ] Performance tests completed
    - [ ] Database migrations reviewed (if any)
    - [ ] Configuration changes reviewed
    - [ ] Dependency updates reviewed
    - [ ] Team notified of deployment
    
    ## Deployment Validation
    
    #{generate_validation_steps(app)}
    
    ## Post-Deployment
    
    - [ ] Health checks passing
    - [ ] Metrics look normal
    - [ ] Error rates within SLA
    - [ ] Response times within SLA
    - [ ] No alerts firing
    - [ ] Smoke tests completed
    - [ ] Team notified of completion
    
    ## Rollback Criteria
    
    Rollback immediately if:
    - [ ] Error rate > 10% for 5 minutes
    - [ ] Critical functionality broken
    - [ ] Security vulnerability detected
    - [ ] Data corruption detected
    - [ ] Performance degradation > 50%
    
    ## Emergency Contacts
    
    - **Team Lead**: Contact via #{app.slack_channel}
    - **On-Call**: PagerDuty escalation
    - **Platform Team**: #platform-team
    - **Security Team**: #security-incidents
    """
  end
end
```

### Lab Review and Production Readiness Discussion (4:45-5:00)

#### Demonstration and Validation (10 minutes)

**Each team demonstrates:**
- Their complete deployment pipeline in action
- Generated Kubernetes manifests and CI/CD configuration
- Monitoring dashboard with real metrics
- One advanced operational feature (runbooks, alerting, etc.)

#### Production Readiness Assessment (5 minutes)

**Key Production Criteria:**
1. **Reliability**: Health checks, circuit breakers, graceful degradation
2. **Observability**: Metrics, logging, tracing, alerting
3. **Security**: TLS, secrets management, vulnerability scanning
4. **Scalability**: Auto-scaling, resource limits, performance testing
5. **Operability**: Runbooks, incident response, rollback procedures

---

## Evening Wrap-up (5:00-6:00)

### Individual Reflection (5:00-5:15)

**Journal about production readiness insights:**
1. What was the most challenging aspect of making DSLs production-ready?
2. How did automation change your thinking about deployment processes?
3. Which monitoring and observability patterns were most valuable?
4. What would you do differently in your production architecture?
5. How do you see DSLs transforming operational practices?

### Team Presentations (5:15-5:45)

**5-minute presentations per team:**
- Demo your complete deployment pipeline
- Explain your most innovative operational pattern
- Share your biggest production challenge and solution
- Describe the operational benefits of your DSL approach

### Tomorrow's Preview (5:45-6:00)

**Day 5: AI Integration and Future Possibilities**

Tomorrow we explore the cutting edge:
- **AI-enhanced DSL development** with LLM integration
- **Natural language to DSL generation** capabilities
- **Intelligent code completion** and suggestions
- **Future possibilities** for DSL evolution
- **Building the next generation** of development tools

**Tonight's Assignment:**
1. **Reading**: "AI Integration" chapter
2. **Experimentation**: Try using AI tools to generate DSL code
3. **Vision thinking**: What would the perfect AI-assisted DSL experience look like?

---

## Day 4 Success Criteria

You've mastered Day 4 if you can:

- [ ] **Deploy DSL-driven applications** to production environments
- [ ] **Generate complete infrastructure configurations** from DSL definitions
- [ ] **Build automated CI/CD pipelines** with DSL integration
- [ ] **Implement comprehensive monitoring** and alerting
- [ ] **Create operational runbooks** and incident response procedures
- [ ] **Apply production readiness principles** to DSL systems
- [ ] **Think operationally** about DSL lifecycle management

### Key Insights to Remember

**Production Readiness:**
- DSLs must generate complete operational configurations, not just application code
- Monitoring and observability are essential from day one
- Automation reduces errors and improves consistency

**Operational Excellence:**
- DSL-generated infrastructure ensures consistency across environments
- Automated deployments enable reliable, repeatable releases
- Comprehensive monitoring enables proactive issue resolution

**Business Value:**
- Reduced time to production through automation
- Improved reliability through standardization
- Enhanced team productivity through operational consistency

Tomorrow we explore how AI will transform DSL development, making sophisticated language creation accessible to even more developers. The production patterns you've mastered today become the foundation for AI-enhanced development workflows.

**Exceptional production engineering work today! You're ready to operate DSL systems at scale.** 🚀