# Document Workflow Examples

This directory contains examples demonstrating how to use the Circuit Breaker library to implement a document workflow system. The examples showcase a declarative DSL for defining workflows, rules, and validations.

## Overview

The document workflow system implements a document review and approval process with the following states:
- `draft`: Initial state for new documents
- `pending_review`: Document submitted for review
- `reviewed`: Review completed with comments
- `approved`: Document approved by manager
- `rejected`: Document rejected with reasons

## Example Files

### `document_dsl.rb`
Demonstrates the declarative workflow DSL that defines:
- State transitions with rules and validations
- Pretty printing of workflow definitions
- Complete workflow execution

### `document_rules.rb`
Shows our enhanced rules DSL with natural language definitions:
```ruby
# Reviewer rules
rule :has_reviewer,
     desc: "Document must have a reviewer assigned",
     &requires(:reviewer_id)

rule :different_reviewer,
     desc: "Reviewer must be different from author",
     &must_be_different(:reviewer_id, :author_id)
```

Available rule builders:
- `requires(field)` - Ensures a field is present and not empty
- `must_be_different(field1, field2)` - Ensures two fields have different values
- `must_be(field, value)` - Ensures a field equals a specific value
- `must_start_with(field, prefix)` - Ensures a field starts with a prefix

### `document_validators.rb`
Demonstrates our enhanced validation DSL:
```ruby
# Basic document information
validator :title,
         desc: "Document title is required",
         &must_be_present(:title)

validator :priority,
         desc: "Priority must be low, medium, or high",
         &must_be_one_of(:priority, %w[low medium high])
```

Available validator builders:
- `must_be_present(field)` - Ensures a field is present
- `must_be_one_of(field, values)` - Ensures a field's value is in a set
- `must_be_url(field)` - Validates URL format
- `must_have_min_words(field, min_count)` - Validates minimum word count

### `document_token.rb`
Defines the document data structure and attributes that are validated and tracked through the workflow.

## Running the Example

Run the complete workflow example:
```bash
ruby document_dsl.rb
```

This will show:
1. A pretty-printed workflow definition showing:
   - All states and their transitions
   - Required rules with descriptions
   - Required validations with descriptions
2. A complete workflow execution demonstrating:
   - Document submission with reviewer
   - Review process with comments
   - Final approval with approver

## Key Features

### Declarative DSL
- Natural language rule definitions
- Clear validation requirements
- Descriptive error messages
- Pretty-printed workflow visualization

### Rules Engine
- Field presence rules
- Field comparison rules
- Value matching rules
- Custom rule definitions

### Validation System
- Field presence validation
- Value inclusion validation
- URL format validation
- Word count validation

### Workflow Management
- State transition management
- Rule enforcement
- Validation checking
- History tracking

## Example Workflow Output

```
Workflow States and Transitions:
==============================
State: draft
  └─> pending_review (via :submit)
      Required rules: has_reviewer, different_reviewer
        - Document must have a reviewer assigned
        - Reviewer must be different from author

State: pending_review
  └─> reviewed (via :review)
      Required rules: has_comments
        - Review must include comments

State: reviewed
  └─> approved (via :approve)
      Required rules: has_approver, different_approver_from_reviewer
        - Document must have an approver assigned
        - Approver must be different from reviewer
  └─> rejected (via :reject)
      Required rules: has_rejection
        - Rejection must include a reason
```

## Implementation Details

The system is built on several core components:
- `CircuitBreaker::WorkflowDSL` - Defines the workflow structure and transitions
- `CircuitBreaker::RulesEngine` - Manages and evaluates business rules
- `CircuitBreaker::Validators` - Handles field and state validations
- `CircuitBreaker::Token` - Represents the document state and data

Each component uses a declarative DSL to make definitions clear and maintainable:
- Rules are defined with clear descriptions of their purpose
- Validations specify their requirements in natural language
- Workflows show a clear visualization of states and transitions
- Error messages are descriptive and actionable

## Best Practices

1. **Rule Definition**
   - Give each rule a clear description
   - Use the most specific rule builder
   - Group related rules together

2. **Validation Definition**
   - Describe the validation requirement clearly
   - Use appropriate validation builders
   - Group validations by purpose

3. **Workflow Definition**
   - Define clear state transitions
   - Attach appropriate rules to transitions
   - Use descriptive transition names

4. **Error Handling**
   - Provide clear error messages
   - Validate early and often
   - Give actionable feedback
