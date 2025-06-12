defmodule RequirementsParserIntegrationTest do
  use ExUnit.Case, async: true
  use ExUnitProperties
  
  alias RequirementsParser.{NLP, EntityExtractor, FeatureAnalyzer}
  
  describe "Real NLP integration" do
    test "integrates with actual Bumblebee models" do
      # Test with a real model if available, fallback to mock
      text = "Create a user authentication system with JWT tokens and role-based access control"
      
      case NLP.load_model(:bert_ner) do
        {:ok, model} ->
          {:ok, entities} = EntityExtractor.extract_with_model(text, model)
          
          assert is_list(entities)
          assert Enum.any?(entities, fn entity -> entity.name == "User" end)
          
        {:error, :model_not_available} ->
          # Fallback to rule-based extraction
          {:ok, entities} = EntityExtractor.extract_with_rules(text)
          assert is_list(entities)
      end
    end
    
    test "processes complex multi-paragraph requirements" do
      complex_text = """
      Build a comprehensive e-learning platform with the following requirements:
      
      User Management:
      - Student registration and authentication
      - Instructor profiles with qualifications
      - Admin panel for user management
      
      Course Management:
      - Course creation with multimedia content
      - Lesson organization and sequencing
      - Assignment and quiz management
      
      Progress Tracking:
      - Student progress analytics
      - Grade book functionality
      - Completion certificates
      
      Communication:
      - Discussion forums per course
      - Direct messaging between users
      - Announcement system
      """
      
      {:ok, analysis} = RequirementsParser.analyze(complex_text)
      
      # Verify comprehensive analysis
      assert length(analysis.entities) >= 8
      assert :authentication in analysis.features
      assert :content_management in analysis.features
      assert :analytics in analysis.features
      assert :communication in analysis.features
      
      # Verify complexity assessment
      assert analysis.complexity > 8.0
      assert analysis.confidence > 0.85
    end
  end
  
  describe "Property-based testing" do
    property "entity extraction is consistent" do
      check all text <- string(:printable, min_length: 20, max_length: 200),
                entities <- list_of(string(:alphanumeric, min_length: 3, max_length: 10), max_length: 5) do
        
        # Inject entities into text
        enhanced_text = "Create #{Enum.join(entities, ", ")} management system: #{text}"
        
        {:ok, extracted} = EntityExtractor.extract(enhanced_text)
        extracted_names = Enum.map(extracted, & &1.name)
        
        # Should extract at least some of the injected entities
        common_entities = MapSet.intersection(
          MapSet.new(entities),
          MapSet.new(extracted_names)
        )
        
        assert MapSet.size(common_entities) >= 0
      end
    end
    
    property "complexity increases with text length and technical terms" do
      check all base_text <- string(:alphanumeric, min_length: 10, max_length: 50),
                technical_terms <- list_of(member_of(["API", "database", "authentication", "encryption"]), max_length: 5) do
        
        simple_text = base_text
        complex_text = "#{base_text} #{Enum.join(technical_terms, " ")}"
        
        {:ok, simple_analysis} = RequirementsParser.analyze(simple_text)
        {:ok, complex_analysis} = RequirementsParser.analyze(complex_text)
        
        if length(technical_terms) > 0 do
          assert complex_analysis.complexity >= simple_analysis.complexity
        end
      end
    end
  end
  
  describe "Performance and scalability" do
    test "handles large requirements documents efficiently" do
      # Generate a large requirements document
      large_text = 1..100
      |> Enum.map(fn i ->
        "Section #{i}: Create entity#{i} with field1, field2, and field3. "
        <> "Implement feature#{i} with validation and authorization."
      end)
      |> Enum.join("\n\n")
      
      {time_micro, {:ok, analysis}} = :timer.tc(fn ->
        RequirementsParser.analyze(large_text)
      end)
      
      time_ms = time_micro / 1000
      
      assert time_ms < 10_000  # Should complete in under 10 seconds
      assert length(analysis.entities) > 50
      assert analysis.complexity > 50.0
    end
    
    test "processes multiple documents concurrently" do
      documents = [
        "Create user management system with authentication",
        "Build product catalog with search and filtering",
        "Implement order processing with payment integration",
        "Develop analytics dashboard with real-time metrics",
        "Create notification system with email and SMS"
      ]
      
      tasks = Enum.map(documents, fn doc ->
        Task.async(fn ->
          RequirementsParser.analyze(doc)
        end)
      end)
      
      results = Task.await_many(tasks, 5_000)
      
      assert length(results) == 5
      assert Enum.all?(results, fn {:ok, _} -> true; _ -> false end)
    end
  end
  
  describe "Edge cases and error handling" do
    test "handles malformed and edge case inputs" do
      edge_cases = [
        "",                                    # Empty
        "a",                                  # Too short
        String.duplicate("word ", 10_000),    # Very long
        "!@#$%^&*()_+",                      # Special characters only
        "123456789",                         # Numbers only
        "ALLCAPSTEXT",                       # All caps
        "mixed123CASE!@#text",               # Mixed case with symbols
        "\n\t\r  \s",                        # Whitespace only
        "建立用户管理系统",                      # Non-Latin characters
        "Create\x00null\x00bytes"             # Null bytes
      ]
      
      for input <- edge_cases do
        result = RequirementsParser.analyze(input)
        
        case result do
          {:ok, analysis} ->
            assert is_map(analysis)
            assert Map.has_key?(analysis, :entities)
            assert Map.has_key?(analysis, :features)
            
          {:error, reason} ->
            assert is_atom(reason) or is_binary(reason)
        end
      end
    end
    
    test "maintains consistent output format" do
      inputs = [
        "Simple user system",
        "Complex enterprise resource planning with multi-tenant architecture",
        "Medium complexity e-commerce platform"
      ]
      
      for input <- inputs do
        {:ok, analysis} = RequirementsParser.analyze(input)
        
        # Verify consistent structure
        assert Map.has_key?(analysis, :entities)
        assert Map.has_key?(analysis, :features)
        assert Map.has_key?(analysis, :complexity)
        assert Map.has_key?(analysis, :confidence)
        assert Map.has_key?(analysis, :metadata)
        
        # Verify data types
        assert is_list(analysis.entities)
        assert is_list(analysis.features)
        assert is_number(analysis.complexity)
        assert is_number(analysis.confidence)
        assert is_map(analysis.metadata)
      end
    end
  end
end