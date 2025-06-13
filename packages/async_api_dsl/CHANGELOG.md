# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-11

### Added

#### Core Features
- Full AsyncAPI 3.0 specification support with complete DSL coverage
- Compile-time validation with comprehensive error reporting
- Runtime introspection for querying API definitions programmatically
- JSON and YAML export capabilities with pretty printing

#### AsyncAPI 3.0 Features
- **Operations as first-class citizens** - New in v3.0, operations are now separate from channels
- **Reply patterns** - Full support for request-reply messaging patterns
- **Enhanced security schemes** - OAuth2 flows, API keys, HTTP authentication
- **Protocol bindings** - WebSocket, Kafka, AMQP, HTTP, and custom protocol support
- **Comprehensive metadata** - Tags, contact information, license details
- **Message traits and operation traits** - Reusable behavior patterns

#### DSL Components
- **Info section** - API metadata including title, version, description, contact, license
- **Servers section** - Server connection details with variables and security
- **Channels section** - Communication channels with parameters and bindings  
- **Operations section** - Send/receive operations with messages and replies
- **Components section** - Reusable messages, schemas, and security schemes

#### Developer Experience
- **Mix task** - `mix async_api.gen` for generating specification files
- **Configuration system** - Flexible configuration options via application config
- **Export utilities** - Multiple export formats and validation
- **Comprehensive documentation** - Full API reference and guides
- **Type safety** - Compile-time type checking and validation

#### Validation and Quality Assurance
- **Schema validation** - JSON Schema validation for message payloads
- **Component validation** - Ensures all referenced components exist
- **Operation validation** - Validates operation-channel-message relationships
- **Channel validation** - Parameter and binding validation
- **Message validation** - Payload and correlation ID validation

#### Runtime Features
- **Introspection API** - Query servers, channels, operations, messages, schemas
- **Component access** - Runtime access to all defined components
- **Existence checks** - Helper functions to check for specific elements
- **Specification generation** - Convert DSL to AsyncAPI 3.0 specification maps

#### Testing and Examples
- **Comprehensive test suite** - Full test coverage including edge cases
- **Kafka tutorial validation** - Tests based on official AsyncAPI Kafka tutorial
- **WebSocket tutorial validation** - Tests based on official AsyncAPI WebSocket tutorial
- **Integration examples** - Phoenix WebSocket and Kafka integration patterns

### Technical Implementation

#### Architecture
- Built on the Spark DSL framework for robust DSL capabilities
- Modular design with separate validation transformers
- Clean separation between DSL definition and specification generation
- Extensible architecture for future AsyncAPI specification updates

#### Performance
- Efficient compile-time processing with minimal runtime overhead
- Optimized entity collection and specification generation
- Lazy evaluation for expensive operations
- Memory-efficient data structures

#### Compatibility
- Elixir 1.15+ support with OTP 26+
- Full AsyncAPI 3.0 specification compliance
- Optional YAML support via yaml_elixir dependency
- Compatible with Phoenix, LiveView, and other Elixir frameworks

### Dependencies
- `spark` - Core DSL framework (path dependency for development)
- `jason` - JSON encoding/decoding
- `yaml_elixir` - Optional YAML support

### Breaking Changes
- This is the initial release, no breaking changes

### Migration Guide
- This is the initial release, no migration needed

### Known Issues
- None at release time

### Future Roadmap
- AsyncAPI 3.1 support when specification is released
- Additional protocol bindings (gRPC, NATS, etc.)
- Integration with OpenAPI specifications
- Code generation capabilities
- Enhanced IDE support and tooling

---

## Development Notes

### Release Process
1. Update version in `mix.exs`
2. Update `CHANGELOG.md` with new features
3. Run full test suite: `mix test`
4. Run code quality checks: `mix credo && mix dialyzer`
5. Generate documentation: `mix docs`
6. Create git tag: `git tag v1.0.0`
7. Push changes: `git push origin main --tags`
8. Publish to Hex: `mix hex.publish`

### Version Strategy
- Major version: Breaking changes to DSL or API
- Minor version: New features, AsyncAPI spec updates
- Patch version: Bug fixes, documentation improvements

### Compatibility Promise
- DSL syntax stability within major versions
- Generated specification format stability
- Runtime introspection API stability