# Setting Up Your Environment

> *"A journey of a thousand miles begins with a single step."* - Lao Tzu

Before embarking on your DSL creation journey, proper environment setup ensures a smooth and productive experience. This chapter covers everything needed to create, develop, and maintain Spark DSLs effectively.

## Prerequisites

### Elixir and Erlang/OTP

Spark requires a recent version of Elixir with OTP support:

**Minimum Requirements**:
- Elixir 1.15+
- Erlang/OTP 26+
- Mix build tool

**Installation**:

**macOS** (using Homebrew):
```bash
brew install elixir
```

**Ubuntu/Debian**:
```bash
# Add Erlang Solutions repository
wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
sudo dpkg -i erlang-solutions_2.0_all.deb
sudo apt-get update

# Install Elixir
sudo apt-get install elixir
```

**Using asdf** (recommended for version management):
```bash
# Install asdf plugins
asdf plugin add erlang
asdf plugin add elixir

# Install latest versions
asdf install erlang 26.2.2
asdf install elixir 1.16.1-otp-26

# Set global versions
asdf global erlang 26.2.2
asdf global elixir 1.16.1-otp-26
```

**Verification**:
```bash
elixir --version
# Expected output:
# Erlang/OTP 26 [erts-14.2.2] [source] [64-bit] [smp:8:8] [ds:8:8:10] [async-threads:1] [jit:ns]
# Elixir 1.16.1 (compiled with Erlang/OTP 26)
```

## Project Setup

### Creating a New Project

Start with a standard Mix project:

```bash
# Create new project
mix new my_dsl_project --sup
cd my_dsl_project
```

### Essential Dependencies

Add Spark and related tools to your `mix.exs`:

```elixir
defp deps do
  [
    # Core Spark framework
    {:spark, "~> 2.2.65"},
    
    # Code generation and project modification
    {:igniter, "~> 0.6.6", only: [:dev]},
    
    # Documentation generation
    {:ex_doc, "~> 0.31", only: :dev, runtime: false},
    
    # Testing utilities
    {:stream_data, "~> 1.0", only: [:test]},
    
    # Development tools
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
    
    # Optional: For advanced examples
    {:jason, "~> 1.4"},
    {:nimble_options, "~> 1.1"}
  ]
end
```

**Install dependencies**:
```bash
mix deps.get
```

### Directory Structure

Organize your project for DSL development:

```
my_dsl_project/
├── lib/
│   ├── my_dsl_project/
│   │   ├── dsl/                    # DSL definitions
│   │   │   ├── my_dsl.ex
│   │   │   └── extensions/
│   │   │       ├── core.ex
│   │   │       └── validations.ex
│   │   ├── transformers/           # Compile-time processors
│   │   │   ├── add_defaults.ex
│   │   │   └── generate_code.ex
│   │   ├── verifiers/              # Validation logic
│   │   │   ├── validate_config.ex
│   │   │   └── check_references.ex
│   │   ├── info/                   # Runtime introspection
│   │   │   └── my_dsl.ex
│   │   └── examples/               # Example DSL usage
│   │       ├── blog.ex
│   │       └── api.ex
│   └── my_dsl_project.ex
├── test/
│   ├── dsl/
│   ├── transformers/
│   ├── verifiers/
│   └── examples/
├── docs/                           # Documentation
├── examples/                       # Real-world examples
└── usage-rules.md                  # LLM-friendly usage guide
```

## Development Tools

### Editor Configuration

#### Visual Studio Code

Install essential extensions:

```bash
# Elixir language support
code --install-extension jakebecker.elixir-ls

# Syntax highlighting improvements  
code --install-extension mjmcloug.vscode-elixir

# Testing support
code --install-extension sammkj.vscode-elixir-test-runner
```

**Workspace settings** (`.vscode/settings.json`):
```json
{
  "elixirLS.projectDir": "",
  "elixirLS.mixEnv": "dev",
  "elixirLS.fetchDeps": true,
  "elixirLS.suggestSpecs": true,
  "files.associations": {
    "*.ex": "elixir",
    "*.exs": "elixir"
  },
  "search.exclude": {
    "**/deps": true,
    "**/_build": true
  }
}
```

#### Emacs

Add to your configuration:

```elisp
;; Elixir support
(use-package elixir-mode
  :ensure t
  :hook (elixir-mode . lsp-deferred))

;; LSP support
(use-package lsp-mode
  :ensure t
  :commands lsp
  :config
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]_build\\'")
  (add-to-list 'lsp-file-watch-ignored-directories "[/\\\\]deps\\'"))
```

#### Vim/Neovim

Install vim-elixir:

```vim
" Using vim-plug
Plug 'elixir-editors/vim-elixir'
Plug 'neovim/nvim-lspconfig'

" LSP configuration
lua << EOF
require'lspconfig'.elixirls.setup{
  cmd = { "/path/to/language_server.sh" };
}
EOF
```

### Spark-Specific Tooling

#### Formatter Configuration

Add to `.formatter.exs`:

```elixir
# .formatter.exs
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  plugins: [Spark.Formatter],
  import_deps: [:spark]
]
```

This enables:
- Automatic DSL syntax formatting
- Proper indentation for nested DSL blocks
- Integration with `mix format`

#### Autocomplete Setup

Generate autocomplete configuration:

```bash
mix spark.formatter
```

This updates your `.formatter.exs` with `locals_without_parens` for your DSLs, enabling better formatting and IDE support.

#### Documentation Setup

Configure ExDoc for DSL documentation:

```elixir
# mix.exs
def project do
  [
    # ... other config
    docs: [
      main: "readme",
      extras: [
        "README.md",
        "docs/getting-started.md",
        "docs/dsl-reference.md"
      ],
      groups_for_extras: [
        "Guides": Path.wildcard("docs/**/*.md")
      ],
      groups_for_modules: [
        "DSL Components": [
          MyDslProject.Dsl,
          MyDslProject.Dsl.Extensions.Core
        ],
        "Transformers": [
          MyDslProject.Transformers.AddDefaults
        ],
        "Verifiers": [
          MyDslProject.Verifiers.ValidateConfig
        ]
      ]
    ]
  ]
end
```

## Quality Assurance Setup

### Testing Configuration

Configure testing for DSL development:

```elixir
# test/test_helper.exs
ExUnit.start()

# Add support for property-based testing
ExUnit.configure(exclude: [property: true])

# Load test support modules
Code.require_file("support/dsl_test_case.ex", __DIR__)
```

**DSL Test Support** (`test/support/dsl_test_case.ex`):
```elixir
defmodule MyDslProject.DslTestCase do
  @moduledoc """
  Test utilities for DSL development.
  """
  
  use ExUnit.CaseTemplate
  
  using do
    quote do
      import MyDslProject.DslTestCase
      alias MyDslProject.Dsl.Info
    end
  end
  
  def build_dsl(opts \\ []) do
    """
    Creates a test DSL module with the given options.
    """
    # Implementation
  end
  
  def assert_compiles(dsl_code) do
    """
    Asserts that DSL code compiles without errors.
    """
    # Implementation
  end
  
  def assert_validation_error(dsl_code, expected_error) do
    """
    Asserts that DSL code produces the expected validation error.
    """
    # Implementation
  end
end
```

### Code Quality

#### Credo Configuration

Create `.credo.exs`:

```elixir
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "test/"
        ],
        excluded: [
          ~r"/_build/",
          ~r"/deps/"
        ]
      },
      checks: [
        # Enabled checks
        {Credo.Check.Consistency.ExceptionNames, []},
        {Credo.Check.Consistency.LineEndings, []},
        {Credo.Check.Consistency.ParameterPatternMatching, []},
        {Credo.Check.Consistency.SpaceAroundOperators, []},
        {Credo.Check.Consistency.SpaceInParentheses, []},
        {Credo.Check.Consistency.TabsOrSpaces, []},
        
        # DSL-specific rules
        {Credo.Check.Design.AliasUsage, [if_nested_deeper_than: 2]},
        {Credo.Check.Readability.ModuleDoc, false},
        
        # Spark DSL considerations
        {Credo.Check.Refactor.CyclomaticComplexity, [max_complexity: 12]}
      ]
    }
  ]
}
```

#### Dialyzer Configuration

Add to `mix.exs`:

```elixir
def project do
  [
    # ... other config
    dialyzer: [
      plt_add_apps: [:mix, :ex_unit],
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      flags: [:error_handling, :race_conditions, :underspecs]
    ]
  ]
end
```

Create PLT (Persistent Lookup Table):

```bash
mix dialyzer --plt
```

## Development Workflow

### Daily Development Commands

**Compilation and Testing**:
```bash
# Compile with warnings as errors
mix compile --warnings-as-errors

# Run tests with coverage
mix test --cover

# Run property-based tests
mix test --include property

# Format code
mix format

# Check code quality
mix credo

# Type checking
mix dialyzer
```

**Documentation Generation**:
```bash
# Generate documentation
mix docs

# Generate DSL cheat sheets
mix spark.cheat_sheets

# Serve docs locally
mix docs && open doc/index.html
```

### Continuous Integration

Example GitHub Actions workflow (`.github/workflows/ci.yml`):

```yaml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    name: Test
    runs-on: ubuntu-latest
    strategy:
      matrix:
        elixir: ['1.15', '1.16']
        otp: ['26']
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Elixir
      uses: erlef/setup-beam@v1
      with:
        elixir-version: ${{ matrix.elixir }}
        otp-version: ${{ matrix.otp }}
    
    - name: Restore dependencies cache
      uses: actions/cache@v3
      with:
        path: deps
        key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
        restore-keys: ${{ runner.os }}-mix-
    
    - name: Install dependencies
      run: mix deps.get
    
    - name: Check formatting
      run: mix format --check-formatted
    
    - name: Check warnings
      run: mix compile --warnings-as-errors
    
    - name: Run tests
      run: mix test --cover
    
    - name: Code quality
      run: mix credo
    
    - name: Generate docs
      run: mix docs
```

## Performance Optimization

### Development Environment

**Increase compiler parallelism**:
```bash
export ERL_COMPILER_OPTIONS="+{hipe,[o3]}"
export ELIXIR_ERL_OPTIONS="+sbwt very_long +swt very_low"
```

**Development aliases** in `mix.exs`:
```elixir
def aliases do
  [
    # Quick development checks
    check: [
      "format --check-formatted",
      "compile --warnings-as-errors", 
      "test",
      "credo"
    ],
    
    # Full quality check
    "check.full": [
      "check",
      "dialyzer",
      "docs"
    ],
    
    # Setup for new contributors
    setup: [
      "deps.get",
      "dialyzer --plt"
    ]
  ]
end
```

### Production Build Optimization

**Compile-time configuration**:
```elixir
# config/prod.exs
import Config

config :my_dsl_project, :spark,
  compile_time_validations: true,
  generate_docs: false,
  cache_info_modules: true
```

## Troubleshooting Common Issues

### Compilation Problems

**Issue**: `undefined function` errors for DSL keywords
**Solution**: Run `mix spark.formatter` to update `locals_without_parens`

**Issue**: Macro expansion errors
**Solution**: Check DSL entity definitions and ensure proper schema validation

**Issue**: Circular dependency errors  
**Solution**: Review transformer and verifier dependencies

### IDE Integration Issues

**Issue**: No autocomplete for DSL keywords
**Solution**: Ensure ElixirLS is running and `mix spark.formatter` has been executed

**Issue**: Syntax highlighting incorrect
**Solution**: Update language server and ensure file associations are correct

### Performance Issues

**Issue**: Slow compilation times
**Solution**: 
- Profile compilation with `mix compile --profile`
- Optimize transformer and verifier performance
- Consider splitting large DSL definitions

**Issue**: High memory usage during development
**Solution**:
- Increase VM memory: `export ERL_MAX_PORTS=32768`
- Use `mix compile --purge-consolidation-cache`

## Next Steps

With your environment properly configured, you're ready to:

1. **Create Your First DSL** - Start with a simple configuration DSL
2. **Explore Examples** - Study the provided example DSLs
3. **Read the Documentation** - Dive deeper into Spark concepts
4. **Join the Community** - Connect with other Spark developers

Your development environment is now optimized for productive DSL development. The tools and configurations in this chapter provide a solid foundation for the journey ahead.

*A well-prepared environment enables flow state—where complex DSL creation feels effortless and natural.*