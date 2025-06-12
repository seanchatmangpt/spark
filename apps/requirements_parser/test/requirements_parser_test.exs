defmodule RequirementsParserTest do
  use ExUnit.Case, async: false
  use RequirementsParser.DataCase

  import Mox
  setup :verify_on_exit!

  alias RequirementsParser.{
    Repo,
    Resources.Specification,
    Resources.ParsedEntity,
    Workflows.NlpProcessing
  }

  describe "RequirementsParser domain operations" do
    test "creates domain with proper resource configuration" do
      assert RequirementsParser.__domain__()
      
      resources = RequirementsParser.Info.resources()
      assert length(resources) == 4
      
      resource_names = Enum.map(resources, & &1.resource)
      assert RequirementsParser.Resources.Specification in resource_names
      assert RequirementsParser.Resources.ParsedEntity in resource_names
      assert RequirementsParser.Resources.FeatureExtraction in resource_names
      assert RequirementsParser.Resources.NlpAnalysis in resource_names
    end

    test "has proper authorization configuration" do
      config = RequirementsParser.Info.authorization()
      assert config.authorize == :by_default
      refute config.require_actor?
    end

    test "validates all resources are accessible" do
      for resource <- RequirementsParser.Info.resources() do
        assert Code.ensure_loaded?(resource.resource)
        assert function_exported?(resource.resource, :spark_dsl_config, 0)
      end
    end
  end

  describe "Specification resource operations" do
    test "creates specification with valid attributes" do
      attrs = %{
        original_text: "Create a user management system with authentication and role-based access control",
        domain: :web,
        language: :english
      }

      assert {:ok, spec} = 
        Specification
        |> Ash.Changeset.for_create(:create, attrs)
        |> RequirementsParser.create()

      assert spec.original_text == attrs.original_text
      assert spec.domain == :web
      assert spec.language == :english
      assert spec.features == []
      assert spec.entities == []
      assert spec.constraints == []
      assert is_binary(spec.id)
    end

    test "validates required original_text attribute" do
      attrs = %{domain: :web}

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        Specification
        |> Ash.Changeset.for_create(:create, attrs)
        |> RequirementsParser.create()

      assert Enum.any?(errors, fn error ->
        error.field == :original_text && error.message =~ "required"
      end)
    end

    test "validates domain constraints" do
      attrs = %{
        original_text: "Test requirements",
        domain: :invalid_domain
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        Specification
        |> Ash.Changeset.for_create(:create, attrs)
        |> RequirementsParser.create()

      assert Enum.any?(errors, fn error ->
        error.field == :domain && error.message =~ "one_of"
      end)
    end

    test "validates minimum text length" do
      attrs = %{
        original_text: "short"
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        Specification
        |> Ash.Changeset.for_create(:create, attrs)
        |> RequirementsParser.create()

      assert Enum.any?(errors, fn error ->
        error.message =~ "minimum"
      end)
    end

    test "validates confidence score constraints" do
      attrs = %{
        original_text: "Valid requirements text with sufficient length",
        confidence_score: Decimal.new("1.5")
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        Specification
        |> Ash.Changeset.for_create(:create, attrs)
        |> RequirementsParser.create()

      assert Enum.any?(errors, fn error ->
        error.field == :confidence_score && error.message =~ "max"
      end)
    end

    test "parse_natural_language action processes text correctly" do
      setup_nlp_mocks()

      attrs = %{
        original_text: "Build a REST API for managing users with CRUD operations and JWT authentication",
        language: :english
      }

      assert {:ok, spec} =
        Specification
        |> Ash.Changeset.for_create(:parse_natural_language, attrs)
        |> RequirementsParser.create()

      assert spec.domain != nil
      assert spec.complexity != nil
      assert spec.confidence_score != nil
      assert length(spec.features) > 0
      assert length(spec.entities) > 0
    end

    test "refine_specification updates specification correctly" do
      spec = create_test_specification()

      refinements = %{
        features: [:crud, :authentication, :validation],
        entities: [
          %{name: "User", type: :model, properties: %{name: "string", email: "string"}},
          %{name: "Session", type: :model, properties: %{token: "string"}}
        ],
        constraints: [:unique_email, :secure_password],
        domain: :api
      }

      assert {:ok, refined_spec} =
        spec
        |> Ash.Changeset.for_update(:refine_specification, refinements)
        |> RequirementsParser.update()

      assert refined_spec.domain == :api
      assert length(refined_spec.features) == 3
      assert :crud in refined_spec.features
      assert :authentication in refined_spec.features
      assert :validation in refined_spec.features
      assert length(refined_spec.entities) == 2
      assert length(refined_spec.constraints) == 2
    end

    test "enhance_with_context adds contextual information" do
      spec = create_test_specification()

      context_data = %{
        tech_stack: ["Elixir", "Phoenix", "PostgreSQL"],
        team_size: 3,
        timeline: "6 weeks",
        experience_level: "intermediate"
      }

      metadata = %{
        performance_requirements: %{response_time: "< 200ms"},
        scalability: %{concurrent_users: 1000}
      }

      assert {:ok, enhanced_spec} =
        spec
        |> Ash.Changeset.for_update(:enhance_with_context, %{metadata: metadata})
        |> Ash.Changeset.set_argument(:context_data, context_data)
        |> RequirementsParser.update()

      assert enhanced_spec.metadata["performance_requirements"] != nil
      assert enhanced_spec.metadata["scalability"] != nil
    end

    test "calculates readiness_score accurately" do
      spec = create_test_specification(%{
        domain: :web,
        complexity: :moderate,
        confidence_score: Decimal.new("0.85"),
        features: [:crud, :authentication, :validation],
        entities: [
          %{name: "User", type: :model},
          %{name: "Session", type: :model}
        ]
      })

      assert {:ok, [spec_with_calc]} =
        Specification
        |> Ash.Query.load(:readiness_score)
        |> Ash.Query.filter(id == ^spec.id)
        |> RequirementsParser.read()

      assert Decimal.gte?(spec_with_calc.readiness_score, Decimal.new("0.0"))
      assert Decimal.lte?(spec_with_calc.readiness_score, Decimal.new("1.0"))
      assert Decimal.gt?(spec_with_calc.readiness_score, Decimal.new("0.5"))
    end

    test "calculates extraction_completeness correctly" do
      incomplete_spec = create_test_specification(%{
        features: [:crud],
        entities: []
      })

      complete_spec = create_test_specification(%{
        features: [:crud, :authentication, :validation],
        entities: [
          %{name: "User", type: :model},
          %{name: "Session", type: :model},
          %{name: "Permission", type: :model}
        ],
        constraints: [:unique_email, :secure_password]
      })

      assert {:ok, [incomplete_with_calc]} =
        Specification
        |> Ash.Query.load(:extraction_completeness)
        |> Ash.Query.filter(id == ^incomplete_spec.id)
        |> RequirementsParser.read()

      assert {:ok, [complete_with_calc]} =
        Specification
        |> Ash.Query.load(:extraction_completeness)
        |> Ash.Query.filter(id == ^complete_spec.id)
        |> RequirementsParser.read()

      assert Decimal.lt?(incomplete_with_calc.extraction_completeness, complete_with_calc.extraction_completeness)
      assert Decimal.gt?(complete_with_calc.extraction_completeness, Decimal.new("0.7"))
    end

    test "determines ambiguity_level correctly" do
      ambiguous_spec = create_test_specification(%{
        original_text: "Create something for users to manage things",
        confidence_score: Decimal.new("0.3")
      })

      clear_spec = create_test_specification(%{
        original_text: "Create a REST API for user authentication with JWT tokens and role-based access control",
        confidence_score: Decimal.new("0.9")
      })

      assert {:ok, [ambiguous_with_calc]} =
        Specification
        |> Ash.Query.load(:ambiguity_level)
        |> Ash.Query.filter(id == ^ambiguous_spec.id)
        |> RequirementsParser.read()

      assert {:ok, [clear_with_calc]} =
        Specification
        |> Ash.Query.load(:ambiguity_level)
        |> Ash.Query.filter(id == ^clear_spec.id)
        |> RequirementsParser.read()

      assert ambiguous_with_calc.ambiguity_level in [:high, :very_high]
      assert clear_with_calc.ambiguity_level in [:low, :very_low]
    end
  end

  describe "ParsedEntity resource operations" do
    test "creates parsed entity with valid attributes" do
      spec = create_test_specification()

      attrs = %{
        entity_type: :model,
        name: "User",
        description: "User model with authentication properties",
        properties: %{
          fields: ["name", "email", "password_hash"],
          validations: ["presence", "uniqueness"],
          associations: ["has_many_sessions"]
        },
        confidence: Decimal.new("0.9")
      }

      assert {:ok, entity} =
        ParsedEntity
        |> Ash.Changeset.for_create(:extract_from_text, attrs)
        |> Ash.Changeset.set_argument(:specification_id, spec.id)
        |> Ash.Changeset.set_argument(:text_span, %{start: 0, end: 50})
        |> RequirementsParser.create()

      assert entity.entity_type == :model
      assert entity.name == "User"
      assert entity.properties["fields"] == ["name", "email", "password_hash"]
      assert entity.specification_id == spec.id
      assert entity.source_span != nil
    end

    test "validates entity_type constraints" do
      spec = create_test_specification()

      attrs = %{
        entity_type: :invalid_type,
        name: "Test"
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        ParsedEntity
        |> Ash.Changeset.for_create(:extract_from_text, attrs)
        |> Ash.Changeset.set_argument(:specification_id, spec.id)
        |> Ash.Changeset.set_argument(:text_span, %{start: 0, end: 10})
        |> RequirementsParser.create()

      assert Enum.any?(errors, fn error ->
        error.field == :entity_type && error.message =~ "one_of"
      end)
    end

    test "validates required name attribute" do
      spec = create_test_specification()

      attrs = %{entity_type: :model}

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        ParsedEntity
        |> Ash.Changeset.for_create(:extract_from_text, attrs)
        |> Ash.Changeset.set_argument(:specification_id, spec.id)
        |> Ash.Changeset.set_argument(:text_span, %{start: 0, end: 10})
        |> RequirementsParser.create()

      assert Enum.any?(errors, fn error ->
        error.field == :name && error.message =~ "required"
      end)
    end

    test "validates confidence score constraints" do
      spec = create_test_specification()

      attrs = %{
        entity_type: :model,
        name: "Test",
        confidence: Decimal.new("1.5")
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        ParsedEntity
        |> Ash.Changeset.for_create(:extract_from_text, attrs)
        |> Ash.Changeset.set_argument(:specification_id, spec.id)
        |> Ash.Changeset.set_argument(:text_span, %{start: 0, end: 10})
        |> RequirementsParser.create()

      assert Enum.any?(errors, fn error ->
        error.field == :confidence && error.message =~ "max"
      end)
    end

    test "creates multiple related entities for specification" do
      spec = create_test_specification()

      entities = [
        %{entity_type: :model, name: "User", description: "User model"},
        %{entity_type: :model, name: "Session", description: "Session model"},
        %{entity_type: :action, name: "authenticate", description: "Login action"},
        %{entity_type: :validation, name: "email_unique", description: "Email uniqueness"}
      ]

      created_entities = 
        for {entity_attrs, index} <- Enum.with_index(entities) do
          {:ok, entity} =
            ParsedEntity
            |> Ash.Changeset.for_create(:extract_from_text, entity_attrs)
            |> Ash.Changeset.set_argument(:specification_id, spec.id)
            |> Ash.Changeset.set_argument(:text_span, %{start: index * 10, end: (index + 1) * 10})
            |> RequirementsParser.create()
          
          entity
        end

      assert length(created_entities) == 4

      # Verify all entities are linked to the specification
      assert {:ok, linked_entities} =
        ParsedEntity
        |> Ash.Query.filter(specification_id == ^spec.id)
        |> RequirementsParser.read()

      assert length(linked_entities) == 4

      entity_types = Enum.map(linked_entities, & &1.entity_type)
      assert :model in entity_types
      assert :action in entity_types
      assert :validation in entity_types
    end
  end

  describe "NlpProcessing workflow" do
    setup do
      setup_comprehensive_nlp_mocks()
      
      %{
        text: "Create a web application for managing e-commerce orders with user authentication, product catalog, shopping cart, and payment processing",
        language: :english,
        domain: :web
      }
    end

    test "executes complete NLP workflow successfully", context do
      input = %{
        text: context.text,
        language: context.language,
        domain: context.domain
      }

      assert {:ok, result} = Reactor.run(NlpProcessing, input, %{}, async?: false)
      
      assert result.original_text == context.text
      assert result.domain == context.domain
      assert length(result.features) > 0
      assert length(result.entities) > 0
      assert Decimal.gt?(result.confidence_score, Decimal.new("0.5"))
    end

    test "runs tokenization and analysis steps concurrently", context do
      start_time = System.monotonic_time()

      input = %{
        text: context.text,
        language: context.language,
        domain: context.domain
      }

      assert {:ok, _result} = Reactor.run(NlpProcessing, input, %{}, async?: true)
      
      end_time = System.monotonic_time()
      duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)
      
      # Should complete faster due to concurrent execution
      assert duration < 500
    end

    test "handles tokenization failure gracefully", context do
      RequirementsParserNLPMock
      |> expect(:tokenize, fn _text, _language ->
        {:error, "Tokenization service unavailable"}
      end)

      input = %{text: context.text, language: context.language, domain: context.domain}

      assert {:error, _reason} = Reactor.run(NlpProcessing, input, %{}, async?: false)
    end

    test "processes different domains correctly" do
      domain_tests = [
        {
          :api,
          "Create REST API endpoints for user management with CRUD operations",
          [:rest, :crud, :endpoints]
        },
        {
          :mobile,
          "Build mobile app with offline sync and push notifications",
          [:mobile, :offline, :notifications]
        },
        {
          :data,
          "Process large datasets with ETL pipelines and analytics dashboards",
          [:etl, :analytics, :pipelines]
        }
      ]

      for {domain, text, expected_features} <- domain_tests do
        input = %{text: text, language: :english, domain: domain}

        assert {:ok, result} = Reactor.run(NlpProcessing, input, %{}, async?: false)
        
        assert result.domain == domain
        assert Enum.any?(expected_features, fn feature ->
          feature in result.features
        end)
      end
    end

    test "extracts complex entities with relationships" do
      complex_text = """
      Create an e-learning platform where instructors can create courses with lessons and quizzes.
      Students can enroll in courses, track progress, and receive certificates upon completion.
      Include admin panel for user management and analytics.
      """

      input = %{text: complex_text, language: :english, domain: :web}

      assert {:ok, result} = Reactor.run(NlpProcessing, input, %{}, async?: false)

      entity_names = Enum.map(result.entities, & &1["name"])
      assert "Instructor" in entity_names
      assert "Student" in entity_names
      assert "Course" in entity_names
      assert "Lesson" in entity_names
      assert "Quiz" in entity_names

      # Check for relationship entities
      assert Enum.any?(result.entities, fn entity ->
        entity["type"] == "relationship" && entity["name"] =~ "enrollment"
      end)
    end

    test "calculates accurate confidence scores based on clarity" do
      clear_requirements = "Build REST API with JWT authentication, user CRUD operations, and PostgreSQL database"
      vague_requirements = "Make something for users to do stuff with data"

      clear_input = %{text: clear_requirements, language: :english, domain: :api}
      vague_input = %{text: vague_requirements, language: :english, domain: :api}

      assert {:ok, clear_result} = Reactor.run(NlpProcessing, clear_input, %{}, async?: false)
      assert {:ok, vague_result} = Reactor.run(NlpProcessing, vague_input, %{}, async?: false)

      assert Decimal.gt?(clear_result.confidence_score, vague_result.confidence_score)
      assert Decimal.gt?(clear_result.confidence_score, Decimal.new("0.7"))
      assert Decimal.lt?(vague_result.confidence_score, Decimal.new("0.5"))
    end

    test "handles multilingual input" do
      multilingual_tests = [
        {:spanish, "Crear una aplicación web para gestión de usuarios con autenticación"},
        {:french, "Créer une application web pour la gestion des utilisateurs avec authentification"},
        {:german, "Erstellen Sie eine Webanwendung für die Benutzerverwaltung mit Authentifizierung"}
      ]

      for {language, text} <- multilingual_tests do
        input = %{text: text, language: language, domain: :web}

        assert {:ok, result} = Reactor.run(NlpProcessing, input, %{}, async?: false)
        
        assert result.language == language
        assert result.original_text == text
        # Should still extract basic features regardless of language
        assert length(result.features) > 0
      end
    end
  end

  describe "ML Model Integration" do
    test "integrates with Bumblebee for NER" do
      setup_bumblebee_mocks()

      text = "The User model should have name, email and created_at fields with proper validation"

      RequirementsParserNLPMock
      |> expect(:extract_entities, fn _tokens, _domain ->
        {:ok, [
          %{name: "User", type: "model", confidence: 0.95, span: %{start: 4, end: 8}},
          %{name: "name", type: "field", confidence: 0.9, span: %{start: 25, end: 29}},
          %{name: "email", type: "field", confidence: 0.9, span: %{start: 31, end: 36}},
          %{name: "created_at", type: "field", confidence: 0.88, span: %{start: 41, end: 51}}
        ]}
      end)

      input = %{text: text, language: :english, domain: :web}

      assert {:ok, result} = Reactor.run(NlpProcessing, input, %{}, async?: false)

      user_entity = Enum.find(result.entities, & &1["name"] == "User")
      assert user_entity != nil
      assert user_entity["type"] == "model"
      assert user_entity["confidence"] == 0.95
    end

    test "handles model loading failures gracefully" do
      BumblebeeMock
      |> expect(:load_model, fn _config ->
        {:error, "Model not found"}
      end)

      input = %{text: "Test requirements", language: :english, domain: :web}

      # Should fall back to rule-based extraction
      assert {:ok, result} = Reactor.run(NlpProcessing, input, %{}, async?: false)
      assert result != nil
    end

    test "processes large text efficiently" do
      large_text = String.duplicate("Create user management system with authentication. ", 100)

      input = %{text: large_text, language: :english, domain: :web}

      start_time = System.monotonic_time()
      assert {:ok, result} = Reactor.run(NlpProcessing, input, %{}, async?: false)
      end_time = System.monotonic_time()

      duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)
      
      # Should complete within reasonable time even for large text
      assert duration < 2000
      assert result.original_text == large_text
      assert length(result.entities) > 0
    end
  end

  describe "Error handling and edge cases" do
    test "handles empty text input" do
      input = %{text: "", language: :english, domain: :web}

      assert {:error, reason} = Reactor.run(NlpProcessing, input, %{}, async?: false)
      assert reason =~ "minimum"
    end

    test "handles malformed input gracefully" do
      malformed_inputs = [
        %{text: nil, language: :english, domain: :web},
        %{text: "Valid text", language: nil, domain: :web},
        %{text: "Valid text", language: :english, domain: nil}
      ]

      for input <- malformed_inputs do
        assert {:error, _reason} = Reactor.run(NlpProcessing, input, %{}, async?: false)
      end
    end

    test "handles database connection failures gracefully" do
      # Simulate DB failure
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(RequirementsParser.Repo)
      :ok = Ecto.Adapters.SQL.Sandbox.mode(RequirementsParser.Repo, :manual)
      
      GenServer.stop(RequirementsParser.Repo)

      attrs = %{original_text: "Test requirements for database failure"}

      assert {:error, _} =
        Specification
        |> Ash.Changeset.for_create(:create, attrs)
        |> RequirementsParser.create()

      # Restart repo for other tests
      start_supervised!(RequirementsParser.Repo)
    end

    test "handles concurrent processing safely" do
      texts = [
        "Create user authentication system",
        "Build product catalog with search",
        "Implement order processing workflow",
        "Add payment gateway integration",
        "Create admin dashboard with analytics"
      ]

      tasks = 
        texts
        |> Enum.map(fn text ->
          Task.async(fn ->
            input = %{text: text, language: :english, domain: :web}
            Reactor.run(NlpProcessing, input, %{}, async?: false)
          end)
        end)

      results = Task.await_many(tasks, 10000)

      # All should succeed
      assert Enum.all?(results, fn
        {:ok, _} -> true
        _ -> false
      end)

      # All should have unique specifications
      specs = Enum.map(results, fn {:ok, result} -> result.id end)
      assert length(Enum.uniq(specs)) == length(specs)
    end
  end

  # Helper functions
  defp create_test_specification(attrs \\ %{}) do
    default_attrs = %{
      original_text: "Create a web application for user management with authentication and role-based access control",
      domain: :web,
      language: :english
    }

    attrs = Map.merge(default_attrs, attrs)

    Specification
    |> Ash.Changeset.for_create(:create, attrs)
    |> RequirementsParser.create!()
  end

  defp setup_nlp_mocks do
    RequirementsParserChangesMock
    |> stub(:tokenize_text, fn changeset -> changeset end)
    |> stub(:extract_intent, fn changeset -> 
      Ash.Changeset.change_attribute(changeset, :metadata, %{intent: "create_web_app"})
    end)
    |> stub(:identify_features, fn changeset ->
      Ash.Changeset.change_attribute(changeset, :features, [:crud, :authentication, :api])
    end)
    |> stub(:infer_entities, fn changeset ->
      entities = [
        %{name: "User", type: :model, properties: %{fields: ["name", "email"]}},
        %{name: "Session", type: :model, properties: %{fields: ["token", "expires_at"]}}
      ]
      Ash.Changeset.change_attribute(changeset, :entities, entities)
    end)
    |> stub(:calculate_complexity, fn changeset ->
      Ash.Changeset.change_attribute(changeset, :complexity, :moderate)
    end)
    |> stub(:calculate_confidence, fn changeset ->
      Ash.Changeset.change_attribute(changeset, :confidence_score, Decimal.new("0.85"))
    end)
  end

  defp setup_comprehensive_nlp_mocks do
    RequirementsParserNLPMock
    |> stub(:tokenize, fn text, _language ->
      tokens = String.split(text, ~r/\s+/)
      {:ok, %{tokens: tokens, metadata: %{word_count: length(tokens)}}}
    end)
    |> stub(:extract_entities, fn _tokens, domain ->
      base_entities = [
        %{name: "User", type: "model", confidence: 0.9},
        %{name: "Order", type: "model", confidence: 0.85},
        %{name: "Product", type: "model", confidence: 0.88}
      ]

      domain_entities = case domain do
        :web -> [%{name: "Session", type: "model", confidence: 0.82} | base_entities]
        :api -> [%{name: "Endpoint", type: "action", confidence: 0.91} | base_entities]
        _ -> base_entities
      end

      {:ok, domain_entities}
    end)
    |> stub(:analyze_intent, fn _tokens ->
      {:ok, %{
        primary_intent: "create_application",
        secondary_intents: ["manage_data", "authenticate_users"],
        confidence: 0.87
      }}
    end)

    RequirementsParserFeaturesMock
    |> stub(:identify_from_entities, fn entities, intent ->
      base_features = [:crud, :authentication]
      
      entity_features = 
        entities
        |> Enum.flat_map(fn entity ->
          case entity["type"] do
            "model" -> [:data_modeling]
            "action" -> [:api_design]
            _ -> []
          end
        end)
        |> Enum.uniq()

      intent_features = 
        case intent.primary_intent do
          "create_application" -> [:web_development]
          _ -> []
        end

      {:ok, base_features ++ entity_features ++ intent_features}
    end)

    RequirementsParserConfidenceMock
    |> stub(:calculate_overall, fn entities, features, intent ->
      entity_confidence = Enum.reduce(entities, 0.0, fn entity, acc ->
        acc + entity["confidence"]
      end) / length(entities)

      feature_confidence = if length(features) > 2, do: 0.9, else: 0.6
      intent_confidence = intent.confidence

      overall = (entity_confidence + feature_confidence + intent_confidence) / 3
      {:ok, Decimal.from_float(overall)}
    end)
  end

  defp setup_bumblebee_mocks do
    BumblebeeMock
    |> stub(:load_model, fn _config ->
      {:ok, %{model: :mock_model, tokenizer: :mock_tokenizer}}
    end)
    |> stub(:apply, fn _model, _input ->
      {:ok, %{
        entities: [
          %{label: "PERSON", score: 0.95, start: 4, end: 8},
          %{label: "FIELD", score: 0.9, start: 25, end: 29}
        ]
      }}
    end)
  end
end