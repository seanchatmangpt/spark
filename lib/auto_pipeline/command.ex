defmodule AutoPipeline.Command do
  @moduledoc """
  Structure representing a discovered command with metadata for execution planning.
  
  REFACTOR: This struct would be transformed into Reactor.Step definitions.
  Each command becomes a step with:
  - name -> step name
  - dependencies -> step arguments
  - estimated_duration -> step timeout
  - resource_requirements -> step context
  
  Migration: Remove after implementing command-to-step conversion.
  """

  defstruct [
    :name,
    :file_path,
    :description,
    :arguments,
    :dependencies,
    :estimated_duration,
    :resource_requirements,
    :output_artifacts,
    :quality_impact,
    :category
  ]

  @type t :: %__MODULE__{
    name: atom(),
    file_path: String.t(),
    description: String.t(),
    arguments: [atom()],
    dependencies: [atom()],
    estimated_duration: integer(),
    resource_requirements: map(),
    output_artifacts: [atom()],
    quality_impact: integer(),
    category: atom()
  }
end