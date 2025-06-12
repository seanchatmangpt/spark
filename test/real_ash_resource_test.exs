defmodule RealAshResourceTest do
  use ExUnit.Case, async: false
  
  @moduledoc """
  Zach Daniel: REAL Ash resource testing with actual resource compilation,
  action execution, and relationship resolution. This tests actual Ash behavior.
  """
  
  # Zach: Real Ash resources for testing
  defmodule User do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets,
      extensions: [Ash.Resource.Change.Builtins]
    
    ets do
      private? true
    end
    
    attributes do
      uuid_primary_key :id
      
      attribute :email, :string do
        allow_nil? false
        constraints [
          match: ~r/^[^\s]+@[^\s]+\.[^\s]+$/
        ]
      end
      
      attribute :name, :string do
        allow_nil? false
        constraints [
          min_length: 2,
          max_length: 50
        ]
      end
      
      attribute :age, :integer do
        constraints [
          min: 0,
          max: 150
        ]
      end
      
      attribute :active, :boolean do
        default true
      end
      
      timestamps()
    end
    
    relationships do
      has_many :posts, Post do
        destination_attribute :author_id
      end
      
      has_many :comments, Comment do
        destination_attribute :author_id
      end
      
      has_one :profile, Profile do
        destination_attribute :user_id
      end
    end
    
    actions do
      defaults [:create, :read, :update, :destroy]
      
      create :register do
        accept [:email, :name, :age]
        
        validate present([:email, :name])
        validate match(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
        
        change fn changeset, _context ->
          Ash.Changeset.change_attribute(changeset, :active, true)
        end
      end
      
      update :deactivate do
        accept []
        
        change fn changeset, _context ->
          Ash.Changeset.change_attribute(changeset, :active, false)
        end
      end
      
      read :active_users do
        filter expr(active == true)
      end
      
      read :by_email do
        argument :email, :string, allow_nil?: false
        filter expr(email == ^arg(:email))
      end
    end
    
    calculations do
      calculate :full_name, :string, expr(name <> " (" <> email <> ")") do
        load [:name, :email]
      end
      
      calculate :post_count, :integer, expr(count(posts)) do
        load :posts
      end
    end
    
    validations do
      validate present([:email, :name])
      validate match(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
    end
  end
  
  defmodule Post do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets
    
    ets do
      private? true
    end
    
    attributes do
      uuid_primary_key :id
      
      attribute :title, :string do
        allow_nil? false
        constraints [min_length: 1, max_length: 200]
      end
      
      attribute :content, :string do
        allow_nil? false
      end
      
      attribute :published, :boolean do
        default false
      end
      
      attribute :author_id, :uuid do
        allow_nil? false
      end
      
      timestamps()
    end
    
    relationships do
      belongs_to :author, User do
        source_attribute :author_id
        destination_attribute :id
      end
      
      has_many :comments, Comment do
        destination_attribute :post_id
      end
    end
    
    actions do
      defaults [:create, :read, :update, :destroy]
      
      create :publish do
        accept [:title, :content, :author_id]
        
        change fn changeset, _context ->
          Ash.Changeset.change_attribute(changeset, :published, true)
        end
      end
      
      read :published do
        filter expr(published == true)
      end
      
      read :by_author do
        argument :author_id, :uuid, allow_nil?: false
        filter expr(author_id == ^arg(:author_id))
      end
    end
    
    calculations do
      calculate :comment_count, :integer, expr(count(comments)) do
        load :comments
      end
    end
  end
  
  defmodule Comment do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets
    
    ets do
      private? true
    end
    
    attributes do
      uuid_primary_key :id
      
      attribute :content, :string do
        allow_nil? false
        constraints [min_length: 1]
      end
      
      attribute :author_id, :uuid do
        allow_nil? false
      end
      
      attribute :post_id, :uuid do
        allow_nil? false
      end
      
      timestamps()
    end
    
    relationships do
      belongs_to :author, User do
        source_attribute :author_id
        destination_attribute :id
      end
      
      belongs_to :post, Post do
        source_attribute :post_id
        destination_attribute :id
      end
    end
    
    actions do
      defaults [:create, :read, :update, :destroy]
    end
  end
  
  defmodule Profile do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Ets
    
    ets do
      private? true
    end
    
    attributes do
      uuid_primary_key :id
      
      attribute :bio, :string
      attribute :website, :string
      attribute :user_id, :uuid, allow_nil?: false
      
      timestamps()
    end
    
    relationships do
      belongs_to :user, User do
        source_attribute :user_id
        destination_attribute :id
      end
    end
    
    actions do
      defaults [:create, :read, :update, :destroy]
    end
  end
  
  # Zach: Real Ash API
  defmodule Api do
    use Ash.Api
    
    resources do
      resource User
      resource Post
      resource Comment
      resource Profile
    end
  end
  
  setup do
    # Zach: Clean ETS tables before each test
    for resource <- [User, Post, Comment, Profile] do
      try do
        Ash.DataLayer.Ets.start(resource, nil)
      rescue
        _ -> :ok
      end
    end
    
    :ok
  end
  
  describe "Real Ash Resource Creation and Validation" do
    test "creates user with valid attributes" do
      # Zach: Test actual Ash resource creation with real validation
      assert {:ok, user} = Api.create(User, %{
        email: "test@example.com",
        name: "Test User",
        age: 25
      })
      
      assert user.email == "test@example.com"
      assert user.name == "Test User"
      assert user.age == 25
      assert user.active == true  # Default value
      assert user.id != nil
      assert user.inserted_at != nil
      assert user.updated_at != nil
    end
    
    test "validates required attributes" do
      # Zach: Test real Ash validation errors
      assert {:error, error} = Api.create(User, %{
        age: 25
        # Missing required email and name
      })
      
      assert %Ash.Error.Invalid{} = error
      errors = error.errors
      
      # Should have validation errors for missing fields
      assert Enum.any?(errors, fn error ->
        match?(%Ash.Error.Changes.Required{field: :email}, error)
      end)
      
      assert Enum.any?(errors, fn error ->
        match?(%Ash.Error.Changes.Required{field: :name}, error)
      end)
    end
    
    test "validates email format" do
      assert {:error, error} = Api.create(User, %{
        email: "invalid-email",
        name: "Test User"
      })
      
      assert %Ash.Error.Invalid{} = error
      # Should have validation error for invalid email format
      assert Enum.any?(error.errors, fn err ->
        String.contains?(Exception.message(err), "email")
      end)
    end
    
    test "validates attribute constraints" do
      # Test name length constraints
      assert {:error, error} = Api.create(User, %{
        email: "test@example.com",
        name: "A"  # Too short
      })
      
      assert %Ash.Error.Invalid{} = error
      
      # Test age constraints
      assert {:error, error} = Api.create(User, %{
        email: "test@example.com",
        name: "Test User",
        age: -5  # Invalid age
      })
      
      assert %Ash.Error.Invalid{} = error
    end
  end
  
  describe "Real Ash Actions and Custom Logic" do
    test "register action applies custom logic" do
      # Zach: Test custom Ash action with changes
      assert {:ok, user} = Api.action(User, :register, %{
        email: "register@example.com",
        name: "Registered User",
        age: 30
      })
      
      assert user.email == "register@example.com"
      assert user.active == true  # Should be set by custom change
    end
    
    test "deactivate action modifies user state" do
      # Create user first
      {:ok, user} = Api.create(User, %{
        email: "deactivate@example.com",
        name: "User To Deactivate"
      })
      
      assert user.active == true
      
      # Deactivate using custom action
      assert {:ok, deactivated_user} = Api.action(user, :deactivate)
      
      assert deactivated_user.active == false
      assert deactivated_user.id == user.id
    end
    
    test "filtered read actions work correctly" do
      # Create active and inactive users
      {:ok, active_user} = Api.create(User, %{
        email: "active@example.com",
        name: "Active User",
        active: true
      })
      
      {:ok, inactive_user} = Api.create(User, %{
        email: "inactive@example.com", 
        name: "Inactive User",
        active: false
      })
      
      # Test active_users filter
      {:ok, active_users} = Api.action(User, :active_users)
      
      active_emails = Enum.map(active_users, & &1.email)
      assert "active@example.com" in active_emails
      refute "inactive@example.com" in active_emails
    end
    
    test "parameterized read actions work correctly" do
      {:ok, user} = Api.create(User, %{
        email: "findme@example.com",
        name: "Find Me"
      })
      
      # Test by_email action with argument
      {:ok, [found_user]} = Api.action(User, :by_email, %{email: "findme@example.com"})
      
      assert found_user.id == user.id
      assert found_user.email == "findme@example.com"
      
      # Test with non-existent email
      {:ok, []} = Api.action(User, :by_email, %{email: "notfound@example.com"})
    end
  end
  
  describe "Real Ash Relationships and Loading" do
    test "creates and loads has_many relationships" do
      # Create user
      {:ok, user} = Api.create(User, %{
        email: "author@example.com",
        name: "Author User"
      })
      
      # Create posts for the user
      {:ok, post1} = Api.create(Post, %{
        title: "First Post",
        content: "Content of first post",
        author_id: user.id
      })
      
      {:ok, post2} = Api.create(Post, %{
        title: "Second Post", 
        content: "Content of second post",
        author_id: user.id
      })
      
      # Load user with posts
      {:ok, user_with_posts} = Api.load(user, :posts)
      
      assert length(user_with_posts.posts) == 2
      post_titles = Enum.map(user_with_posts.posts, & &1.title)
      assert "First Post" in post_titles
      assert "Second Post" in post_titles
    end
    
    test "creates and loads belongs_to relationships" do
      {:ok, user} = Api.create(User, %{
        email: "postauthor@example.com",
        name: "Post Author"
      })
      
      {:ok, post} = Api.create(Post, %{
        title: "Test Post",
        content: "Test content",
        author_id: user.id
      })
      
      # Load post with author
      {:ok, post_with_author} = Api.load(post, :author)
      
      assert post_with_author.author.id == user.id
      assert post_with_author.author.email == "postauthor@example.com"
    end
    
    test "creates and loads nested relationships" do
      # Create user
      {:ok, user} = Api.create(User, %{
        email: "nested@example.com",
        name: "Nested User"
      })
      
      # Create post
      {:ok, post} = Api.create(Post, %{
        title: "Post with Comments",
        content: "This post will have comments",
        author_id: user.id
      })
      
      # Create comments
      {:ok, comment1} = Api.create(Comment, %{
        content: "First comment",
        author_id: user.id,
        post_id: post.id
      })
      
      {:ok, comment2} = Api.create(Comment, %{
        content: "Second comment",
        author_id: user.id,
        post_id: post.id
      })
      
      # Load user with posts and comments on posts
      {:ok, user_with_nested} = Api.load(user, posts: [:comments])
      
      assert length(user_with_nested.posts) == 1
      post_with_comments = hd(user_with_nested.posts)
      assert length(post_with_comments.comments) == 2
      
      comment_contents = Enum.map(post_with_comments.comments, & &1.content)
      assert "First comment" in comment_contents
      assert "Second comment" in comment_contents
    end
    
    test "loads has_one relationships" do
      {:ok, user} = Api.create(User, %{
        email: "profile@example.com",
        name: "Profile User"
      })
      
      {:ok, profile} = Api.create(Profile, %{
        bio: "This is my bio",
        website: "https://example.com",
        user_id: user.id
      })
      
      {:ok, user_with_profile} = Api.load(user, :profile)
      
      assert user_with_profile.profile.id == profile.id
      assert user_with_profile.profile.bio == "This is my bio"
    end
  end
  
  describe "Real Ash Calculations" do
    test "calculations work with loaded data" do
      {:ok, user} = Api.create(User, %{
        email: "calc@example.com",
        name: "Calc User"
      })
      
      # Test full_name calculation
      {:ok, user_with_calc} = Api.load(user, :full_name)
      
      expected_full_name = "Calc User (calc@example.com)"
      assert user_with_calc.full_name == expected_full_name
    end
    
    test "aggregate calculations work correctly" do
      {:ok, user} = Api.create(User, %{
        email: "aggregate@example.com",
        name: "Aggregate User"
      })
      
      # Create posts
      for i <- 1..3 do
        Api.create(Post, %{
          title: "Post #{i}",
          content: "Content #{i}",
          author_id: user.id
        })
      end
      
      # Test post_count calculation
      {:ok, user_with_count} = Api.load(user, :post_count)
      
      assert user_with_count.post_count == 3
    end
    
    test "nested aggregate calculations" do
      {:ok, user} = Api.create(User, %{
        email: "nested_agg@example.com",
        name: "Nested Agg User"
      })
      
      {:ok, post} = Api.create(Post, %{
        title: "Post with Comments",
        content: "Content",
        author_id: user.id
      })
      
      # Create comments
      for i <- 1..5 do
        Api.create(Comment, %{
          content: "Comment #{i}",
          author_id: user.id,
          post_id: post.id
        })
      end
      
      # Test comment_count calculation on post
      {:ok, post_with_count} = Api.load(post, :comment_count)
      
      assert post_with_count.comment_count == 5
    end
  end
  
  describe "Real Ash Query Performance" do
    test "bulk operations perform efficiently" do
      # Create many users to test bulk performance
      start_time = System.monotonic_time(:microsecond)
      
      users = for i <- 1..100 do
        {:ok, user} = Api.create(User, %{
          email: "bulk#{i}@example.com",
          name: "Bulk User #{i}",
          age: 20 + rem(i, 50)
        })
        user
      end
      
      creation_time = System.monotonic_time(:microsecond) - start_time
      
      # Should create 100 users in reasonable time (less than 1 second)
      assert creation_time < 1_000_000
      assert length(users) == 100
      
      # Test bulk read performance
      read_start = System.monotonic_time(:microsecond)
      {:ok, all_users} = Api.read(User)
      read_time = System.monotonic_time(:microsecond) - read_start
      
      # Should read all users quickly
      assert read_time < 100_000  # Less than 100ms
      assert length(all_users) >= 100
    end
    
    test "complex queries with relationships perform adequately" do
      # Create complex data structure
      {:ok, user} = Api.create(User, %{
        email: "complex@example.com",
        name: "Complex User"
      })
      
      # Create many posts with comments
      for i <- 1..20 do
        {:ok, post} = Api.create(Post, %{
          title: "Post #{i}",
          content: "Content #{i}",
          author_id: user.id
        })
        
        # Add comments to each post
        for j <- 1..5 do
          Api.create(Comment, %{
            content: "Comment #{j} on post #{i}",
            author_id: user.id,
            post_id: post.id
          })
        end
      end
      
      # Test complex query performance
      query_start = System.monotonic_time(:microsecond)
      
      {:ok, user_with_data} = Api.load(user, [
        :posts,
        posts: [:comments],
        :post_count
      ])
      
      query_time = System.monotonic_time(:microsecond) - query_start
      
      # Complex query should complete in reasonable time
      assert query_time < 500_000  # Less than 500ms
      
      # Verify data loaded correctly
      assert length(user_with_data.posts) == 20
      assert user_with_data.post_count == 20
      
      # Verify comments loaded
      total_comments = Enum.sum(Enum.map(user_with_data.posts, fn post ->
        length(post.comments)
      end))
      assert total_comments == 100  # 20 posts * 5 comments each
    end
  end
end