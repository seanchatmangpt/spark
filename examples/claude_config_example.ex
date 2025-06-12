defmodule MyApp.ClaudeConfig do
  @moduledoc """
  Example Claude Code configuration for a Phoenix application.
  
  This demonstrates how to use the ClaudeConfig DSL to define:
  - Project information
  - Security permissions for tools and bash commands
  - Reusable command templates
  
  To generate the .claude directory structure:
  
      ClaudeConfig.generate_claude_directory(MyApp.ClaudeConfig)
  
  This will create:
  - .claude/config.json with permissions and project info
  - .claude/commands/*.md files for each command template
  """

  use ClaudeConfig

  # Project Information
  project do
    name "MyApp Phoenix Application"
    description "A modern Phoenix web application with LiveView"
    language "Elixir"
    framework "Phoenix"
    version "1.0.0"
  end

  # Security Permissions
  permissions do
    # File Operations - Allow reading all files
    allow_tool "Read(**/*)"
    
    # Writing permissions - be specific about what can be written
    allow_tool "Write(**/*.ex)"        # Elixir source files
    allow_tool "Write(**/*.exs)"       # Elixir script files
    allow_tool "Write(**/*.heex)"      # Phoenix templates
    allow_tool "Write(**/*.md)"        # Documentation
    allow_tool "Write(**/*.json)"      # Configuration files
    allow_tool "Write(**/*.yml)"       # YAML files
    allow_tool "Write(**/*.yaml)"      # YAML files
    allow_tool "Write(mix.exs)"        # Mix project file
    allow_tool "Write(.formatter.exs)" # Code formatter config
    allow_tool "Write(config/**/*)"    # Config directory
    allow_tool "Write(priv/**/*)"      # Private resources
    allow_tool "Write(assets/**/*)"    # Frontend assets

    # Directory and file exploration
    allow_tool "LS(**/*)"
    allow_tool "Glob(**/*)"
    allow_tool "Grep(**/*)"

    # Development Commands
    allow_bash "mix *"                 # All Mix commands
    allow_bash "iex *"                 # Interactive Elixir
    allow_bash "elixir *"              # Elixir runtime
    allow_bash "git *"                 # Git operations
    allow_bash "npm *"                 # Node package manager
    allow_bash "yarn *"                # Yarn package manager
    allow_bash "find *"                # File finding
    allow_bash "grep *"                # Text search
    allow_bash "rg *"                  # Ripgrep
    allow_bash "cat *"                 # File reading
    allow_bash "head *"                # File head
    allow_bash "tail *"                # File tail
    allow_bash "mkdir *"               # Directory creation
    allow_bash "cp *"                  # File copying
    allow_bash "mv *"                  # File moving
    allow_bash "echo *"                # Echo command

    # Security Denials - Prevent dangerous operations
    deny_bash "rm -rf *"               # Recursive deletion
    deny_bash "sudo *"                 # Superuser operations
    deny_bash "chmod 777 *"            # Overly permissive permissions
    deny_bash "chown *"                # Ownership changes
    deny_bash "dd *"                   # Disk operations
    deny_bash "mkfs *"                 # Filesystem operations
    deny_bash "fdisk *"                # Disk partitioning
    deny_bash "mount *"                # Filesystem mounting
    deny_bash "umount *"               # Filesystem unmounting

    # File System Protection
    deny_tool "Write(/etc/**/*)"       # System configuration
    deny_tool "Write(/usr/**/*)"       # System binaries
    deny_tool "Write(/bin/**/*)"       # System binaries
    deny_tool "Write(/sbin/**/*)"      # System admin binaries
    deny_tool "Write(~/.ssh/**/*)"     # SSH keys
    deny_tool "Write(~/.aws/**/*)"     # AWS credentials
    deny_tool "Write(**/.env)"         # Environment files
    deny_tool "Write(**/secrets.*)"    # Secret files
  end

  # Command Templates
  commands do
    command "test-suite" do
      description "Run comprehensive test suite with coverage"
      usage "/test-suite [type] [options]"
      content """
      # Test Suite Runner
      
      Runs the complete Phoenix application test suite with coverage reporting and performance analysis.
      
      ## Usage
      ```
      /test-suite [type] [options]
      ```
      
      ## Arguments
      - `type` - Optional: unit, integration, all (default: all)
      - `options` - Optional: --cover, --parallel, --watch
      
      ## Examples
      ```bash
      # Run all tests with coverage
      /test-suite all --cover
      
      # Run only unit tests
      /test-suite unit
      
      # Watch mode for development
      /test-suite unit --watch
      ```
      
      ## Implementation
      
      ```elixir
      # Run based on arguments
      case type do
        "unit" -> 
          System.cmd("mix", ["test", "test/unit/"])
        "integration" ->
          System.cmd("mix", ["test", "test/integration/"])
        _ ->
          System.cmd("mix", ["test", "--cover"])
      end
      ```
      """
      examples [
        "mix test --cover",
        "mix test test/unit/ --parallel",
        "mix test --watch"
      ]
    end

    command "dev-setup" do
      description "Set up development environment"
      usage "/dev-setup [force]"
      content """
      # Development Environment Setup
      
      Initializes the development environment for the Phoenix application.
      
      ## Usage
      ```
      /dev-setup [force]
      ```
      
      ## What it does
      1. Install dependencies with `mix deps.get`
      2. Set up database with `mix ecto.setup`
      3. Install Node.js dependencies for assets
      4. Compile assets
      5. Start development server
      
      ## Implementation
      
      ```bash
      # Install Elixir dependencies
      mix deps.get
      
      # Database setup
      mix ecto.setup
      
      # Install and build assets
      cd assets && npm install && npm run build
      cd ..
      
      # Start development server
      mix phx.server
      ```
      """
    end

    command "deploy-check" do
      description "Pre-deployment validation and checks"
      content """
      # Deployment Readiness Check
      
      Validates that the application is ready for deployment by running comprehensive checks.
      
      ## Checks Performed
      
      ### Code Quality
      - Code compilation without warnings
      - Code formatting validation
      - Credo code analysis
      - Dialyzer type checking
      
      ### Testing
      - Full test suite execution
      - Test coverage validation (>90%)
      - Performance test execution
      
      ### Security
      - Dependency vulnerability scanning
      - Configuration validation
      - Secrets detection
      
      ### Infrastructure
      - Database migration validation
      - Asset compilation
      - Environment configuration check
      
      ## Implementation
      
      ```bash
      # Code quality checks
      mix compile --warnings-as-errors
      mix format --check-formatted
      mix credo --strict
      mix dialyzer
      
      # Testing
      mix test --cover
      mix test.performance
      
      # Security
      mix deps.audit
      mix sobelow
      
      # Infrastructure
      mix ecto.migrate --dry-run
      mix assets.build
      mix release --dry-run
      ```
      """
    end

    command "debug-session" do
      description "Start interactive debugging session"
      content """
      # Interactive Debugging Session
      
      Starts an interactive IEx session with the application loaded and debugging tools available.
      
      ## Features
      - Application preloaded
      - Debugging helpers available
      - Database connection active
      - Recompilation on code changes
      
      ## Usage
      
      ```bash
      # Start debugging session
      iex -S mix phx.server
      
      # Common debugging commands:
      # - recompile()          # Recompile changed modules
      # - :observer.start()    # Start Observer GUI
      # - :debugger.start()    # Start Debugger
      # - IEx.break!(module, :function) # Set breakpoint
      ```
      
      ## Debugging Helpers
      
      ```elixir
      # Inspect data with labels
      IO.inspect(data, label: "Debug")
      
      # Pipe-friendly debugging
      data
      |> IO.inspect(label: "Before transformation")
      |> transform_function()
      |> IO.inspect(label: "After transformation")
      
      # Pattern matching debugging
      require IEx; IEx.pry()
      ```
      """
    end

    command "performance-profile" do
      description "Profile application performance"
      content """
      # Performance Profiling
      
      Analyzes application performance using various profiling tools.
      
      ## Profiling Tools
      
      ### Memory Profiling
      ```bash
      # Memory usage analysis
      mix profile.memory MyApp.heavy_function()
      ```
      
      ### Time Profiling  
      ```bash
      # Execution time analysis
      mix profile.cprof MyApp.heavy_function()
      mix profile.fprof MyApp.heavy_function()
      ```
      
      ### Process Analysis
      ```elixir
      # In IEx session
      :observer.start()
      
      # Process tree visualization
      :pman.start()
      
      # Memory inspection
      :recon.memory_usage(:current)
      ```
      
      ### Database Performance
      ```bash
      # Query analysis
      mix ecto.explain "SELECT * FROM users WHERE email = $1" --analyze
      
      # Index usage analysis
      mix ecto.migrations.status
      ```
      
      ## Performance Testing
      ```bash
      # Load testing
      mix test test/performance/
      
      # Benchmark specific functions
      mix bench.compare
      ```
      """
    end
  end
end