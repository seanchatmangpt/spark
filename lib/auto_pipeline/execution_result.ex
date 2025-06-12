defmodule AutoPipeline.ExecutionResult do
  @moduledoc """
  Structure representing the result of pipeline execution.
  
  REFACTOR: Reactor returns its own result structure.
  This would be replaced by the return value from Reactor.run/4
  which includes step results, halted state, and errors.
  
  Migration: Use Reactor's result structure directly.
  """

  defstruct [
    :status,
    :wave_index,
    :results,
    :quality_check,
    :total_commands,
    :successful_commands,
    :failed_commands
  ]

  @type t :: %__MODULE__{
    status: :completed | :aborted | :failed,
    wave_index: integer() | nil,
    results: [map()],
    quality_check: map() | nil,
    total_commands: integer(),
    successful_commands: integer(),
    failed_commands: integer()
  }
end