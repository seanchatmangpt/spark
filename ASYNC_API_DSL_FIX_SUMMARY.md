# AsyncAPI DSL Forward Reference Fix Summary

## Problem
The AsyncAPI DSL file (`/Users/sac/dev/spark/lib/async_api/dsl.ex`) had multiple forward reference issues where entities were being referenced before they were defined, causing compilation errors.

## Forward References Fixed

### Main Issues Identified:
1. `@external_docs` referenced before definition
2. `@server_variable` referenced before definition  
3. `@security_requirement` referenced before definition
4. `@parameter` referenced before definition
5. `@schema` referenced before definition
6. `@message_ref` referenced before definition
7. `@reply` referenced before definition
8. `@correlation_id` referenced before definition
9. `@message_example` referenced before definition
10. `@property` recursive self-reference issue
11. `@oauth_flows` referenced before definition
12. `@oauth_flow` referenced before definition
13. `@scope` referenced before definition

## Solution Applied

### Entity Ordering Strategy:
Reordered all entity definitions using a dependency-first approach:

1. **Base entities with no dependencies** (defined first):
   - `@external_docs`
   - `@contact`
   - `@license`
   - `@server_variable`
   - `@security_requirement`
   - `@correlation_id`
   - `@message_example`
   - `@scope`

2. **Property entity with recursive reference**:
   - Defined `@property` without recursive reference initially
   - Added recursive reference using `%{@property | entities: [properties: [@property]]}`

3. **Entities that depend on base entities**:
   - `@tag` (depends on `@external_docs`)
   - `@oauth_flow` (depends on `@scope`)
   - `@oauth_flows` (depends on `@oauth_flow`)
   - `@schema` (depends on `@property`)
   - `@parameter` (depends on `@schema`)
   - `@message_ref`
   - `@reply` (depends on `@message_ref`)
   - `@security_scheme` (depends on `@oauth_flows`)

4. **Complex entities that depend on multiple other entities**:
   - `@server` (depends on `@server_variable`, `@security_requirement`, `@tag`, `@external_docs`)
   - `@channel` (depends on `@parameter`, `@tag`, `@external_docs`)
   - `@operation` (depends on `@security_requirement`, `@tag`, `@external_docs`, `@message_ref`, `@reply`)
   - `@message` (depends on `@correlation_id`, `@message_example`, `@tag`, `@external_docs`)

5. **Root-level entities** (defined last):
   - `@async_api_id`
   - `@default_content_type`
   - `@info`

### Additional Fixes:
- Fixed sections definition in `@components_section` by converting from keyword list format to proper list format
- Handled recursive `@property` reference using module attribute merging

## Result
The AsyncAPI DSL now compiles successfully without any forward reference errors. All entity dependencies are properly ordered, and the recursive property reference is handled correctly.

## Files Modified
- `/Users/sac/dev/spark/lib/async_api/dsl.ex` - Complete entity reordering and dependency resolution

## Verification
The file compiles successfully with `mix compile lib/async_api/dsl.ex` showing only warnings about unused attributes but no compilation errors.