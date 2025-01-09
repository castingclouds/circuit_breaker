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

### 1. AI-Powered Document Analysis
- Content quality and structure assessment
- Sentiment and tone analysis
- Automatic context detection (technical, business, academic)
- Improvement suggestions
- Word count validation

### 2. Workflow Management
- State-based workflow engine
- Policy-based transitions
- Rule validation
- History tracking

### 3. Document Assistant Tools
- Content Analysis Tool
  - Structure evaluation
  - Clarity assessment
  - Completeness check
  - Length requirements validation

- Sentiment Analysis Tool
  - Overall sentiment scoring
  - Emotional tone analysis
  - Formality level assessment
  - Context-specific analysis
  - Accessibility evaluation

- Improvement Suggestions Tool
  - Structure recommendations
  - Clarity improvements
  - Content completeness suggestions

## Requirements

1. Ruby 2.7 or higher
2. Ollama installed and running locally (for AI-powered document analysis)
   - Install from [Ollama's website](https://ollama.ai)
   - Pull the Qwen model: `ollama pull qwen2.5-coder`
   - Start the Ollama server: `ollama serve`

## Setup

1. Install dependencies:
```bash
bundle install
```

2. Ensure Ollama is running:
```bash
curl http://localhost:11434/api/tags
```

3. Run the example:
```bash
ruby document_workflow.rb
```

## Example Files

### `document_workflow.rb`
Demonstrates the workflow DSL and execution:

```ruby
workflow = CircuitBreaker::WorkflowDSL.define do
  # Define states and transitions
  flow(:draft >> :pending_review)
    .transition(:submit)
    .policy(
      validations: { all: [:reviewer_id] },
      rules: { all: [:has_reviewer, :different_reviewer] }
    )

  # Additional states and transitions...
end

# Initialize document assistant with AI capabilities
assistant = DocumentAssistant.define do
  use_model 'qwen2.5-coder'
  with_system_prompt "Custom prompt for document analysis..."
  with_parameters temperature: 0.7, top_p: 0.9
end

# Get AI analysis
analysis = assistant.analyze_document(document)
```

### `document_assistant.rb`
Implements the AI-powered document analysis system:

```ruby
class DocumentAssistant
  def self.define(&block)
    new.tap { |assistant| assistant.instance_eval(&block) }
  end

  def analyze_document(token)
    @executor
      .update_context(input: generate_analysis_prompt(token))
      .execute
  end
end
```

Key features:
- DSL-style configuration
- Automatic context detection
- Comprehensive document analysis
- Sentiment and tone evaluation
- Improvement suggestions

### `document_rules.rb`
Defines the rules DSL:

```ruby
rule :has_reviewer,
     desc: "Document must have a reviewer assigned",
     &requires(:reviewer_id)

rule :different_reviewer,
     desc: "Reviewer must be different from author",
     &must_be_different(:reviewer_id, :author_id)
```

Available rule builders:
- `requires(field)`: Ensures field presence
- `must_be_different(field1, field2)`: Ensures different values
- `must_be(field, value)`: Validates exact value
- `must_start_with(field, prefix)`: Validates prefix

## AI Analysis Features

### 1. Content Analysis
- Structure evaluation
  - Paragraph count and organization
  - Section identification
  - Heading analysis
- Clarity assessment
  - Sentence complexity
  - Word choice
  - Readability metrics
- Completeness check
  - Key section presence
  - Required elements
  - Content depth

### 2. Sentiment Analysis
- Overall sentiment scoring (0-10)
- Emotional tone detection
  - Confidence level
  - Uncertainty markers
  - Urgency indicators
  - Caution signals
- Formality assessment
  - Formal vs informal language
  - Professional tone
  - Engagement level

### 3. Context-Specific Analysis
- Technical context
  - Technical term usage
  - Implementation details
  - Architecture patterns
- Business context
  - ROI focus
  - Stakeholder considerations
  - Strategic alignment
- Academic context
  - Research methodology
  - Citation patterns
  - Academic rigor

## Customization

### 1. AI Model Configuration
```ruby
assistant = DocumentAssistant.define do
  use_model 'qwen2.5-coder'  # or other Ollama models
  with_system_prompt "Custom analysis prompt..."
  with_parameters(
    temperature: 0.7,
    top_p: 0.9,
    top_k: 40
  )
end
```

### 2. Analysis Tools
```ruby
# Add custom analysis tool
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
    # Your custom analysis logic
  end
end

# Use custom tool
assistant = DocumentAssistant.define do
  use_model 'qwen2.5-coder'
  add_tool CustomAnalysisTool.new
end
```

### 3. Workflow Rules
```ruby
# Add custom rule
rule :meets_deadline,
     desc: "Document must be submitted before deadline",
     &before_date(:submission_date, :deadline)

# Use in workflow
workflow = CircuitBreaker::WorkflowDSL.define do
  flow(:draft >> :pending_review)
    .transition(:submit)
    .policy(
      rules: { all: [:meets_deadline] }
    )
end
```

## Error Handling

The system includes robust error handling:

1. AI Integration
   - Connection retry logic
   - Timeout handling
   - Response validation
   - Fallback responses

2. Workflow Validation
   - Rule violation detection
   - State transition validation
   - Input parameter validation
   - Context validation

3. Document Processing
   - Content validation
   - Format verification
   - Size limit checks
   - Permission validation

## Best Practices

1. Document Analysis
   - Use specific context types for better analysis
   - Provide clear document structure
   - Include all required sections
   - Follow formatting guidelines

2. Workflow Management
   - Define clear transition rules
   - Implement proper validation
   - Track state changes
   - Maintain audit history

3. AI Integration
   - Configure appropriate timeouts
   - Handle errors gracefully
   - Validate AI responses
   - Monitor performance

## Contributing

1. Fork the repository
2. Create your feature branch
3. Add tests for new features
4. Submit a pull request

## License

This example is part of the Circuit Breaker library and is available under the MIT license.
