# ClaudeConfig DSL Naming Conventions

This document establishes naming conventions for the ClaudeConfig DSL to ensure consistency with Spark framework patterns and Elixir community standards.

## Overview

ClaudeConfig follows the established Spark DSL patterns for naming, which in turn follow Elixir community conventions. The key principle is **clarity and consistency** without unnecessary prefixes.

## DSL Structure Naming

### Module Names
- **Main DSL Module**: `ClaudeConfig` (PascalCase)
- **DSL Extension**: `ClaudeConfig.Dsl` (PascalCase with `.Dsl` suffix)
- **Info Module**: `ClaudeConfig.Info` (PascalCase with `.Info` suffix)
- **Transformers**: `ClaudeConfig.Transformers.ValidateConfig` (descriptive transformer name)

### Section Names
Use lowercase atoms that describe the configuration area:
- `:project` - Project metadata and information
- `:permissions` - Security permissions and access control
- `:commands` - Reusable command templates

### Entity Names
Use singular, lowercase atoms that describe the specific configuration item:
- `:project` - Project information (singular, only one allowed)
- `:allow_tool` - Tool permission to allow
- `:deny_tool` - Tool permission to deny  
- `:allow_bash` - Bash command pattern to allow
- `:deny_bash` - Bash command pattern to deny
- `:command` - Command template definition

## Info Module Function Naming

### Auto-Generated Functions
Spark InfoGenerator automatically creates functions based on section and entity names:

```elixir
# Section name becomes function name for entities in that section
project(resource)                    # Returns list of :project entities
permissions_allow_tool(resource)     # Returns list of :allow_tool entities from :permissions
permissions_deny_tool(resource)      # Returns list of :deny_tool entities from :permissions  
permissions_allow_bash(resource)     # Returns list of :allow_bash entities from :permissions
permissions_deny_bash(resource)      # Returns list of :deny_bash entities from :permissions
commands_command(resource)           # Returns list of :command entities from :commands
```

### Custom Helper Functions
Use descriptive names without unnecessary prefixes:

```elixir
# Good - Clear, descriptive, follows Elixir conventions
def project_info(resource)          # Returns single project (handles list->single conversion)
def permissions(resource)           # Returns structured permissions object
def commands(resource)              # Returns all command templates
def command(resource, name)         # Returns specific command by name
def command_names(resource)         # Returns list of command names
def tool_allowed?(resource, pattern) # Permission check with ? suffix for boolean
def bash_allowed?(resource, cmd)    # Permission check with ? suffix for boolean

# Bad - Unnecessary prefixes
def get_project_info(resource)      # Avoid "get_" prefix
def fetch_commands(resource)        # Avoid "fetch_" prefix  
def retrieve_permissions(resource)  # Avoid "retrieve_" prefix
```

### Boolean Function Naming
Functions returning booleans should end with `?`:
- `tool_allowed?/2` - Checks if a tool pattern is allowed
- `bash_allowed?/2` - Checks if a bash command is allowed
- `command_exists?/2` - Checks if a command exists (if implemented)

## Entity Struct Naming

### Entity Modules
Use descriptive PascalCase names that match the domain:
```elixir
ClaudeConfig.Dsl.Project          # Project information
ClaudeConfig.Dsl.AllowTool        # Tool permission to allow
ClaudeConfig.Dsl.DenyTool         # Tool permission to deny
ClaudeConfig.Dsl.AllowBash        # Bash command to allow
ClaudeConfig.Dsl.DenyBash         # Bash command to deny
ClaudeConfig.Dsl.Command          # Command template
ClaudeConfig.Dsl.Permissions      # Container for permission groups
```

### Struct Field Names
Use lowercase atoms with underscores:
```elixir
%ClaudeConfig.Dsl.Project{
  name: "My Project",              # Clear, descriptive
  description: "Project desc",     # Standard naming
  language: "Elixir",             # Not "programming_language" - context is clear
  framework: "Phoenix",           # Optional framework
  version: "1.0.0"               # Semantic version
}

%ClaudeConfig.Dsl.Command{
  name: "test-runner",            # Kebab-case for command names
  description: "Run tests",       # Brief description
  content: "# Markdown content",  # Full template content
  usage: "/test-runner [args]",   # Usage pattern
  examples: ["mix test"]          # List of examples
}
```

## DSL Usage Naming

### DSL Keywords
Use clear, imperative verbs where appropriate:
```elixir
# Project configuration - declarative
project do
  name "My App"
  description "A sample app"
  language "Elixir"
end

# Permissions - imperative verbs
permissions do
  allow_tool "Read(**/*)"         # "allow" is imperative
  deny_bash "rm -rf *"           # "deny" is imperative
end

# Commands - noun-based (templates)
commands do
  command "test-runner" do        # Command name in kebab-case
    description "Run tests"
    content "..."
  end
end
```

### Command Template Naming
Command names should use kebab-case for consistency with CLI conventions:
- `"test-runner"` ✓ (not `"test_runner"` or `"testRunner"`)
- `"build-docs"` ✓ (not `"build_docs"`)
- `"deploy-check"` ✓ (not `"deployCheck"`)

## File and Directory Naming

### Module Files
Follow Elixir conventions (snake_case):
```
lib/claude_config.ex                          # Main module
lib/claude_config/dsl.ex                     # DSL extension
lib/claude_config/info.ex                    # Info module  
lib/claude_config/transformers/validate_config.ex  # Transformer
```

### Test Files
Mirror the module structure:
```
test/claude_config_test.exs                          # Main tests
test/claude_config/dsl_validation_test.exs          # DSL validation tests
test/claude_config/pattern_matching_test.exs        # Pattern matching tests
```

### Generated Files
Follow Claude Code conventions:
```
.claude/config.json                          # Main configuration
.claude/commands/test-runner.md             # Command templates (kebab-case)
.claude/commands/build-docs.md              # Command templates (kebab-case)
```

## Error Message Naming

Use clear, descriptive error messages:
```elixir
# Good - Clear and actionable
"Only one project configuration is allowed, got: 3"
"Duplicate command names found: test-runner, build-docs"  
"Invalid tool pattern: 'InvalidTool(**/*)', expected format like 'Read(**/*)', 'Write(**/*.ex)'"

# Bad - Vague or technical jargon
"Project error"
"Command conflict"
"Pattern invalid"
```

## Documentation Naming

### Function Documentation
Use clear, consistent patterns:
```elixir
@doc "Get project information (only one allowed per module)"
@doc "Get permissions configuration"  
@doc "Get all command templates"
@doc "Get a specific command template by name"
@doc "Check if a tool pattern is allowed"
@doc "Check if a bash command is allowed"
```

### Module Documentation
Start with purpose, then provide examples:
```elixir
@moduledoc """
DSL for managing Claude Code .claude directory configurations.

Provides a declarative way to define Claude Code project settings, permissions,
and command templates through a structured DSL that generates proper .claude
directory structures.

## Example

    defmodule MyProject.ClaudeConfig do
      use ClaudeConfig
      # ... DSL usage
    end
"""
```

## Consistency Rules

### 1. No Unnecessary Prefixes
- ❌ `get_project()`, `fetch_commands()`, `retrieve_permissions()`
- ✅ `project_info()`, `commands()`, `permissions()`

### 2. Boolean Functions End with `?`
- ❌ `tool_allowed()`, `is_bash_allowed()`
- ✅ `tool_allowed?()`, `bash_allowed?()`

### 3. Use Domain Language
- ❌ `config_items()`, `settings_list()`
- ✅ `commands()`, `permissions()`

### 4. Be Consistent Across Similar Functions
```elixir
# All entity accessors follow same pattern
def commands(resource)              # All commands
def command(resource, name)         # Specific command by name
def command_names(resource)         # List of names

# All permission checks follow same pattern  
def tool_allowed?(resource, pattern)
def bash_allowed?(resource, command)
```

### 5. Match Spark Framework Patterns
Follow established Spark DSL conventions for Info modules, transformers, and entity definitions to maintain consistency across the ecosystem.

## Summary

The ClaudeConfig naming conventions prioritize:
1. **Clarity** - Names should be immediately understandable
2. **Consistency** - Similar functions use similar naming patterns  
3. **Brevity** - Avoid unnecessary prefixes and verbosity
4. **Standards** - Follow Elixir and Spark framework conventions
5. **Domain Alignment** - Use terms that match the Claude Code domain

These conventions ensure ClaudeConfig integrates seamlessly with the Spark DSL ecosystem while providing an intuitive API for Claude Code configuration management.