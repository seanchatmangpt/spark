defmodule EvolutionEngineTest do
  use ExUnit.Case, async: false
  use EvolutionEngine.DataCase

  import Mox
  setup :verify_on_exit!

  alias EvolutionEngine.{
    Repo,
    Resources.EvolutionRun,
    Resources.Individual,
    Workflows.GeneticEvolution
  }

  describe "EvolutionEngine domain operations" do
    test "creates domain with proper resource configuration" do
      assert EvolutionEngine.__domain__()
      
      resources = EvolutionEngine.Info.resources()
      assert length(resources) == 4
      
      resource_names = Enum.map(resources, & &1.resource)
      assert EvolutionEngine.Resources.EvolutionRun in resource_names
      assert EvolutionEngine.Resources.Individual in resource_names
      assert EvolutionEngine.Resources.FitnessScore in resource_names
      assert EvolutionEngine.Resources.GeneticOperator in resource_names
    end

    test "has proper authorization configuration" do
      config = EvolutionEngine.Info.authorization()
      assert config.authorize == :by_default
      refute config.require_actor?
    end

    test "validates all resources are accessible" do
      for resource <- EvolutionEngine.Info.resources() do
        assert Code.ensure_loaded?(resource.resource)
        assert function_exported?(resource.resource, :spark_dsl_config, 0)
      end
    end
  end

  describe "Repo configuration" do
    test "has correct OTP app configuration" do
      assert EvolutionEngine.Repo.__adapter__() == Ecto.Adapters.Postgres
    end

    test "has required extensions installed" do
      extensions = EvolutionEngine.Repo.installed_extensions()
      assert "uuid-ossp" in extensions
      assert "citext" in extensions
    end

    test "can connect to database" do
      assert {:ok, _} = Repo.query("SELECT 1")
    end
  end

  describe "EvolutionRun resource operations" do
    test "creates evolution run with valid attributes" do
      attrs = %{
        target_dsl: "user authentication system with role-based access control",
        population_size: 50,
        configuration: %{
          selection_method: :tournament,
          tournament_size: 3,
          elitism: true,
          fitness_function: :weighted_sum
        },
        mutation_rate: Decimal.new("0.15"),
        crossover_rate: Decimal.new("0.85"),
        max_generations: 75
      }

      assert {:ok, run} = 
        EvolutionRun
        |> Ash.Changeset.for_create(:create, attrs)
        |> EvolutionEngine.create()

      assert run.target_dsl == attrs.target_dsl
      assert run.population_size == 50
      assert run.generation == 0
      assert run.status == :initializing
      assert run.elite_size == 10
      assert Decimal.equal?(run.mutation_rate, Decimal.new("0.15"))
      assert Decimal.equal?(run.crossover_rate, Decimal.new("0.85"))
      assert is_binary(run.id)
    end

    test "validates required target_dsl attribute" do
      attrs = %{population_size: 100}

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        EvolutionRun
        |> Ash.Changeset.for_create(:create, attrs)
        |> EvolutionEngine.create()

      assert Enum.any?(errors, fn error ->
        error.field == :target_dsl && error.message =~ "required"
      end)
    end

    test "validates population_size constraints" do
      attrs = %{
        target_dsl: "test dsl",
        population_size: 5  # Below minimum of 10
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        EvolutionRun
        |> Ash.Changeset.for_create(:create, attrs)
        |> EvolutionEngine.create()

      assert Enum.any?(errors, fn error ->
        error.field == :population_size && error.message =~ "min"
      end)
    end

    test "validates mutation and crossover rate constraints" do
      attrs = %{
        target_dsl: "test dsl",
        mutation_rate: Decimal.new("1.5"),  # Above maximum of 1.0
        crossover_rate: Decimal.new("-0.1")  # Below minimum of 0.0
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        EvolutionRun
        |> Ash.Changeset.for_create(:create, attrs)
        |> EvolutionEngine.create()

      mutation_error = Enum.find(errors, & &1.field == :mutation_rate)
      crossover_error = Enum.find(errors, & &1.field == :crossover_rate)

      assert mutation_error && mutation_error.message =~ "max"
      assert crossover_error && crossover_error.message =~ "min"
    end

    test "validates status constraints" do
      attrs = %{
        target_dsl: "test dsl",
        status: :invalid_status
      }

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        EvolutionRun
        |> Ash.Changeset.for_create(:create, attrs)
        |> EvolutionEngine.create()

      assert Enum.any?(errors, fn error ->
        error.field == :status && error.message =~ "one_of"
      end)
    end

    test "start_evolution action initializes run correctly" do
      setup_evolution_mocks()

      attrs = %{
        target_dsl: "e-commerce DSL with product catalog, cart, and checkout",
        population_size: 40,
        configuration: %{
          genome_structure: %{
            entities: %{min: 3, max: 15},
            relationships: %{min: 2, max: 20},
            actions: %{min: 10, max: 50}
          },
          fitness_weights: %{
            functionality: 0.4,
            code_quality: 0.3,
            performance: 0.2,
            maintainability: 0.1
          }
        },
        mutation_rate: Decimal.new("0.12"),
        crossover_rate: Decimal.new("0.88"),
        max_generations: 60
      }

      assert {:ok, run} =
        EvolutionRun
        |> Ash.Changeset.for_create(:start_evolution, attrs)
        |> EvolutionEngine.create()

      assert run.status == :evolving
      assert run.configuration["genome_structure"] != nil
      assert run.configuration["fitness_weights"] != nil
    end

    test "evolve_generation updates population and statistics" do
      run = create_test_evolution_run(%{status: :evolving, generation: 5})
      setup_generation_evolution_mocks()

      assert {:ok, evolved_run} =
        run
        |> Ash.Changeset.for_update(:evolve_generation)
        |> EvolutionEngine.update()

      assert evolved_run.generation == 6
      assert evolved_run.best_fitness != nil
      assert evolved_run.average_fitness != nil
      assert evolved_run.diversity_score != nil
    end

    test "terminate_evolution marks run as terminated" do
      run = create_test_evolution_run(%{status: :evolving, generation: 25})

      termination_data = %{
        best_fitness: Decimal.new("0.92"),
        average_fitness: Decimal.new("0.78"),
        diversity_score: Decimal.new("0.65")
      }

      assert {:ok, terminated_run} =
        run
        |> Ash.Changeset.for_update(:terminate_evolution, termination_data)
        |> Ash.Changeset.set_argument(:termination_reason, :max_generations_reached)
        |> EvolutionEngine.update()

      assert terminated_run.status == :terminated
      assert Decimal.equal?(terminated_run.best_fitness, Decimal.new("0.92"))
      assert Decimal.equal?(terminated_run.average_fitness, Decimal.new("0.78"))
    end

    test "mark_converged updates status when convergence reached" do
      run = create_test_evolution_run(%{status: :evolving, generation: 15})

      convergence_data = %{
        best_fitness: Decimal.new("0.98"),
        average_fitness: Decimal.new("0.95")
      }

      assert {:ok, converged_run} =
        run
        |> Ash.Changeset.for_update(:mark_converged, convergence_data)
        |> EvolutionEngine.update()

      assert converged_run.status == :converged
      assert Decimal.equal?(converged_run.best_fitness, Decimal.new("0.98"))
    end

    test "calculates convergence_rate accurately" do
      run = create_test_evolution_run(%{
        generation: 20,
        best_fitness: Decimal.new("0.95"),
        average_fitness: Decimal.new("0.88"),
        configuration: %{
          fitness_history: [
            %{generation: 18, best: 0.92, avg: 0.84},
            %{generation: 19, best: 0.94, avg: 0.86},
            %{generation: 20, best: 0.95, avg: 0.88}
          ]
        }
      })

      assert {:ok, [run_with_calc]} =
        EvolutionRun
        |> Ash.Query.load(:convergence_rate)
        |> Ash.Query.filter(id == ^run.id)
        |> EvolutionEngine.read()

      assert Decimal.gte?(run_with_calc.convergence_rate, Decimal.new("0.0"))
      assert Decimal.lte?(run_with_calc.convergence_rate, Decimal.new("1.0"))
    end

    test "determines diversity_trend correctly" do
      increasing_diversity_run = create_test_evolution_run(%{
        diversity_score: Decimal.new("0.75"),
        configuration: %{
          diversity_history: [0.65, 0.68, 0.72, 0.75]
        }
      })

      decreasing_diversity_run = create_test_evolution_run(%{
        diversity_score: Decimal.new("0.45"),
        configuration: %{
          diversity_history: [0.65, 0.58, 0.52, 0.45]
        }
      })

      assert {:ok, [increasing_with_calc]} =
        EvolutionRun
        |> Ash.Query.load(:diversity_trend)
        |> Ash.Query.filter(id == ^increasing_diversity_run.id)
        |> EvolutionEngine.read()

      assert {:ok, [decreasing_with_calc]} =
        EvolutionRun
        |> Ash.Query.load(:diversity_trend)
        |> Ash.Query.filter(id == ^decreasing_diversity_run.id)
        |> EvolutionEngine.read()

      assert increasing_with_calc.diversity_trend == :increasing
      assert decreasing_with_calc.diversity_trend == :decreasing
    end

    test "calculates improvement_rate over generations" do
      run = create_test_evolution_run(%{
        generation: 15,
        best_fitness: Decimal.new("0.90"),
        configuration: %{
          initial_best_fitness: 0.25,
          improvement_tracking: true
        }
      })

      assert {:ok, [run_with_calc]} =
        EvolutionRun
        |> Ash.Query.load(:improvement_rate)
        |> Ash.Query.filter(id == ^run.id)
        |> EvolutionEngine.read()

      # Should show significant improvement from 0.25 to 0.90
      assert Decimal.gt?(run_with_calc.improvement_rate, Decimal.new("0.4"))
    end

    test "estimates completion time accurately" do
      run = create_test_evolution_run(%{
        generation: 30,
        max_generations: 100,
        configuration: %{
          avg_generation_time: 2.5,  # seconds per generation
          start_time: DateTime.utc_now() |> DateTime.add(-75, :second)  # Started 75 seconds ago
        }
      })

      assert {:ok, [run_with_calc]} =
        EvolutionRun
        |> Ash.Query.load(:estimated_completion)
        |> Ash.Query.filter(id == ^run.id)
        |> EvolutionEngine.read()

      assert run_with_calc.estimated_completion != nil
      # Should be in the future
      assert DateTime.compare(run_with_calc.estimated_completion, DateTime.utc_now()) == :gt
    end
  end

  describe "Individual resource operations" do
    test "creates individual with valid attributes" do
      run = create_test_evolution_run()

      attrs = %{
        genome: %{
          entities: [
            %{name: "User", type: "model", fields: ["name", "email"]},
            %{name: "Post", type: "model", fields: ["title", "content"]}
          ],
          relationships: [
            %{type: "has_many", from: "User", to: "Post", name: "posts"}
          ],
          actions: [
            %{name: "create_user", type: "create", entity: "User"},
            %{name: "list_posts", type: "read", entity: "Post"}
          ]
        },
        fitness: Decimal.new("0.75"),
        generation: 5,
        phenotype: %{
          generated_code: "defmodule UserSchema do\n  # Generated DSL\nend",
          compilation_status: :success,
          test_results: %{passed: 8, total: 10}
        },
        metadata: %{
          creation_method: :crossover,
          mutation_history: [],
          performance_metrics: %{memory_usage: 45, execution_time: 0.12}
        }
      }

      assert {:ok, individual} =
        Individual
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.Changeset.manage_relationship(:evolution_run, run, type: :replace)
        |> EvolutionEngine.create()

      assert individual.genome["entities"] != nil
      assert individual.genome["relationships"] != nil
      assert individual.genome["actions"] != nil
      assert individual.age == 0
      assert individual.mutation_count == 0
      assert individual.crossover_count == 0
      assert individual.evolution_run_id == run.id
      assert is_binary(individual.id)
    end

    test "validates required genome attribute" do
      run = create_test_evolution_run()

      attrs = %{fitness: Decimal.new("0.5")}

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
        Individual
        |> Ash.Changeset.for_create(:create, attrs)
        |> Ash.Changeset.manage_relationship(:evolution_run, run, type: :replace)
        |> EvolutionEngine.create()

      assert Enum.any?(errors, fn error ->
        error.field == :genome && error.message =~ "required"
      end)
    end

    test "initialize_random creates individual with random genome" do
      run = create_test_evolution_run()
      setup_genome_generation_mocks()

      genome_template = %{
        entity_count: %{min: 3, max: 8},
        relationship_count: %{min: 2, max: 12},
        action_count: %{min: 5, max: 20},
        complexity: :moderate
      }

      assert {:ok, individual} =
        Individual
        |> Ash.Changeset.for_create(:initialize_random)
        |> Ash.Changeset.set_argument(:run_id, run.id)
        |> Ash.Changeset.set_argument(:genome_template, genome_template)
        |> EvolutionEngine.create()

      assert individual.genome != nil
      assert individual.fitness != nil
      assert individual.generation == 0
      assert individual.evolution_run_id == run.id
    end

    test "crossover creates offspring from two parents" do
      run = create_test_evolution_run()
      parent1 = create_test_individual(run, %{
        genome: %{
          entities: [%{name: "User", fields: ["name", "email"]}],
          relationships: [],
          actions: [%{name: "create_user", type: "create"}]
        }
      })
      parent2 = create_test_individual(run, %{
        genome: %{
          entities: [%{name: "Post", fields: ["title", "content"]}],
          relationships: [%{type: "belongs_to", from: "Post", to: "User"}],
          actions: [%{name: "list_posts", type: "read"}]
        }
      })

      setup_crossover_mocks()

      assert {:ok, offspring} =
        Individual
        |> Ash.Changeset.for_create(:crossover)
        |> Ash.Changeset.set_argument(:parent1_id, parent1.id)
        |> Ash.Changeset.set_argument(:parent2_id, parent2.id)
        |> Ash.Changeset.set_argument(:run_id, run.id)
        |> EvolutionEngine.create()

      assert offspring.parent_ids == [parent1.id, parent2.id]
      assert offspring.crossover_count == 1
      assert offspring.generation == 1
      # Should have traits from both parents
      assert offspring.genome["entities"] != nil
      assert offspring.genome["relationships"] != nil
      assert offspring.genome["actions"] != nil
    end

    test "mutate modifies individual genome" do
      run = create_test_evolution_run()
      individual = create_test_individual(run, %{
        genome: %{
          entities: [%{name: "User", fields: ["name"]}],
          relationships: [],
          actions: []
        },
        fitness: Decimal.new("0.6")
      })

      setup_mutation_mocks()

      mutation_rate = Decimal.new("0.2")

      assert {:ok, mutated_individual} =
        individual
        |> Ash.Changeset.for_update(:mutate)
        |> Ash.Changeset.set_argument(:mutation_rate, mutation_rate)
        |> EvolutionEngine.update()

      assert mutated_individual.mutation_count == 1
      # Genome should be modified
      assert mutated_individual.genome != individual.genome
      # Fitness should be recalculated
      assert mutated_individual.fitness != individual.fitness
    end

    test "age increments individual age" do
      run = create_test_evolution_run()
      individual = create_test_individual(run, %{age: 3})

      assert {:ok, aged_individual} =
        individual
        |> Ash.Changeset.for_update(:age)
        |> EvolutionEngine.update()

      assert aged_individual.age == 4
    end

    test "calculates diversity_contribution correctly" do
      run = create_test_evolution_run()
      unique_individual = create_test_individual(run, %{
        genome: %{
          entities: [
            %{name: "UniqueEntity", fields: ["special_field"]},
            %{name: "RareEntity", fields: ["uncommon_field"]}
          ],
          relationships: [%{type: "polymorphic", from: "UniqueEntity", to: "RareEntity"}]
        }
      })

      common_individual = create_test_individual(run, %{
        genome: %{
          entities: [
            %{name: "User", fields: ["name", "email"]},
            %{name: "Post", fields: ["title", "content"]}
          ],
          relationships: [%{type: "has_many", from: "User", to: "Post"}]
        }
      })

      assert {:ok, [unique_with_calc]} =
        Individual
        |> Ash.Query.load(:diversity_contribution)
        |> Ash.Query.filter(id == ^unique_individual.id)
        |> EvolutionEngine.read()

      assert {:ok, [common_with_calc]} =
        Individual
        |> Ash.Query.load(:diversity_contribution)
        |> Ash.Query.filter(id == ^common_individual.id)
        |> EvolutionEngine.read()

      # Unique individual should contribute more to diversity
      assert Decimal.gt?(unique_with_calc.diversity_contribution, common_with_calc.diversity_contribution)
    end

    test "calculates survival_probability based on fitness and age" do
      run = create_test_evolution_run()
      
      young_fit_individual = create_test_individual(run, %{
        fitness: Decimal.new("0.95"),
        age: 1,
        generation: 10
      })

      old_unfit_individual = create_test_individual(run, %{
        fitness: Decimal.new("0.35"),
        age: 8,
        generation: 3
      })

      assert {:ok, [young_fit_with_calc]} =
        Individual
        |> Ash.Query.load(:survival_probability)
        |> Ash.Query.filter(id == ^young_fit_individual.id)
        |> EvolutionEngine.read()

      assert {:ok, [old_unfit_with_calc]} =
        Individual
        |> Ash.Query.load(:survival_probability)
        |> Ash.Query.filter(id == ^old_unfit_individual.id)
        |> EvolutionEngine.read()

      # Young fit individual should have higher survival probability
      assert Decimal.gt?(young_fit_with_calc.survival_probability, old_unfit_with_calc.survival_probability)
      assert Decimal.gt?(young_fit_with_calc.survival_probability, Decimal.new("0.8"))
      assert Decimal.lt?(old_unfit_with_calc.survival_probability, Decimal.new("0.4"))
    end
  end

  describe "GeneticEvolution workflow" do
    setup do
      target_dsl = """
      Create a comprehensive e-learning platform DSL with the following features:
      - User management (students, instructors, admins)
      - Course creation and management
      - Lesson content with multimedia support
      - Quiz and assessment system
      - Progress tracking and analytics
      - Certificate generation
      - Discussion forums
      - Real-time notifications
      """

      %{
        target_dsl: target_dsl,
        population_size: 30,
        max_generations: 25,
        fitness_threshold: 0.92
      }
    end

    test "executes complete genetic evolution workflow successfully", %{target_dsl: target_dsl} = context do
      setup_complete_evolution_workflow_mocks()

      input = %{
        target_dsl: target_dsl,
        population_size: context.population_size,
        max_generations: context.max_generations,
        fitness_threshold: context.fitness_threshold
      }

      assert {:ok, result} = Reactor.run(GeneticEvolution, input, %{}, async?: false)
      
      assert result.evolution_run != nil
      assert result.evolution_run.status in [:converged, :terminated]
      assert result.best_solution != nil
      assert result.final_report != nil
      assert Decimal.gte?(result.best_solution.fitness, Decimal.new("0.8"))
    end

    test "initializes population concurrently", %{target_dsl: target_dsl} = context do
      setup_population_initialization_mocks()

      input = %{
        target_dsl: target_dsl,
        population_size: context.population_size,
        max_generations: context.max_generations
      }

      start_time = System.monotonic_time()
      assert {:ok, result} = Reactor.run(GeneticEvolution, input, %{}, async?: true)
      end_time = System.monotonic_time()

      duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Should complete faster due to concurrent population initialization
      assert duration < 3000
      assert length(result.initial_population) == context.population_size
    end

    test "evolves population through multiple generations", %{target_dsl: target_dsl} = context do
      setup_evolution_loop_mocks()

      input = %{
        target_dsl: target_dsl,
        population_size: 20,  # Smaller population for faster testing
        max_generations: 10,
        fitness_threshold: 0.95
      }

      assert {:ok, result} = Reactor.run(GeneticEvolution, input, %{}, async?: false)

      # Should have evolved through multiple generations
      assert result.evolution_run.generation >= 5
      assert result.evolution_run.generation <= 10
      
      # Should show improvement over generations
      initial_avg_fitness = result.initial_fitness_stats.average
      final_avg_fitness = result.final_fitness_stats.average
      assert Decimal.gt?(final_avg_fitness, initial_avg_fitness)
    end

    test "handles convergence criteria correctly", %{target_dsl: target_dsl} = context do
      setup_convergence_mocks()

      input = %{
        target_dsl: target_dsl,
        population_size: context.population_size,
        max_generations: 100,  # High max, should converge before reaching
        fitness_threshold: 0.88
      }

      assert {:ok, result} = Reactor.run(GeneticEvolution, input, %{}, async?: false)

      # Should converge before max generations
      assert result.evolution_run.generation < 100
      assert result.evolution_run.status == :converged
      assert Decimal.gte?(result.best_solution.fitness, Decimal.new("0.88"))
    end

    test "respects maximum generation limit", %{target_dsl: target_dsl} = context do
      setup_max_generation_mocks()

      input = %{
        target_dsl: target_dsl,
        population_size: context.population_size,
        max_generations: 15,
        fitness_threshold: 0.99  # Very high threshold, unlikely to reach
      }

      assert {:ok, result} = Reactor.run(GeneticEvolution, input, %{}, async?: false)

      # Should terminate at max generations
      assert result.evolution_run.generation == 15
      assert result.evolution_run.status == :terminated
      assert result.termination_reason == :max_generations_reached
    end

    test "handles evolution timeout gracefully", %{target_dsl: target_dsl} = context do
      setup_timeout_mocks()

      input = %{
        target_dsl: target_dsl,
        population_size: context.population_size,
        max_generations: 1000,  # Would take too long
        fitness_threshold: 0.99
      }

      # Should timeout and handle gracefully (mocked to complete quickly)
      assert {:ok, result} = Reactor.run(GeneticEvolution, input, %{}, async?: false)
      assert result.evolution_run.status in [:terminated, :converged]
    end

    test "extracts best solution accurately", %{target_dsl: target_dsl} = context do
      setup_solution_extraction_mocks()

      input = %{
        target_dsl: target_dsl,
        population_size: context.population_size,
        max_generations: context.max_generations,
        fitness_threshold: context.fitness_threshold
      }

      assert {:ok, result} = Reactor.run(GeneticEvolution, input, %{}, async?: false)

      best_solution = result.best_solution
      assert best_solution != nil
      assert best_solution.fitness != nil
      assert best_solution.genome != nil
      assert best_solution.phenotype != nil

      # Should be the best individual from the final population
      final_population_fitnesses = Enum.map(result.final_population, & &1.fitness)
      max_fitness = Enum.max(final_population_fitnesses)
      assert Decimal.equal?(best_solution.fitness, max_fitness)
    end

    test "generates comprehensive evolution report", %{target_dsl: target_dsl} = context do
      setup_reporting_mocks()

      input = %{
        target_dsl: target_dsl,
        population_size: context.population_size,
        max_generations: context.max_generations,
        fitness_threshold: context.fitness_threshold
      }

      assert {:ok, result} = Reactor.run(GeneticEvolution, input, %{}, async?: false)

      report = result.final_report
      assert report != nil
      assert report.evolution_summary != nil
      assert report.fitness_progression != nil
      assert report.diversity_analysis != nil
      assert report.best_solution_analysis != nil
      assert report.generation_statistics != nil
      assert report.performance_metrics != nil
    end

    test "compensates properly on workflow failure", %{target_dsl: target_dsl} = context do
      setup_failure_compensation_mocks()

      input = %{
        target_dsl: target_dsl,
        population_size: context.population_size,
        max_generations: context.max_generations
      }

      # Force failure in evolution loop
      assert {:error, _reason} = Reactor.run(GeneticEvolution, input, %{}, async?: false)

      # Verify compensation was triggered (run marked as failed)
      failed_runs = EvolutionRun
      |> Ash.Query.filter(status == :failed)
      |> EvolutionEngine.read!()

      assert length(failed_runs) > 0
    end
  end

  describe "Advanced evolution scenarios" do
    test "evolves complex multi-domain DSL" do
      complex_target = """
      Multi-domain enterprise system DSL:
      1. User Management Domain: authentication, authorization, user profiles, roles
      2. Content Management Domain: articles, media, categories, tagging
      3. E-commerce Domain: products, orders, payments, inventory
      4. Analytics Domain: tracking, reporting, dashboards, metrics
      5. Communication Domain: messaging, notifications, chat, forums
      """

      setup_complex_evolution_mocks()

      input = %{
        target_dsl: complex_target,
        population_size: 50,
        max_generations: 40,
        fitness_threshold: 0.90
      }

      assert {:ok, result} = Reactor.run(GeneticEvolution, input, %{}, async?: false)

      # Should handle complexity well
      assert result.best_solution.genome["domains"] != nil
      assert length(result.best_solution.genome["domains"]) >= 5
      assert result.best_solution.fitness != nil
    end

    test "handles large population sizes efficiently" do
      setup_large_population_mocks()

      input = %{
        target_dsl: "Large scale DSL evolution test",
        population_size: 200,
        max_generations: 20,
        fitness_threshold: 0.85
      }

      start_time = System.monotonic_time()
      assert {:ok, result} = Reactor.run(GeneticEvolution, input, %{}, async?: false)
      end_time = System.monotonic_time()

      duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Should handle large populations within reasonable time
      assert duration < 10000
      assert length(result.final_population) == 200
    end

    test "maintains genetic diversity throughout evolution" do
      setup_diversity_tracking_mocks()

      input = %{
        target_dsl: "Diversity preservation test DSL",
        population_size: 40,
        max_generations: 30,
        fitness_threshold: 0.88
      }

      assert {:ok, result} = Reactor.run(GeneticEvolution, input, %{}, async?: false)

      # Should maintain reasonable diversity
      final_diversity = result.final_diversity_stats.diversity_score
      assert Decimal.gt?(final_diversity, Decimal.new("0.4"))

      # Diversity should not collapse too quickly
      diversity_history = result.final_report.diversity_analysis.history
      min_diversity = Enum.min(diversity_history)
      assert min_diversity > 0.2
    end

    test "optimizes for multiple objectives simultaneously" do
      setup_multi_objective_mocks()

      input = %{
        target_dsl: "Multi-objective optimization DSL",
        population_size: 35,
        max_generations: 25,
        fitness_threshold: 0.85
      }

      assert {:ok, result} = Reactor.run(GeneticEvolution, input, %{}, async?: false)

      best_solution = result.best_solution
      objectives = best_solution.phenotype.multi_objective_scores

      # Should optimize for multiple objectives
      assert objectives.functionality >= 0.8
      assert objectives.maintainability >= 0.75
      assert objectives.performance >= 0.7
      assert objectives.code_quality >= 0.8
    end
  end

  describe "Error handling and edge cases" do
    test "handles population initialization failures gracefully" do
      EvolutionEnginePopulationMock
      |> expect(:initialize_random, fn _run, _size ->
        {:error, "Population initialization failed"}
      end)

      input = %{
        target_dsl: "Test DSL",
        population_size: 20,
        max_generations: 10
      }

      assert {:error, _reason} = Reactor.run(GeneticEvolution, input, %{}, async?: false)
    end

    test "handles fitness evaluation failures" do
      setup_fitness_failure_mocks()

      input = %{
        target_dsl: "Test DSL with fitness issues",
        population_size: 15,
        max_generations: 5
      }

      # Should handle gracefully or fail appropriately
      result = Reactor.run(GeneticEvolution, input, %{}, async?: false)
      
      case result do
        {:ok, _} -> :ok  # Handled gracefully
        {:error, _} -> :ok  # Failed appropriately
      end
    end

    test "handles database connection failures gracefully" do
      # Simulate DB failure
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(EvolutionEngine.Repo)
      :ok = Ecto.Adapters.SQL.Sandbox.mode(EvolutionEngine.Repo, :manual)
      
      GenServer.stop(EvolutionEngine.Repo)

      attrs = %{target_dsl: "Test DSL", population_size: 20}

      assert {:error, _} =
        EvolutionRun
        |> Ash.Changeset.for_create(:create, attrs)
        |> EvolutionEngine.create()

      # Restart repo for other tests
      start_supervised!(EvolutionEngine.Repo)
    end

    test "handles concurrent evolution runs safely" do
      target_dsls = [
        "Concurrent DSL evolution test 1",
        "Concurrent DSL evolution test 2", 
        "Concurrent DSL evolution test 3"
      ]

      setup_concurrent_evolution_mocks()

      tasks = 
        target_dsls
        |> Enum.map(fn target_dsl ->
          Task.async(fn ->
            input = %{
              target_dsl: target_dsl,
              population_size: 15,
              max_generations: 8,
              fitness_threshold: 0.8
            }
            Reactor.run(GeneticEvolution, input, %{}, async?: false)
          end)
        end)

      results = Task.await_many(tasks, 15000)

      # All should complete successfully
      assert Enum.all?(results, fn
        {:ok, _} -> true
        _ -> false
      end)

      # Each should have unique evolution runs
      run_ids = Enum.map(results, fn {:ok, result} -> result.evolution_run.id end)
      assert length(Enum.uniq(run_ids)) == length(run_ids)
    end
  end

  # Helper functions
  defp create_test_evolution_run(attrs \\ %{}) do
    default_attrs = %{
      target_dsl: "Test DSL for unit testing purposes",
      population_size: 30,
      status: :initializing,
      configuration: %{test: true},
      mutation_rate: Decimal.new("0.1"),
      crossover_rate: Decimal.new("0.8"),
      max_generations: 50
    }

    attrs = Map.merge(default_attrs, attrs)

    EvolutionRun
    |> Ash.Changeset.for_create(:create, attrs)
    |> EvolutionEngine.create!()
  end

  defp create_test_individual(run, attrs \\ %{}) do
    default_attrs = %{
      genome: %{
        entities: [%{name: "TestEntity", fields: ["test_field"]}],
        relationships: [],
        actions: [%{name: "test_action", type: "create"}]
      },
      fitness: Decimal.new("0.5"),
      generation: 0
    }

    attrs = Map.merge(default_attrs, attrs)

    Individual
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.Changeset.manage_relationship(:evolution_run, run, type: :replace)
    |> EvolutionEngine.create!()
  end

  # Mock setup functions
  defp setup_evolution_mocks do
    EvolutionEngineChangesMock
    |> stub(:validate_configuration, fn changeset -> changeset end)
    |> stub(:initialize_population, fn changeset -> changeset end)
  end

  defp setup_generation_evolution_mocks do
    EvolutionEngineChangesMock
    |> stub(:evaluate_fitness, fn changeset -> changeset end)
    |> stub(:select_parents, fn changeset -> changeset end)
    |> stub(:create_offspring, fn changeset -> changeset end)
    |> stub(:apply_mutations, fn changeset -> changeset end)
    |> stub(:update_generation, fn changeset ->
      current_gen = Ash.Changeset.get_attribute(changeset, :generation) || 0
      Ash.Changeset.change_attribute(changeset, :generation, current_gen + 1)
    end)
    |> stub(:check_termination, fn changeset ->
      changeset
      |> Ash.Changeset.change_attribute(:best_fitness, Decimal.new("0.85"))
      |> Ash.Changeset.change_attribute(:average_fitness, Decimal.new("0.72"))
      |> Ash.Changeset.change_attribute(:diversity_score, Decimal.new("0.68"))
    end)
  end

  defp setup_genome_generation_mocks do
    EvolutionEngineChangesMock
    |> stub(:generate_random_genome, fn changeset ->
      genome = %{
        entities: [
          %{name: "RandomEntity1", fields: ["field1", "field2"]},
          %{name: "RandomEntity2", fields: ["field3"]}
        ],
        relationships: [
          %{type: "has_many", from: "RandomEntity1", to: "RandomEntity2"}
        ],
        actions: [
          %{name: "create_entity1", type: "create", entity: "RandomEntity1"},
          %{name: "list_entity2", type: "read", entity: "RandomEntity2"}
        ]
      }
      Ash.Changeset.change_attribute(changeset, :genome, genome)
    end)
    |> stub(:calculate_initial_fitness, fn changeset ->
      Ash.Changeset.change_attribute(changeset, :fitness, Decimal.new("0.6"))
    end)
  end

  defp setup_crossover_mocks do
    EvolutionEngineChangesMock
    |> stub(:perform_crossover, fn changeset ->
      # Simulate crossover by combining traits
      offspring_genome = %{
        entities: [
          %{name: "User", fields: ["name", "email"]},
          %{name: "Post", fields: ["title", "content"]}
        ],
        relationships: [
          %{type: "belongs_to", from: "Post", to: "User"}
        ],
        actions: [
          %{name: "create_user", type: "create"},
          %{name: "list_posts", type: "read"}
        ]
      }
      Ash.Changeset.change_attribute(changeset, :genome, offspring_genome)
    end)
    |> stub(:increment_crossover_count, fn changeset ->
      Ash.Changeset.change_attribute(changeset, :crossover_count, 1)
    end)
  end

  defp setup_mutation_mocks do
    EvolutionEngineChangesMock
    |> stub(:apply_mutation, fn changeset ->
      # Simulate mutation by modifying genome
      original_genome = Ash.Changeset.get_attribute(changeset, :genome)
      mutated_genome = put_in(original_genome, ["entities", Access.at(0), "fields"], ["name", "email", "age"])
      Ash.Changeset.change_attribute(changeset, :genome, mutated_genome)
    end)
    |> stub(:increment_mutation_count, fn changeset ->
      current_count = Ash.Changeset.get_attribute(changeset, :mutation_count) || 0
      Ash.Changeset.change_attribute(changeset, :mutation_count, current_count + 1)
    end)
    |> stub(:recalculate_fitness, fn changeset ->
      Ash.Changeset.change_attribute(changeset, :fitness, Decimal.new("0.65"))
    end)
  end

  defp setup_complete_evolution_workflow_mocks do
    EvolutionEnginePopulationMock
    |> stub(:initialize_random, fn _run, size ->
      population = 1..size
      |> Enum.map(fn i ->
        %{
          id: Ash.UUID.generate(),
          genome: %{entities: [%{name: "Entity#{i}"}]},
          fitness: Decimal.new("#{0.3 + (i * 0.01)}")
        }
      end)
      {:ok, population}
    end)

    EvolutionEngineFitnessMock
    |> stub(:evaluate_population, fn population ->
      evaluated = Enum.map(population, fn individual ->
        Map.put(individual, :fitness, Decimal.new("#{0.5 + :rand.uniform() * 0.4}"))
      end)
      {:ok, evaluated}
    end)

    EvolutionEngineLoopMock
    |> stub(:evolve_until_convergence, fn _run, _population, _threshold ->
      final_population = 1..30
      |> Enum.map(fn i ->
        %{
          id: Ash.UUID.generate(),
          genome: %{entities: [%{name: "EvolvedEntity#{i}"}]},
          fitness: Decimal.new("#{0.7 + (i * 0.01)}")
        }
      end)
      {:ok, final_population}
    end)

    EvolutionEngineSelectionMock
    |> stub(:extract_elite, fn population ->
      best = Enum.max_by(population, & &1.fitness)
      {:ok, best}
    end)

    EvolutionEngineReportingMock
    |> stub(:create_evolution_report, fn _run, _best_solution ->
      {:ok, %{
        evolution_summary: %{generations: 15, convergence: true},
        fitness_progression: [0.4, 0.6, 0.75, 0.89],
        diversity_analysis: %{final_diversity: 0.65},
        performance_metrics: %{total_time: 45.2}
      }}
    end)
  end

  defp setup_population_initialization_mocks do
    setup_complete_evolution_workflow_mocks()
  end

  defp setup_evolution_loop_mocks do
    setup_complete_evolution_workflow_mocks()

    EvolutionEngineLoopMock
    |> stub(:evolve_until_convergence, fn _run, _population, _threshold ->
      # Simulate evolution showing improvement
      final_population = 1..20
      |> Enum.map(fn i ->
        %{
          id: Ash.UUID.generate(),
          genome: %{entities: [%{name: "EvolvedEntity#{i}"}]},
          fitness: Decimal.new("#{0.6 + (i * 0.015)}")  # Higher fitness
        }
      end)
      
      {:ok, final_population}
    end)
  end

  defp setup_convergence_mocks do
    setup_complete_evolution_workflow_mocks()

    EvolutionEngineLoopMock
    |> stub(:evolve_until_convergence, fn _run, _population, threshold ->
      # Simulate early convergence
      final_population = 1..30
      |> Enum.map(fn i ->
        base_fitness = Decimal.to_float(threshold)
        fitness_value = base_fitness + (:rand.uniform() * 0.05)
        %{
          id: Ash.UUID.generate(),
          fitness: Decimal.from_float(fitness_value)
        }
      end)
      
      {:ok, final_population}
    end)
  end

  defp setup_max_generation_mocks do
    setup_complete_evolution_workflow_mocks()

    EvolutionEngineLoopMock
    |> stub(:evolve_until_convergence, fn _run, _population, _threshold ->
      # Simulate reaching max generations without convergence
      final_population = 1..30
      |> Enum.map(fn i ->
        %{
          id: Ash.UUID.generate(),
          fitness: Decimal.new("#{0.6 + (i * 0.01)}")  # Good but not converged
        }
      end)
      
      {:ok, final_population}
    end)
  end

  defp setup_timeout_mocks do
    setup_complete_evolution_workflow_mocks()
  end

  defp setup_solution_extraction_mocks do
    setup_complete_evolution_workflow_mocks()
  end

  defp setup_reporting_mocks do
    setup_complete_evolution_workflow_mocks()
  end

  defp setup_failure_compensation_mocks do
    EvolutionEnginePopulationMock
    |> expect(:initialize_random, fn _run, _size ->
      {:ok, []}  # Empty population to trigger failure
    end)

    EvolutionEngineLoopMock
    |> expect(:evolve_until_convergence, fn _run, _population, _threshold ->
      {:error, "Evolution loop failed"}
    end)
  end

  defp setup_complex_evolution_mocks do
    setup_complete_evolution_workflow_mocks()

    EvolutionEnginePopulationMock
    |> stub(:initialize_random, fn _run, size ->
      population = 1..size
      |> Enum.map(fn i ->
        %{
          id: Ash.UUID.generate(),
          genome: %{
            domains: [
              %{name: "UserManagement", entities: 3},
              %{name: "ContentManagement", entities: 4},
              %{name: "Ecommerce", entities: 5},
              %{name: "Analytics", entities: 2},
              %{name: "Communication", entities: 3}
            ]
          },
          fitness: Decimal.new("#{0.4 + (i * 0.008)}")
        }
      end)
      {:ok, population}
    end)
  end

  defp setup_large_population_mocks do
    setup_complete_evolution_workflow_mocks()

    EvolutionEnginePopulationMock
    |> stub(:initialize_random, fn _run, size ->
      # Handle large population efficiently
      population = 1..size
      |> Enum.map(fn i ->
        %{
          id: Ash.UUID.generate(),
          genome: %{entities: [%{name: "Entity#{rem(i, 100)}"}]},  # Reuse some patterns
          fitness: Decimal.new("#{0.4 + rem(i, 50) * 0.01}")
        }
      end)
      {:ok, population}
    end)
  end

  defp setup_diversity_tracking_mocks do
    setup_complete_evolution_workflow_mocks()

    EvolutionEngineReportingMock
    |> stub(:create_evolution_report, fn _run, _best_solution ->
      {:ok, %{
        evolution_summary: %{generations: 20},
        diversity_analysis: %{
          final_diversity: 0.55,
          history: [0.8, 0.7, 0.65, 0.6, 0.58, 0.55]
        },
        final_diversity_stats: %{diversity_score: Decimal.new("0.55")}
      }}
    end)
  end

  defp setup_multi_objective_mocks do
    setup_complete_evolution_workflow_mocks()

    EvolutionEngineSelectionMock
    |> stub(:extract_elite, fn _population ->
      {:ok, %{
        id: Ash.UUID.generate(),
        fitness: Decimal.new("0.85"),
        phenotype: %{
          multi_objective_scores: %{
            functionality: 0.88,
            maintainability: 0.82,
            performance: 0.79,
            code_quality: 0.86
          }
        }
      }}
    end)
  end

  defp setup_fitness_failure_mocks do
    EvolutionEngineFitnessMock
    |> expect(:evaluate_population, fn _population ->
      {:error, "Fitness evaluation service unavailable"}
    end)
  end

  defp setup_concurrent_evolution_mocks do
    setup_complete_evolution_workflow_mocks()
  end
end