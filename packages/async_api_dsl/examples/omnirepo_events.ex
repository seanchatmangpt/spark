defmodule OmniRepo.Events.Api do
  @moduledoc """
  OmniRepo event system definition using AsyncAPI with polyglot code generation.
  
  This module defines the complete event architecture for OmniRepo, a polyglot
  repository management system. It automatically generates high-performance
  clients in Rust, Python, Elixir, and TypeScript.
  """
  
  use AsyncApiPolyglot

  # Root-level configuration
  id "urn:com:omnirepo:events"
  default_content_type "application/capnproto"

  info do
    title "OmniRepo Events API"
    version "1.0.0"
    description """
    High-performance event system for OmniRepo - a polyglot repository management platform.
    
    This API enables real-time communication between Rust indexing engines, Python analysis
    pipelines, Elixir web services, and TypeScript frontends with sub-millisecond latency
    and zero-copy serialization.
    """
    
    contact do
      name "OmniRepo Team"
      url "https://omnirepo.dev/support"
      email "events@omnirepo.dev"
    end
    
    license do
      name "MIT"
      url "https://opensource.org/licenses/MIT"
    end
  end

  servers do
    server :production, "nats://events.omnirepo.prod:4222" do
      protocol :nats
      description "Production NATS cluster with JetStream persistence"
      
      variables do
        variable :region do
          default "us-west-2"
          description "AWS region for the NATS cluster"
          enum ["us-west-2", "us-east-1", "eu-west-1"]
        end
      end
    end
    
    server :staging, "nats://events.omnirepo.staging:4222" do
      protocol :nats
      description "Staging NATS server for development and testing"
    end
    
    server :development, "nats://localhost:4222" do
      protocol :nats
      description "Local NATS server for development"
    end
  end

  channels do
    channel "repositories.{repoId}.indexed" do
      description "Repository indexing completion events"
      
      parameters do
        parameter :repoId do
          description "Repository identifier"
          schema do
            type :string
            pattern "^[a-zA-Z0-9_-]+$"
          end
        end
      end
    end
    
    channel "repositories.{repoId}.analysis" do
      description "Code analysis results and metrics"
      
      parameters do
        parameter :repoId do
          description "Repository identifier"
          schema do
            type :string
            pattern "^[a-zA-Z0-9_-]+$"
          end
        end
      end
    end
    
    channel "repositories.{repoId}.changes" do
      description "Real-time file and dependency changes"
      
      parameters do
        parameter :repoId do
          description "Repository identifier"
          schema do
            type :string
            pattern "^[a-zA-Z0-9_-]+$"
          end
        end
      end
    end
    
    channel "metrics.performance" do
      description "High-frequency performance metrics stream"
    end
    
    channel "metrics.usage" do
      description "Usage analytics and user behavior metrics"
    end
    
    channel "system.alerts" do
      description "System-wide alerts and notifications"
    end
    
    channel "search.queries" do
      description "Search query logs and results"
    end
  end

  operations do
    # Repository indexing operations
    operation :publishRepositoryIndexed do
      action :send
      channel "repositories.{repoId}.indexed"
      summary "Notify that repository indexing is complete"
      description "Published by Rust indexing engine when a repository has been fully indexed"
      
      message :repositoryIndexed
    end
    
    operation :receiveRepositoryIndexed do
      action :receive
      channel "repositories.{repoId}.indexed"
      summary "Listen for repository indexing completion"
      description "Subscribed by web services to update UI and trigger analysis"
      
      message :repositoryIndexed
    end
    
    # Code analysis operations
    operation :publishAnalysisResults do
      action :send
      channel "repositories.{repoId}.analysis"
      summary "Publish code analysis results"
      description "Published by Python analysis pipeline with metrics and insights"
      
      message :analysisResults
    end
    
    operation :receiveAnalysisResults do
      action :receive
      channel "repositories.{repoId}.analysis"
      summary "Listen for analysis results"
      description "Subscribed by frontend to display code quality metrics"
      
      message :analysisResults
    end
    
    # Change tracking operations
    operation :publishFileChanges do
      action :send
      channel "repositories.{repoId}.changes"
      summary "Publish file change events"
      description "Real-time file modifications and dependency updates"
      
      message :fileChanges
    end
    
    operation :receiveFileChanges do
      action :receive
      channel "repositories.{repoId}.changes"
      summary "Listen for file changes"
      description "Real-time updates for live editing and collaboration"
      
      message :fileChanges
    end
    
    # Performance metrics operations
    operation :publishPerformanceMetrics do
      action :send
      channel "metrics.performance"
      summary "Publish performance metrics"
      description "High-frequency metrics from all system components"
      
      message :performanceMetrics
    end
    
    operation :receivePerformanceMetrics do
      action :receive
      channel "metrics.performance"
      summary "Listen for performance metrics"
      description "Monitoring dashboard and alerting subscriptions"
      
      message :performanceMetrics
    end
    
    # Search operations
    operation :publishSearchQuery do
      action :send
      channel "search.queries"
      summary "Log search queries"
      description "Track search patterns for optimization and analytics"
      
      message :searchQuery
    end
    
    operation :receiveSearchQuery do
      action :receive
      channel "search.queries"
      summary "Process search queries"
      description "Analytics pipeline for search optimization"
      
      message :searchQuery
    end
  end

  components do
    messages do
      message :repositoryIndexed do
        title "Repository Indexed"
        summary "Repository indexing completion notification"
        payload :repositoryIndexedPayload
        
        correlation_id do
          description "Links indexing request to completion"
          location "$message.header#/correlationId"
        end
      end
      
      message :analysisResults do
        title "Analysis Results"
        summary "Code analysis and metrics results"
        payload :analysisResultsPayload
        
        correlation_id do
          description "Links analysis request to results"
          location "$message.header#/correlationId"
        end
      end
      
      message :fileChanges do
        title "File Changes"
        summary "Real-time file modification events"
        payload :fileChangesPayload
      end
      
      message :performanceMetrics do
        title "Performance Metrics"
        summary "System performance measurements"
        payload :performanceMetricsPayload
      end
      
      message :searchQuery do
        title "Search Query"
        summary "Search query logging event"
        payload :searchQueryPayload
      end
    end
    
    schemas do
      schema :repositoryIndexedPayload do
        type :object
        title "Repository Indexed Event"
        description "Payload for repository indexing completion events"
        
        property :repositoryId, :string do
          description "Unique repository identifier"
          pattern "^[a-zA-Z0-9_-]+$"
        end
        
        property :indexedAt, :string do
          description "Indexing completion timestamp"
          format "date-time"
        end
        
        property :statistics, :object do
          description "Indexing statistics and metrics"
          
          property :totalFiles, :integer do
            description "Total number of files indexed"
            minimum 0
          end
          
          property :totalSymbols, :integer do
            description "Total number of symbols indexed"
            minimum 0
          end
          
          property :languages, :array do
            description "Programming languages detected"
            items type: :string
          end
          
          property :indexSizeBytes, :integer do
            description "Size of generated index in bytes"
            minimum 0
          end
          
          property :dependencies, :array do
            description "External dependencies found"
            items type: :string
          end
          
          required [:totalFiles, :totalSymbols, :languages, :indexSizeBytes]
        end
        
        property :durationMs, :integer do
          description "Indexing duration in milliseconds"
          minimum 0
        end
        
        property :version, :string do
          description "Index schema version"
          pattern "^\\d+\\.\\d+\\.\\d+$"
        end
        
        property :errors, :array do
          description "Non-fatal errors encountered during indexing"
          items do
            type :object
            property :file, :string
            property :error, :string
            property :line, :integer
          end
        end
        
        required [:repositoryId, :indexedAt, :statistics, :durationMs, :version]
      end
      
      schema :analysisResultsPayload do
        type :object
        title "Analysis Results Event"
        description "Code analysis results and quality metrics"
        
        property :repositoryId, :string do
          description "Repository identifier"
          pattern "^[a-zA-Z0-9_-]+$"
        end
        
        property :analysisId, :string do
          description "Unique analysis run identifier"
          format "uuid"
        end
        
        property :analysisType, :string do
          description "Type of analysis performed"
          enum ["quality", "security", "performance", "dependencies", "complexity"]
        end
        
        property :results, :object do
          description "Analysis results by category"
          
          property :codeQuality, :object do
            description "Code quality metrics"
            
            property :score, :number do
              description "Overall quality score (0-100)"
              minimum 0
              maximum 100
            end
            
            property :maintainabilityIndex, :number do
              description "Maintainability index"
              minimum 0
              maximum 100
            end
            
            property :technicalDebt, :object do
              description "Technical debt measurements"
              
              property :hours, :number do
                description "Estimated hours to fix technical debt"
                minimum 0
              end
              
              property :rating, :string do
                description "Technical debt rating"
                enum ["A", "B", "C", "D", "E"]
              end
            end
          end
          
          property :security, :object do
            description "Security analysis results"
            
            property :vulnerabilities, :array do
              description "Security vulnerabilities found"
              items do
                type :object
                property :severity, :string, enum: ["low", "medium", "high", "critical"]
                property :type, :string
                property :file, :string
                property :line, :integer
                property :description, :string
              end
            end
            
            property :securityScore, :number do
              description "Security score (0-100)"
              minimum 0
              maximum 100
            end
          end
          
          property :performance, :object do
            description "Performance analysis results"
            
            property :hotspots, :array do
              description "Performance hotspots identified"
              items do
                type :object
                property :function, :string
                property :file, :string
                property :estimatedImpact, :string, enum: ["low", "medium", "high"]
                property :suggestions, :array, items: type: :string
              end
            end
          end
        end
        
        property :completedAt, :string do
          description "Analysis completion timestamp"
          format "date-time"
        end
        
        property :durationMs, :integer do
          description "Analysis duration in milliseconds"
          minimum 0
        end
        
        required [:repositoryId, :analysisId, :analysisType, :results, :completedAt, :durationMs]
      end
      
      schema :fileChangesPayload do
        type :object
        title "File Changes Event"
        description "Real-time file modification events"
        
        property :repositoryId, :string do
          description "Repository identifier"
          pattern "^[a-zA-Z0-9_-]+$"
        end
        
        property :changeId, :string do
          description "Unique change identifier"
          format "uuid"
        end
        
        property :changeType, :string do
          description "Type of change"
          enum ["created", "modified", "deleted", "renamed", "moved"]
        end
        
        property :files, :array do
          description "Files affected by this change"
          items do
            type :object
            property :path, :string
            property :oldPath, :string
            property :changeType, :string, enum: ["created", "modified", "deleted", "renamed"]
            property :linesAdded, :integer, minimum: 0
            property :linesRemoved, :integer, minimum: 0
            property :language, :string
          end
        end
        
        property :author, :object do
          description "Change author information"
          
          property :userId, :string
          property :email, :string, format: "email"
          property :name, :string
        end
        
        property :timestamp, :string do
          description "Change timestamp"
          format "date-time"
        end
        
        property :commitHash, :string do
          description "Git commit hash if applicable"
          pattern "^[a-f0-9]{40}$"
        end
        
        property :branch, :string do
          description "Git branch name"
        end
        
        required [:repositoryId, :changeId, :changeType, :files, :timestamp]
      end
      
      schema :performanceMetricsPayload do
        type :object
        title "Performance Metrics Event"
        description "High-frequency system performance metrics"
        
        property :source, :string do
          description "Metrics source component"
          enum ["indexer", "analyzer", "web-server", "search-engine", "database"]
        end
        
        property :timestamp, :string do
          description "Metrics timestamp"
          format "date-time"
        end
        
        property :metrics, :object do
          description "Performance metrics by category"
          
          property :cpu, :object do
            description "CPU utilization metrics"
            
            property :usagePercent, :number do
              description "CPU usage percentage"
              minimum 0
              maximum 100
            end
            
            property :loadAverage, :array do
              description "System load averages [1m, 5m, 15m]"
              items type: :number, minimum: 0
            end
          end
          
          property :memory, :object do
            description "Memory utilization metrics"
            
            property :usedBytes, :integer do
              description "Used memory in bytes"
              minimum 0
            end
            
            property :totalBytes, :integer do
              description "Total memory in bytes"
              minimum 0
            end
            
            property :usagePercent, :number do
              description "Memory usage percentage"
              minimum 0
              maximum 100
            end
          end
          
          property :operations, :object do
            description "Operation-specific metrics"
            
            property :requestsPerSecond, :number do
              description "Requests handled per second"
              minimum 0
            end
            
            property :avgResponseTimeMs, :number do
              description "Average response time in milliseconds"
              minimum 0
            end
            
            property :errorRate, :number do
              description "Error rate percentage"
              minimum 0
              maximum 100
            end
          end
          
          property :storage, :object do
            description "Storage I/O metrics"
            
            property :readBytesPerSec, :integer do
              description "Bytes read per second"
              minimum 0
            end
            
            property :writeBytesPerSec, :integer do
              description "Bytes written per second"
              minimum 0
            end
            
            property :iopsRead, :integer do
              description "Read operations per second"
              minimum 0
            end
            
            property :iopsWrite, :integer do
              description "Write operations per second"
              minimum 0
            end
          end
        end
        
        required [:source, :timestamp, :metrics]
      end
      
      schema :searchQueryPayload do
        type :object
        title "Search Query Event"
        description "Search query logging and analytics"
        
        property :queryId, :string do
          description "Unique query identifier"
          format "uuid"
        end
        
        property :query, :string do
          description "Search query text"
          min_length 1
          max_length 1000
        end
        
        property :filters, :object do
          description "Applied search filters"
          
          property :languages, :array do
            description "Programming language filters"
            items type: :string
          end
          
          property :fileTypes, :array do
            description "File type filters"
            items type: :string
          end
          
          property :repositories, :array do
            description "Repository filters"
            items type: :string
          end
          
          property :dateRange, :object do
            description "Date range filter"
            
            property :from, :string, format: "date-time"
            property :to, :string, format: "date-time"
          end
        end
        
        property :results, :object do
          description "Search results summary"
          
          property :totalResults, :integer do
            description "Total number of results found"
            minimum 0
          end
          
          property :executionTimeMs, :number do
            description "Query execution time in milliseconds"
            minimum 0
          end
          
          property :resultTypes, :object do
            description "Results by type"
            
            property :files, :integer, minimum: 0
            property :symbols, :integer, minimum: 0
            property :comments, :integer, minimum: 0
            property :documentation, :integer, minimum: 0
          end
        end
        
        property :user, :object do
          description "User context"
          
          property :userId, :string
          property :sessionId, :string
          property :ipAddress, :string
        end
        
        property :timestamp, :string do
          description "Query timestamp"
          format "date-time"
        end
        
        required [:queryId, :query, :results, :timestamp]
      end
    end
    
    security_schemes do
      security_scheme :apiKey do
        type :apiKey
        name "X-API-Key"
        location :header
        description "API key for service-to-service authentication"
      end
      
      security_scheme :jwt do
        type :http
        scheme "bearer"
        bearer_format "JWT"
        description "JWT token for user authentication"
      end
    end
  end
end