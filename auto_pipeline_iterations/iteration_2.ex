defmodule AutoPipeline.Iterations.ExternalIntegration do
  @moduledoc """
  Integration with External Services and APIs

  This iteration demonstrates sophisticated integration patterns with external services,
  APIs, and third-party tools to create comprehensive development pipelines.

  MCP Mode: database
  Collaboration: community
  """

  use Spark.Dsl, default_extensions: [extensions: [AutoPipeline.Dsl]]

  pipeline_configuration do
    configuration :api_integrated do
      max_parallel(8)
      quality_threshold(90)
      timeout_multiplier(2.0)
      memory_limit(12288)
      enable_optimizations(true)

      # External service configuration
      external_service_timeout(45_000)
      api_retry_strategy(:exponential_backoff)
      circuit_breaker_enabled(true)
      service_discovery_enabled(true)
    end
  end

  pipeline_tasks do
    # GitHub integration for PR analysis
    task :github_pr_analysis do
      description("Analyze GitHub PR with advanced metrics")
      command("gh pr view --json && gh pr checks --format json")
      timeout(60_000)
      parallel(true)
      external_dependencies([:github_api])

      api_integrations(%{
        github: %{
          endpoints: ["pr_details", "check_runs", "reviews"],
          rate_limit_aware: true,
          caching_ttl: 300
        }
      })

      condition("System.get_env('GITHUB_TOKEN') != nil")
    end

    # Docker registry integration
    task :docker_integration do
      description("Build and push to Docker registry with vulnerability scanning")
      command("docker build -t app:latest . && docker push app:latest && docker scout quickview")
      depends_on([:compile_with_tests])
      timeout(180_000)
      parallel(false)
      external_dependencies([:docker_registry, :docker_scout])

      resource_requirements(%{
        disk_space_mb: 4096,
        network_bandwidth: :high
      })
    end

    # Kubernetes deployment validation
    task :k8s_validation do
      description("Validate Kubernetes manifests and deploy to staging")

      command(
        "kubectl apply --dry-run=client -f k8s/ && kubectl apply -f k8s/ --namespace=staging"
      )

      depends_on([:docker_integration])
      timeout(120_000)
      parallel(false)
      external_dependencies([:kubernetes_api])

      api_integrations(%{
        kubernetes: %{
          endpoints: ["apply", "validate", "status"],
          namespace: "staging",
          rollback_on_failure: true
        }
      })
    end

    # Database migration with external validation
    task :database_migration_with_validation do
      description("Run database migrations with external validation service")
      command("mix ecto.migrate && curl -X POST http://validator-service/validate-schema")
      depends_on([:compile_with_tests])
      timeout(90_000)
      parallel(false)
      external_dependencies([:database, :schema_validator_api])

      api_integrations(%{
        schema_validator: %{
          endpoint: "http://validator-service/validate-schema",
          method: :post,
          retry_count: 3,
          validation_timeout: 30_000
        }
      })
    end

    # Security scanning with multiple services
    task :multi_security_scan do
      description("Comprehensive security scanning with multiple external services")
      command("mix deps.audit && bandit -r . && snyk test --json")
      depends_on([:compile_with_tests])
      timeout(150_000)
      parallel(true)
      external_dependencies([:snyk_api, :bandit_service])

      api_integrations(%{
        snyk: %{
          endpoints: ["test", "monitor"],
          authentication: :token,
          report_format: :json
        },
        sonarqube: %{
          endpoint: "http://sonar:9000/api/project_analyses/search",
          quality_gate_check: true
        }
      })
    end

    # Performance monitoring integration
    task :apm_integration do
      description("Integrate with Application Performance Monitoring services")
      command("mix profile.eprof && curl -X POST http://apm-service/metrics")
      depends_on([:compile_with_tests])
      timeout(120_000)
      parallel(true)
      external_dependencies([:apm_service, :metrics_collector])

      api_integrations(%{
        newrelic: %{
          endpoints: ["deployments", "metrics"],
          api_key_env: "NEWRELIC_API_KEY"
        },
        datadog: %{
          endpoints: ["metrics", "events"],
          tags: ["environment:ci", "service:autopipeline"]
        }
      })
    end

    # Slack notification with rich formatting
    task :slack_notification do
      description("Send detailed pipeline results to Slack with rich formatting")
      command("mix pipeline.report --format slack && curl -X POST $SLACK_WEBHOOK")
      depends_on([:multi_security_scan, :apm_integration, :k8s_validation])
      timeout(30_000)
      parallel(false)
      external_dependencies([:slack_api])

      api_integrations(%{
        slack: %{
          webhook_env: "SLACK_WEBHOOK",
          rich_formatting: true,
          thread_replies: true,
          attachment_support: true
        }
      })

      final_notification(true)
    end

    # Compilation task for dependencies
    task :compile_with_tests do
      description("Compile application with test dependencies")
      command("mix deps.get && mix compile --force && mix test --compile")
      timeout(180_000)
      parallel(false)
      priority(:highest)
    end
  end

  # MCP Integration for External Services
  mcp_integration do
    api_gateway :external_services do
      base_url("https://api-gateway.pipeline-services.io")
      authentication(:oauth2)

      rate_limiting(%{
        requests_per_minute: 1000,
        burst_allowance: 50
      })

      service_discovery(true)
    end

    database_connector :integration_logs do
      connection_string("postgresql://localhost/integration_logs")
      tables([:api_calls, :service_responses, :error_logs, :performance_metrics])
      connection_pooling(true)
    end

    community_insights :integration_patterns do
      share_patterns([:successful_integrations, :common_failures, :performance_benchmarks])
      collaborative_debugging(true)
      pattern_recommendations(true)
    end
  end

  # Circuit breaker configuration for external services
  circuit_breaker do
    service :github_api do
      failure_threshold(5)
      recovery_timeout(60_000)
      half_open_max_calls(3)
    end

    service :docker_registry do
      failure_threshold(3)
      recovery_timeout(120_000)
      half_open_max_calls(1)
    end

    service :kubernetes_api do
      failure_threshold(2)
      recovery_timeout(180_000)
      half_open_max_calls(2)
    end
  end
end
