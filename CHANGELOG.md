# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2024-12-11

### Added
- Initial implementation of Petri Net workflow system
- Core components:
  - `Token` class for representing workflow state markers
  - `Place` class for representing workflow states
  - `Arc` class for connecting places and transitions
  - `Transition` class for state change logic
  - `PetriNet` class for overall workflow management
- Thread-safe token operations with mutex protection
- Support for weighted arcs
- Guard conditions on transitions
- Token data preservation during transitions
- JSON serialization for workflow state
- Example workflow demonstrating approval process
- Basic project documentation:
  - README with usage examples and comparisons to Argo Workflows
  - MIT License
  - This CHANGELOG

### Technical Details
- Proper handling of token flow between places and transitions
- Atomic transition firing with all-or-nothing semantics
- Step-by-step execution with `step` method
- Full workflow execution with `run_to_completion`
- State inspection through `marking` method
- Thread-safe operations in `Place` and `Transition` classes

## [Unreleased]

### Planned
- Visualization support for workflow graphs
- Persistence layer for workflow state
- Support for timed transitions
- Advanced synchronization patterns
- Integration with external systems
- Web-based workflow designer
- Performance optimizations for large workflows
- Additional example workflows
- Testing framework and test suite
- CI/CD pipeline setup
- Documentation website
- API documentation
- Contributing guidelines
