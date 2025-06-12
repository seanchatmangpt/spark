defmodule IntegrationTest do
  @moduledoc """
  Real integration test for our DSLs in a real Spark environment.
  """
  
  use ExUnit.Case
  
  describe "HttpApiDsl integration" do
    test "compiles and works with basic routes" do
      defmodule TestApi do
        use HttpApiDsl
        
        routes do
          route :get, "/users", :list_users
          route :post, "/users", :create_user
        end
      end
      
      assert Code.ensure_loaded?(TestApi)
      
      # Test Info module functions work
      routes = HttpApiDsl.Info.routes(TestApi)
      assert length(routes) == 2
      
      get_route = Enum.find(routes, &(&1.method == :get))
      assert get_route.path == "/users"
      assert get_route.handler == :list_users
      # Should have default CORS middleware
      assert :cors in get_route.middleware
      
      post_route = Enum.find(routes, &(&1.method == :post))
      # Should have CORS + CSRF middleware
      assert :cors in post_route.middleware
      assert :csrf in post_route.middleware
    end
    
    test "validates middleware references" do
      assert_raise Spark.Error.DslError, ~r/undefined middleware: nonexistent/, fn ->
        defmodule BadApi do
          use HttpApiDsl
          
          routes do
            route :get, "/test", :test_handler, middleware: [:nonexistent]
          end
        end
      end
    end
    
    test "works with custom middleware" do
      defmodule CustomApi do
        use HttpApiDsl
        
        middlewares do
          middleware :rate_limit, options: [max_requests: 100]
        end
        
        routes do
          route :get, "/limited", :limited_handler, middleware: [:rate_limit]
        end
      end
      
      routes = HttpApiDsl.Info.routes(CustomApi)
      limited_route = hd(routes)
      
      assert :cors in limited_route.middleware
      assert :rate_limit in limited_route.middleware
    end
    
    test "generates OpenAPI spec" do
      defmodule ApiForSpec do
        use HttpApiDsl
        
        routes do
          route :get, "/posts", :list_posts
          route :post, "/posts", :create_post
        end
      end
      
      spec = HttpApiDsl.Info.to_openapi(ApiForSpec, %{"title" => "Test API"})
      
      assert spec["openapi"] == "3.0.0"
      assert spec["info"]["title"] == "Test API"
      assert Map.has_key?(spec["paths"], "/posts")
      assert Map.has_key?(spec["paths"]["/posts"], :get)
      assert Map.has_key?(spec["paths"]["/posts"], :post)
    end
  end
  
  describe "SimpleDatabaseDsl integration" do
    test "compiles and works with basic tables" do
      defmodule TestSchema do
        use SimpleDatabaseDsl
        
        tables do
          table :users
          table :posts, primary_key: :uuid
        end
      end
      
      assert Code.ensure_loaded?(TestSchema)
      
      tables = SimpleDatabaseDsl.Info.tables(TestSchema)
      assert length(tables) == 2
      
      users_table = Enum.find(tables, &(&1.name == :users))
      assert users_table.primary_key == :id
      assert users_table.timestamps == true
      
      posts_table = Enum.find(tables, &(&1.name == :posts))
      assert posts_table.primary_key == :uuid
      assert posts_table.timestamps == true
    end
    
    test "validates at least one table required" do
      assert_raise Spark.Error.DslError, ~r/At least one table must be defined/, fn ->
        defmodule EmptySchema do
          use SimpleDatabaseDsl
        end
      end
    end
  end
  
  describe "Real Spark integration" do
    test "Info modules are generated correctly" do
      # Test that InfoGenerator functions are available
      assert function_exported?(HttpApiDsl.Info, :routes, 1)
      assert function_exported?(HttpApiDsl.Info, :middlewares, 1)
      assert function_exported?(SimpleDatabaseDsl.Info, :tables, 1)
      
      defmodule InfoTestApi do
        use HttpApiDsl
        
        routes do
          route :get, "/test", :test_handler
        end
      end
      
      routes = HttpApiDsl.Info.routes(InfoTestApi)
      assert is_list(routes)
      assert length(routes) == 1
      
      route = hd(routes)
      assert route.method == :get
      assert route.path == "/test"
      assert route.handler == :test_handler
    end
    
    test "transformers run during compilation" do
      defmodule TransformerTestApi do
        use HttpApiDsl
        
        routes do
          route :post, "/secure", :secure_handler
        end
      end
      
      routes = HttpApiDsl.Info.routes(TransformerTestApi)
      secure_route = hd(routes)
      
      # Transformer should have added default middleware
      assert :cors in secure_route.middleware
      assert :csrf in secure_route.middleware
      assert :auth in secure_route.middleware
    end
    
    test "verifiers catch errors during compilation" do
      # This should work - using custom middleware that's defined
      defmodule ValidCustomApi do
        use HttpApiDsl
        
        middlewares do
          middleware :custom_auth
        end
        
        routes do
          route :get, "/protected", :protected_handler, middleware: [:custom_auth]
        end
      end
      
      # This should fail - using undefined middleware
      assert_raise Spark.Error.DslError, fn ->
        defmodule InvalidCustomApi do
          use HttpApiDsl
          
          routes do
            route :get, "/protected", :protected_handler, middleware: [:undefined_middleware]
          end
        end
      end
    end
    
    test "error messages are helpful" do
      try do
        defmodule BadMiddlewareApi do
          use HttpApiDsl
          
          routes do
            route :get, "/test", :test_handler, middleware: [:missing_middleware]
          end
        end
      rescue
        error ->
          assert error.message =~ "undefined middleware: missing_middleware"
          assert error.path == [:routes]
      end
    end
  end
  
  describe "Real world scenarios" do
    test "blog API with authentication" do
      defmodule BlogApi do
        use HttpApiDsl
        
        middlewares do
          middleware :rate_limit, options: [max_requests: 1000]
          middleware :cache, options: [ttl: 300]
        end
        
        routes do
          # Public routes
          route :get, "/posts", :list_posts, middleware: [:cache]
          route :get, "/posts/:slug", :get_post, middleware: [:cache]
          
          # Admin routes (get default auth middleware)
          route :post, "/admin/posts", :create_post, middleware: [:rate_limit]
          route :put, "/admin/posts/:id", :update_post
          route :delete, "/admin/posts/:id", :delete_post
        end
      end
      
      routes = HttpApiDsl.Info.routes(BlogApi)
      assert length(routes) == 5
      
      # Check public routes
      list_posts = Enum.find(routes, &(&1.path == "/posts"))
      assert :cors in list_posts.middleware
      assert :cache in list_posts.middleware
      refute :auth in list_posts.middleware
      
      # Check admin routes
      create_post = Enum.find(routes, &(&1.path == "/admin/posts"))
      assert :cors in create_post.middleware
      assert :csrf in create_post.middleware
      assert :auth in create_post.middleware
      assert :rate_limit in create_post.middleware
      
      delete_post = Enum.find(routes, &(&1.path == "/admin/posts/:id"))
      assert :cors in delete_post.middleware
      assert :csrf in delete_post.middleware
      assert :auth in delete_post.middleware
    end
    
    test "database schema with multiple tables" do
      defmodule BlogSchema do
        use SimpleDatabaseDsl
        
        tables do
          table :authors, primary_key: :uuid
          table :posts
          table :comments, timestamps: false
        end
      end
      
      tables = SimpleDatabaseDsl.Info.tables(BlogSchema)
      assert length(tables) == 3
      
      authors = Enum.find(tables, &(&1.name == :authors))
      assert authors.primary_key == :uuid
      assert authors.timestamps == true
      
      posts = Enum.find(tables, &(&1.name == :posts))
      assert posts.primary_key == :id
      assert posts.timestamps == true
      
      comments = Enum.find(tables, &(&1.name == :comments))
      assert comments.primary_key == :id
      assert comments.timestamps == false
    end
  end
end