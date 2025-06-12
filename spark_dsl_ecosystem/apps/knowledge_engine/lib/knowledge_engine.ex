defmodule KnowledgeEngine do
  @moduledoc """
  Sparse Priming Representation (SPR) engine for DSL knowledge management.
  
  This module implements a knowledge compression and decompression system
  that enables efficient storage and retrieval of DSL patterns, best practices,
  and implementation knowledge using SPR techniques.
  
  ## Features
  
  - SPR compression of DSL knowledge
  - Semantic search and retrieval
  - Pattern matching and recommendation
  - Knowledge graph construction
  - Continuous learning from new DSLs
  """
  
  use GenServer
  require Logger
  
  alias KnowledgeEngine.{
    SPRCompressor,
    SPRDecompressor,
    SemanticIndex,
    PatternLibrary,
    KnowledgeGraph
  }
  
  @doc """
  Starts the knowledge engine.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Compresses DSL knowledge into SPR format.
  """
  def compress(knowledge) when is_map(knowledge) do
    GenServer.call(__MODULE__, {:compress, knowledge})
  end
  
  @doc """
  Decompresses SPR back into usable knowledge.
  """
  def decompress(spr, context \\ %{}) do
    GenServer.call(__MODULE__, {:decompress, spr, context})
  end
  
  @doc """
  Searches for relevant knowledge based on query.
  """
  def search(query, opts \\ []) do
    GenServer.call(__MODULE__, {:search, query, opts})
  end
  
  @doc """
  Adds new knowledge to the engine.
  """
  def learn(knowledge) do
    GenServer.cast(__MODULE__, {:learn, knowledge})
  end
  
  @doc """
  Gets recommendations based on current context.
  """
  def get_recommendations(context) do
    GenServer.call(__MODULE__, {:recommend, context})
  end
  
  # GenServer callbacks
  
  @impl true
  def init(opts) do
    state = %{
      spr_store: %{},
      semantic_index: SemanticIndex.new(),
      pattern_library: PatternLibrary.new(),
      knowledge_graph: KnowledgeGraph.new(),
      config: build_config(opts)
    }
    
    # Load initial knowledge base if provided
    if opts[:knowledge_base] do
      load_knowledge_base(state, opts[:knowledge_base])
    else
      {:ok, state}
    end
  end
  
  @impl true
  def handle_call({:compress, knowledge}, _from, state) do
    case SPRCompressor.compress(knowledge, state.config) do
      {:ok, spr} ->
        # Store SPR and update indices
        new_state = store_spr(state, spr, knowledge)
        {:reply, {:ok, spr}, new_state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl true
  def handle_call({:decompress, spr, context}, _from, state) do
    result = SPRDecompressor.decompress(spr, context, state)
    {:reply, result, state}
  end
  
  @impl true
  def handle_call({:search, query, opts}, _from, state) do
    results = perform_search(query, opts, state)
    {:reply, {:ok, results}, state}
  end
  
  @impl true
  def handle_call({:recommend, context}, _from, state) do
    recommendations = generate_recommendations(context, state)
    {:reply, {:ok, recommendations}, state}
  end
  
  @impl true
  def handle_cast({:learn, knowledge}, state) do
    new_state = integrate_knowledge(state, knowledge)
    {:noreply, new_state}
  end
  
  # Private functions
  
  defp build_config(opts) do
    %{
      compression_level: Keyword.get(opts, :compression_level, :balanced),
      max_spr_size: Keyword.get(opts, :max_spr_size, 1024),
      semantic_threshold: Keyword.get(opts, :semantic_threshold, 0.7),
      pattern_min_frequency: Keyword.get(opts, :pattern_min_frequency, 3),
      learning_rate: Keyword.get(opts, :learning_rate, 0.1)
    }
  end
  
  defp load_knowledge_base(state, knowledge_base_path) do
    case File.read(knowledge_base_path) do
      {:ok, content} ->
        knowledge = Jason.decode!(content)
        loaded_state = Enum.reduce(knowledge, state, fn item, acc ->
          integrate_knowledge(acc, item)
        end)
        {:ok, loaded_state}
        
      {:error, reason} ->
        Logger.warn("Failed to load knowledge base: #{inspect(reason)}")
        {:ok, state}
    end
  end
  
  defp store_spr(state, spr, original_knowledge) do
    # Generate unique ID for SPR
    spr_id = generate_spr_id(spr)
    
    # Store SPR
    updated_store = Map.put(state.spr_store, spr_id, %{
      spr: spr,
      metadata: extract_metadata(original_knowledge),
      created_at: DateTime.utc_now()
    })
    
    # Update semantic index
    updated_index = SemanticIndex.add(
      state.semantic_index,
      spr_id,
      extract_semantic_features(original_knowledge)
    )
    
    # Update pattern library
    updated_patterns = PatternLibrary.add_patterns(
      state.pattern_library,
      extract_patterns(original_knowledge)
    )
    
    # Update knowledge graph
    updated_graph = KnowledgeGraph.add_node(
      state.knowledge_graph,
      spr_id,
      original_knowledge
    )
    
    %{state |
      spr_store: updated_store,
      semantic_index: updated_index,
      pattern_library: updated_patterns,
      knowledge_graph: updated_graph
    }
  end
  
  defp generate_spr_id(spr) do
    :crypto.hash(:sha256, :erlang.term_to_binary(spr))
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end
  
  defp extract_metadata(knowledge) do
    %{
      type: Map.get(knowledge, :type, :general),
      domain: Map.get(knowledge, :domain, :unknown),
      tags: Map.get(knowledge, :tags, []),
      version: Map.get(knowledge, :version, "1.0.0")
    }
  end
  
  defp extract_semantic_features(knowledge) do
    # Extract semantic features for indexing
    features = []
    
    # Extract from description
    if desc = Map.get(knowledge, :description) do
      features = features ++ tokenize_and_embed(desc)
    end
    
    # Extract from code samples
    if code = Map.get(knowledge, :code) do
      features = features ++ extract_code_features(code)
    end
    
    # Extract from patterns
    if patterns = Map.get(knowledge, :patterns) do
      features = features ++ Enum.flat_map(patterns, &pattern_to_features/1)
    end
    
    features
  end
  
  defp tokenize_and_embed(text) do
    # Simplified tokenization and embedding
    text
    |> String.downcase()
    |> String.split(~r/\W+/)
    |> Enum.filter(&(String.length(&1) > 2))
    |> Enum.uniq()
  end
  
  defp extract_code_features(code) do
    # Extract features from code
    features = []
    
    # Module names
    modules = Regex.scan(~r/defmodule\s+(\S+)/, code)
              |> Enum.map(fn [_, mod] -> "module:#{mod}" end)
    
    # Function names
    functions = Regex.scan(~r/def\s+(\w+)/, code)
                |> Enum.map(fn [_, func] -> "function:#{func}" end)
    
    # DSL keywords
    dsl_keywords = Regex.scan(~r/(section|entity|attribute|transform|verify)/, code)
                   |> Enum.map(fn [_, keyword] -> "dsl:#{keyword}" end)
    
    features ++ modules ++ functions ++ dsl_keywords
  end
  
  defp pattern_to_features(pattern) do
    case pattern do
      %{name: name, type: type} ->
        ["pattern:#{name}", "pattern_type:#{type}"]
      _ ->
        []
    end
  end
  
  defp extract_patterns(knowledge) do
    base_patterns = Map.get(knowledge, :patterns, [])
    
    # Extract patterns from code if available
    code_patterns = if code = Map.get(knowledge, :code) do
      extract_patterns_from_code(code)
    else
      []
    end
    
    base_patterns ++ code_patterns
  end
  
  defp extract_patterns_from_code(code) do
    patterns = []
    
    # DSL structure patterns
    if String.contains?(code, "use Spark.Dsl.Extension") do
      patterns = [%{
        type: :dsl_extension,
        name: :spark_extension,
        frequency: 1
      } | patterns]
    end
    
    # Section patterns
    section_count = length(Regex.scan(~r/@section/, code))
    if section_count > 0 do
      patterns = [%{
        type: :structural,
        name: :section_based,
        frequency: section_count
      } | patterns]
    end
    
    # Entity patterns
    entity_count = length(Regex.scan(~r/@entity/, code))
    if entity_count > 0 do
      patterns = [%{
        type: :structural,
        name: :entity_based,
        frequency: entity_count
      } | patterns]
    end
    
    patterns
  end
  
  defp perform_search(query, opts, state) do
    # Convert query to features
    query_features = extract_semantic_features(%{description: query})
    
    # Search semantic index
    matches = SemanticIndex.search(
      state.semantic_index,
      query_features,
      Keyword.get(opts, :limit, 10)
    )
    
    # Retrieve and rank results
    matches
    |> Enum.map(fn {spr_id, score} ->
      spr_data = Map.get(state.spr_store, spr_id)
      %{
        spr_id: spr_id,
        score: score,
        metadata: spr_data.metadata,
        preview: generate_preview(spr_data.spr)
      }
    end)
    |> Enum.sort_by(& &1.score, :desc)
  end
  
  defp generate_preview(spr) do
    # Generate human-readable preview of SPR
    case spr do
      %{summary: summary} -> summary
      %{description: desc} -> String.slice(desc, 0, 100) <> "..."
      _ -> "SPR data"
    end
  end
  
  defp generate_recommendations(context, state) do
    # Extract context features
    context_features = extract_context_features(context)
    
    # Find similar patterns
    similar_patterns = PatternLibrary.find_similar(
      state.pattern_library,
      context_features
    )
    
    # Get related knowledge from graph
    related_knowledge = if context[:current_spr] do
      KnowledgeGraph.get_related(
        state.knowledge_graph,
        context.current_spr,
        max_depth: 2
      )
    else
      []
    end
    
    # Combine and rank recommendations
    recommendations = compile_recommendations(
      similar_patterns,
      related_knowledge,
      context
    )
    
    Enum.take(recommendations, 5)
  end
  
  defp extract_context_features(context) do
    features = []
    
    if domain = context[:domain] do
      features = ["domain:#{domain}" | features]
    end
    
    if requirements = context[:requirements] do
      features = features ++ extract_semantic_features(%{description: requirements})
    end
    
    if current_code = context[:current_code] do
      features = features ++ extract_code_features(current_code)
    end
    
    features
  end
  
  defp compile_recommendations(patterns, related, context) do
    recommendations = []
    
    # Pattern-based recommendations
    pattern_recs = Enum.map(patterns, fn {pattern, score} ->
      %{
        type: :pattern,
        pattern: pattern,
        score: score * 0.7,
        suggestion: pattern_to_suggestion(pattern)
      }
    end)
    
    # Knowledge-based recommendations
    knowledge_recs = Enum.map(related, fn {spr_id, relation_type} ->
      %{
        type: :knowledge,
        spr_id: spr_id,
        relation: relation_type,
        score: relation_score(relation_type),
        suggestion: "Consider related: #{relation_type}"
      }
    end)
    
    (pattern_recs ++ knowledge_recs)
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.uniq_by(& &1.suggestion)
  end
  
  defp pattern_to_suggestion(pattern) do
    case pattern.name do
      :section_based -> "Use section-based DSL structure"
      :entity_based -> "Define entities for your domain objects"
      :spark_extension -> "Extend Spark.Dsl.Extension for full features"
      _ -> "Apply pattern: #{pattern.name}"
    end
  end
  
  defp relation_score(:extends), do: 0.9
  defp relation_score(:similar_to), do: 0.8
  defp relation_score(:uses), do: 0.7
  defp relation_score(:related_to), do: 0.6
  defp relation_score(_), do: 0.5
  
  defp integrate_knowledge(state, knowledge) do
    # Compress and store new knowledge
    case SPRCompressor.compress(knowledge, state.config) do
      {:ok, spr} ->
        store_spr(state, spr, knowledge)
        
      {:error, reason} ->
        Logger.error("Failed to integrate knowledge: #{inspect(reason)}")
        state
    end
  end
end

# Placeholder modules for the knowledge engine components
defmodule KnowledgeEngine.SPRCompressor do
  def compress(knowledge, config) do
    # Simplified compression
    spr = %{
      summary: extract_summary(knowledge),
      key_concepts: extract_key_concepts(knowledge),
      patterns: extract_patterns(knowledge),
      compressed_at: DateTime.utc_now()
    }
    
    if byte_size(:erlang.term_to_binary(spr)) <= config.max_spr_size do
      {:ok, spr}
    else
      {:error, :spr_too_large}
    end
  end
  
  defp extract_summary(knowledge) do
    Map.get(knowledge, :description, "")
    |> String.slice(0, 200)
  end
  
  defp extract_key_concepts(knowledge) do
    # Would use NLP to extract key concepts
    Map.get(knowledge, :concepts, [])
  end
  
  defp extract_patterns(knowledge) do
    Map.get(knowledge, :patterns, [])
  end
end

defmodule KnowledgeEngine.SPRDecompressor do
  def decompress(spr, context, state) do
    # Simplified decompression
    {:ok, %{
      summary: spr.summary,
      concepts: spr.key_concepts,
      patterns: spr.patterns,
      context_specific: apply_context(spr, context)
    }}
  end
  
  defp apply_context(spr, context) do
    # Would apply context to generate specific knowledge
    %{
      adapted_for: context[:domain] || :general
    }
  end
end

defmodule KnowledgeEngine.SemanticIndex do
  def new do
    %{index: %{}, features: %{}}
  end
  
  def add(index, id, features) do
    updated_features = Map.put(index.features, id, features)
    updated_index = Enum.reduce(features, index.index, fn feature, acc ->
      Map.update(acc, feature, [id], &[id | &1])
    end)
    
    %{index | index: updated_index, features: updated_features}
  end
  
  def search(index, query_features, limit) do
    # Simple feature matching
    scores = Enum.reduce(index.features, %{}, fn {id, features}, acc ->
      score = calculate_similarity(query_features, features)
      if score > 0 do
        Map.put(acc, id, score)
      else
        acc
      end
    end)
    
    scores
    |> Enum.sort_by(fn {_, score} -> score end, :desc)
    |> Enum.take(limit)
  end
  
  defp calculate_similarity(features1, features2) do
    set1 = MapSet.new(features1)
    set2 = MapSet.new(features2)
    
    intersection = MapSet.intersection(set1, set2) |> MapSet.size()
    union = MapSet.union(set1, set2) |> MapSet.size()
    
    if union == 0 do
      0
    else
      intersection / union
    end
  end
end

defmodule KnowledgeEngine.PatternLibrary do
  def new do
    %{patterns: %{}, frequency: %{}}
  end
  
  def add_patterns(library, patterns) do
    Enum.reduce(patterns, library, fn pattern, acc ->
      add_pattern(acc, pattern)
    end)
  end
  
  def find_similar(library, features) do
    # Find patterns matching features
    library.patterns
    |> Enum.filter(fn {_, pattern} ->
      pattern_matches_features?(pattern, features)
    end)
    |> Enum.map(fn {id, pattern} ->
      {pattern, calculate_match_score(pattern, features)}
    end)
    |> Enum.sort_by(fn {_, score} -> score end, :desc)
  end
  
  defp add_pattern(library, pattern) do
    pattern_id = generate_pattern_id(pattern)
    
    updated_patterns = Map.put(library.patterns, pattern_id, pattern)
    updated_frequency = Map.update(
      library.frequency,
      pattern.name,
      1,
      &(&1 + 1)
    )
    
    %{library | patterns: updated_patterns, frequency: updated_frequency}
  end
  
  defp generate_pattern_id(pattern) do
    "#{pattern.type}_#{pattern.name}_#{:rand.uniform(1000)}"
  end
  
  defp pattern_matches_features?(pattern, features) do
    pattern_features = ["pattern:#{pattern.name}", "pattern_type:#{pattern.type}"]
    Enum.any?(pattern_features, &(&1 in features))
  end
  
  defp calculate_match_score(pattern, features) do
    # Simple scoring based on feature overlap
    if "pattern:#{pattern.name}" in features do
      1.0
    else
      0.5
    end
  end
end

defmodule KnowledgeEngine.KnowledgeGraph do
  def new do
    %{nodes: %{}, edges: %{}}
  end
  
  def add_node(graph, id, knowledge) do
    node = %{
      id: id,
      type: Map.get(knowledge, :type, :general),
      metadata: extract_metadata(knowledge)
    }
    
    updated_nodes = Map.put(graph.nodes, id, node)
    
    # Add edges based on relationships
    updated_edges = add_edges(graph.edges, id, knowledge)
    
    %{graph | nodes: updated_nodes, edges: updated_edges}
  end
  
  def get_related(graph, node_id, opts) do
    max_depth = Keyword.get(opts, :max_depth, 1)
    
    find_related_nodes(graph, node_id, max_depth)
  end
  
  defp extract_metadata(knowledge) do
    %{
      domain: Map.get(knowledge, :domain),
      tags: Map.get(knowledge, :tags, [])
    }
  end
  
  defp add_edges(edges, id, knowledge) do
    # Would analyze knowledge to find relationships
    edges
  end
  
  defp find_related_nodes(graph, node_id, max_depth) do
    # Simplified - would do actual graph traversal
    []
  end
end