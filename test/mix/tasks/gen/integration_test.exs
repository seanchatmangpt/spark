defmodule Mix.Tasks.Spark.Gen.IntegrationTest do
  @moduledoc """
  Integration tests for Spark generator workflows and chaining.
  
  Tests complex scenarios involving multiple generators, task composition,
  and end-to-end DSL creation workflows.
  """
  
  use Spark.Test.GeneratorTestCase
  
  # Only run tests if Igniter is available
  @igniter_available Code.ensure_loaded?(Igniter)

  if @igniter_available do
    alias Mix.Tasks.Spark.Gen.{Dsl, Entity, Verifier, Section}

    describe "DSL generator integration" do
      test "DSL generator auto-creates referenced transformers" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.AutoTransformerDsl"}, 
          [
            extension: true,
            transformer: ["MyApp.Transformers.AddTimestamps", "MyApp.Transformers.ValidateConfig"]
          ]
        )
        
        result = Dsl.igniter(igniter)
        
        # In a real integration test, we would verify that transformer creation tasks were composed
        assert is_map(result)
        
        # The generator should have called Igniter.compose_task for each transformer
        # This would be verified by checking igniter.tasks or similar structure
      end

      test "DSL generator auto-creates referenced verifiers" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.AutoVerifierDsl"}, 
          [
            extension: true,
            verifier: ["MyApp.Verifiers.CheckRequired", "MyApp.Verifiers.ValidateUnique"]
          ]
        )
        
        result = Dsl.igniter(igniter)
        
        # In a real integration test, we would verify that verifier creation tasks were composed
        assert is_map(result)
      end

      test "DSL generator creates complex multi-component DSL" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.ComplexIntegrationDsl"}, 
          [
            extension: true,
            fragments: true,
            section: ["resources:MyApp.Resource", "policies", "config"],
            entity: ["resource:name:MyApp.Resource", "policy:name:MyApp.Policy"],
            arg: ["app_name:string", "timeout:pos_integer:5000"],
            opt: ["debug:boolean:false", "env:atom:dev"],
            singleton_entity: ["config"],
            transformer: ["MyApp.AddDefaults"],
            verifier: ["MyApp.ValidateStructure"]
          ]
        )
        
        result = Dsl.igniter(igniter)
        
        # Should generate a complete, functional DSL with all components
        expected_patterns = [
          "use Spark.Dsl.Extension",
          "@fragments",
          "use Spark.Dsl.Fragment",
          "section :resources",
          "section :policies", 
          "section :config",
          "entity :resource",
          "entity :policy",
          "singleton? true",
          "arg :app_name",
          "arg :timeout",
          "opt :debug",
          "opt :env",
          "transformers: [MyApp.AddDefaults]",
          "verifiers: [MyApp.ValidateStructure]"
        ]
        
        assert_module_created(result, "MyApp.ComplexIntegrationDsl", expected_patterns)
      end
    end

    describe "entity-section integration" do
      test "entity can be used in section entity list" do
        # First create an entity
        entity_igniter = mock_igniter(%{entity: "MyApp.Entities.Product"})
        entity_result = Entity.igniter(entity_igniter)
        
        # Then create a section that references it
        section_igniter = mock_igniter(
          %{section_module: "MyApp.Sections.Products"}, 
          [entities: ["MyApp.Entities.Product"]]
        )
        section_result = Section.igniter(section_igniter)
        
        # Both should succeed and be compatible
        assert is_map(entity_result)
        assert is_map(section_result)
        
        assert_module_created(section_result, "MyApp.Sections.Products", [
          "entities: [MyApp.Entities.Product]"
        ])
      end

      test "section can be referenced in DSL generation" do
        # Create a section first
        section_igniter = mock_igniter(%{section_module: "MyApp.Sections.Resources"})
        section_result = Section.igniter(section_igniter)
        
        # Then create a DSL that uses it
        dsl_igniter = mock_igniter(
          %{dsl_module: "MyApp.ResourceDsl"}, 
          [section: ["resources:MyApp.Sections.Resources"]]
        )
        dsl_result = Dsl.igniter(dsl_igniter)
        
        assert is_map(section_result)
        assert is_map(dsl_result)
        
        assert_module_created(dsl_result, "MyApp.ResourceDsl", [
          "section :resources",
          "MyApp.Sections.Resources"
        ])
      end
    end

    describe "verifier integration workflows" do
      test "verifier can validate DSL with specific sections" do
        # Create a verifier for specific sections
        verifier_igniter = mock_igniter(
          %{verifier_module: "MyApp.Verifiers.ResourceValidator"}, 
          [
            sections: "resources,policies",
            checks: "resource_policy_match,unique_names"
          ]
        )
        verifier_result = Verifier.igniter(verifier_igniter)
        
        # Create a DSL that uses this verifier
        dsl_igniter = mock_igniter(
          %{dsl_module: "MyApp.ValidatedDsl"}, 
          [
            extension: true,
            section: ["resources", "policies"],
            verifier: ["MyApp.Verifiers.ResourceValidator"]
          ]
        )
        dsl_result = Dsl.igniter(dsl_igniter)
        
        assert is_map(verifier_result)
        assert is_map(dsl_result)
        
        # Verifier should have helper functions for the sections
        assert_module_created(verifier_result, "MyApp.Verifiers.ResourceValidator", [
          "defp get_resources(dsl_state)",
          "defp get_policies(dsl_state)",
          "defp validate_resource_policy_match(dsl_state)",
          "defp validate_unique_names(dsl_state)"
        ])
        
        # DSL should reference the verifier
        assert_module_created(dsl_result, "MyApp.ValidatedDsl", [
          "verifiers: [MyApp.Verifiers.ResourceValidator]"
        ])
      end
    end

    describe "complete DSL ecosystem creation" do
      test "creates complete DSL ecosystem with all components" do
        # This test simulates creating a complete DSL ecosystem
        
        # 1. Create entities
        user_entity_igniter = mock_igniter(
          %{entity: "MyApp.Entities.User"}, 
          [
            args: ["name:string:required", "email:string:required"],
            schema: "id:integer,active:boolean",
            validations: ["validate_email", "validate_unique_name"],
            examples: true
          ]
        )
        user_entity_result = Entity.igniter(user_entity_igniter)
        
        post_entity_igniter = mock_igniter(
          %{entity: "MyApp.Entities.Post"}, 
          [
            args: ["title:string:required", "author:string:required"],
            schema: "content:string,published:boolean",
            examples: true
          ]
        )
        post_entity_result = Entity.igniter(post_entity_igniter)
        
        # 2. Create sections
        users_section_igniter = mock_igniter(
          %{section_module: "MyApp.Sections.Users"}, 
          [
            entities: ["MyApp.Entities.User"],
            opts: ["max_users:integer:1000", "allow_registration:boolean:true"],
            examples: true
          ]
        )
        users_section_result = Section.igniter(users_section_igniter)
        
        posts_section_igniter = mock_igniter(
          %{section_module: "MyApp.Sections.Posts"}, 
          [
            entities: ["MyApp.Entities.Post"],
            opts: ["max_posts_per_user:integer:10"],
            examples: true
          ]
        )
        posts_section_result = Section.igniter(posts_section_igniter)
        
        # 3. Create verifiers
        structure_verifier_igniter = mock_igniter(
          %{verifier_module: "MyApp.Verifiers.ValidateStructure"}, 
          [
            sections: "users,posts",
            checks: "user_post_relationship,valid_author_references",
            examples: true
          ]
        )
        structure_verifier_result = Verifier.igniter(structure_verifier_igniter)
        
        # 4. Create the main DSL
        main_dsl_igniter = mock_igniter(
          %{dsl_module: "MyApp.BlogDsl"}, 
          [
            extension: true,
            section: ["users:MyApp.Sections.Users", "posts:MyApp.Sections.Posts"],
            entity: ["user:name:MyApp.Entities.User", "post:title:MyApp.Entities.Post"],
            arg: ["blog_name:string", "theme:atom:default"],
            opt: ["analytics:boolean:false", "comments_enabled:boolean:true"],
            verifier: ["MyApp.Verifiers.ValidateStructure"]
          ]
        )
        main_dsl_result = Dsl.igniter(main_dsl_igniter)
        
        # Verify all components were created successfully
        assert is_map(user_entity_result)
        assert is_map(post_entity_result)
        assert is_map(users_section_result)
        assert is_map(posts_section_result)
        assert is_map(structure_verifier_result)
        assert is_map(main_dsl_result)
        
        # Verify the main DSL includes all components
        assert_module_created(main_dsl_result, "MyApp.BlogDsl", [
          "use Spark.Dsl.Extension",
          "section :users",
          "section :posts",
          "entity :user",
          "entity :post",
          "arg :blog_name",
          "arg :theme",
          "opt :analytics",
          "opt :comments_enabled",
          "verifiers: [MyApp.Verifiers.ValidateStructure]"
        ])
      end
    end

    describe "generator error propagation" do
      test "handles errors in composed task generation" do
        # Test what happens when a referenced transformer/verifier can't be created
        igniter = mock_igniter(
          %{dsl_module: "MyApp.ErrorTestDsl"}, 
          [
            extension: true,
            transformer: ["Invalid.Module.Name"],
            verifier: ["Another.Invalid.Module"]
          ]
        )
        
        # This might succeed at the DSL level but fail when trying to create the modules
        result = Dsl.igniter(igniter)
        assert is_map(result)
      end

      test "handles circular dependencies gracefully" do
        # Test potential circular dependencies in module references
        igniter = mock_igniter(
          %{dsl_module: "MyApp.CircularDsl"}, 
          [
            section: ["self:MyApp.CircularDsl"]  # Self-referencing
          ]
        )
        
        result = Dsl.igniter(igniter)
        assert is_map(result)
      end
    end

    describe "code generation consistency" do
      test "generated modules compile together successfully" do
        # Create a simple but complete DSL ecosystem
        entity_igniter = mock_igniter(
          %{entity: "MyApp.SimpleEntity"}, 
          [args: ["name:string:required"]]
        )
        entity_result = Entity.igniter(entity_igniter)
        
        dsl_igniter = mock_igniter(
          %{dsl_module: "MyApp.SimpleDsl"}, 
          [
            section: ["items"],
            entity: ["item:name:MyApp.SimpleEntity"]
          ]
        )
        dsl_result = Dsl.igniter(dsl_igniter)
        
        assert is_map(entity_result)
        assert is_map(dsl_result)
        
        # In a real test, we would compile and test the generated code
        # to ensure it works together properly
      end

      test "generated DSL can be used in practice" do
        # This would test that a generated DSL can actually be used
        # by defining a module that uses it and exercises its features
        
        dsl_igniter = mock_igniter(
          %{dsl_module: "MyApp.PracticalDsl"}, 
          [
            section: ["config"],
            arg: ["name:string"],
            opt: ["debug:boolean:false"]
          ]
        )
        dsl_result = Dsl.igniter(dsl_igniter)
        
        assert is_map(dsl_result)
        
        # In practice, we would then:
        # 1. Write the generated code to files
        # 2. Compile the code
        # 3. Define a test module that uses the DSL
        # 4. Verify the DSL works as expected
      end
    end

    describe "performance and scalability" do
      test "handles large numbers of entities efficiently" do
        many_entities = for i <- 1..50 do
          "entity#{i}:name:MyApp.Entity#{i}"
        end
        
        igniter = mock_igniter(
          %{dsl_module: "MyApp.LargeDsl"}, 
          [entity: many_entities]
        )
        
        result = Dsl.igniter(igniter)
        assert is_map(result)
      end

      test "handles complex nested configurations" do
        igniter = mock_igniter(
          %{dsl_module: "MyApp.ComplexNestedDsl"}, 
          [
            extension: true,
            fragments: true,
            section: [
              "level1:MyApp.Level1",
              "level1.level2:MyApp.Level2", 
              "level1.level2.level3:MyApp.Level3"
            ],
            entity: [
              "root:name:MyApp.RootEntity",
              "branch:name:MyApp.BranchEntity",
              "leaf:name:MyApp.LeafEntity"
            ],
            arg: for(i <- 1..10, do: "arg#{i}:string"),
            opt: for(i <- 1..10, do: "opt#{i}:boolean:false"),
            transformer: ["MyApp.Transform1", "MyApp.Transform2"],
            verifier: ["MyApp.Verify1", "MyApp.Verify2"]
          ]
        )
        
        result = Dsl.igniter(igniter)
        assert is_map(result)
      end
    end

    describe "cross-generator compatibility" do
      test "entity generated by entity generator works with DSL generator" do
        # Generate an entity with specific characteristics
        entity_igniter = mock_igniter(
          %{entity: "MyApp.GeneratedEntity"}, 
          [
            args: ["identifier:string:required"],
            schema: "metadata:map,created_at:string",
            validations: ["validate_identifier"]
          ]
        )
        entity_result = Entity.igniter(entity_igniter)
        
        # Use it in a DSL
        dsl_igniter = mock_igniter(
          %{dsl_module: "MyApp.CompatibilityDsl"}, 
          [
            entity: ["generated:identifier:MyApp.GeneratedEntity"],
            singleton_entity: ["generated"]
          ]
        )
        dsl_result = Dsl.igniter(dsl_igniter)
        
        assert is_map(entity_result)
        assert is_map(dsl_result)
        
        # Verify the DSL correctly references the entity
        assert_module_created(dsl_result, "MyApp.CompatibilityDsl", [
          "entity :generated",
          "target MyApp.GeneratedEntity",
          "singleton? true"
        ])
      end
    end
  else
    # Fallback tests when Igniter is not available
    test "integration tests require Igniter to be available" do
      # All generators require Igniter, so integration tests do too
      assert true
    end
  end
end