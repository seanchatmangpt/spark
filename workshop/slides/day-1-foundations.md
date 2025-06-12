# Day 1: Foundations and First Steps
## The Tao of Spark Workshop

> *"The way to get started is to quit talking and begin doing."* - Walt Disney

---

## Welcome to Your DSL Journey

### What You'll Accomplish Today
- Transform from DSL user to DSL creator
- Understand the philosophical foundation of DSL design
- Build your first complete DSL with validation
- Experience the joy of natural language creation

### Today's Schedule
- **9:00-12:00**: Philosophy, concepts, live coding
- **1:00-5:00**: Hands-on lab work
- **5:00-6:00**: Reflection and next-day preview

---

## The DSL Mindset Shift

### Traditional Programming Mindset
```
Problem → Algorithm → Code → Solution
```

### DSL Design Mindset  
```
Domain → Language → Usage → Implementation
```

**Key Insight**: Start with how you want the DSL to be used, not how to implement it.

---

## Why DSLs Matter

### The Configuration Evolution

**Worst: Scattered Magic Numbers**
```elixir
# Buried in various modules
timeout = 30_000
retries = 3
url = "https://api.example.com"
```

**Bad: Configuration Files**
```elixir
# config/config.exs
config :my_app, :api,
  timeout: 30_000,
  retries: 3,
  url: "https://api.example.com"
```

---

## Configuration Evolution (continued)

**Good: Structured Configuration**
```elixir
defmodule MyApp.Config do
  def api_config do
    %{
      timeout: 30_000,
      retries: 3,
      url: "https://api.example.com"
    }
  end
end
```

**Excellent: Domain DSL**
```elixir
defmodule MyApp.Config do
  use MyApp.ServiceDsl
  
  service :api do
    base_url "https://api.example.com"
    timeout :timer.seconds(30)
    retries 3
    circuit_breaker enabled: true
  end
end
```

---

## What Changed?

### From Config to DSL
- **Vocabulary**: `service`, `base_url`, `circuit_breaker` vs generic config keys
- **Validation**: Invalid configurations caught at compile time
- **Documentation**: DSL is self-documenting
- **Tooling**: IDE support, autocomplete, error messages
- **Introspection**: Can query configuration at runtime

### The "Magic" Moment
When your DSL reads like natural domain language, you've achieved something profound.

---

## Spark's Revolutionary Approach

### Traditional DSL Development
```elixir
defmacro field(name, type) do
  quote do
    # 50+ lines of complex AST manipulation
    # Manual validation logic
    # No automatic introspection
    # Difficult testing and debugging
  end
end
```

### Spark's Data-Driven Approach
```elixir
@field %Spark.Dsl.Entity{
  name: :field,
  args: [:name, :type],
  schema: [
    name: [type: :atom, required: true],
    type: [type: {:one_of, [:string, :integer]}, required: true]
  ]
}
```

**Result**: Automatic validation, introspection, documentation, and tooling!

---

## Core Principles Review

### 1. Declarative Expression
Describe **what** you want, not **how** to achieve it.

### 2. Data-Driven Architecture
DSL structure as queryable data, not hidden in macros.

### 3. Composable Abstractions
Small pieces that combine naturally.

### 4. Progressive Enhancement
Start simple, add complexity as needed.

### 5. Fail-Fast Validation
Catch errors at compile time with clear messages.

---

## Live Coding: Task Management DSL

### Domain Analysis
What concepts exist in task management?
- **Tasks**: name, priority, due dates, assignees, status
- **Projects**: collections of related tasks
- **Workflow**: todo → in_progress → done

Let's build this together step by step...

---

## Entity Structures

```elixir
defmodule TaskDsl.Entities do
  defmodule Task do
    defstruct [
      :name, :priority, :due_date, 
      :assignee, :status, :description
    ]
  end
  
  defmodule Project do
    defstruct [:name, :description, tasks: []]
  end
end
```

**Mental Model Check**: Do these structures capture the domain naturally?

---

## DSL Entity Definition

```elixir
@task %Spark.Dsl.Entity{
  name: :task,
  target: Entities.Task,
  args: [:name],
  schema: [
    name: [type: :string, required: true],
    priority: [type: {:one_of, [:low, :medium, :high]}, default: :medium],
    due_date: [type: :date],
    assignee: [type: :string],
    status: [type: {:one_of, [:todo, :in_progress, :done]}, default: :todo],
    description: [type: :string]
  ]
}
```

**Key Elements**:
- `name`: DSL keyword
- `target`: Struct to populate
- `args`: Required positional arguments
- `schema`: Validation rules and types

---

## Project Entity and Section

```elixir
@project %Spark.Dsl.Entity{
  name: :project,
  target: Entities.Project,
  args: [:name],
  entities: [task: @task],  # Tasks nested in projects
  schema: [
    name: [type: :string, required: true],
    description: [type: :string]
  ]
}

@projects %Spark.Dsl.Section{
  name: :projects,
  entities: [@project]
}

use Spark.Dsl.Extension, sections: [@projects]
```

---

## The Complete DSL Module

```elixir
defmodule TaskDsl do
  use Spark.Dsl,
    default_extensions: [extensions: [TaskDsl.Extension]]
end
```

That's it! Now we can use our DSL...

---

## Using Our DSL

```elixir
defmodule TeamTasks do
  use TaskDsl
  
  projects do
    project "Spark Workshop" do
      description "Learn to build DSLs with Spark"
      
      task "Prepare materials" do
        priority :high
        assignee "instructor"
        due_date ~D[2024-01-15]
        status :done
      end
      
      task "Build first DSL" do
        priority :high
        assignee "participants"
        status :todo
      end
    end
  end
end
```

---

## Runtime Introspection

```elixir
defmodule TaskDsl.Info do
  use Spark.InfoGenerator,
    extension: TaskDsl.Extension,
    sections: [:projects]
end

# Usage:
iex> TaskDsl.Info.projects(TeamTasks)
iex> TaskDsl.Info.project(TeamTasks, "Spark Workshop")
```

**Automatic Functions Generated**:
- `projects/1` - Get all projects
- `project/2` - Get specific project
- `project!/2` - Get specific project or raise

---

## The Magic Moment

### What We Just Built
- A natural language for describing projects and tasks
- Compile-time validation of all data
- Runtime introspection capabilities
- Self-documenting structure
- IDE support and autocomplete

### What Spark Gave Us for Free
- Entity validation
- Runtime query functions
- Error handling
- Documentation generation
- Formatter integration

---

## Lab Time: Personal Configuration DSL

### Your Challenge
Build a DSL that captures your personal development environment preferences.

**Why This Domain?**
- Complex enough to be interesting
- Personal enough to be motivating  
- Familiar enough to focus on DSL design
- Real enough to see immediate value

---

## Lab Structure

### Required Components
1. **Editor Configuration**: Theme, fonts, extensions
2. **Terminal Setup**: Shell, appearance, aliases
3. **Project Organization**: Workspaces, categories
4. **Git Configuration**: User info, aliases

### Design Process
1. **Domain Analysis** (15 min): List tools and settings
2. **Entity Design** (30 min): Create structs
3. **DSL Extension** (45 min): Define entities and validation
4. **Usage Testing** (30 min): Create your actual config
5. **Info Module** (20 min): Add introspection

---

## Example Lab Structure

```elixir
defmodule MyDev.Config do
  use PersonalDsl
  
  editor :vscode do
    theme "Dracula"
    font_size 14
    extensions [:elixir_ls, :vim, :git_lens]
  end
  
  terminal :iterm2 do
    shell :zsh
    theme "Dracula"
    opacity 0.95
  end
  
  workspace do
    base_path "~/code"
    categories do
      category :work, path: "work"
      category :personal, path: "personal"
    end
  end
end
```

---

## Validation Ideas

### Domain-Specific Validation
```elixir
def validate_font_size(size) when is_integer(size) and size >= 8 and size <= 72 do
  {:ok, size}
end

def validate_color(color) when is_binary(color) do
  cond do
    String.match?(color, ~r/^#[0-9A-Fa-f]{6}$/) -> {:ok, color}
    color in ~w[red green blue black white] -> {:ok, color}
    true -> {:error, "Invalid color format"}
  end
end
```

### Schema Integration
```elixir
font_size: [type: {:custom, __MODULE__, :validate_font_size, []}]
theme: [type: {:custom, __MODULE__, :validate_color, []}]
```

---

## Reflection Questions

### As You Build
- What parts feel most natural to write?
- Where do you struggle with vocabulary?
- What validation prevents errors you'd make?
- How is this different from config files?

### The Deeper Questions
- When does your DSL start feeling "right"?
- What makes syntax feel natural vs. forced?
- How does domain vocabulary affect your thinking?

---

## Lab Enhancement

### Advanced Features
- **Custom Validation**: Domain-specific rules
- **Configuration Generation**: Output actual config files
- **Cross-Platform Support**: Handle OS differences
- **Enhanced Info Module**: Sophisticated query functions

### Example Enhancement
```elixir
defmodule PersonalDsl.Generator do
  def generate_vscode_settings(module) do
    config = PersonalDsl.Info.editor_config(module)
    
    %{
      "workbench.colorTheme" => config.theme,
      "editor.fontSize" => config.font_size
    }
    |> Jason.encode!(pretty: true)
  end
end
```

---

## Key Insights from Today

### Mental Model Shifts
- From implementation to interface design
- From code structure to domain vocabulary
- From runtime errors to compile-time safety
- From documentation to self-documenting syntax

### Spark's Power
- Data-driven DSL definition
- Automatic validation and introspection
- Built-in tooling and IDE support
- Extensible architecture

### Tomorrow's Journey
We move from personal tools to business problems, building production-ready DSLs for real organizational challenges.

---

## Evening Assignment

### Required Reading
- "Real-World Application" chapter from *The Tao of Spark*
- Skim API Gateway DSL examples

### Domain Research
Choose a business domain from your work that has:
- Complex configuration needs
- Multiple stakeholders with different mental models
- Current pain points with existing tools

### Preparation Questions
1. Who would use a DSL in this domain?
2. What vocabulary do domain experts use?
3. What processes do people follow?
4. Where do current tools cause friction?

---

## Success Criteria

You've mastered Day 1 if you can:

- [ ] **Explain the DSL mindset** vs. traditional programming
- [ ] **Build a working DSL** with validation and introspection
- [ ] **Add meaningful validation** that prevents real errors
- [ ] **Use runtime introspection** to query DSL data
- [ ] **Think in domain terms** rather than implementation details

### The Transformation
You're no longer thinking like a DSL user—you're thinking like a DSL designer.

Tomorrow we take these skills to real business problems!

---

## Questions and Discussion

*"Every expert was once a beginner. Every pro was once an amateur. Today you begin the journey from DSL user to DSL creator."*

### Open Floor
- What surprised you most about DSL design?
- Which concepts need more clarification?
- What are you excited to build tomorrow?

**Thank you for an amazing Day 1!**