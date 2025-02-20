# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-02-19

### Added
- New Pipeline System:
  - Tool-based execution flow
  - Parameter passing between actions
  - Simple and intuitive syntax
  - Modular pipeline definitions
- Command Line Interface:
  - `cb pipeline` command for running pipelines
  - `cb workflow` command for workflow execution
  - Debug mode with detailed logging
- Enhanced Tool Framework:
  - Basic tools with direct execution
  - Chainable tools for complex pipelines
  - AI-powered tools with LLM integration
  - Tool parameter validation
- Example Pipelines:
  - Hello World pipeline example
  - Document processing pipeline
  - Custom tool examples
- Improved Documentation:
  - Updated README with pipeline documentation
  - New examples and best practices
  - Tool development guide

### Changed
- Restructured project layout for better organization
- Simplified workflow syntax
- Enhanced error handling and logging
- Improved tool registration system
- Updated configuration system

### Technical Details
- New PipelineParser class for parsing pipeline definitions
- Tool registry for managing available tools
- Parameter passing between pipeline actions
- Enhanced debugging capabilities
- Improved error messages and validation

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
  - README with usage examples
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
- Visualization support for workflow and pipeline graphs
- Persistence layer for workflow and pipeline state
- Support for timed transitions and scheduled pipelines
- Advanced synchronization patterns
- Integration with external systems
- Web-based workflow and pipeline designer
- Performance optimizations for large workflows
- Additional example workflows and pipelines
- Testing framework and test suite
- CI/CD pipeline setup
- Documentation website
- API documentation
- Contributing guidelines
