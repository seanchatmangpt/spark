# Day 1: Foundations and First Steps

> *"A journey of a thousand miles begins with a single step."* - Lao Tzu

Welcome to Day 1 of The Tao of Spark workshop! Today we transform from DSL users to DSL designers through philosophical understanding and hands-on practice.

## Daily Objectives

By the end of Day 1, you will:
- ✅ Understand the fundamental philosophy behind DSL design
- ✅ Grasp Spark's revolutionary data-driven approach
- ✅ Build your first complete DSL with validation and introspection
- ✅ Develop intuition for domain modeling and DSL architecture
- ✅ Experience the joy of creating languages that feel natural

## Pre-Day Setup Checklist

**Before arriving, ensure you have:**
- [ ] Elixir 1.15+ installed and working (`elixir --version`)
- [ ] Git configured with your credentials
- [ ] Preferred editor/IDE set up with Elixir support
- [ ] Read the "Philosophy of DSLs" chapter from the book
- [ ] Brainstormed one work-related domain that could benefit from a DSL

---

## Morning Session (9:00-12:00)

### Opening Circle (9:00-9:30)
**Welcome & Introductions**

Each participant shares:
- Name and current role
- Elixir experience level
- Most interesting DSL you've used
- One domain from your work that feels "messy" to configure
- What you hope to build by end of week

**Workshop Philosophy**
- This is a **maker's workshop** - we learn by building
- **Mistakes are features** - they reveal important insights
- **Collaboration over competition** - we succeed together
- **Real problems only** - no toy examples after today

### Foundation Concepts (9:30-10:30)
**The DSL Mindset Shift**

Traditional programming mindset:
```
Problem → Algorithm → Code → Solution
```

DSL design mindset:
```
Domain → Language → Usage → Implementation
```

**Live Example: The Evolution of Configuration**

*Worst: Scattered Magic Numbers*
```elixir
# Buried in various modules
timeout = 30_000
retries = 3
url = "https://api.example.com"
```

*Bad: Configuration Files*
```elixir
# config/config.exs
config :my_app, :api,
  timeout: 30_000,
  retries: 3,
  url: "https://api.example.com"
```

*Good: Structured Configuration*
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

*Excellent: Domain DSL*
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

**What Changed?**
- **Vocabulary**: `service`, `base_url`, `circuit_breaker` vs generic config keys
- **Validation**: Invalid configurations caught at compile time
- **Documentation**: DSL is self-documenting
- **Tooling**: IDE support, autocomplete, error messages
- **Introspection**: Can query configuration at runtime

### Break (10:30-10:45)

### Live Coding Session (10:45-12:00)
**Building Your First DSL Together**

We'll build a task management DSL step by step:

**Step 1: Domain Analysis (10 minutes)**
What concepts exist in task management?
- Tasks with names, priorities, due dates
- Projects that contain tasks  
- Assignees who work on tasks
- Status tracking (todo, in_progress, done)

**Step 2: Entity Design (15 minutes)**
```elixir
# lib/task_dsl/entities.ex
defmodule TaskDsl.Entities do
  defmodule Task do
    defstruct [:name, :priority, :due_date, :assignee, :status, :description]
  end
  
  defmodule Project do
    defstruct [:name, :description, tasks: []]
  end
end
```

**Step 3: DSL Definition (20 minutes)**
```elixir
# lib/task_dsl/extension.ex
defmodule TaskDsl.Extension do
  alias TaskDsl.Entities
  
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
  
  @project %Spark.Dsl.Entity{
    name: :project,
    target: Entities.Project,
    args: [:name],
    entities: [task: @task],
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
end
```

**Step 4: DSL Module (10 minutes)**
```elixir
# lib/task_dsl.ex
defmodule TaskDsl do
  use Spark.Dsl, default_extensions: [extensions: [TaskDsl.Extension]]
end
```

**Step 5: Usage Example (15 minutes)**
```elixir
# test/example_usage.exs
defmodule TeamTasks do
  use TaskDsl
  
  projects do
    project "Spark Workshop" do
      description "Intensive 5-day DSL mastery workshop"
      
      task "Prepare materials" do
        priority :high
        assignee "instructor"
        due_date ~D[2024-01-15]
        status :done
      end
      
      task "Setup development environment" do
        priority :medium
        assignee "participants"
        due_date ~D[2024-01-20]
        status :in_progress
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

**Step 6: Introspection (10 minutes)**
```elixir
# lib/task_dsl/info.ex
defmodule TaskDsl.Info do
  use Spark.InfoGenerator,
    extension: TaskDsl.Extension,
    sections: [:projects]
end

# Usage
iex> TaskDsl.Info.projects(TeamTasks)
iex> TaskDsl.Info.project(TeamTasks, "Spark Workshop")
```

**Reflection Questions:**
- What feels natural about this DSL syntax?
- What validation would be helpful?
- How might this DSL evolve over time?

---

## Afternoon Lab Session (1:00-5:00)

### Lab 1.1: Personal Configuration DSL (1:00-3:00)

**Objective:** Build a DSL for managing your personal development environment configuration.

**Your Challenge:** Create a DSL that captures how you like to configure your development tools. This should be deeply personal - reflect your actual preferences and workflow.

**Starting Template:**
```elixir
defmodule PersonalDsl do
  use Spark.Dsl, default_extensions: [extensions: [PersonalDsl.Extension]]
end

defmodule MyDev.Config do
  use PersonalDsl
  
  # Your configuration goes here...
end
```

**Required Features:**
1. **Editor Configuration**
   - Editor choice (VSCode, Vim, Emacs, etc.)
   - Theme preferences
   - Font settings
   - Extension/plugin lists

2. **Terminal Setup**  
   - Terminal application
   - Shell preference
   - Theme and appearance
   - Custom aliases or functions

3. **Project Organization**
   - Workspace locations
   - Project categorization
   - Language-specific settings
   - Git configurations

**Example Implementation:**
```elixir
defmodule MyDev.Config do
  use PersonalDsl
  
  editor :vscode do
    theme "Dracula"
    font_family "Fira Code"
    font_size 14
    ligatures true
    
    extensions do
      extension "elixir-ls"
      extension "vim"
      extension "git-lens"
      extension "thunder-client"
    end
  end
  
  terminal :iterm2 do
    shell :zsh
    theme "Dracula"
    opacity 0.95
    blur true
    
    aliases do
      alias_cmd "ll", "ls -la"
      alias_cmd "gst", "git status"
      alias_cmd "gco", "git checkout"
    end
  end
  
  workspace do
    base_path "~/code"
    
    categories do
      category :work, path: "work"
      category :personal, path: "personal"  
      category :learning, path: "learning"
    end
  end
  
  git do
    user_name "Your Name"
    user_email "you@example.com"
    default_branch "main"
    
    aliases do
      git_alias "co", "checkout"
      git_alias "br", "branch"
      git_alias "st", "status"
    end
  end
end
```

**Implementation Steps:**

1. **Domain Analysis (15 minutes)**
   - List all the tools you configure regularly
   - Identify the settings you change most often
   - Think about relationships between configurations

2. **Entity Design (30 minutes)**
   - Create structs for each major concept
   - Define the data each entity needs to hold
   - Consider nested relationships

3. **DSL Extension (45 minutes)**
   - Define entities with proper schemas
   - Add validation for your specific needs
   - Create sections to organize related entities

4. **Usage and Testing (30 minutes)**
   - Create your actual configuration using the DSL
   - Test edge cases and validation
   - Verify that the DSL feels natural to use

5. **Info Module (20 minutes)**
   - Add runtime introspection capabilities
   - Create helper functions for common queries
   - Test accessing configuration data

**Validation Ideas:**
- File paths should exist or be creatable
- Font sizes should be reasonable (8-72)
- Color codes should be valid hex or named colors
- Extension names should follow marketplace conventions

**Stretch Goals:**
- Add platform-specific configurations (macOS vs Linux vs Windows)
- Include dotfile generation capabilities
- Add workspace synchronization features
- Create backup/restore functionality

### Break (3:00-3:15)

### Lab 1.2: DSL Enhancement and Validation (3:15-4:30)

**Objective:** Add sophisticated validation and enhanced features to your personal DSL.

**Enhancement Tasks:**

**1. Custom Validation (30 minutes)**
Add domain-specific validation beyond basic schema types:

```elixir
# Custom validators in your extension
def validate_color(color) when is_binary(color) do
  cond do
    String.match?(color, ~r/^#[0-9A-Fa-f]{6}$/) -> {:ok, color}
    color in ~w[red green blue black white] -> {:ok, color}
    true -> {:error, "Invalid color format"}
  end
end

def validate_font_size(size) when is_integer(size) and size >= 8 and size <= 72 do
  {:ok, size}
end
def validate_font_size(size) do
  {:error, "Font size must be between 8 and 72, got: #{size}"}
end
```

**2. Advanced Schema Features (25 minutes)**
Enhance your entity schemas with:
- Custom types using the validators above
- Default value functions that compute at runtime
- Conditional requirements (some fields required only if others are set)
- Cross-field validation

**3. Enhanced Info Module (25 minutes)**
Add sophisticated introspection capabilities:

```elixir
defmodule PersonalDsl.Info do
  use Spark.InfoGenerator,
    extension: PersonalDsl.Extension,
    sections: [:editor, :terminal, :workspace, :git]
  
  def editor_config(module) do
    case editor(module) do
      {:ok, config} -> config
      :error -> default_editor_config()
    end
  end
  
  def all_extensions(module) do
    module
    |> editor_config()
    |> Map.get(:extensions, [])
  end
  
  def workspace_projects(module, category) do
    module
    |> workspace()
    |> Map.get(:categories, [])
    |> Enum.find(&(&1.name == category))
    |> case do
      nil -> []
      cat -> list_projects_in_path(cat.path)
    end
  end
  
  defp default_editor_config do
    %{theme: "default", font_size: 14, font_family: "monospace"}
  end
  
  defp list_projects_in_path(path) do
    # Implementation to list actual directories
  end
end
```

**4. Configuration Generation (20 minutes)**
Add functions that can generate actual configuration files:

```elixir
defmodule PersonalDsl.Generator do
  alias PersonalDsl.Info
  
  def generate_vscode_settings(module) do
    config = Info.editor_config(module)
    
    %{
      "workbench.colorTheme" => config.theme,
      "editor.fontFamily" => config.font_family,
      "editor.fontSize" => config.font_size,
      "editor.fontLigatures" => config.ligatures
    }
    |> Jason.encode!(pretty: true)
  end
  
  def generate_gitconfig(module) do
    git_config = Info.git(module)
    
    """
    [user]
      name = #{git_config.user_name}
      email = #{git_config.user_email}
    
    [init]
      defaultBranch = #{git_config.default_branch}
    """
  end
end
```

### Lab Review and Sharing (4:30-5:00)

**Pair Sharing (15 minutes)**
Partner with someone and:
- Demo your DSL configuration
- Explain one validation rule you're proud of
- Show your favorite generated output
- Get feedback on what feels natural vs. awkward

**Group Discussion (15 minutes)**
Come together to discuss:
- What patterns emerged across different implementations?
- Which parts of the DSL felt most natural to write?
- What validation rules proved most valuable?
- How did your mental model evolve during implementation?

---

## Evening Wrap-up (5:00-6:00)

### Reflection Session (5:00-5:30)
**Individual Journaling (10 minutes)**
Write brief responses to:
1. What was the biggest mental shift from thinking in code to thinking in language?
2. When did your DSL start to feel "right"? What changed?
3. What aspect of domain modeling surprised you?
4. How is your personal DSL different from how you'd configure things with files?

**Pair Sharing (10 minutes)**
Share insights with a partner.

**Group Insights (10 minutes)**
Volunteers share key insights with the whole group.

### Preview and Preparation (5:30-6:00)
**Tomorrow's Challenge**
Day 2 moves from personal tools to business problems. We'll build production-ready DSLs that solve real organizational challenges.

**Tonight's Assignment**
1. **Reading**: "Real-World Application" chapter from the book
2. **Domain Research**: Choose a business domain from your work that has complex configuration or process definition needs
3. **Stakeholder Thinking**: Identify who would use a DSL in that domain and what their mental model looks like

**Preview: API Gateway DSL**
Tomorrow we'll build a sophisticated API gateway configuration DSL that:
- Manages upstream services and health checks
- Configures routing, authentication, and rate limiting  
- Generates actual gateway configurations
- Provides monitoring and observability integration

Get excited - we're moving into production-grade DSL territory!

---

## Day 1 Success Criteria

You've successfully completed Day 1 if you can:

- [ ] **Explain the DSL mindset** - How is designing a language different from writing code?
- [ ] **Build a working DSL** - Your personal configuration DSL compiles and validates input
- [ ] **Add meaningful validation** - Your DSL catches common mistakes and provides helpful errors
- [ ] **Use introspection** - You can query your DSL configuration at runtime
- [ ] **Generate output** - Your DSL can produce actual configuration files or data structures
- [ ] **Think in domain terms** - You instinctively consider the user's vocabulary and mental model

## Resources and References

### Code Repository
All Day 1 examples and solutions: `workshop-day-1` branch

### Additional Reading
- [Spark.Dsl.Entity documentation](https://hexdocs.pm/spark/Spark.Dsl.Entity.html)
- [Spark.Dsl.Extension documentation](https://hexdocs.pm/spark/Spark.Dsl.Extension.html)
- [NimbleOptions schema reference](https://hexdocs.pm/nimble_options/NimbleOptions.html#new/1)

### Troubleshooting
**Common Issues:**
- **"undefined function"** errors → Run `mix deps.get` and restart your editor
- **Schema validation failures** → Check your schema types match Spark conventions  
- **Compilation errors** → Ensure all required fields are provided in schema

**Get Help:**
- Instructor office hours: Available throughout afternoon labs
- Peer collaboration: Encouraged for problem-solving
- Slack channel: `#workshop-day1` for async questions

---

*"Every expert was once a beginner. Every pro was once an amateur. Today you begin the journey from DSL user to DSL creator."*

**Next:** [Day 2 - Real-World Application →](../day-2/README.md)