defmodule UsageAnalyzerTest do
  use ExUnit.Case, async: false
  use UsageAnalyzer.DataCase

  import Mox
  setup :verify_on_exit!

  alias UsageAnalyzer.{
    Repo,
    Resources.AnalysisReport,
    Resources.PatternDetection,
    Workflows.ComprehensiveAnalysis
  }

  describe "UsageAnalyzer domain operations" do
    test "creates domain with proper resource configuration" do
      assert UsageAnalyzer.__domain__()
      
      resources = UsageAnalyzer.Info.resources()
      assert length(resources) == 4
      
      resource_names = Enum.map(resources, & &1.resource)
      assert UsageAnalyzer.Resources.AnalysisReport in resource_names
      assert UsageAnalyzer.Resources.PatternDetection in resource_names
      assert UsageAnalyzer.Resources.PerformanceMetric in resource_names
      assert UsageAnalyzer.Resources.UsageInsight in resource_names
    end

    test "has proper authorization configuration" do
      config = UsageAnalyzer.Info.authorization()
      assert config.authorize == :by_default
      refute config.require_actor?
    end

    test "validates all resources are accessible" do
      for resource <- UsageAnalyzer.Info.resources() do
        assert Code.ensure_loaded?(resource.resource)
        assert function_exported?(resource.resource, :spark_dsl_config, 0)
      end
    end
  end

  describe "Repo configuration" do
    test "has correct OTP app configuration" do
      assert UsageAnalyzer.Repo.__adapter__() == Ecto.Adapters.Postgres
    end

    test "has required extensions installed" do
      extensions = UsageAnalyzer.Repo.installed_extensions()
      assert "uuid-ossp" in extensions
      assert "citext" in extensions
    end

    test "can connect to database" do
      assert {:ok, _} = Repo.query("SELECT 1")
    end
  end

  describe "AnalysisReport resource operations" do
    test "creates analysis report with valid attributes" do
      attrs = %{
        target_dsl: "Ash e-commerce DSL with products, orders, and payments",
        analysis_type: :patterns,
        time_window: "7d",
        data_sources: [:git_commits, :issue_tracker, :performance_logs],
        analysis_depth: :deep,
        findings: %{
          common_patterns: ["CRUD operations", "validation patterns", "relationship patterns"],
          anti_patterns: ["over-normalization", "missing validations"],
          optimization_opportunities: ["index usage", "query optimization"]
        },
        recommendations: [
          "Add composite indexes for frequently queried fields",
          "Implement caching for read-heavy operations",
          "Consider pagination for large result sets"
        ],
        confidence: Decimal.new("0.85"),
        sample_size: 1500
      }

      assert {:ok, report} = 
        AnalysisReport
        |> Ash.Changeset.for_create(:create, attrs)
        |> UsageAnalyzer.create()

      assert report.target_dsl == attrs.target_dsl
      assert report.analysis_type == :patterns
      assert report.time_window == "7d"
      assert report.data_sources == [:git_commits, :issue_tracker, :performance_logs]
      assert report.analysis_depth == :deep
      assert report.status == :pending
      assert map_size(report.findings) > 0
      assert length(report.recommendations) == 3
      assert Decimal.equal?(report.confidence, Decimal.new("0.85"))
      assert is_binary(report.id)
    end

    test "validates required target_dsl attribute" do
      attrs = %{analysis_type: :patterns}

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        AnalysisReport
        |> Ash.Changeset.for_create(:create, attrs)
        |> UsageAnalyzer.create()

      assert Enum.any?(errors, fn error ->
        error.field == :target_dsl && error.message =~ "required"
      end)
    end

    test "validates analysis_type constraints" do
      attrs = %{
        target_dsl: "test dsl",
        analysis_type: :invalid_type
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        AnalysisReport
        |> Ash.Changeset.for_create(:create, attrs)
        |> UsageAnalyzer.create()

      assert Enum.any?(errors, fn error ->
        error.field == :analysis_type && error.message =~ "one_of"
      end)
    end

    test "validates confidence constraints" do
      attrs = %{
        target_dsl: "test dsl",
        analysis_type: :patterns,
        confidence: Decimal.new("1.5")
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        AnalysisReport
        |> Ash.Changeset.for_create(:create, attrs)
        |> UsageAnalyzer.create()

      assert Enum.any?(errors, fn error ->
        error.field == :confidence && error.message =~ "max"
      end)
    end

    test "validates analysis_depth and status constraints" do
      attrs = %{
        target_dsl: "test dsl",
        analysis_type: :patterns,
        analysis_depth: :invalid_depth,
        status: :invalid_status
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        AnalysisReport
        |> Ash.Changeset.for_create(:create, attrs)
        |> UsageAnalyzer.create()

      depth_error = Enum.find(errors, & &1.field == :analysis_depth)
      status_error = Enum.find(errors, & &1.field == :status)

      assert depth_error && depth_error.message =~ "one_of"
      assert status_error && status_error.message =~ "one_of"
    end

    test "analyze_dsl_usage action processes DSL correctly" do
      setup_usage_analysis_mocks()

      attrs = %{
        target_dsl: "Phoenix LiveView DSL with real-time features and form handling",
        analysis_type: :patterns,
        time_window: "14d",
        data_sources: [:git_commits, :performance_logs, :user_feedback],
        analysis_depth: :comprehensive
      }

      assert {:ok, report} =
        AnalysisReport
        |> Ash.Changeset.for_create(:analyze_dsl_usage, attrs)
        |> UsageAnalyzer.create()

      assert report.status == :analyzing
      assert report.data_sources == [:git_commits, :performance_logs, :user_feedback]
      assert report.analysis_depth == :comprehensive
    end

    test "introspect_ash_resource action analyzes resource structure" do
      # Create a mock Ash resource for testing
      defmodule TestResource do
        use Ash.Resource, 
          extensions: [AshPostgres.DataLayer],
          data_layer: AshPostgres.DataLayer

        attributes do
          uuid_primary_key :id
          attribute :name, :string, allow_nil?: false
          attribute :email, :string
          attribute :age, :integer
        end

        relationships do
          has_many :posts, TestPost
          belongs_to :organization, TestOrganization
        end

        actions do
          defaults [:create, :read, :update, :destroy]
          
          create :register do
            accept [:name, :email]
          end
          
          read :by_email do
            argument :email, :string, allow_nil?: false
          end
        end

        validations do
          validate present(:name)
          validate present(:email)
        end
      end

      setup_introspection_mocks()

      attrs = %{target_dsl: "TestResource introspection analysis"}

      assert {:ok, report} =
        AnalysisReport
        |> Ash.Changeset.for_create(:introspect_ash_resource, attrs)
        |> Ash.Changeset.set_argument(:resource_module, TestResource)
        |> UsageAnalyzer.create()

      assert report.analysis_type == :introspection
      assert report.target_dsl == "TestResource introspection analysis"
    end

    test "complete_analysis updates report with final results" do
      report = create_test_analysis_report(%{status: :analyzing})

      completion_data = %{
        findings: %{
          patterns_discovered: 15,
          anti_patterns_found: 3,
          performance_bottlenecks: 2,
          optimization_opportunities: 8
        },
        recommendations: [
          "Implement connection pooling for database operations",
          "Add caching layer for frequently accessed data",
          "Optimize complex queries with proper indexing",
          "Consider using GenStage for data processing pipelines"
        ],
        confidence: Decimal.new("0.92"),
        sample_size: 2500
      }

      assert {:ok, completed_report} =
        report
        |> Ash.Changeset.for_update(:complete_analysis, completion_data)
        |> UsageAnalyzer.update()

      assert completed_report.status == :completed
      assert completed_report.findings["patterns_discovered"] == 15
      assert length(completed_report.recommendations) == 4
      assert Decimal.equal?(completed_report.confidence, Decimal.new("0.92"))
      assert completed_report.sample_size == 2500
    end

    test "mark_failed updates status and logs error" do
      report = create_test_analysis_report(%{status: :analyzing})

      assert {:ok, failed_report} =
        report
        |> Ash.Changeset.for_update(:mark_failed)
        |> Ash.Changeset.set_argument(:error_reason, "Data source unavailable: git repository not accessible")
        |> UsageAnalyzer.update()

      assert failed_report.status == :failed
    end

    test "calculates actionability_score correctly" do
      report = create_test_analysis_report(%{
        findings: %{
          actionable_patterns: 12,
          total_patterns: 20,
          severity_distribution: %{high: 4, medium: 8, low: 8}
        },
        recommendations: [
          "High priority: Fix database connection pooling",
          "Medium priority: Add query optimization",
          "Low priority: Update documentation"
        ],
        confidence: Decimal.new("0.88")
      })

      assert {:ok, [report_with_calc]} =
        AnalysisReport
        |> Ash.Query.load(:actionability_score)
        |> Ash.Query.filter(id == ^report.id)
        |> UsageAnalyzer.read()

      assert Decimal.gte?(report_with_calc.actionability_score, Decimal.new("0.0"))
      assert Decimal.lte?(report_with_calc.actionability_score, Decimal.new("1.0"))
      assert Decimal.gt?(report_with_calc.actionability_score, Decimal.new("0.6"))
    end

    test "calculates pattern_strength accurately" do
      strong_pattern_report = create_test_analysis_report(%{
        findings: %{
          pattern_frequency: %{
            "CRUD operations" => 150,
            "validation patterns" => 89,
            "relationship patterns" => 67
          },
          pattern_consistency: 0.92,
          statistical_significance: 0.95
        }
      })

      weak_pattern_report = create_test_analysis_report(%{
        findings: %{
          pattern_frequency: %{
            "rare pattern 1" => 3,
            "rare pattern 2" => 2
          },
          pattern_consistency: 0.45,
          statistical_significance: 0.32
        }
      })

      assert {:ok, [strong_with_calc]} =
        AnalysisReport
        |> Ash.Query.load(:pattern_strength)
        |> Ash.Query.filter(id == ^strong_pattern_report.id)
        |> UsageAnalyzer.read()

      assert {:ok, [weak_with_calc]} =
        AnalysisReport
        |> Ash.Query.load(:pattern_strength)
        |> Ash.Query.filter(id == ^weak_pattern_report.id)
        |> UsageAnalyzer.read()

      assert Decimal.gt?(strong_with_calc.pattern_strength, weak_with_calc.pattern_strength)
      assert Decimal.gt?(strong_with_calc.pattern_strength, Decimal.new("0.8"))
      assert Decimal.lt?(weak_with_calc.pattern_strength, Decimal.new("0.5"))
    end

    test "determines recommendation_priority correctly" do
      high_priority_report = create_test_analysis_report(%{
        findings: %{
          critical_issues: 5,
          performance_impact: "high",
          security_concerns: 2
        },
        confidence: Decimal.new("0.95"),
        sample_size: 5000
      })

      low_priority_report = create_test_analysis_report(%{
        findings: %{
          minor_suggestions: 3,
          performance_impact: "low",
          security_concerns: 0
        },
        confidence: Decimal.new("0.65"),
        sample_size: 150
      })

      assert {:ok, [high_priority_with_calc]} =
        AnalysisReport
        |> Ash.Query.load(:recommendation_priority)
        |> Ash.Query.filter(id == ^high_priority_report.id)
        |> UsageAnalyzer.read()

      assert {:ok, [low_priority_with_calc]} =
        AnalysisReport
        |> Ash.Query.load(:recommendation_priority)
        |> Ash.Query.filter(id == ^low_priority_report.id)
        |> UsageAnalyzer.read()

      assert high_priority_with_calc.recommendation_priority in [:high, :critical]
      assert low_priority_with_calc.recommendation_priority in [:low, :medium]
    end
  end

  describe "PatternDetection resource operations" do
    test "creates pattern detection with valid attributes" do
      report = create_test_analysis_report()

      attrs = %{
        pattern_type: :structural,
        pattern_name: "Nested Resource Pattern",
        description: "Resources with deeply nested relationships exceeding 3 levels",
        frequency: 25,
        confidence: Decimal.new("0.89"),
        impact_level: :medium,
        pattern_data: %{
          max_nesting_depth: 5,
          average_nesting_depth: 3.2,
          affected_resources: ["User", "Organization", "Project", "Task", "Comment"],
          performance_impact: %{
            query_complexity: "high",
            memory_usage: "moderate"
          }
        },
        examples: [
          %{
            resource: "User",
            nesting_path: ["Organization", "Project", "Task", "Comment"],
            depth: 4
          },
          %{
            resource: "Comment",
            nesting_path: ["User", "Organization", "Project", "Task"],
            depth: 4
          }
        ]
      }

      assert {:ok, pattern} =
        PatternDetection
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.Changeset.manage_relationship(:analysis_report, report, type: :replace)
        |> UsageAnalyzer.create()

      assert pattern.pattern_type == :structural
      assert pattern.pattern_name == "Nested Resource Pattern"
      assert pattern.frequency == 25
      assert Decimal.equal?(pattern.confidence, Decimal.new("0.89"))
      assert pattern.impact_level == :medium
      assert pattern.pattern_data["max_nesting_depth"] == 5
      assert length(pattern.examples) == 2
      assert pattern.analysis_report_id == report.id
      assert is_binary(pattern.id)
    end

    test "validates required pattern_name attribute" do
      report = create_test_analysis_report()

      attrs = %{pattern_type: :structural}

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        PatternDetection
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.Changeset.manage_relationship(:analysis_report, report, type: :replace)
        |> UsageAnalyzer.create()

      assert Enum.any?(errors, fn error ->
        error.field == :pattern_name && error.message =~ "required"
      end)
    end

    test "validates pattern_type and impact_level constraints" do
      report = create_test_analysis_report()

      attrs = %{
        pattern_name: "Test Pattern",
        pattern_type: :invalid_type,
        impact_level: :invalid_level,
        confidence: Decimal.new("1.5")
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        PatternDetection
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.Changeset.manage_relationship(:analysis_report, report, type: :replace)
        |> UsageAnalyzer.create()

      type_error = Enum.find(errors, & &1.field == :pattern_type)
      level_error = Enum.find(errors, & &1.field == :impact_level)
      confidence_error = Enum.find(errors, & &1.field == :confidence)

      assert type_error && type_error.message =~ "one_of"
      assert level_error && level_error.message =~ "one_of"
      assert confidence_error && confidence_error.message =~ "max"
    end

    test "detect_pattern action validates and calculates impact" do
      report = create_test_analysis_report()
      setup_pattern_detection_mocks()

      attrs = %{
        pattern_type: :behavioral,
        pattern_name: "Excessive Action Complexity",
        description: "Actions with too many arguments and complex logic",
        frequency: 8,
        confidence: Decimal.new("0.76"),
        impact_level: :high,
        pattern_data: %{
          avg_argument_count: 7.5,
          max_argument_count: 12,
          complexity_score: 8.2
        },
        examples: [
          %{
            action_name: "complex_create",
            argument_count: 10,
            complexity_factors: ["nested_validations", "multiple_calculations"]
          }
        ]
      }

      assert {:ok, pattern} =
        PatternDetection
        |> Ash.Changeset.for_create(:detect_pattern, attrs)
        |> Ash.Changeset.set_argument(:report_id, report.id)
        |> UsageAnalyzer.create()

      assert pattern.pattern_type == :behavioral
      assert pattern.impact_level == :high
      assert pattern.analysis_report_id == report.id
    end

    test "calculates significance_score correctly" do
      report = create_test_analysis_report()

      high_significance_pattern = create_test_pattern_detection(report, %{
        frequency: 150,
        confidence: Decimal.new("0.95"),
        impact_level: :critical,
        pattern_data: %{
          affected_users: 1200,
          performance_degradation: "severe"
        }
      })

      low_significance_pattern = create_test_pattern_detection(report, %{
        frequency: 2,
        confidence: Decimal.new("0.45"),
        impact_level: :low,
        pattern_data: %{
          affected_users: 5,
          performance_degradation: "negligible"
        }
      })

      assert {:ok, [high_sig_with_calc]} =
        PatternDetection
        |> Ash.Query.load(:significance_score)
        |> Ash.Query.filter(id == ^high_significance_pattern.id)
        |> UsageAnalyzer.read()

      assert {:ok, [low_sig_with_calc]} =
        PatternDetection
        |> Ash.Query.load(:significance_score)
        |> Ash.Query.filter(id == ^low_significance_pattern.id)
        |> UsageAnalyzer.read()

      assert Decimal.gt?(high_sig_with_calc.significance_score, low_sig_with_calc.significance_score)
      assert Decimal.gt?(high_sig_with_calc.significance_score, Decimal.new("0.8"))
      assert Decimal.lt?(low_sig_with_calc.significance_score, Decimal.new("0.4"))
    end

    test "creates multiple patterns for single report" do
      report = create_test_analysis_report()

      patterns_data = [
        %{
          pattern_type: :structural,
          pattern_name: "Over-normalization",
          frequency: 12,
          impact_level: :medium
        },
        %{
          pattern_type: :behavioral,
          pattern_name: "Missing Validations",
          frequency: 8,
          impact_level: :high
        },
        %{
          pattern_type: :temporal,
          pattern_name: "Peak Usage Bottlenecks",
          frequency: 3,
          impact_level: :critical
        },
        %{
          pattern_type: :semantic,
          pattern_name: "Inconsistent Naming",
          frequency: 45,
          impact_level: :low
        }
      ]

      created_patterns = 
        for pattern_data <- patterns_data do
          {:ok, pattern} =
            PatternDetection
            |> Ash.Changeset.for_create(:create, pattern_data)
            |> Ash.Changeset.manage_relationship(:analysis_report, report, type: :replace)
            |> UsageAnalyzer.create()
          
          pattern
        end

      assert length(created_patterns) == 4

      # Verify all patterns are linked to the same report
      assert {:ok, linked_patterns} =
        PatternDetection
        |> Ash.Query.filter(analysis_report_id == ^report.id)
        |> UsageAnalyzer.read()

      assert length(linked_patterns) == 4

      pattern_types = Enum.map(linked_patterns, & &1.pattern_type)
      assert :structural in pattern_types
      assert :behavioral in pattern_types
      assert :temporal in pattern_types
      assert :semantic in pattern_types
    end
  end

  describe "ComprehensiveAnalysis workflow" do
    setup do
      target_dsl = """
      E-learning platform DSL comprehensive analysis:
      - User management with student/instructor roles
      - Course creation and content management
      - Interactive lessons with multimedia support
      - Assessment and quiz systems
      - Progress tracking and analytics
      - Certification and badging
      - Discussion forums and collaboration
      - Real-time notifications and messaging
      """

      %{
        target_dsl: target_dsl,
        analysis_depth: :comprehensive,
        time_window: "30d"
      }
    end

    test "executes complete comprehensive analysis successfully", %{target_dsl: target_dsl} = context do
      setup_comprehensive_analysis_mocks()

      input = %{
        target_dsl: target_dsl,
        analysis_depth: context.analysis_depth,
        time_window: context.time_window
      }

      assert {:ok, result} = Reactor.run(ComprehensiveAnalysis, input, %{}, async?: false)
      
      assert result.master_report != nil
      assert result.synthesized_insights != nil
      assert result.actionable_recommendations != nil
      assert result.analysis_reports != nil
      assert length(result.analysis_reports) == 4
    end

    test "runs multiple analysis types concurrently", %{target_dsl: target_dsl} = context do
      setup_concurrent_analysis_mocks()

      input = %{
        target_dsl: target_dsl,
        analysis_depth: context.analysis_depth,
        time_window: context.time_window
      }

      start_time = System.monotonic_time()
      assert {:ok, result} = Reactor.run(ComprehensiveAnalysis, input, %{}, async?: true)
      end_time = System.monotonic_time()

      duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Should complete faster due to concurrent analysis
      assert duration < 2000

      # Verify all analysis types were created
      analysis_types = Enum.map(result.analysis_reports, & &1.analysis_type)
      assert :patterns in analysis_types
      assert :performance in analysis_types
      assert :pain_points in analysis_types
      assert :introspection in analysis_types
    end

    test "synthesizes insights from multiple analyses", %{target_dsl: target_dsl} = context do
      setup_insight_synthesis_mocks()

      input = %{
        target_dsl: target_dsl,
        analysis_depth: context.analysis_depth,
        time_window: context.time_window
      }

      assert {:ok, result} = Reactor.run(ComprehensiveAnalysis, input, %{}, async?: false)

      insights = result.synthesized_insights
      assert insights.cross_cutting_patterns != nil
      assert insights.correlation_analysis != nil
      assert insights.priority_matrix != nil
      assert insights.impact_assessment != nil
    end

    test "generates actionable recommendations", %{target_dsl: target_dsl} = context do
      setup_recommendation_generation_mocks()

      input = %{
        target_dsl: target_dsl,
        analysis_depth: context.analysis_depth,
        time_window: context.time_window
      }

      assert {:ok, result} = Reactor.run(ComprehensiveAnalysis, input, %{}, async?: false)

      recommendations = result.actionable_recommendations
      assert length(recommendations.immediate_actions) > 0
      assert length(recommendations.short_term_improvements) > 0
      assert length(recommendations.long_term_strategic) > 0
      
      # Should have prioritized recommendations
      assert recommendations.priority_score != nil
      assert recommendations.implementation_effort != nil
      assert recommendations.expected_impact != nil
    end

    test "creates comprehensive master report", %{target_dsl: target_dsl} = context do
      setup_master_report_mocks()

      input = %{
        target_dsl: target_dsl,
        analysis_depth: context.analysis_depth,
        time_window: context.time_window
      }

      assert {:ok, result} = Reactor.run(ComprehensiveAnalysis, input, %{}, async?: false)

      master_report = result.master_report
      assert master_report.executive_summary != nil
      assert master_report.detailed_findings != nil
      assert master_report.pattern_analysis != nil
      assert master_report.performance_analysis != nil
      assert master_report.pain_point_analysis != nil
      assert master_report.recommendations != nil
      assert master_report.implementation_roadmap != nil
      assert master_report.risk_assessment != nil
    end

    test "handles different analysis depths appropriately", %{target_dsl: target_dsl} do
      depth_tests = [
        {:surface, 500},
        {:moderate, 1500},
        {:deep, 3000},
        {:comprehensive, 5000}
      ]

      setup_depth_analysis_mocks()

      for {depth, expected_min_duration} <- depth_tests do
        input = %{
          target_dsl: target_dsl,
          analysis_depth: depth,
          time_window: "7d"
        }

        start_time = System.monotonic_time()
        assert {:ok, result} = Reactor.run(ComprehensiveAnalysis, input, %{}, async?: false)
        end_time = System.monotonic_time()

        duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

        # Deeper analysis should generally take longer (mocked appropriately)
        assert result.analysis_depth == depth
        assert result.completeness_score >= depth_to_completeness(depth)
      end
    end

    test "handles various time windows correctly", %{target_dsl: target_dsl} = context do
      time_window_tests = [
        {"1d", :recent},
        {"7d", :weekly},
        {"30d", :monthly},
        {"90d", :quarterly},
        {"365d", :yearly}
      ]

      setup_time_window_analysis_mocks()

      for {time_window, expected_scope} <- time_window_tests do
        input = %{
          target_dsl: target_dsl,
          analysis_depth: context.analysis_depth,
          time_window: time_window
        }

        assert {:ok, result} = Reactor.run(ComprehensiveAnalysis, input, %{}, async?: false)

        assert result.time_window == time_window
        assert result.temporal_scope == expected_scope
        assert result.sample_size >= time_window_to_sample_size(time_window)
      end
    end
  end

  describe "Ash Resource Introspection" do
    test "analyzes simple Ash resource correctly" do
      defmodule SimpleTestResource do
        use Ash.Resource

        attributes do
          uuid_primary_key :id
          attribute :name, :string, allow_nil?: false
          attribute :email, :string
        end

        actions do
          defaults [:create, :read, :update, :destroy]
        end
      end

      analysis = UsageAnalyzer.analyze_ash_resource(SimpleTestResource)

      assert analysis.structure.attributes != nil
      assert analysis.structure.actions != nil
      assert analysis.usage_patterns.create_actions == 1
      assert analysis.usage_patterns.read_actions == 1
      assert analysis.usage_patterns.update_actions == 1
      assert analysis.usage_patterns.destroy_actions == 1
      assert analysis.complexity_metrics.attribute_count == 3  # id, name, email
      assert analysis.complexity_metrics.relationship_count == 0
    end

    test "analyzes complex Ash resource with relationships" do
      defmodule ComplexTestResource do
        use Ash.Resource,
          extensions: [AshPostgres.DataLayer, AshJsonApi.Resource],
          data_layer: AshPostgres.DataLayer

        attributes do
          uuid_primary_key :id
          attribute :title, :string, allow_nil?: false
          attribute :content, :string
          attribute :published, :boolean, default: false
          attribute :view_count, :integer, default: 0
          attribute :metadata, :map, default: %{}
        end

        relationships do
          belongs_to :author, Author
          has_many :comments, Comment
          many_to_many :tags, Tag, through: PostTag
        end

        actions do
          defaults [:create, :read, :update, :destroy]
          
          create :publish do
            accept [:title, :content]
            change set_attribute(:published, true)
          end
          
          read :published do
            filter expr(published == true)
          end
          
          read :by_author do
            argument :author_id, :uuid, allow_nil?: false
            filter expr(author_id == ^arg(:author_id))
          end
          
          update :increment_views do
            change increment(:view_count, amount: 1)
          end
        end

        calculations do
          calculate :word_count, :integer do
            calculation fn query, _context ->
              from q in query,
                select: fragment("array_length(string_to_array(?, ' '), 1)", q.content)
            end
          end
        end

        validations do
          validate present(:title), message: "Title is required"
          validate present(:content), message: "Content is required"
        end
      end

      analysis = UsageAnalyzer.analyze_ash_resource(ComplexTestResource)

      assert analysis.structure.attributes != nil
      assert analysis.structure.relationships != nil
      assert analysis.structure.calculations != nil
      assert analysis.structure.validations != nil
      
      assert analysis.usage_patterns.create_actions == 2  # default create + publish
      assert analysis.usage_patterns.read_actions == 3   # default read + published + by_author
      assert analysis.usage_patterns.update_actions == 2 # default update + increment_views
      assert analysis.usage_patterns.destroy_actions == 1
      
      assert analysis.usage_patterns.custom_patterns.count == 4  # publish, published, by_author, increment_views
      assert analysis.usage_patterns.custom_patterns.naming_patterns[:create_pattern] != nil
      assert analysis.usage_patterns.custom_patterns.naming_patterns[:update_pattern] != nil
      
      assert analysis.complexity_metrics.attribute_count == 6  # id, title, content, published, view_count, metadata
      assert analysis.complexity_metrics.relationship_count == 3  # author, comments, tags
      assert analysis.complexity_metrics.complexity_score > 0
      
      assert analysis.extension_usage.extensions != nil
      assert analysis.extension_usage.data_layer != nil
      assert analysis.extension_usage.api_layers != nil
    end

    test "extracts naming patterns correctly" do
      defmodule NamingPatternsTestResource do
        use Ash.Resource

        attributes do
          uuid_primary_key :id
          attribute :name, :string
        end

        actions do
          defaults [:create, :read, :update, :destroy]
          
          create :create_with_validation
          create :create_draft
          update :update_status
          update :update_priority
          read :get_active
          read :get_by_status
          read :list_recent
          read :list_all
          action :archive, :atom
          action :restore, :atom
          action :process_batch, :atom
        end
      end

      analysis = UsageAnalyzer.analyze_ash_resource(NamingPatternsTestResource)

      naming_patterns = analysis.usage_patterns.custom_patterns.naming_patterns
      
      assert naming_patterns[:create_pattern] != nil
      assert naming_patterns[:update_pattern] != nil
      assert naming_patterns[:get_pattern] != nil
      assert naming_patterns[:list_pattern] != nil
      assert naming_patterns[:other_pattern] != nil
      
      # Should have multiple actions in create and update patterns
      assert length(naming_patterns[:create_pattern]) >= 2
      assert length(naming_patterns[:update_pattern]) >= 2
    end

    test "analyzes extension usage correctly" do
      defmodule ExtensionTestResource do
        use Ash.Resource,
          extensions: [AshPostgres.DataLayer, AshJsonApi.Resource, AshGraphql.Resource],
          data_layer: AshPostgres.DataLayer

        attributes do
          uuid_primary_key :id
          attribute :name, :string
        end

        actions do
          defaults [:create, :read, :update, :destroy]
        end
      end

      analysis = UsageAnalyzer.analyze_ash_resource(ExtensionTestResource)

      assert analysis.extension_usage.extensions != nil
      assert analysis.extension_usage.data_layer != nil
      assert analysis.extension_usage.api_layers != nil
      
      # Should detect AshPostgres as data layer
      assert analysis.extension_usage.data_layer != nil
      
      # Should detect multiple API layers
      assert length(analysis.extension_usage.api_layers) >= 1
    end
  end

  describe "Advanced analysis scenarios" do
    test "analyzes large-scale enterprise DSL" do
      enterprise_dsl = """
      Enterprise Resource Planning (ERP) DSL Analysis:
      
      Core Modules:
      - Human Resources: employee management, payroll, benefits, performance
      - Financial Management: accounting, budgeting, reporting, compliance
      - Supply Chain: inventory, procurement, vendor management, logistics
      - Customer Relations: CRM, sales, marketing, support
      - Project Management: planning, resource allocation, tracking, reporting
      - Business Intelligence: analytics, dashboards, KPIs, forecasting
      
      Integration Points:
      - External APIs: payment gateways, shipping providers, tax services
      - Legacy Systems: mainframe integration, data migration
      - Third-party Tools: email systems, document management, collaboration
      
      Performance Requirements:
      - 10,000+ concurrent users
      - Sub-second response times
      - 99.9% uptime
      - Real-time data synchronization
      """

      setup_enterprise_analysis_mocks()

      input = %{
        target_dsl: enterprise_dsl,
        analysis_depth: :comprehensive,
        time_window: "90d"
      }

      assert {:ok, result} = Reactor.run(ComprehensiveAnalysis, input, %{}, async?: false)

      # Should handle enterprise complexity
      assert result.complexity_rating == :enterprise
      assert result.scalability_assessment != nil
      assert result.integration_analysis != nil
      assert result.performance_projections != nil
    end

    test "analyzes microservices architecture patterns" do
      microservices_dsl = """
      Microservices Architecture DSL Analysis:
      
      Service Decomposition:
      - User Service: authentication, authorization, profile management
      - Product Service: catalog, inventory, pricing
      - Order Service: cart, checkout, fulfillment
      - Payment Service: transactions, billing, subscriptions
      - Notification Service: email, SMS, push notifications
      - Analytics Service: tracking, reporting, metrics
      
      Communication Patterns:
      - Synchronous: REST APIs, GraphQL endpoints
      - Asynchronous: message queues, event streaming
      - Service mesh: load balancing, circuit breakers, retries
      
      Data Management:
      - Database per service
      - Event sourcing for audit trails
      - CQRS for read/write separation
      """

      setup_microservices_analysis_mocks()

      input = %{
        target_dsl: microservices_dsl,
        analysis_depth: :deep,
        time_window: "60d"
      }

      assert {:ok, result} = Reactor.run(ComprehensiveAnalysis, input, %{}, async?: false)

      # Should identify microservices patterns
      assert result.architecture_pattern == :microservices
      assert result.service_decomposition_analysis != nil
      assert result.communication_pattern_analysis != nil
      assert result.data_consistency_analysis != nil
    end

    test "analyzes real-time and streaming patterns" do
      streaming_dsl = """
      Real-time Streaming Platform DSL Analysis:
      
      Data Ingestion:
      - Kafka event streams
      - WebSocket connections
      - Server-sent events
      - Webhook receivers
      
      Processing Pipeline:
      - Stream processing with GenStage
      - Real-time aggregations
      - Complex event processing
      - Machine learning inference
      
      Output Channels:
      - Live dashboards
      - Push notifications
      - Real-time analytics
      - Automated alerts
      """

      setup_streaming_analysis_mocks()

      input = %{
        target_dsl: streaming_dsl,
        analysis_depth: :deep,
        time_window: "14d"
      }

      assert {:ok, result} = Reactor.run(ComprehensiveAnalysis, input, %{}, async?: false)

      # Should identify streaming patterns
      assert result.streaming_patterns != nil
      assert result.real_time_capabilities != nil
      assert result.throughput_analysis != nil
      assert result.latency_characteristics != nil
    end
  end

  describe "Error handling and edge cases" do
    test "handles analysis failures gracefully" do
      UsageAnalyzerChangesMock
      |> expect(:collect_usage_data, fn _changeset ->
        {:error, "Data collection service unavailable"}
      end)

      attrs = %{
        target_dsl: "Test DSL for failure handling",
        analysis_type: :patterns,
        data_sources: [:git_commits]
      }

      # Should handle failure appropriately
      result = AnalysisReport
      |> Ash.Changeset.for_create(:analyze_dsl_usage, attrs)
      |> UsageAnalyzer.create()

      case result do
        {:ok, report} -> assert report.status in [:failed, :pending]
        {:error, _} -> :ok  # Expected failure
      end
    end

    test "handles database connection failures gracefully" do
      # Simulate DB failure
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(UsageAnalyzer.Repo)
      :ok = Ecto.Adapters.SQL.Sandbox.mode(UsageAnalyzer.Repo, :manual)
      
      GenServer.stop(UsageAnalyzer.Repo)

      attrs = %{target_dsl: "Test DSL", analysis_type: :patterns}

      assert {:error, _} =
        AnalysisReport
        |> Ash.Changeset.for_create(:create, attrs)
        |> UsageAnalyzer.create()

      # Restart repo for other tests
      start_supervised!(UsageAnalyzer.Repo)
    end

    test "handles concurrent analyses safely" do
      target_dsls = [
        "Concurrent analysis test 1: E-commerce platform",
        "Concurrent analysis test 2: Social media platform",
        "Concurrent analysis test 3: Financial trading platform"
      ]

      setup_concurrent_safety_mocks()

      tasks = 
        target_dsls
        |> Enum.map(fn target_dsl ->
          Task.async(fn ->
            input = %{
              target_dsl: target_dsl,
              analysis_depth: :moderate,
              time_window: "7d"
            }
            Reactor.run(ComprehensiveAnalysis, input, %{}, async?: false)
          end)
        end)

      results = Task.await_many(tasks, 10000)

      # All should complete successfully
      assert Enum.all?(results, fn
        {:ok, _} -> true
        _ -> false
      end)

      # Each should have unique analysis reports
      report_ids = 
        results
        |> Enum.flat_map(fn {:ok, result} -> Enum.map(result.analysis_reports, & &1.id) end)
        |> Enum.uniq()

      expected_count = length(target_dsls) * 4  # 4 analysis types per DSL
      assert length(report_ids) == expected_count
    end

    test "handles invalid DSL content gracefully" do
      invalid_dsls = [
        "",  # Empty content
        "Invalid non-DSL content with no structure",
        String.duplicate("x", 100_000),  # Extremely large content
        "DSL with special chars: !@#$%^&*(){}[]|\\:;\"'<>,.?/~`"
      ]

      for invalid_dsl <- invalid_dsls do
        attrs = %{
          target_dsl: invalid_dsl,
          analysis_type: :patterns,
          analysis_depth: :surface
        }

        # Should either succeed with warnings or fail gracefully
        result = AnalysisReport
        |> Ash.Changeset.for_create(:create, attrs)
        |> UsageAnalyzer.create()

        case result do
          {:ok, report} -> 
            assert report.target_dsl == invalid_dsl
          {:error, _} -> 
            :ok  # Graceful failure is acceptable
        end
      end
    end
  end

  # Helper functions
  defp create_test_analysis_report(attrs \\ %{}) do
    default_attrs = %{
      target_dsl: "Test DSL for comprehensive analysis and pattern detection",
      analysis_type: :patterns,
      time_window: "30d",
      data_sources: [:git_commits, :performance_logs],
      analysis_depth: :moderate,
      status: :pending
    }

    attrs = Map.merge(default_attrs, attrs)

    AnalysisReport
    |> Ash.Changeset.for_create(:create, attrs)
    |> UsageAnalyzer.create!()
  end

  defp create_test_pattern_detection(report, attrs \\ %{}) do
    default_attrs = %{
      pattern_type: :structural,
      pattern_name: "Test Pattern #{System.unique_integer()}",
      description: "Test pattern for unit testing",
      frequency: 10,
      confidence: Decimal.new("0.8"),
      impact_level: :medium
    }

    attrs = Map.merge(default_attrs, attrs)

    PatternDetection
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.Changeset.manage_relationship(:analysis_report, report, type: :replace)
    |> UsageAnalyzer.create!()
  end

  defp depth_to_completeness(depth) do
    case depth do
      :surface -> 0.6
      :moderate -> 0.75
      :deep -> 0.9
      :comprehensive -> 0.95
    end
  end

  defp time_window_to_sample_size(time_window) do
    case time_window do
      "1d" -> 50
      "7d" -> 300
      "30d" -> 1200
      "90d" -> 3500
      "365d" -> 15000
    end
  end

  # Mock setup functions
  defp setup_usage_analysis_mocks do
    UsageAnalyzerChangesMock
    |> stub(:validate_data_sources, fn changeset -> changeset end)
    |> stub(:collect_usage_data, fn changeset -> changeset end)
    |> stub(:analyze_patterns, fn changeset -> changeset end)
    |> stub(:generate_insights, fn changeset -> changeset end)
    |> stub(:create_recommendations, fn changeset -> changeset end)
  end

  defp setup_introspection_mocks do
    UsageAnalyzerChangesMock
    |> stub(:introspect_ash_resource, fn changeset -> changeset end)
    |> stub(:analyze_resource_complexity, fn changeset -> changeset end)
    |> stub(:extract_usage_patterns, fn changeset -> changeset end)
  end

  defp setup_pattern_detection_mocks do
    UsageAnalyzerChangesMock
    |> stub(:validate_pattern_data, fn changeset -> changeset end)
    |> stub(:calculate_impact, fn changeset -> changeset end)
  end

  defp setup_comprehensive_analysis_mocks do
    UsageAnalyzerSynthesisMock
    |> stub(:combine_analyses, fn reports ->
      {:ok, %{
        cross_cutting_patterns: ["authentication", "validation", "caching"],
        correlation_analysis: %{strong_correlations: 5, weak_correlations: 12},
        priority_matrix: %{high: 3, medium: 8, low: 15}
      }}
    end)

    UsageAnalyzerRecommendationsMock
    |> stub(:generate_actionable, fn _insights, _target_dsl ->
      {:ok, %{
        immediate_actions: ["Fix critical security issue", "Optimize slow query"],
        short_term_improvements: ["Add caching layer", "Implement monitoring"],
        long_term_strategic: ["Microservices migration", "Event-driven architecture"],
        priority_score: 0.85,
        implementation_effort: :moderate,
        expected_impact: :high
      }}
    end)

    UsageAnalyzerReportingMock
    |> stub(:create_comprehensive_report, fn _insights, _recommendations ->
      {:ok, %{
        executive_summary: %{key_findings: 5, critical_issues: 2},
        detailed_findings: %{patterns: 25, anti_patterns: 8},
        recommendations: %{total: 15, prioritized: 8}
      }}
    end)
  end

  defp setup_concurrent_analysis_mocks do
    setup_comprehensive_analysis_mocks()
  end

  defp setup_insight_synthesis_mocks do
    setup_comprehensive_analysis_mocks()
  end

  defp setup_recommendation_generation_mocks do
    setup_comprehensive_analysis_mocks()
  end

  defp setup_master_report_mocks do
    setup_comprehensive_analysis_mocks()

    UsageAnalyzerReportingMock
    |> stub(:create_comprehensive_report, fn _insights, _recommendations ->
      {:ok, %{
        executive_summary: %{
          key_findings: 8,
          critical_issues: 3,
          improvement_opportunities: 12
        },
        detailed_findings: %{
          structural_patterns: 15,
          behavioral_patterns: 10,
          performance_issues: 5
        },
        pattern_analysis: %{
          most_common: "CRUD operations",
          most_problematic: "N+1 queries",
          emerging_trends: ["GraphQL adoption", "Real-time features"]
        },
        performance_analysis: %{
          bottlenecks: 3,
          optimization_potential: "high",
          scalability_concerns: 2
        },
        pain_point_analysis: %{
          developer_friction: ["complex setup", "unclear documentation"],
          user_experience: ["slow response times", "confusing navigation"],
          operational: ["deployment complexity", "monitoring gaps"]
        },
        recommendations: %{
          immediate: 4,
          short_term: 7,
          long_term: 4
        },
        implementation_roadmap: %{
          phase_1: "Performance optimization",
          phase_2: "Architecture improvements",
          phase_3: "Feature enhancements"
        },
        risk_assessment: %{
          high_risk: 1,
          medium_risk: 3,
          low_risk: 8
        }
      }}
    end)
  end

  defp setup_depth_analysis_mocks do
    UsageAnalyzerMock
    |> stub(:create!, fn _resource, attrs ->
      depth = attrs.analysis_depth
      
      %{
        id: Ash.UUID.generate(),
        analysis_depth: depth,
        completeness_score: depth_to_completeness(depth),
        processing_time: depth_to_processing_time(depth)
      }
    end)
  end

  defp setup_time_window_analysis_mocks do
    UsageAnalyzerMock
    |> stub(:create!, fn _resource, attrs ->
      time_window = attrs.time_window
      
      %{
        id: Ash.UUID.generate(),
        time_window: time_window,
        temporal_scope: time_window_to_scope(time_window),
        sample_size: time_window_to_sample_size(time_window)
      }
    end)
  end

  defp setup_enterprise_analysis_mocks do
    setup_comprehensive_analysis_mocks()

    UsageAnalyzerMock
    |> stub(:create!, fn _resource, attrs ->
      %{
        id: Ash.UUID.generate(),
        analysis_type: attrs.analysis_type,
        complexity_rating: :enterprise,
        scalability_assessment: %{rating: "high", concerns: []},
        integration_analysis: %{external_apis: 15, legacy_systems: 3},
        performance_projections: %{expected_load: "10k+ users", response_time: "< 200ms"}
      }
    end)
  end

  defp setup_microservices_analysis_mocks do
    setup_comprehensive_analysis_mocks()

    UsageAnalyzerMock
    |> stub(:create!, fn _resource, _attrs ->
      %{
        id: Ash.UUID.generate(),
        architecture_pattern: :microservices,
        service_decomposition_analysis: %{services: 6, boundaries: "well_defined"},
        communication_pattern_analysis: %{sync: 60, async: 40},
        data_consistency_analysis: %{eventual_consistency: true, conflicts: "minimal"}
      }
    end)
  end

  defp setup_streaming_analysis_mocks do
    setup_comprehensive_analysis_mocks()

    UsageAnalyzerMock
    |> stub(:create!, fn _resource, _attrs ->
      %{
        id: Ash.UUID.generate(),
        streaming_patterns: %{kafka: true, genstage: true, websockets: true},
        real_time_capabilities: %{latency: "< 50ms", throughput: "high"},
        throughput_analysis: %{events_per_second: 10000, peak_capacity: 50000},
        latency_characteristics: %{p50: 15, p95: 45, p99: 100}
      }
    end)
  end

  defp setup_concurrent_safety_mocks do
    setup_comprehensive_analysis_mocks()
  end

  defp depth_to_processing_time(depth) do
    case depth do
      :surface -> 100
      :moderate -> 300
      :deep -> 800
      :comprehensive -> 1500
    end
  end

  defp time_window_to_scope(time_window) do
    case time_window do
      "1d" -> :recent
      "7d" -> :weekly
      "30d" -> :monthly
      "90d" -> :quarterly
      "365d" -> :yearly
    end
  end
end