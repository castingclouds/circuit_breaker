# Document Workflow Examples

This directory contains examples demonstrating how to use the Circuit Breaker library to implement a document workflow system. The examples showcase various features including state management, validation rules, event handling, and workflow visualization.

## Overview

The document workflow system implements a simple document review and approval process with the following states:
- `draft`: Initial state for new documents
- `pending_review`: Document submitted for review
- `reviewed`: Review completed with comments
- `approved`: Document approved by manager
- `rejected`: Document rejected with reasons

## Example Files

### `token_example.rb`
Defines the `Document` class that inherits from `CircuitBreaker::Token`. It demonstrates:
- State transitions and validation rules
- Attribute validation (title, content, tags, etc.)
- Event handling and hooks
- Timing tracking (submission, review, approval times)

### `workflow_example.rb`
Shows a complete document workflow lifecycle including:
- Document creation with metadata
- State transitions (submit → review → approve)
- Event handling and notifications
- Workflow visualization export
- History tracking

### `rules_example.rb`
Demonstrates various validation rules and constraints:
- Title validation (required, capitalization)
- Content length requirements
- Reviewer/approver validation (prevent self-review)
- Metadata validation (tags, priority)
- State-specific validation rules

## Running the Examples

Each example can be run independently:

```bash
# Run the complete workflow example
ruby workflow_example.rb

# Run the validation rules example
ruby rules_example.rb

# Run the visualization example
ruby visualization_example.rb
```

## Key Features Demonstrated

### State Management
- DSL-based workflow definition
- State transitions with validation
- Guard conditions and requirements

### Validation Rules
- Attribute-level validation
- State-specific validation
- Transition rules
- Custom validation logic

### Event Handling
- Before/after transition hooks
- Attribute change tracking
- Async event handlers
- Audit logging

### Timing and History
- Submission time tracking
- Review duration calculation
- Total processing time
- Complete audit history

### Visualization
- Multiple output formats (HTML, Mermaid, DOT)
- State diagram generation
- Transition visualization
- Workflow documentation

## Implementation Details

The examples use the Circuit Breaker library's core features:
- `CircuitBreaker::Token` for state and attribute management
- `CircuitBreaker::WorkflowDSL` for workflow definition
- Petri net-based state machine implementation
- Event system for notifications and logging

## Example Workflow

1. Create a new document with title, content, and metadata
2. Submit for review (requires reviewer ID)
3. Add review comments (requires minimum length)
4. Approve or reject (requires different approver)
5. Track timing and history throughout

The workflow enforces business rules such as:
- No self-review or self-approval
- Minimum content length requirements
- Required fields for each state
- Valid metadata formats

## Extending the Examples

You can extend these examples by:
1. Adding new states or transitions
2. Implementing additional validation rules
3. Creating custom event handlers
4. Adding new visualization formats
5. Implementing more complex workflows

## Error Handling

The examples demonstrate proper error handling for:
- Invalid state transitions
- Validation failures
- Missing required fields
- Business rule violations

Each error includes descriptive messages to help identify and fix issues.
