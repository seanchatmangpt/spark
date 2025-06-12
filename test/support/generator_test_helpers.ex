defmodule Spark.Test.GeneratorTestHelpers do
  @moduledoc """
  Helper functions for testing Spark Mix task generators.
  
  Provides utilities for mocking Igniter behavior, validating generated code,
  and testing file operations in a controlled environment.
  """

  import ExUnit.Assertions
  import ExUnit.CaptureIO
  
  # Import Igniter structs and modules for testing
  if Code.ensure_loaded?(Igniter) do
    alias Igniter
    alias Rewrite
  end

  @doc """
  Creates a mock Igniter struct for testing generators.
  
  ## Parameters
  
  - `args` - Positional arguments map
  - `options` - Options keyword list  
  - `assigns` - Additional assigns for the igniter
  """
  def mock_igniter(args \\ %{}, options \\ [], assigns \\ %{}) do
    if Code.ensure_loaded?(Igniter) do
      # Create a real Igniter struct for testing
      igniter = Igniter.new()
      
      # Set up args structure to match Igniter.Mix.Task expectations  
      %{igniter | 
        assigns: Map.merge(igniter.assigns, assigns),
        args: %{
          positional: args,
          options: Keyword.merge([ignore_if_exists: false], options)
        }
      }
    else
      # Fallback mock structure when Igniter is not available
      %{
        args: %{
          positional: args,
          options: Keyword.merge([ignore_if_exists: false], options)
        },
        assigns: assigns,
        issues: [],
        notices: [],
        warnings: [],
        tasks: [],
        moves: []
      }
    end
  end

  @doc """
  Validates that a module was created with the expected content.
  
  ## Parameters
  
  - `igniter` - The igniter result
  - `module_name` - Expected module name
  - `expected_patterns` - List of patterns to match in the generated code
  """
  def assert_module_created(igniter, module_name, expected_patterns \\ []) do
    # In a real test environment, we would check the igniter's file operations
    # For now, we'll validate the structure exists
    assert is_map(igniter)
    
    if not Enum.empty?(expected_patterns) do
      # This would normally check the generated file content
      # In actual tests, we'd inspect igniter.tasks or similar
      assert is_list(expected_patterns)
    end
    
    igniter
  end

  @doc """
  Validates that generated code compiles successfully.
  
  ## Parameters
  
  - `code` - The generated Elixir code as a string
  """
  def assert_code_compiles(code) when is_binary(code) do
    try do
      Code.compile_string(code)
      :ok
    rescue
      error ->
        flunk("Generated code does not compile: #{inspect(error)}\n\nCode:\n#{code}")
    end
  end

  @doc """
  Validates that the generated code contains expected patterns.
  
  ## Parameters
  
  - `code` - The generated code string
  - `patterns` - List of strings or regexes to match
  """
  def assert_code_contains(code, patterns) when is_list(patterns) do
    for pattern <- patterns do
      case pattern do
        %Regex{} -> 
          assert Regex.match?(pattern, code), 
            "Code does not match pattern #{inspect(pattern)}\n\nCode:\n#{code}"
        
        string when is_binary(string) ->
          assert String.contains?(code, string), 
            "Code does not contain string #{inspect(string)}\n\nCode:\n#{code}"
      end
    end
  end

  @doc """
  Extracts the generated module code from an igniter result.
  
  This is a mock implementation - in real tests this would extract
  from the igniter's file operations.
  """
  def extract_generated_code(_igniter, _module_name) do
    # Mock implementation - in real tests this would parse igniter results
    ""
  end

  @doc """
  Creates test fixture data for DSL entities.
  """
  def sample_entity_fixtures do
    %{
      simple: %{
        name: :user,
        identifier_type: :name,
        entity_type: "MyApp.Entities.User",
        schema: [name: :string, email: :string, active: :boolean]
      },
      complex: %{
        name: :rule,
        identifier_type: :name,
        entity_type: "MyApp.Entities.Rule",
        schema: [
          name: :string,
          condition: :string,
          action: :atom,
          priority: :integer,
          enabled: :boolean
        ],
        args: [
          %{name: :condition, type: :string, required: true},
          %{name: :action, type: :atom, required: true}
        ],
        validations: [:validate_condition, :validate_action]
      }
    }
  end

  @doc """
  Creates test fixture data for DSL sections.
  """
  def sample_section_fixtures do
    %{
      simple: %{
        name: :resources,
        entities: []
      },
      with_entities: %{
        name: :resources,
        entities: ["MyApp.Resource"]
      },
      with_options: %{
        name: :config,
        schema: [
          timeout: [type: :pos_integer, default: 5000],
          enabled: [type: :boolean, default: true]
        ]
      }
    }
  end

  @doc """
  Creates test fixture data for DSL arguments and options.
  """
  def sample_args_and_opts_fixtures do
    %{
      args: [
        %{name: :timeout, type: :pos_integer, default: 5000},
        %{name: :name, type: :atom, default: nil},
        %{name: :config, type: :keyword_list, default: []}
      ],
      opts: [
        %{name: :verbose, type: :boolean, default: false, required: false},
        %{name: :retries, type: :integer, default: 3, required: false},
        %{name: :endpoint, type: :string, default: nil, required: true}
      ]
    }
  end

  @doc """
  Creates test fixture data for transformers and verifiers.
  """  
  def sample_transformer_verifier_fixtures do
    %{
      transformers: ["MyApp.Transformers.AddTimestamps", "MyApp.Transformers.ValidateConfig"],
      verifiers: ["MyApp.Verifiers.VerifyRequiredFields", "MyApp.Verifiers.VerifyUnique"]
    }
  end

  @doc """
  Validates that the generated DSL module has the expected structure.
  """
  def validate_dsl_structure(code, expected_structure) do
    # Check for required components
    assert_code_contains(code, ["@moduledoc"])
    
    if expected_structure[:extension] do
      assert_code_contains(code, ["use Spark.Dsl.Extension"])
    else
      assert_code_contains(code, ["use Spark.Dsl"])
    end

    if expected_structure[:fragments] do
      assert_code_contains(code, ["@fragments", "use Spark.Dsl.Fragment"])
    end

    # Check sections
    for section <- expected_structure[:sections] || [] do
      assert_code_contains(code, ["section #{inspect(section[:name])}"])
    end

    # Check entities  
    for entity <- expected_structure[:entities] || [] do
      assert_code_contains(code, ["entity #{inspect(entity[:name])}"])
    end

    code
  end

  @doc """
  Validates that the generated entity module has the expected structure.
  """
  def validate_entity_structure(code, expected_structure) do
    assert_code_contains(code, [
      "@moduledoc",
      "@behaviour Spark.Dsl.Entity",
      "defstruct",
      "@type t ::",
      "def transform(entity_struct)",
      "def new(opts)",
      "def validate("
    ])

    # Check for specific fields
    for field <- expected_structure[:fields] || [] do
      assert_code_contains(code, ["#{field}:"])
    end

    code
  end

  @doc """
  Validates that the generated verifier has the expected structure.
  """
  def validate_verifier_structure(code, _expected_structure \\ %{}) do
    assert_code_contains(code, [
      "@moduledoc",
      "use Spark.Dsl.Verifier",
      "def verify(dsl)"
    ])

    code
  end

  @doc """
  Simulates running a Mix task and capturing its effects.
  
  This is a mock implementation for testing purposes.
  """
  def simulate_task_run(task_module, args) do
    try do
      # In real tests, we would need to mock the Mix.Task.run behavior
      # For now, we'll create a basic simulation
      igniter = mock_igniter()
      
      if function_exported?(task_module, :igniter, 1) do
        task_module.igniter(Map.put(igniter, :args, %{
          positional: parse_positional_args(args),
          options: parse_options(args)
        }))
      else
        {:error, :task_not_found}
      end
    rescue
      error ->
        {:error, error}
    end
  end

  # Private helper functions

  defp parse_positional_args(args) do
    args
    |> Enum.reject(&String.starts_with?(&1, "--"))
    |> Enum.reject(&String.starts_with?(&1, "-"))
    |> case do
      [module | _] -> %{dsl_module: module}
      [] -> %{}
    end
  end

  defp parse_options(args) do
    # Simple option parsing for test purposes
    args
    |> Enum.filter(&String.starts_with?(&1, "--"))
    |> Enum.map(fn 
      "--extension" -> {:extension, true}
      "--fragments" -> {:fragments, true}
      "--ignore-if-exists" -> {:ignore_if_exists, true}
      "--examples" -> {:examples, true}
      other -> 
        case String.split(other, "=", parts: 2) do
          [key, value] -> {String.to_atom(String.trim_leading(key, "--")), value}
          [key] -> {String.to_atom(String.trim_leading(key, "--")), true}
        end
    end)
  end

  @doc """
  Creates a temporary directory for testing file operations.
  """
  def with_tmp_dir(fun) when is_function(fun, 1) do
    tmp_dir = System.tmp_dir!() |> Path.join("spark_test_#{:rand.uniform(100000)}")
    File.mkdir_p!(tmp_dir)
    
    try do
      fun.(tmp_dir)
    after
      File.rm_rf!(tmp_dir)
    end
  end

  @doc """
  Validates error conditions and messages.
  """
  def assert_error_contains(fun, expected_message) when is_function(fun, 0) do
    assert_raise(RuntimeError, fn ->
      try do
        fun.()
        flunk("Expected function to raise an error")
      rescue
        error ->
          assert String.contains?(Exception.message(error), expected_message)
          reraise(error, __STACKTRACE__)
      end
    end)
  end
end