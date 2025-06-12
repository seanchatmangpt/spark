defmodule EvolutionEnginePropertyTest do
  use ExUnit.Case
  use ExUnitProperties
  
  alias EvolutionEngine.{GeneticAlgorithm, Population, Fitness, Selection}
  
  describe "Property-based genetic algorithm testing" do
    property "population size remains constant through generations" do
      check all population_size <- integer(10..100),
                generations <- integer(1..10),
                mutation_rate <- float(min: 0.0, max: 0.3),
                crossover_rate <- float(min: 0.5, max: 1.0) do
        
        config = %{
          population_size: population_size,
          max_generations: generations,
          mutation_rate: mutation_rate,
          crossover_rate: crossover_rate,
          elite_size: div(population_size, 10)
        }
        
        initial_population = Population.initialize(population_size, :simple_genome)
        result = GeneticAlgorithm.evolve(initial_population, config)
        
        # Population size should remain constant
        assert length(result.final_population) == population_size
        
        # Each generation should maintain size
        for gen_data <- result.generation_history do
          assert length(gen_data.population) == population_size
        end
      end
    end
    
    property "fitness never decreases with elitism" do
      check all population_size <- integer(20..50),
                elite_size <- integer(2..10),
                generations <- integer(2..5) do
        
        config = %{
          population_size: population_size,
          max_generations: generations,
          mutation_rate: 0.1,
          crossover_rate: 0.8,
          elite_size: min(elite_size, div(population_size, 2))
        }
        
        initial_population = Population.initialize(population_size, :fitness_genome)
        result = GeneticAlgorithm.evolve(initial_population, config)
        
        # Extract best fitness from each generation
        fitness_progression = Enum.map(result.generation_history, fn gen ->
          gen.population
          |> Enum.map(&Fitness.evaluate/1)
          |> Enum.max()
        end)
        
        # With elitism, best fitness should never decrease
        for {current, next} <- Enum.zip(fitness_progression, tl(fitness_progression)) do
          assert next >= current, "Fitness decreased: #{current} -> #{next}"
        end
      end
    end
    
    property "mutation rate affects genetic diversity" do
      check all population_size <- integer(30..60),
                low_mutation <- float(min: 0.01, max: 0.05),
                high_mutation <- float(min: 0.2, max: 0.4) do
        
        base_config = %{
          population_size: population_size,
          max_generations: 5,
          crossover_rate: 0.8,
          elite_size: 3
        }
        
        low_config = Map.put(base_config, :mutation_rate, low_mutation)
        high_config = Map.put(base_config, :mutation_rate, high_mutation)
        
        initial_pop = Population.initialize(population_size, :diversity_genome)
        
        low_result = GeneticAlgorithm.evolve(initial_pop, low_config)
        high_result = GeneticAlgorithm.evolve(initial_pop, high_config)
        
        low_diversity = Population.calculate_diversity(low_result.final_population)
        high_diversity = Population.calculate_diversity(high_result.final_population)
        
        # Higher mutation should generally maintain more diversity
        # Allow some tolerance due to randomness
        assert high_diversity >= low_diversity * 0.8
      end
    end
    
    property "selection pressure affects convergence speed" do
      check all population_size <- integer(40..80),
                low_pressure <- integer(2..3),    # Tournament size
                high_pressure <- integer(8..12) do
        
        base_config = %{
          population_size: population_size,
          max_generations: 10,
          mutation_rate: 0.1,
          crossover_rate: 0.8,
          elite_size: 4
        }
        
        low_config = Map.put(base_config, :selection_pressure, low_pressure)
        high_config = Map.put(base_config, :selection_pressure, high_pressure)
        
        initial_pop = Population.initialize(population_size, :convergence_genome)
        
        low_result = GeneticAlgorithm.evolve(initial_pop, low_config)
        high_result = GeneticAlgorithm.evolve(initial_pop, high_config)
        
        # Measure convergence by fitness improvement rate
        low_improvement = calculate_improvement_rate(low_result.generation_history)
        high_improvement = calculate_improvement_rate(high_result.generation_history)
        
        # Higher selection pressure should converge faster
        assert high_improvement >= low_improvement * 0.9
      end
    end
  end
  
  describe "Genome mutation properties" do
    property "mutation preserves genome structure" do
      check all genome_size <- integer(5..20),
                mutation_rate <- float(min: 0.1, max: 0.9) do
        
        original_genome = %{
          entities: for(i <- 1..genome_size, do: %{id: i, data: "entity_#{i}"}),
          metadata: %{size: genome_size, type: :test}
        }
        
        individual = %{genome: original_genome, fitness: 0.5}
        mutated = EvolutionEngine.Mutation.apply(individual, mutation_rate)
        
        # Structure should be preserved
        assert Map.has_key?(mutated.genome, :entities)
        assert Map.has_key?(mutated.genome, :metadata)
        assert is_list(mutated.genome.entities)
        assert is_map(mutated.genome.metadata)
        
        # Entity count should be similar (allowing for add/remove mutations)
        original_count = length(original_genome.entities)
        mutated_count = length(mutated.genome.entities)
        assert abs(mutated_count - original_count) <= max(1, div(original_count, 4))
      end
    end
    
    property "crossover produces valid offspring" do
      check all parent1_size <- integer(3..15),
                parent2_size <- integer(3..15) do
        
        parent1 = %{
          genome: %{
            entities: for(i <- 1..parent1_size, do: %{id: i, source: :parent1}),
            config: %{optimization: :speed}
          },
          fitness: 0.8
        }
        
        parent2 = %{
          genome: %{
            entities: for(i <- 1..parent2_size, do: %{id: i + 100, source: :parent2}),
            config: %{optimization: :memory}
          },
          fitness: 0.7
        }
        
        offspring = EvolutionEngine.Crossover.uniform(parent1, parent2)
        
        # Offspring should have valid structure
        assert Map.has_key?(offspring.genome, :entities)
        assert Map.has_key?(offspring.genome, :config)
        assert is_list(offspring.genome.entities)
        
        # Should have traits from both parents
        entity_sources = Enum.map(offspring.genome.entities, & &1.source)
        assert :parent1 in entity_sources or :parent2 in entity_sources
        
        # Size should be reasonable
        offspring_size = length(offspring.genome.entities)
        min_size = min(parent1_size, parent2_size)
        max_size = max(parent1_size, parent2_size)
        assert offspring_size >= div(min_size, 2)
        assert offspring_size <= max_size * 2
      end
    end
  end
  
  describe "Fitness landscape properties" do
    property "fitness function is deterministic" do
      check all entities <- list_of(string(:alphanumeric, min_length: 1, max_length: 10), min_length: 1, max_length: 20),
                complexity <- integer(1..10) do
        
        genome = %{
          entities: Enum.map(entities, &%{name: &1, complexity: complexity}),
          relationships: [],
          metadata: %{version: 1}
        }
        
        individual = %{genome: genome, fitness: nil}
        
        # Multiple evaluations should yield same result
        fitness1 = Fitness.evaluate(individual)
        fitness2 = Fitness.evaluate(individual)
        fitness3 = Fitness.evaluate(individual)
        
        assert fitness1 == fitness2
        assert fitness2 == fitness3
      end
    end
    
    property "fitness increases with beneficial traits" do
      check all base_entities <- integer(1..5),
                additional_entities <- integer(0..10),
                relationship_count <- integer(0..8) do
        
        base_genome = %{
          entities: for(i <- 1..base_entities, do: %{name: "Entity#{i}", type: :model}),
          relationships: [],
          validations: []
        }
        
        enhanced_genome = %{
          entities: for(i <- 1..(base_entities + additional_entities), do: %{name: "Entity#{i}", type: :model}),
          relationships: for(i <- 1..relationship_count, do: %{from: "Entity1", to: "Entity#{i+1}", type: :has_many}),
          validations: [:presence, :uniqueness]
        }
        
        base_individual = %{genome: base_genome, fitness: nil}
        enhanced_individual = %{genome: enhanced_genome, fitness: nil}
        
        base_fitness = Fitness.evaluate(base_individual)
        enhanced_fitness = Fitness.evaluate(enhanced_individual)
        
        # Enhanced genome should generally have higher fitness
        if additional_entities > 0 or relationship_count > 0 do
          assert enhanced_fitness >= base_fitness
        end
      end
    end
  end
  
  # Helper functions
  defp calculate_improvement_rate(generation_history) do
    if length(generation_history) < 2 do
      0.0
    else
      first_gen = hd(generation_history)
      last_gen = List.last(generation_history)
      
      first_best = first_gen.population |> Enum.map(&Fitness.evaluate/1) |> Enum.max()
      last_best = last_gen.population |> Enum.map(&Fitness.evaluate/1) |> Enum.max()
      
      if first_best > 0 do
        (last_best - first_best) / first_best
      else
        last_best
      end
    end
  end
end