defmodule AutoPipeline.Automation.Command do
  @moduledoc """
  Represents a discovered command with its metadata and execution characteristics.
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
    arguments: list({atom(), String.t()}),
    dependencies: list(atom()),
    estimated_duration: :short | :medium | :long | :infinite,
    resource_requirements: :low | :medium | :high,
    output_artifacts: list(atom()),
    quality_impact: :low | :medium | :high,
    category: :generation | :analysis | :documentation | :testing | :optimization | :utility
  }
end

defmodule AutoPipeline.Automation.CommandDiscovery do
  @moduledoc """
  Results of command discovery phase including categorization and dependency analysis.
  """
  
  defstruct [
    :all_commands,
    :categorized,
    :dependency_graph,
    :execution_plan
  ]

  @type t :: %__MODULE__{
    all_commands: list(AutoPipeline.Automation.Command.t()),
    categorized: map(),
    dependency_graph: map(),
    execution_plan: list(list(AutoPipeline.Automation.Command.t()))
  }
end

defmodule AutoPipeline.Automation.ExecutionSchedule do
  @moduledoc """
  Optimized execution schedule with waves, timing, and quality checkpoints.
  """
  
  defstruct [
    :waves,
    :total_estimated_time,
    :resource_requirements,
    :critical_path,
    :quality_checkpoints
  ]

  @type t :: %__MODULE__{
    waves: list(list(AutoPipeline.Automation.Command.t())),
    total_estimated_time: non_neg_integer(),
    resource_requirements: :low | :medium | :high,
    critical_path: list(AutoPipeline.Automation.Command.t()),
    quality_checkpoints: list(map())
  }
end

defmodule AutoPipeline.Automation.CommandResult do
  @moduledoc """
  Result of executing a single command including quality metrics and artifacts.
  """
  
  defstruct [
    :command,
    :status,
    :output,
    :quality_score,
    :execution_time,
    :artifacts,
    :errors,
    :warnings
  ]

  @type t :: %__MODULE__{
    command: atom(),
    status: :success | :failed | :low_quality,
    output: String.t(),
    quality_score: non_neg_integer(),
    execution_time: non_neg_integer(),
    artifacts: list(),
    errors: list(String.t()),
    warnings: list(String.t())
  }
end

defmodule AutoPipeline.Automation.QualityCheckpoint do
  @moduledoc """
  Quality assessment and decision point during pipeline execution.
  """
  
  defstruct [
    :status,
    :metrics,
    :improvements,
    :recommendations
  ]

  @type t :: %__MODULE__{
    status: :continue | :abort | :retry_with_improvements,
    metrics: map(),
    improvements: list(AutoPipeline.Automation.QualityImprovement.t()),
    recommendations: list(String.t())
  }
end

defmodule AutoPipeline.Automation.QualityImprovement do
  @moduledoc """
  Specific improvement suggestion for a low-quality command result.
  """
  
  defstruct [
    :command,
    :issue,
    :improvement_strategy,
    :modified_args,
    :additional_context
  ]

  @type t :: %__MODULE__{
    command: atom(),
    issue: String.t(),
    improvement_strategy: String.t(),
    modified_args: map(),
    additional_context: String.t()
  }
end

defmodule AutoPipeline.Automation.PipelineReport do
  @moduledoc """
  Comprehensive report of pipeline execution with all metrics and artifacts.
  """
  
  defstruct [
    :summary,
    :sections,
    :file_paths
  ]

  @type t :: %__MODULE__{
    summary: map(),
    sections: map(),
    file_paths: map()
  }
end