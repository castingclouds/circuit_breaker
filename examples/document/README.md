# Document Workflow Examples

This directory contains examples demonstrating how to use the Circuit Breaker library to implement a document workflow system. The examples showcase a declarative DSL for defining workflows, rules, and validations.

## Overview

The document workflow system implements a document review and approval process with the following states:
- `draft`: Initial state for new documents
- `pending_review`: Document submitted for review
- `reviewed`: Review completed with comments
- `approved`: Document approved by manager
- `rejected`: Document rejected with reasons

## Requirements

1. Ruby 2.7 or higher
2. Ollama installed and running locally (for AI-powered document analysis)
   - Install from [Ollama's website](https://ollama.ai)
   - Pull the CodeLlama model: `ollama pull codellama`
   - Start the Ollama server: `ollama serve`

## Setup

1. Install dependencies:
```bash
bundle install
```

2. Ensure Ollama is running:
```bash
# Check if Ollama is running and models are available
ollama list
```

3. Run the example:
```bash
ruby document_workflow.rb
```

The example will:
1. Show the workflow definition
2. Create a sample document
3. Perform AI analysis using Ollama
4. Execute the workflow steps with validation
5. Display the final document state

## Example Files

### `document_workflow.rb`
Demonstrates the declarative workflow DSL that defines:
- State transitions with policy-based rules and validations
- Pretty printing of workflow definitions
- Complete workflow execution
- AI-powered document analysis using Ollama integration

The workflow now includes an AI assistant that analyzes documents and provides feedback:

```ruby
# Initialize document assistant with Ollama
assistant = DocumentAssistant.new('codellama')

# Get AI analysis of the document
analysis = assistant.analyze_document(token)
```

The DocumentAssistant provides two powerful tools:

1. **AnalyzeContentTool**: Analyzes document content for:
   - Word count requirements
   - Document structure
   - Writing clarity
   - Content completeness

2. **SuggestImprovementsTool**: Provides specific improvement suggestions for:
   - Document structure (sections, headings, transitions)
   - Writing clarity (sentence length, active voice)
   - Content completeness (required sections)

Example of AI-powered document analysis:
```ruby
# Create a document assistant using Ollama
assistant = DocumentAssistant.new(
  model: 'codellama',  # or other Ollama models
  ollama_base_url: 'http://localhost:11434'  # optional
)

# Get AI analysis before submitting
analysis = assistant.analyze_document(document)
puts analysis
# Output:
# Word Count Analysis: 150 words (minimum: 100)
# Length Status: Meets minimum requirement
#
# Content Analysis:
# - Structure: 1 paragraph detected. Consider adding more structure.
# - Clarity: Found 2 complex sentences. Consider simplifying for better clarity.
# - Completeness: 1/3 key sections identified.
```

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
         desc: "Priority must be low, medium, high, or urgent",
         &must_be_one_of(:priority, %w[low medium high urgent])
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
ruby document_workflow.rb
```

This will show:
1. A pretty-printed workflow definition showing:
   - All states and their transitions
   - Required rules with descriptions
   - Required validations with descriptions
2. AI-powered document analysis with:
   - Content structure evaluation
   - Writing clarity assessment
   - Completeness check
   - Specific improvement suggestions

## Customizing the AI Assistant

The DocumentAssistant can be customized in several ways:

1. **Change the LLM Model**:
```ruby
# Use different Ollama models
assistant = DocumentAssistant.new('mistral')  # Use Mistral
assistant = DocumentAssistant.new('llama2')   # Use Llama 2
```

2. **Custom Analysis Tools**:
```ruby
class CustomAnalysisTool < CircuitBreaker::Executors::LLM::Tool
  def initialize
    super(
      name: 'custom_analysis',
      description: 'Your custom analysis logic',
      parameters: {
        content: { type: 'string', description: 'Content to analyze' }
      }
    )
  end

  def execute(content:)
    # Your custom analysis logic here
  end
end

# Use custom tools
assistant = DocumentAssistant.new(
  model: 'codellama',
  tools: [CustomAnalysisTool.new]
)
```

3. **Configure Ollama Settings**:
```ruby
assistant = DocumentAssistant.new(
  model: 'codellama',
  ollama_base_url: 'http://custom-ollama-server:11434',
  system_prompt: "Custom system prompt for specialized analysis"
)
```

4. **Extend Analysis Capabilities**:
- Add new analysis methods to AnalyzeContentTool
- Create specialized tools for different document types
- Implement custom improvement suggestions

Example of adding a new analysis capability:
```ruby
class AnalyzeContentTool
  def analyze_technical_depth(content)
    technical_terms = content.scan(/\b(algorithm|implementation|architecture)\b/i)
    "Technical depth: #{technical_terms.size} technical terms found"
  end
end
```

## Key Features

### Policy-Based Workflow DSL
- Declarative policy definitions for transitions
- Support for complex validation rules:
  - `all`: All validations must pass
  - `any`: At least one validation must pass
- Support for complex rule combinations:
  - `all`: All rules must pass
  - `any`: At least one rule must pass
- Clear error messages showing which policy failed

### Rules Engine
- Field presence rules
- Field comparison rules
- Value matching rules
- Custom rule definitions
- Support for complex rule combinations

### Validation System
- Field presence validation
- Value inclusion validation
- URL format validation
- Word count validation
- Support for complex validation combinations

### Workflow Management
- Policy-based state transition management
- Automatic rule and validation conversion
- Comprehensive error handling
- Detailed transition history tracking

## Best Practices

### 1. Policy Definition
- Use clear, descriptive rule names
- Group related rules under `all` or `any`
- Keep validation requirements clear and focused
- Use appropriate validation combinations

### 2. Rule Implementation
- Implement atomic, single-purpose rules
- Use descriptive rule builders
- Add debug output for complex rules
- Test all rule combinations

### 3. Validation Definition
- Describe the validation requirement clearly
- Use appropriate validation builders
- Group validations by purpose
- Test edge cases and combinations

### 4. Error Handling
- Provide clear error messages
- Include context in validation errors
- Track failed transitions in history
- Add debug output for troubleshooting

## Example Use Cases

### Document Review Process
```ruby
# Define a document review workflow with:
# 1. Reviewer different from author
# 2. Admin approval required
# 3. Either word count or external URL required
workflow = CircuitBreaker::WorkflowDSL.define do
  flow(:draft >> :pending_review)
    .transition(:submit)
    .policy(
      validations: { all: [:reviewer_id] },
      rules: { all: [:has_reviewer, :different_reviewer] }
    )

  flow(:reviewed >> :approved)
    .transition(:approve)
    .policy(
      validations: {
        all: [:approver_id, :reviewer_comments],
        any: [:external_url, :word_count]
      },
      rules: {
        all: [:has_approver, :different_approver_from_reviewer],
        any: [:is_admin]
      }
    )
end
```
