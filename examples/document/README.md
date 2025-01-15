# Document Workflow Examples

This directory contains examples demonstrating how to use the Circuit Breaker library to implement a document workflow system with AI-powered analysis. The examples showcase a declarative DSL for defining workflows, rules, validations, and AI-powered document analysis.

## Overview

The document workflow system implements a document review and approval process with the following states:
- `draft`: Initial state for new documents
- `pending_review`: Document submitted for review
- `reviewed`: Review completed with comments
- `approved`: Document approved by manager
- `rejected`: Document rejected with reasons

## Features

### 1. Unified Rules System
- Declarative rule definitions using DSL
- Complex rule chains with AND/OR logic
- Built-in validation helpers
- Clear error reporting
- Rule reusability across transitions

### 2. Workflow Management
- Intuitive state transition syntax (`from >> to`)
- Policy-based transitions with rule chains
- Comprehensive history tracking
- Event handling and state management
- Automatic validation during transitions

### 3. Document Rules
- Document validation rules:
  - `valid_reviewer`: Ensures reviewer is assigned
  - `valid_review`: Validates review comments
  - `valid_approver`: Checks approver assignment
  - `is_admin_approver`: Verifies approver permissions
  - `valid_word_count`: Checks document length
  - `valid_external_url`: Validates external references

### 4. AI-Powered Document Analysis
- Content quality and structure assessment
- Sentiment and tone analysis
- Automatic context detection
- Improvement suggestions
- Word count validation

## Example Usage

### 1. Define Document Rules

```ruby
rules = DocumentRules.define do
  rule :valid_reviewer do |token|
    token.reviewer_id.present?
  end

  rule :valid_review do |token|
    token.reviewer_comments.present?
  end

  rule :is_admin_approver do |token|
    token.approver_id&.start_with?('admin_')
  end
end
```

### 2. Create Workflow

```ruby
workflow = CircuitBreaker::WorkflowDSL.define(rules: rules) do
  states :draft, :pending_review, :reviewed, :approved, :rejected

  flow(:draft >> :pending_review)
    .transition(:submit)
    .policy(rules: { all: [:valid_reviewer] })

  flow(:pending_review >> :reviewed)
    .transition(:review)
    .policy(
      rules: {
        all: [:valid_review],
        any: [:is_high_priority, :is_urgent]
      }
    )

  flow(:reviewed >> :approved)
    .transition(:approve)
    .policy(
      rules: {
        all: [:valid_approver, :valid_review, :is_admin_approver],
        any: [:valid_external_url, :valid_word_count]
      }
    )
end
```

### 3. Process Document

```ruby
# Create document
token = Examples::DocumentToken.new(
  title: "Project Proposal",
  content: "Detailed project proposal...",
  priority: "high",
  author_id: "charlie789"
)

# Add to workflow
workflow.add_token(token)

# Submit document
token.reviewer_id = "bob456"
workflow.fire_transition(:submit, token)

# Review document
token.reviewer_comments = "Detailed review comments..."
workflow.fire_transition(:review, token)

# Approve document
token.approver_id = "admin_eve789"
workflow.fire_transition(:approve, token)

# View history
token.history.each do |event|
  puts "#{event[:timestamp]}: #{event[:transition]} from #{event[:from]} to #{event[:to]}"
end
```

## Files

- `document_token.rb`: Token class for documents
- `document_rules.rb`: Rule definitions for document workflow
- `document_workflow.rb`: Main workflow implementation
- `document_assistant.rb`: AI-powered document analysis

## Requirements

1. Ruby 2.7 or higher
2. Ollama installed and running locally (for AI-powered document analysis)

## Running the Example

```bash
ruby document_workflow.rb
```

This will execute the example workflow, showing:
1. Workflow definition and states
2. Document transitions through states
3. Rule validations at each step
4. Complete transition history
