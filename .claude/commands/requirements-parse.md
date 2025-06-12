# Requirements Parse - Natural Language to DSL Specification

Converts human requirements in natural language, examples, or sketches into formal DSL specifications that can be used by the AGI factory for autonomous DSL generation.

## Usage
```
/requirements-parse <input> [output_format] [domain_context]
```

## Arguments
- `input` - Natural language requirements, example code, or specification file
- `output_format` - Optional: structured, entity_map, behavioral, constraints (default: structured)
- `domain_context` - Optional: web, data, validation, api, workflow (default: inferred)

## Input Types

### Natural Language Requirements
```
"I need a DSL for defining API endpoints where each endpoint can have authentication rules, input validation, rate limiting, and custom middleware. The syntax should be declarative and easy to read."
```

### Example Code
```elixir
# User provides existing code they want to convert to DSL
def create_user(params) do
  with {:ok, validated} <- validate_params(params),
       {:ok, user} <- User.create(validated),
       :ok <- send_welcome_email(user) do
    {:ok, user}
  end
end
```

### Partial Specifications
```
api do
  endpoint "/users" do
    auth :required
    validate User.changeset()
    rate_limit 100, :per_minute
  end
end
```

## Examples
```bash
# Parse natural language requirements
/requirements-parse "I need a validation DSL with conditional rules" structured validation

# Convert existing code to DSL specification
/requirements-parse example_workflow.ex behavioral workflow

# Analyze partial DSL and complete specification
/requirements-parse partial_dsl.ex constraints api
```

## Implementation

### Natural Language Processing
```elixir
def parse_natural_language(text, domain_context) do
  # Extract domain concepts and entities
  entities = extract_entities(text, domain_context)
  relationships = identify_relationships(text, entities)
  behaviors = extract_behaviors(text)
  constraints = infer_constraints(text, entities)
  
  # Analyze syntax preferences from language cues
  syntax_style = infer_syntax_preferences(text)
  api_patterns = identify_preferred_patterns(text)
  
  %DSLSpecification{
    domain: domain_context,
    entities: entities,
    relationships: relationships,
    behaviors: behaviors,
    constraints: constraints,
    syntax_style: syntax_style,
    api_patterns: api_patterns,
    performance_requirements: extract_performance_cues(text),
    usability_requirements: extract_usability_cues(text)
  }
end

defp extract_entities(text, domain) do
  # Use domain-specific entity recognition
  base_entities = nlp_extract_entities(text)
  
  # Enhance with domain knowledge
  enhanced_entities = case domain do
    :api -> enhance_with_api_entities(base_entities, text)
    :validation -> enhance_with_validation_entities(base_entities, text)
    :workflow -> enhance_with_workflow_entities(base_entities, text)
    :data -> enhance_with_data_entities(base_entities, text)
    _ -> infer_domain_and_enhance(base_entities, text)
  end
  
  # Extract entity properties and relationships
  Enum.map(enhanced_entities, fn entity ->
    %Entity{
      name: entity.name,
      type: classify_entity_type(entity, domain),
      properties: extract_entity_properties(entity, text),
      validation_rules: infer_entity_validations(entity, text),
      relationships: find_entity_relationships(entity, enhanced_entities, text)
    }
  end)
end
```

### Code Analysis and Reverse Engineering
```elixir
def reverse_engineer_from_code(code_input) do
  # Parse existing code structure
  ast = Code.string_to_quoted!(code_input)
  
  # Extract patterns and structures
  patterns = analyze_code_patterns(ast)
  data_flow = trace_data_flow(ast)
  validation_logic = extract_validation_patterns(ast)
  error_handling = analyze_error_patterns(ast)
  
  # Convert to DSL specification
  %DSLSpecification{
    entities: infer_entities_from_code(patterns),
    behaviors: extract_behaviors_from_flow(data_flow),
    constraints: convert_validations_to_constraints(validation_logic),
    error_handling: convert_error_handling(error_handling),
    api_style: infer_api_style_from_code(patterns),
    complexity_level: assess_code_complexity(ast)
  }
end

defp analyze_code_patterns(ast) do
  # Identify common patterns in the code
  patterns = %{
    function_patterns: extract_function_patterns(ast),
    data_patterns: extract_data_structures(ast),
    control_flow: analyze_control_flow(ast),
    module_structure: analyze_module_organization(ast)
  }
  
  # Classify patterns by DSL relevance
  classify_dsl_relevant_patterns(patterns)
end
```

### Specification Synthesis
```elixir
def synthesize_complete_specification(parsed_input, domain_context) do
  # Start with parsed requirements
  base_spec = parsed_input
  
  # Fill in missing pieces with domain knowledge
  enhanced_spec = enhance_with_domain_defaults(base_spec, domain_context)
  
  # Infer missing relationships and constraints
  complete_spec = infer_missing_elements(enhanced_spec)
  
  # Validate specification completeness
  validated_spec = validate_specification_completeness(complete_spec)
  
  # Generate multiple implementation strategies
  implementation_strategies = generate_implementation_approaches(validated_spec)
  
  %CompleteSpecification{
    original_input: parsed_input,
    enhanced_specification: validated_spec,
    implementation_strategies: implementation_strategies,
    estimated_complexity: calculate_implementation_complexity(validated_spec),
    recommended_approach: select_optimal_strategy(implementation_strategies),
    potential_extensions: identify_future_extensions(validated_spec)
  }
end
```

## Output Formats

### Structured Format
Complete formal specification with all components:
```elixir
%DSLSpecification{
  domain: :api,
  entities: [
    %Entity{name: :endpoint, properties: [:path, :method, :auth]},
    %Entity{name: :middleware, properties: [:name, :config]}
  ],
  behaviors: [
    %Behavior{name: :authenticate, triggers: [:before_request]},
    %Behavior{name: :validate, triggers: [:on_input]}
  ],
  constraints: [
    %Constraint{entity: :endpoint, rule: "path must be unique"},
    %Constraint{entity: :auth, rule: "method must be in allowed_methods"}
  ]
}
```

### Entity Map Format
Entity-relationship focused view:
```
Entities:
  - Endpoint (path, method, auth_rules, middleware_stack)
  - AuthRule (type, config, failure_action)
  - Middleware (name, priority, config)

Relationships:
  - Endpoint HAS_MANY AuthRules
  - Endpoint HAS_ORDERED_LIST Middleware
  - AuthRule REFERENCES User or Role
```

### Behavioral Format
Behavior and workflow focused:
```
Behaviors:
  1. Request arrives → Check auth rules → Validate input
  2. On auth failure → Return 401 → Log attempt
  3. On validation failure → Return 400 → Include errors
  4. On success → Execute middleware → Call handler
```

### Constraints Format
Validation and constraint focused:
```
Constraints:
  - endpoint.path: unique, must start with '/', no spaces
  - auth.type: one_of([bearer, basic, api_key, none])
  - middleware.priority: integer, 1-100, unique per endpoint
  - rate_limit.count: positive_integer, default: 1000
```

This command enables the AGI factory to understand human requirements in any format and convert them into precise specifications for autonomous DSL generation.