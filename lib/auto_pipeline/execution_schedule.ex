defmodule AutoPipeline.ExecutionSchedule do
  @moduledoc """
  Represents an optimized execution schedule for commands with dependency management.
  
  REFACTOR: Reactor handles execution scheduling internally.
  The DAG-based execution order is computed automatically.
  No need for manual wave calculation or scheduling.
  
  Migration: Remove this module entirely.
  """

  defstruct [
    :commands,
    :total_estimated_time,
    :waves,
    :critical_path
  ]

  @type t :: %__MODULE__{
    commands: [AutoPipeline.Command.t()],
    total_estimated_time: integer(),
    waves: [[AutoPipeline.Command.t()]],
    critical_path: [atom()]
  }
end