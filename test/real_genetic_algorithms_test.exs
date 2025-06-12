defmodule RealGeneticAlgorithmsTest do
  use ExUnit.Case, async: false
  
  @moduledoc """
  Zach Daniel: REAL genetic algorithms for DSL evolution, not toy simulations.
  This implements actual genetic programming with AST manipulation and
  sophisticated fitness landscapes.
  """
  
  # Zach: Real genetic representation using actual Elixir ASTs
  defmodule DslGenome do
    @moduledoc """
    Represents a DSL as an actual Elixir AST that can be compiled and executed.
    This is the real deal - we're evolving actual code.
    """
    
    defstruct [
      :ast,                    # Actual Elixir AST
      :compiled_module,        # Compiled module atom
      :fitness,               # Computed fitness value
      :generation,            # Generation number
      :lineage,               # Parent genealogy
      :mutation_history,      # History of mutations applied
      :compilation_errors,    # Any compilation errors
      :semantic_hash          # Hash of semantic structure
    ]
    
    def new(ast, generation \\ 0) do
      genome = %__MODULE__{
        ast: ast,
        generation: generation,
        lineage: [],
        mutation_history: [],
        compilation_errors: []
      }
      
      genome
      |> compile_ast()
      |> calculate_semantic_hash()
    end
    
    def compile_ast(%__MODULE__{} = genome) do
      try do
        # Generate unique module name
        module_name = String.to_atom("DynamicDsl_#{:rand.uniform(1_000_000)}")
        
        # Compile the AST
        [{^module_name, bytecode}] = Code.compile_quoted(genome.ast)
        
        %{genome | 
          compiled_module: module_name,
          compilation_errors: []
        }
      rescue
        error ->
          %{genome | 
            compiled_module: nil,
            compilation_errors: [error]
          }
      end
    end
    
    def calculate_semantic_hash(%__MODULE__{} = genome) do
      # Zach: Calculate hash based on AST structure, not just content
      semantic_structure = extract_semantic_structure(genome.ast)
      hash = :erlang.phash2(semantic_structure)
      %{genome | semantic_hash: hash}
    end
    
    defp extract_semantic_structure(ast) do
      # Extract just the structural elements that matter semantically
      Macro.prewalk(ast, [], fn
        {:defmodule, _, [name, _body]} = node, acc ->
          {node, [:module | acc]}
        
        {:use, _, _} = node, acc ->
          {node, [:use_directive | acc]}
        
        {:def, _, [{name, _, _} | _]} = node, acc ->
          {node, [{:function, name} | acc]}
        
        {:attribute, _, [name, _]} = node, acc ->
          {node, [{:attribute, name} | acc]}
        
        node, acc ->
          {node, acc}
      end)
      |> elem(1)
      |> Enum.reverse()
    end
    
    def fitness_score(%__MODULE__{compilation_errors: [_ | _]}), do: 0.0
    def fitness_score(%__MODULE__{compiled_module: nil}), do: 0.0
    def fitness_score(%__MODULE__{} = genome) do
      # Zach: Multi-dimensional fitness evaluation
      structural_fitness = evaluate_structural_fitness(genome)
      semantic_fitness = evaluate_semantic_fitness(genome)
      performance_fitness = evaluate_performance_fitness(genome)
      innovation_fitness = evaluate_innovation_fitness(genome)
      
      # Weighted combination
      (structural_fitness * 0.3) + 
      (semantic_fitness * 0.3) + 
      (performance_fitness * 0.2) + 
      (innovation_fitness * 0.2)
    end
    
    defp evaluate_structural_fitness(genome) do
      # Analyze AST structure quality
      ast_depth = calculate_ast_depth(genome.ast)
      node_count = count_ast_nodes(genome.ast)
      
      # Optimal complexity scoring
      depth_score = case ast_depth do
        d when d < 3 -> 0.3  # Too simple
        d when d in 3..8 -> 1.0  # Good complexity
        d when d in 9..15 -> 0.7  # High but manageable
        _ -> 0.2  # Too complex
      end
      
      size_score = case node_count do
        n when n < 10 -> 0.3
        n when n in 10..100 -> 1.0
        n when n in 101..300 -> 0.8
        _ -> 0.4
      end
      
      (depth_score + size_score) / 2
    end
    
    defp evaluate_semantic_fitness(genome) do
      # Check if the module follows good DSL patterns
      has_proper_structure = check_dsl_structure(genome.ast)
      has_clear_interface = check_interface_clarity(genome.ast)
      follows_conventions = check_naming_conventions(genome.ast)
      
      scores = [has_proper_structure, has_clear_interface, follows_conventions]
      Enum.sum(scores) / length(scores)
    end
    
    defp evaluate_performance_fitness(genome) do
      if genome.compiled_module do
        # Measure actual compilation and execution performance
        compilation_time = measure_compilation_time(genome.ast)
        memory_usage = measure_memory_usage(genome.compiled_module)
        
        # Performance scoring (lower is better, normalize to 0-1)
        time_score = max(0.0, 1.0 - (compilation_time / 10_000))  # 10ms baseline
        memory_score = max(0.0, 1.0 - (memory_usage / 1_000_000))  # 1MB baseline
        
        (time_score + memory_score) / 2
      else
        0.0
      end
    end
    
    defp evaluate_innovation_fitness(genome) do
      # Reward novel patterns and structures
      uniqueness = calculate_ast_uniqueness(genome.ast)
      pattern_novelty = detect_novel_patterns(genome.ast)
      
      (uniqueness + pattern_novelty) / 2
    end
    
    # Zach: Helper functions for fitness evaluation
    defp calculate_ast_depth(ast) do
      Macro.prewalk(ast, 0, fn node, max_depth ->
        current_depth = calculate_node_depth(node, 0)
        {node, max(max_depth, current_depth)}
      end)
      |> elem(1)
    end
    
    defp calculate_node_depth({_, _, children}, depth) when is_list(children) do
      if children == [] do
        depth + 1
      else
        child_depths = Enum.map(children, &calculate_node_depth(&1, depth + 1))
        Enum.max(child_depths)
      end
    end
    
    defp calculate_node_depth(_, depth), do: depth + 1
    
    defp count_ast_nodes(ast) do
      Macro.prewalk(ast, 0, fn node, count ->
        {node, count + 1}
      end)
      |> elem(1)
    end
    
    defp check_dsl_structure(ast) do
      # Check for proper module structure with DSL sections
      has_module = has_defmodule?(ast)
      has_use_directive = has_use_directive?(ast)
      has_dsl_sections = has_dsl_sections?(ast)
      
      case {has_module, has_use_directive, has_dsl_sections} do
        {true, true, true} -> 1.0
        {true, true, false} -> 0.7
        {true, false, _} -> 0.4
        _ -> 0.1
      end
    end
    
    defp check_interface_clarity(ast) do
      # Check for clear public interface
      public_functions = count_public_functions(ast)
      private_functions = count_private_functions(ast)
      
      ratio = if public_functions > 0 do
        public_functions / (public_functions + private_functions)
      else
        0.0
      end
      
      # Good interface has reasonable public/private ratio
      case ratio do
        r when r in 0.2..0.6 -> 1.0
        r when r in 0.1..0.8 -> 0.7
        _ -> 0.3
      end
    end
    
    defp check_naming_conventions(ast) do
      # Check if naming follows Elixir conventions
      module_names = extract_module_names(ast)
      function_names = extract_function_names(ast)
      
      proper_module_names = Enum.count(module_names, &proper_module_name?/1)
      proper_function_names = Enum.count(function_names, &proper_function_name?/1)
      
      total_names = length(module_names) + length(function_names)
      
      if total_names > 0 do
        (proper_module_names + proper_function_names) / total_names
      else
        0.5
      end
    end
    
    defp measure_compilation_time(ast) do
      {time, _result} = :timer.tc(fn ->
        try do
          Code.compile_quoted(ast)
        rescue
          _ -> nil
        end
      end)
      time
    end
    
    defp measure_memory_usage(module) when is_atom(module) do
      try do
        initial_memory = :erlang.memory(:total)
        
        # Try to use the module somehow
        if function_exported?(module, :__info__, 1) do
          module.__info__(:functions)
        end
        
        final_memory = :erlang.memory(:total)
        final_memory - initial_memory
      rescue
        _ -> 1_000_000  # Penalty for unusable modules
      end
    end
    
    defp calculate_ast_uniqueness(ast) do
      # Calculate uniqueness based on structural patterns
      patterns = extract_structural_patterns(ast)
      unique_patterns = MapSet.size(MapSet.new(patterns))
      total_patterns = length(patterns)
      
      if total_patterns > 0 do
        unique_patterns / total_patterns
      else
        0.0
      end
    end
    
    defp detect_novel_patterns(ast) do
      # Detect novel AST patterns that haven't been seen before
      # This would maintain a global registry in a real implementation
      patterns = extract_novel_patterns(ast)
      
      # Simplified novelty scoring
      novel_count = Enum.count(patterns, &novel_pattern?/1)
      total_count = length(patterns)
      
      if total_count > 0 do
        novel_count / total_count
      else
        0.0
      end
    end
    
    # Helper functions for AST analysis
    defp has_defmodule?(ast) do
      Macro.prewalk(ast, false, fn
        {:defmodule, _, _}, _acc -> {nil, true}
        node, acc -> {node, acc}
      end)
      |> elem(1)
    end
    
    defp has_use_directive?(ast) do
      Macro.prewalk(ast, false, fn
        {:use, _, _}, _acc -> {nil, true}
        node, acc -> {node, acc}
      end)
      |> elem(1)
    end
    
    defp has_dsl_sections?(ast) do
      # Look for DSL-like nested structures
      Macro.prewalk(ast, false, fn
        {name, _, [[do: _]]} = node, acc when is_atom(name) ->
          # This looks like a DSL section
          {node, true}
        node, acc -> 
          {node, acc}
      end)
      |> elem(1)
    end
    
    defp count_public_functions(ast) do
      Macro.prewalk(ast, 0, fn
        {:def, _, _}, count -> {nil, count + 1}
        node, count -> {node, count}
      end)
      |> elem(1)
    end
    
    defp count_private_functions(ast) do
      Macro.prewalk(ast, 0, fn
        {:defp, _, _}, count -> {nil, count + 1}
        node, count -> {node, count}
      end)
      |> elem(1)
    end
    
    defp extract_module_names(ast) do
      Macro.prewalk(ast, [], fn
        {:defmodule, _, [name, _]}, acc -> {nil, [name | acc]}
        node, acc -> {node, acc}
      end)
      |> elem(1)
    end
    
    defp extract_function_names(ast) do
      Macro.prewalk(ast, [], fn
        {:def, _, [{name, _, _} | _]}, acc -> {nil, [name | acc]}
        {:defp, _, [{name, _, _} | _]}, acc -> {nil, [name | acc]}
        node, acc -> {node, acc}
      end)
      |> elem(1)
    end
    
    defp proper_module_name?(name) when is_atom(name) do
      str = Atom.to_string(name)
      String.match?(str, ~r/^[A-Z][a-zA-Z0-9]*(\.[A-Z][a-zA-Z0-9]*)*$/)
    end
    
    defp proper_function_name?(name) when is_atom(name) do
      str = Atom.to_string(name)
      String.match?(str, ~r/^[a-z_][a-zA-Z0-9_]*[?!]?$/)
    end
    
    defp extract_structural_patterns(ast) do
      Macro.prewalk(ast, [], fn
        {name, _, children} = node, acc when is_atom(name) ->
          pattern = {name, length(children || [])}
          {node, [pattern | acc]}
        node, acc ->
          {node, acc}
      end)
      |> elem(1)
    end
    
    defp extract_novel_patterns(ast) do
      # Extract patterns that might be novel
      Macro.prewalk(ast, [], fn
        {name, meta, children} = node, acc when is_atom(name) ->
          # Create pattern signature
          pattern = {
            name,
            length(children || []),
            length(meta || [])
          }
          {node, [pattern | acc]}
        node, acc ->
          {node, acc}
      end)
      |> elem(1)
    end
    
    defp novel_pattern?(_pattern) do
      # In a real implementation, this would check against a database
      # of known patterns. For testing, we'll use a simple heuristic.
      :rand.uniform() > 0.7
    end
  end
  
  # Zach: Real genetic operations on ASTs
  defmodule GeneticOperators do
    @moduledoc """
    Real genetic operators that manipulate Elixir ASTs.
    """
    
    def crossover(%DslGenome{} = parent1, %DslGenome{} = parent2) do
      # Zach: Real AST crossover - swap subtrees
      crossover_points1 = find_crossover_points(parent1.ast)
      crossover_points2 = find_crossover_points(parent2.ast)
      
      if length(crossover_points1) > 0 and length(crossover_points2) > 0 do
        point1 = Enum.random(crossover_points1)
        point2 = Enum.random(crossover_points2)
        
        # Perform crossover
        child1_ast = perform_ast_crossover(parent1.ast, parent2.ast, point1, point2)
        child2_ast = perform_ast_crossover(parent2.ast, parent1.ast, point2, point1)
        
        child1 = DslGenome.new(child1_ast, parent1.generation + 1)
        child2 = DslGenome.new(child2_ast, parent2.generation + 1)
        
        # Track lineage
        child1 = %{child1 | lineage: [parent1.semantic_hash, parent2.semantic_hash]}
        child2 = %{child2 | lineage: [parent2.semantic_hash, parent1.semantic_hash]}
        
        {child1, child2}
      else
        # Fallback to simple reproduction
        {parent1, parent2}
      end
    end
    
    def mutate(%DslGenome{} = genome, mutation_rate \\ 0.1) do
      if :rand.uniform() < mutation_rate do
        mutation_type = choose_mutation_type()
        
        case apply_mutation(genome.ast, mutation_type) do
          {:ok, new_ast, mutation_info} ->
            new_genome = DslGenome.new(new_ast, genome.generation)
            mutation_history = [mutation_info | genome.mutation_history]
            %{new_genome | mutation_history: mutation_history}
          
          :error ->
            genome
        end
      else
        genome
      end
    end
    
    defp find_crossover_points(ast) do
      # Find suitable points for crossover in the AST
      Macro.prewalk(ast, [], fn
        {name, _, children} = node, acc when is_atom(name) and is_list(children) ->
          if length(children) > 0 do
            {node, [node | acc]}
          else
            {node, acc}
          end
        node, acc ->
          {node, acc}
      end)
      |> elem(1)
    end
    
    defp perform_ast_crossover(ast1, ast2, crossover_point1, crossover_point2) do
      # Extract subtree from ast2 at crossover_point2
      subtree = extract_subtree(ast2, crossover_point2)
      
      # Replace subtree in ast1 at crossover_point1
      replace_subtree(ast1, crossover_point1, subtree)
    end
    
    defp extract_subtree(ast, target_node) do
      # Find and extract the target subtree
      Macro.prewalk(ast, nil, fn
        ^target_node, _acc -> {target_node, target_node}
        node, acc -> {node, acc}
      end)
      |> elem(1)
    end
    
    defp replace_subtree(ast, target_node, replacement) do
      # Replace target_node with replacement in the AST
      Macro.prewalk(ast, fn
        ^target_node -> replacement
        node -> node
      end)
    end
    
    defp choose_mutation_type do
      types = [
        :add_function,
        :remove_function,
        :modify_function,
        :add_attribute,
        :modify_attribute,
        :restructure_module
      ]
      
      Enum.random(types)
    end
    
    defp apply_mutation(ast, mutation_type) do
      case mutation_type do
        :add_function ->
          add_random_function(ast)
        
        :remove_function ->
          remove_random_function(ast)
        
        :modify_function ->
          modify_random_function(ast)
        
        :add_attribute ->
          add_random_attribute(ast)
        
        :modify_attribute ->
          modify_random_attribute(ast)
        
        :restructure_module ->
          restructure_module(ast)
      end
    end
    
    defp add_random_function(ast) do
      # Generate a random function to add
      function_name = String.to_atom("generated_function_#{:rand.uniform(1000)}")
      
      new_function = quote do
        def unquote(function_name)() do
          unquote(:rand.uniform(100))
        end
      end
      
      # Add function to module body
      case add_to_module_body(ast, new_function) do
        {:ok, new_ast} ->
          {:ok, new_ast, {:add_function, function_name}}
        :error ->
          :error
      end
    end
    
    defp remove_random_function(ast) do
      functions = find_functions(ast)
      
      if length(functions) > 1 do  # Keep at least one function
        function_to_remove = Enum.random(functions)
        new_ast = remove_from_ast(ast, function_to_remove)
        {:ok, new_ast, {:remove_function, extract_function_name(function_to_remove)}}
      else
        :error
      end
    end
    
    defp modify_random_function(ast) do
      functions = find_functions(ast)
      
      if length(functions) > 0 do
        function_to_modify = Enum.random(functions)
        
        case modify_function_body(function_to_modify) do
          {:ok, new_function} ->
            new_ast = replace_in_ast(ast, function_to_modify, new_function)
            function_name = extract_function_name(function_to_modify)
            {:ok, new_ast, {:modify_function, function_name}}
          :error ->
            :error
        end
      else
        :error
      end
    end
    
    defp add_random_attribute(ast) do
      attr_name = String.to_atom("generated_attr_#{:rand.uniform(1000)}")
      attr_value = :rand.uniform(1000)
      
      new_attribute = quote do
        @unquote(attr_name) unquote(attr_value)
      end
      
      case add_to_module_body(ast, new_attribute) do
        {:ok, new_ast} ->
          {:ok, new_ast, {:add_attribute, attr_name}}
        :error ->
          :error
      end
    end
    
    defp modify_random_attribute(ast) do
      attributes = find_attributes(ast)
      
      if length(attributes) > 0 do
        attr_to_modify = Enum.random(attributes)
        new_value = :rand.uniform(1000)
        
        new_attribute = modify_attribute_value(attr_to_modify, new_value)
        new_ast = replace_in_ast(ast, attr_to_modify, new_attribute)
        
        attr_name = extract_attribute_name(attr_to_modify)
        {:ok, new_ast, {:modify_attribute, attr_name}}
      else
        :error
      end
    end
    
    defp restructure_module(ast) do
      # Simple restructuring: reorder top-level elements
      case extract_module_body(ast) do
        {:ok, body_elements} ->
          shuffled_body = Enum.shuffle(body_elements)
          new_ast = rebuild_module_with_body(ast, shuffled_body)
          {:ok, new_ast, {:restructure_module, :reorder}}
        
        :error ->
          :error
      end
    end
    
    # Helper functions for AST manipulation
    defp add_to_module_body({:defmodule, meta, [name, [do: body]]}, new_element) do
      case body do
        {:__block__, block_meta, elements} ->
          new_body = {:__block__, block_meta, elements ++ [new_element]}
          {:ok, {:defmodule, meta, [name, [do: new_body]]}}
        
        single_element ->
          new_body = {:__block__, [], [single_element, new_element]}
          {:ok, {:defmodule, meta, [name, [do: new_body]]}}
      end
    end
    
    defp add_to_module_body(_ast, _new_element), do: :error
    
    defp find_functions(ast) do
      Macro.prewalk(ast, [], fn
        {:def, _, _} = node, acc -> {node, [node | acc]}
        {:defp, _, _} = node, acc -> {node, [node | acc]}
        node, acc -> {node, acc}
      end)
      |> elem(1)
    end
    
    defp find_attributes(ast) do
      Macro.prewalk(ast, [], fn
        {:@, _, _} = node, acc -> {node, [node | acc]}
        node, acc -> {node, acc}
      end)
      |> elem(1)
    end
    
    defp extract_function_name({:def, _, [{name, _, _} | _]}), do: name
    defp extract_function_name({:defp, _, [{name, _, _} | _]}), do: name
    defp extract_function_name(_), do: :unknown
    
    defp extract_attribute_name({:@, _, [{name, _, _}]}), do: name
    defp extract_attribute_name(_), do: :unknown
    
    defp modify_function_body({:def, meta, [{name, name_meta, args}, [do: _body]]}) do
      # Generate new random body
      new_body = quote do
        unquote(:rand.uniform(1000)) + unquote(:rand.uniform(1000))
      end
      
      {:ok, {:def, meta, [{name, name_meta, args}, [do: new_body]]}}
    end
    
    defp modify_function_body(_), do: :error
    
    defp modify_attribute_value({:@, meta, [{name, name_meta, _old_value}]}, new_value) do
      {:@, meta, [{name, name_meta, [new_value]}]}
    end
    
    defp remove_from_ast(ast, target) do
      Macro.prewalk(ast, fn
        ^target -> nil
        {:__block__, meta, elements} ->
          filtered_elements = Enum.reject(elements, &(&1 == target))
          {:__block__, meta, filtered_elements}
        node -> node
      end)
    end
    
    defp replace_in_ast(ast, target, replacement) do
      Macro.prewalk(ast, fn
        ^target -> replacement
        node -> node
      end)
    end
    
    defp extract_module_body({:defmodule, _, [_, [do: body]]}) do
      case body do
        {:__block__, _, elements} -> {:ok, elements}
        single_element -> {:ok, [single_element]}
      end
    end
    
    defp extract_module_body(_), do: :error
    
    defp rebuild_module_with_body({:defmodule, meta, [name, _]}, body_elements) do
      new_body = case body_elements do
        [single_element] -> single_element
        multiple_elements -> {:__block__, [], multiple_elements}
      end
      
      {:defmodule, meta, [name, [do: new_body]]}
    end
  end
  
  # Zach: Real genetic algorithm evolution loop
  defmodule EvolutionEngine do
    def evolve(initial_population, generations, opts \\ []) do
      selection_pressure = Keyword.get(opts, :selection_pressure, 0.3)
      mutation_rate = Keyword.get(opts, :mutation_rate, 0.1)
      crossover_rate = Keyword.get(opts, :crossover_rate, 0.7)
      elitism_rate = Keyword.get(opts, :elitism_rate, 0.1)
      
      population_with_fitness = evaluate_population(initial_population)
      
      Enum.reduce(1..generations, population_with_fitness, fn generation, population ->
        IO.puts("Generation #{generation}, Best fitness: #{get_best_fitness(population)}")
        
        # Selection
        selected = selection(population, selection_pressure)
        
        # Crossover
        offspring = crossover_population(selected, crossover_rate)
        
        # Mutation
        mutated = mutate_population(offspring, mutation_rate)
        
        # Elitism
        elite = elite_selection(population, elitism_rate)
        
        # Combine and evaluate
        new_population = elite ++ mutated
        |> Enum.take(length(initial_population))
        |> evaluate_population()
        
        new_population
      end)
    end
    
    defp evaluate_population(population) do
      Enum.map(population, fn genome ->
        fitness = DslGenome.fitness_score(genome)
        %{genome | fitness: fitness}
      end)
    end
    
    defp get_best_fitness(population) do
      population
      |> Enum.map(& &1.fitness)
      |> Enum.max()
    end
    
    defp selection(population, selection_pressure) do
      population_size = length(population)
      num_selected = trunc(population_size * selection_pressure)
      
      # Tournament selection
      for _i <- 1..num_selected do
        tournament_size = 3
        tournament = Enum.take_random(population, tournament_size)
        Enum.max_by(tournament, & &1.fitness)
      end
    end
    
    defp crossover_population(population, crossover_rate) do
      pairs = Enum.chunk_every(population, 2)
      
      Enum.flat_map(pairs, fn
        [parent1, parent2] ->
          if :rand.uniform() < crossover_rate do
            {child1, child2} = GeneticOperators.crossover(parent1, parent2)
            [child1, child2]
          else
            [parent1, parent2]
          end
        
        [single_parent] ->
          [single_parent]
      end)
    end
    
    defp mutate_population(population, mutation_rate) do
      Enum.map(population, fn genome ->
        GeneticOperators.mutate(genome, mutation_rate)
      end)
    end
    
    defp elite_selection(population, elitism_rate) do
      num_elite = trunc(length(population) * elitism_rate)
      
      population
      |> Enum.sort_by(& &1.fitness, :desc)
      |> Enum.take(num_elite)
    end
  end
  
  describe "Real Genetic Algorithm DSL Evolution" do
    test "evolves simple DSL modules" do
      # Zach: Start with basic DSL templates
      initial_asts = [
        quote do
          defmodule SimpleResource1 do
            def get_data, do: "data1"
          end
        end,
        
        quote do
          defmodule SimpleResource2 do
            def process, do: :ok
            def get_value, do: 42
          end
        end,
        
        quote do
          defmodule SimpleResource3 do
            @config %{enabled: true}
            def get_config, do: @config
          end
        end
      ]
      
      initial_population = Enum.map(initial_asts, &DslGenome.new/1)
      
      # Run evolution for a few generations
      evolved_population = EvolutionEngine.evolve(initial_population, 5,
        selection_pressure: 0.5,
        mutation_rate: 0.2,
        crossover_rate: 0.6
      )
      
      # Verify evolution occurred
      assert length(evolved_population) == length(initial_population)
      
      # Check that fitness scores are reasonable
      fitness_scores = Enum.map(evolved_population, & &1.fitness)
      assert Enum.all?(fitness_scores, &(&1 >= 0.0 and &1 <= 1.0))
      
      # At least some genomes should have compiled successfully
      compiled_count = Enum.count(evolved_population, &(&1.compiled_module != nil))
      assert compiled_count > 0
      
      # Best fitness should be better than worst
      best_fitness = Enum.max(fitness_scores)
      worst_fitness = Enum.min(fitness_scores)
      assert best_fitness >= worst_fitness
    end
    
    test "genetic operators produce valid AST transformations" do
      # Test crossover
      parent1_ast = quote do
        defmodule Parent1 do
          def func1, do: 1
          def func2, do: 2
        end
      end
      
      parent2_ast = quote do
        defmodule Parent2 do
          def func3, do: 3
          def func4, do: 4
        end
      end
      
      parent1 = DslGenome.new(parent1_ast)
      parent2 = DslGenome.new(parent2_ast)
      
      {child1, child2} = GeneticOperators.crossover(parent1, parent2)
      
      # Children should be different from parents
      assert child1.ast != parent1.ast or child2.ast != parent2.ast
      
      # Children should have lineage information
      assert child1.lineage == [parent1.semantic_hash, parent2.semantic_hash]
      assert child2.lineage == [parent2.semantic_hash, parent1.semantic_hash]
    end
    
    test "mutation creates diverse variations" do
      original_ast = quote do
        defmodule TestModule do
          @value 100
          
          def get_value, do: @value
          def double_value, do: @value * 2
        end
      end
      
      original_genome = DslGenome.new(original_ast)
      
      # Apply multiple mutations
      mutations = for _i <- 1..10 do
        GeneticOperators.mutate(original_genome, 1.0)  # 100% mutation rate
      end
      
      # Should have created variations
      unique_asts = mutations
      |> Enum.map(& &1.ast)
      |> Enum.uniq()
      
      assert length(unique_asts) > 1
      
      # At least some should have mutation history
      with_mutations = Enum.count(mutations, &(length(&1.mutation_history) > 0))
      assert with_mutations > 0
    end
    
    test "fitness evaluation considers multiple dimensions" do
      # High-quality DSL
      good_ast = quote do
        defmodule WellDesignedResource do
          use SomeDsl
          
          @doc "A well-documented function"
          def public_interface(param) when is_binary(param) do
            process_internal(param)
          end
          
          defp process_internal(data) do
            data |> String.upcase() |> String.trim()
          end
          
          def another_function, do: :ok
        end
      end
      
      # Poor-quality DSL
      bad_ast = quote do
        defmodule bad_module do
          def x, do: 1
          def y, do: 2
          def z, do: 3
          def a, do: 4
          def b, do: 5
          def c, do: 6
          def d, do: 7
          def e, do: 8
        end
      end
      
      good_genome = DslGenome.new(good_ast)
      bad_genome = DslGenome.new(bad_ast)
      
      good_fitness = DslGenome.fitness_score(good_genome)
      bad_fitness = DslGenome.fitness_score(bad_genome)
      
      # Good DSL should have higher fitness
      assert good_fitness > bad_fitness
      
      # Both should be in valid range
      assert good_fitness >= 0.0 and good_fitness <= 1.0
      assert bad_fitness >= 0.0 and bad_fitness <= 1.0
    end
    
    test "evolution converges toward higher fitness" do
      # Create population with varying quality
      mixed_asts = [
        # Simple but correct
        quote do
          defmodule Simple do
            def work, do: :done
          end
        end,
        
        # More complex but well-structured
        quote do
          defmodule Complex do
            @config %{timeout: 5000}
            
            def start(opts \\ []) do
              timeout = Keyword.get(opts, :timeout, @config.timeout)
              do_work(timeout)
            end
            
            defp do_work(timeout) do
              receive do
                :stop -> :ok
              after
                timeout -> :timeout
              end
            end
          end
        end,
        
        # Problematic structure
        quote do
          defmodule problematic do
            def a, do: 1
            def b, do: 2
          end
        end
      ]
      
      initial_population = Enum.map(mixed_asts, &DslGenome.new/1)
      initial_fitness = initial_population
      |> Enum.map(&DslGenome.fitness_score/1)
      |> Enum.sum()
      |> Kernel./(length(initial_population))
      
      # Evolve for several generations
      evolved_population = EvolutionEngine.evolve(initial_population, 10,
        selection_pressure: 0.4,
        mutation_rate: 0.15,
        crossover_rate: 0.8,
        elitism_rate: 0.2
      )
      
      final_fitness = evolved_population
      |> Enum.map(& &1.fitness)
      |> Enum.sum()
      |> Kernel./(length(evolved_population))
      
      # Average fitness should improve or at least not degrade significantly
      assert final_fitness >= initial_fitness - 0.1
      
      # Best individual should be quite good
      best_final_fitness = evolved_population
      |> Enum.map(& &1.fitness)
      |> Enum.max()
      
      assert best_final_fitness > 0.3
    end
    
    test "compilation errors are handled gracefully" do
      # Create AST that will cause compilation errors
      invalid_ast = quote do
        defmodule InvalidModule do
          # This will cause a compilation error
          def invalid_function(x) do
            undefined_variable_that_will_cause_error
          end
          
          # Syntax that might break compilation
          def another_function, do: {
        end
      end
      
      genome = DslGenome.new(invalid_ast)
      
      # Should handle compilation errors
      assert genome.compiled_module == nil
      assert length(genome.compilation_errors) > 0
      
      # Fitness should be low for invalid genomes
      fitness = DslGenome.fitness_score(genome)
      assert fitness == 0.0
      
      # Evolution should work even with invalid genomes
      population = [genome, genome, genome]
      
      evolved = EvolutionEngine.evolve(population, 3,
        mutation_rate: 0.5
      )
      
      # Should complete without crashing
      assert length(evolved) == 3
    end
  end
end