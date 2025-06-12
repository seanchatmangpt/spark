defmodule TaskDsl.Entities do
  @moduledoc """
  Entity structs for the task management DSL.
  
  These structs define the data structures that will hold
  the information from DSL definitions at runtime.
  """
  
  defmodule Task do
    @moduledoc """
    Represents a single task with metadata.
    """
    defstruct [
      :name,
      :priority,
      :due_date,
      :assignee,
      :status,
      :description,
      :created_at,
      :estimated_hours
    ]
    
    @type t :: %__MODULE__{
      name: String.t(),
      priority: :low | :medium | :high,
      due_date: Date.t() | nil,
      assignee: String.t() | nil,
      status: :todo | :in_progress | :done | :blocked,
      description: String.t() | nil,
      created_at: DateTime.t() | nil,
      estimated_hours: non_neg_integer() | nil
    }
  end
  
  defmodule Project do
    @moduledoc """
    Represents a project containing multiple tasks.
    """
    defstruct [
      :name,
      :description,
      :start_date,
      :end_date,
      :owner,
      tasks: []
    ]
    
    @type t :: %__MODULE__{
      name: String.t(),
      description: String.t() | nil,
      start_date: Date.t() | nil,
      end_date: Date.t() | nil,
      owner: String.t() | nil,
      tasks: [Task.t()]
    }
  end
end