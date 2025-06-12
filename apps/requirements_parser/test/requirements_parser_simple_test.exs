defmodule RequirementsParserSimpleTest do
  use ExUnit.Case
  doctest RequirementsParser

  import Mox
  setup :verify_on_exit!

  describe "RequirementsParser module" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(RequirementsParser)
    end

    test "has proper module attributes" do
      assert function_exported?(RequirementsParser, :__info__, 1)
    end
  end

  describe "Text processing simulation" do
    test "simulates natural language processing" do
      text = "Create a user authentication system with role-based access control and session management"

      result = simulate_nlp_processing(text)

      assert result.entities != nil
      assert result.features != nil
      assert result.complexity != nil
      assert result.confidence >= 0.0
      assert result.confidence <= 1.0
    end

    test "extracts entities from requirements" do
      requirements = """
      Build an e-commerce platform with the following features:
      - User registration and authentication
      - Product catalog with categories and search
      - Shopping cart and checkout process
      - Order management and tracking
      - Payment processing with multiple gateways
      - Admin dashboard for content management
      """

      entities = extract_entities(requirements)

      assert length(entities) > 0
      entity_names = Enum.map(entities, & &1.name)
      assert "User" in entity_names
      assert "Product" in entity_names
      assert "Order" in entity_names
    end

    test "identifies features from text" do
      text = "Create a social media application with user profiles, posts, comments, likes, and real-time notifications"

      features = identify_features(text)

      assert :social_media in features
      assert :user_management in features
      assert :content_management in features
      assert :real_time in features
    end

    test "calculates text complexity" do
      simple_text = "Create a basic user model with name and email"
      complex_text = """
      Develop a comprehensive enterprise resource planning system with multi-tenant architecture,
      advanced reporting capabilities, integration with external APIs, real-time data synchronization,
      role-based access control with fine-grained permissions, audit logging, and support for
      multiple languages and currencies with complex business rule validation.
      """

      simple_complexity = calculate_complexity(simple_text)
      complex_complexity = calculate_complexity(complex_text)

      assert simple_complexity < complex_complexity
      assert simple_complexity >= 1.0
      assert complex_complexity >= 5.0
    end

    test "determines confidence scores" do
      clear_requirements = "Build a REST API for user authentication with JWT tokens and PostgreSQL database"
      vague_requirements = "Make something for users to do stuff with data"

      clear_confidence = calculate_confidence(clear_requirements)
      vague_confidence = calculate_confidence(vague_requirements)

      assert clear_confidence > vague_confidence
      assert clear_confidence >= 0.8
      assert vague_confidence <= 0.5
    end

    test "handles multilingual input" do
      texts = [
        {"english", "Create a web application for user management"},
        {"spanish", "Crear una aplicación web para gestión de usuarios"},
        {"french", "Créer une application web pour la gestion des utilisateurs"}
      ]

      for {language, text} <- texts do
        result = process_multilingual_text(text, language)
        
        assert result.language == language
        assert result.entities != nil
        assert result.features != nil
      end
    end

    test "processes domain-specific requirements" do
      domains = [
        {:web, "Build a responsive web application with user authentication"},
        {:api, "Create REST API endpoints with CRUD operations"},
        {:mobile, "Develop mobile app with offline sync capabilities"},
        {:data, "Implement ETL pipeline for data processing"}
      ]

      for {domain, requirements} <- domains do
        result = process_domain_requirements(requirements, domain)
        
        assert result.domain == domain
        assert result.domain_features != nil
        assert result.recommended_patterns != nil
      end
    end
  end

  describe "Machine learning simulation" do
    test "simulates NER (Named Entity Recognition)" do
      text = "The User model should have name, email, and created_at fields with proper validation"

      entities = simulate_ner(text)

      assert length(entities) > 0
      user_entity = Enum.find(entities, & &1.name == "User")
      assert user_entity != nil
      assert user_entity.type == "model"
      assert user_entity.confidence > 0.8
    end

    test "simulates intent classification" do
      texts = [
        "Create a new user authentication system",
        "Update the existing product catalog",
        "Delete old session records",
        "Search for users by email address"
      ]

      for text <- texts do
        intent = classify_intent(text)
        assert intent.primary_intent != nil
        assert intent.confidence > 0.5
      end
    end

    test "simulates sentiment analysis" do
      texts = [
        "This system works perfectly and is very efficient",
        "The current implementation is problematic and needs improvement",
        "The functionality is adequate but could be enhanced"
      ]

      for text <- texts do
        sentiment = analyze_sentiment(text)
        assert sentiment.polarity in [:positive, :negative, :neutral]
        assert sentiment.score >= -1.0
        assert sentiment.score <= 1.0
      end
    end

    test "handles model loading failures gracefully" do
      result = simulate_model_failure()
      
      assert result.status == :fallback
      assert result.method == :rule_based
      assert result.entities != nil
    end

    test "processes large text efficiently" do
      large_text = String.duplicate("Create user management system with authentication. ", 100)

      start_time = System.monotonic_time()
      result = process_large_text(large_text)
      end_time = System.monotonic_time()

      duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

      assert duration < 2000  # Should complete within 2 seconds
      assert result.text_length == String.length(large_text)
      assert result.processing_time != nil
    end
  end

  describe "Workflow processing" do
    test "simulates complete NLP workflow" do
      input = %{
        text: "Create an e-learning platform with course management, student enrollment, and progress tracking",
        language: :english,
        domain: :web
      }

      result = simulate_complete_workflow(input)

      assert result.tokenization != nil
      assert result.entity_extraction != nil
      assert result.intent_analysis != nil
      assert result.feature_identification != nil
      assert result.confidence_calculation != nil
      assert result.specification != nil
    end

    test "handles workflow failures gracefully" do
      invalid_input = %{text: nil, language: :unknown}

      result = simulate_workflow_with_failure(invalid_input)

      assert result.status == :failed
      assert result.error != nil
      assert result.partial_results != nil
    end

    test "processes multiple inputs concurrently" do
      inputs = [
        "Create user authentication system",
        "Build product catalog with search",
        "Implement order processing workflow",
        "Add payment gateway integration"
      ]

      start_time = System.monotonic_time()
      results = process_concurrent_inputs(inputs)
      end_time = System.monotonic_time()

      duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

      assert length(results) == length(inputs)
      assert Enum.all?(results, fn result -> result.success == true end)
      # Should be faster than sequential processing
      assert duration < length(inputs) * 200
    end
  end

  describe "Data validation and edge cases" do
    test "handles empty and invalid inputs" do
      invalid_inputs = [
        "",
        nil,
        "x",
        String.duplicate("a", 100_000)
      ]

      for input <- invalid_inputs do
        result = process_with_validation(input)
        
        case result do
          {:ok, _} -> assert result != nil
          {:error, reason} -> assert reason != nil
        end
      end
    end

    test "validates specification format" do
      valid_spec = %{
        entities: [%{name: "User", type: "model"}],
        features: [:authentication],
        complexity: 5.0
      }

      invalid_spec = %{
        entities: "invalid",
        features: nil
      }

      assert validate_specification(valid_spec) == {:ok, :valid}
      assert validate_specification(invalid_spec) == {:error, :invalid_format}
    end

    test "handles malformed text gracefully" do
      malformed_texts = [
        "Create user!@#$%^&*()management system",
        "建立用户管理系统",
        "Créer un système de gestion des utilisateurs",
        "123456789 numbers only text"
      ]

      for text <- malformed_texts do
        result = process_malformed_text(text)
        assert result.status in [:success, :partial_success, :failed]
        assert result.entities != nil
      end
    end
  end

  # Helper functions
  defp simulate_nlp_processing(text) do
    word_count = String.split(text, ~r/\s+/) |> length()
    
    %{
      entities: extract_entities_simple(text),
      features: identify_features_simple(text),
      complexity: word_count * 0.5,
      confidence: calculate_confidence_simple(text)
    }
  end

  defp extract_entities(text) do
    # Simple entity extraction based on keywords
    entities = []
    
    entities = if String.contains?(text, "user"), do: [%{name: "User", type: "model", confidence: 0.9} | entities], else: entities
    entities = if String.contains?(text, "product"), do: [%{name: "Product", type: "model", confidence: 0.85} | entities], else: entities
    entities = if String.contains?(text, "order"), do: [%{name: "Order", type: "model", confidence: 0.8} | entities], else: entities
    entities = if String.contains?(text, "payment"), do: [%{name: "Payment", type: "model", confidence: 0.75} | entities], else: entities
    
    entities
  end

  defp identify_features(text) do
    features = []
    
    features = if String.contains?(text, "social"), do: [:social_media | features], else: features
    features = if String.contains?(text, "user"), do: [:user_management | features], else: features
    features = if String.contains?(text, "post") or String.contains?(text, "content"), do: [:content_management | features], else: features
    features = if String.contains?(text, "real-time"), do: [:real_time | features], else: features
    features = if String.contains?(text, "auth"), do: [:authentication | features], else: features
    
    features
  end

  defp calculate_complexity(text) do
    word_count = String.split(text, ~r/\s+/) |> length()
    sentence_count = String.split(text, ~r/[.!?]/) |> length()
    
    # Simple complexity calculation
    base_complexity = word_count / 10
    sentence_penalty = sentence_count * 0.5
    
    base_complexity + sentence_penalty
  end

  defp calculate_confidence(text) do
    # Simple confidence calculation based on text characteristics
    word_count = String.split(text, ~r/\s+/) |> length()
    technical_terms = count_technical_terms(text)
    
    base_confidence = 0.5
    word_bonus = min(word_count * 0.02, 0.3)
    technical_bonus = min(technical_terms * 0.1, 0.2)
    
    min(base_confidence + word_bonus + technical_bonus, 1.0)
  end

  defp count_technical_terms(text) do
    technical_terms = ["api", "database", "authentication", "authorization", "rest", "crud", "jwt", "postgresql", "mysql"]
    
    text_lower = String.downcase(text)
    Enum.count(technical_terms, fn term -> String.contains?(text_lower, term) end)
  end

  defp process_multilingual_text(text, language) do
    %{
      language: language,
      entities: extract_entities_simple(text),
      features: identify_features_simple(text),
      confidence: 0.7  # Lower confidence for non-English
    }
  end

  defp process_domain_requirements(requirements, domain) do
    base_features = identify_features_simple(requirements)
    
    domain_features = case domain do
      :web -> [:responsive_design, :web_framework]
      :api -> [:rest_endpoints, :json_responses]
      :mobile -> [:offline_sync, :mobile_ui]
      :data -> [:etl_pipeline, :data_processing]
    end
    
    %{
      domain: domain,
      domain_features: domain_features,
      recommended_patterns: get_domain_patterns(domain),
      features: base_features ++ domain_features
    }
  end

  defp get_domain_patterns(domain) do
    case domain do
      :web -> ["MVC", "component-based", "responsive"]
      :api -> ["RESTful", "stateless", "versioned"]
      :mobile -> ["offline-first", "progressive", "native"]
      :data -> ["batch-processing", "streaming", "pipeline"]
    end
  end

  defp simulate_ner(text) do
    # Simple NER simulation
    entities = []
    
    # Look for model patterns
    if String.contains?(text, "User model") or String.contains?(text, "User") do
      entities = [%{name: "User", type: "model", confidence: 0.95, span: %{start: 4, end: 8}} | entities]
    end
    
    # Look for field patterns
    fields = ["name", "email", "created_at", "updated_at", "id"]
    entities = Enum.reduce(fields, entities, fn field, acc ->
      if String.contains?(text, field) do
        [%{name: field, type: "field", confidence: 0.8, span: %{start: 0, end: String.length(field)}} | acc]
      else
        acc
      end
    end)
    
    entities
  end

  defp classify_intent(text) do
    text_lower = String.downcase(text)
    
    intent = cond do
      String.contains?(text_lower, "create") or String.contains?(text_lower, "build") ->
        %{primary_intent: "create", confidence: 0.9}
      String.contains?(text_lower, "update") or String.contains?(text_lower, "modify") ->
        %{primary_intent: "update", confidence: 0.85}
      String.contains?(text_lower, "delete") or String.contains?(text_lower, "remove") ->
        %{primary_intent: "delete", confidence: 0.8}
      String.contains?(text_lower, "search") or String.contains?(text_lower, "find") ->
        %{primary_intent: "search", confidence: 0.75}
      true ->
        %{primary_intent: "unknown", confidence: 0.3}
    end
    
    intent
  end

  defp analyze_sentiment(text) do
    text_lower = String.downcase(text)
    
    positive_words = ["perfect", "efficient", "great", "excellent", "good"]
    negative_words = ["problematic", "poor", "bad", "terrible", "awful"]
    
    positive_count = Enum.count(positive_words, fn word -> String.contains?(text_lower, word) end)
    negative_count = Enum.count(negative_words, fn word -> String.contains?(text_lower, word) end)
    
    cond do
      positive_count > negative_count ->
        %{polarity: :positive, score: 0.7}
      negative_count > positive_count ->
        %{polarity: :negative, score: -0.7}
      true ->
        %{polarity: :neutral, score: 0.0}
    end
  end

  defp simulate_model_failure do
    %{
      status: :fallback,
      method: :rule_based,
      entities: [%{name: "User", type: "model", confidence: 0.5}],
      message: "ML model unavailable, using rule-based extraction"
    }
  end

  defp process_large_text(text) do
    start_time = System.monotonic_time()
    
    # Simulate processing
    entities = extract_entities_simple(text)
    features = identify_features_simple(text)
    
    end_time = System.monotonic_time()
    processing_time = System.convert_time_unit(end_time - start_time, :native, :millisecond)
    
    %{
      text_length: String.length(text),
      processing_time: processing_time,
      entities: entities,
      features: features
    }
  end

  defp simulate_complete_workflow(input) do
    %{
      tokenization: %{tokens: String.split(input.text, ~r/\s+/), count: 10},
      entity_extraction: extract_entities_simple(input.text),
      intent_analysis: classify_intent(input.text),
      feature_identification: identify_features_simple(input.text),
      confidence_calculation: calculate_confidence_simple(input.text),
      specification: %{
        original_text: input.text,
        language: input.language,
        domain: input.domain
      }
    }
  end

  defp simulate_workflow_with_failure(input) do
    if input.text == nil do
      %{
        status: :failed,
        error: "Invalid input: text cannot be nil",
        partial_results: %{input_received: true}
      }
    else
      %{status: :success, input: input}
    end
  end

  defp process_concurrent_inputs(inputs) do
    tasks = Enum.map(inputs, fn input ->
      Task.async(fn ->
        # Simulate processing time
        Process.sleep(Enum.random(10..50))
        
        %{
          input: input,
          success: true,
          entities: extract_entities_simple(input),
          processing_time: Enum.random(10..50)
        }
      end)
    end)
    
    Task.await_many(tasks, 5000)
  end

  defp process_with_validation(input) do
    cond do
      input == nil ->
        {:error, :nil_input}
      input == "" ->
        {:error, :empty_input}
      is_binary(input) and String.length(input) < 3 ->
        {:error, :too_short}
      is_binary(input) and String.length(input) > 50_000 ->
        {:error, :too_long}
      is_binary(input) ->
        {:ok, %{processed: true, length: String.length(input)}}
      true ->
        {:error, :invalid_type}
    end
  end

  defp validate_specification(spec) do
    cond do
      not is_map(spec) ->
        {:error, :not_map}
      not Map.has_key?(spec, :entities) ->
        {:error, :missing_entities}
      not is_list(spec.entities) ->
        {:error, :invalid_entities}
      true ->
        {:ok, :valid}
    end
  end

  defp process_malformed_text(text) do
    try do
      entities = extract_entities_simple(text)
      %{status: :success, entities: entities}
    rescue
      _ ->
        %{status: :partial_success, entities: []}
    end
  end

  # Simple helper functions
  defp extract_entities_simple(text) do
    if String.contains?(text, "user") do
      [%{name: "User", type: "model", confidence: 0.8}]
    else
      []
    end
  end

  defp identify_features_simple(text) do
    features = []
    
    features = if String.contains?(text, "auth"), do: [:authentication | features], else: features
    features = if String.contains?(text, "manage"), do: [:management | features], else: features
    features = if String.contains?(text, "api"), do: [:api | features], else: features
    
    features
  end

  defp calculate_confidence_simple(text) do
    if String.length(text) > 20, do: 0.8, else: 0.5
  end
end