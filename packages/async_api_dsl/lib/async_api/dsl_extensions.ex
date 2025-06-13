defmodule AsyncApi.DslExtensions do
  @moduledoc """
  Extended DSL configuration that includes polyglot code generation transformers.
  
  This module adds the Cap'n Proto and multi-language client generation transformers
  to the standard AsyncAPI DSL, enabling automatic generation of high-performance
  clients in Rust, Python, Elixir, and TypeScript.
  """

  @transformers [
    # Standard AsyncAPI validation transformers
    AsyncApi.Transformers.ValidateComponents,
    AsyncApi.Transformers.ValidateMessages,
    AsyncApi.Transformers.ValidateSchemas,
    AsyncApi.Transformers.ValidateChannels,
    AsyncApi.Transformers.ValidateOperations,
    
    # Polyglot code generation transformers
    AsyncApi.Transformers.GenerateCapnProto,
    AsyncApi.Transformers.GenerateClients,
    AsyncApi.Transformers.WriteGeneratedFiles,
    AsyncApi.Transformers.ConcurrentFileWriter
  ]

  use Spark.Dsl.Extension,
    sections: [],
    entities: [],
    transformers: @transformers

  def sections, do: []
  def entities, do: []
  def transformers, do: @transformers
end