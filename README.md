# Circuit Breaker

Circuit Breaker is a powerful Ruby library that provides a declarative DSL for building AI-powered workflows and assistants. It seamlessly integrates with various LLM providers and offers robust tools for document analysis, workflow management, and autonomous agents.

## Features

### 1. Declarative Workflow DSL
- State-based workflow engine
- Policy-based transitions
- Rule validation
- History tracking
- Event handling

### 2. AI Integration
- Multiple LLM providers (OpenAI, Ollama)
- Automatic model detection
- Tool integration framework
- Memory management
- Error handling with retries

### 3. Document Analysis
- Content quality assessment
- Sentiment and tone analysis
- Context detection
- Improvement suggestions
- Structure evaluation

### 4. Executors
- AssistantExecutor for AI-powered tools
- AgentExecutor for autonomous tasks
- Custom executor support
- Chainable tool pipelines

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'circuit_breaker'
```

And then execute:
```bash
$ bundle install
```

Or install it yourself as:
```bash
$ gem install circuit_breaker
```

## Quick Start

### 1. Define a Workflow

```ruby
workflow = CircuitBreaker::WorkflowDSL.define do
  # Define states and transitions
  flow(:draft >> :pending_review)
    .transition(:submit)
    .policy(
      validations: { all: [:reviewer_id] },
      rules: { all: [:has_reviewer, :different_reviewer] }
    )

  flow(:pending_review >> :reviewed)
    .transition(:review)
    .policy(
      rules: { all: [:has_comments] }
    )

  flow(:reviewed >> [:approved, :rejected])
    .transitions(:approve, :reject)
    .policy(
      rules: { all: [:is_admin] }
    )
end
```

### 2. Create an AI Assistant

```ruby
assistant = CircuitBreaker::Executors::AssistantExecutor.define do
  use_model 'qwen2.5-coder'
  with_system_prompt "You are a document analysis assistant..."
  with_parameters temperature: 0.7, top_p: 0.9
  add_tools [
    ContentAnalysisTool.new,
    SentimentAnalysisTool.new,
    ImprovementTool.new
  ]
end

result = assistant
  .update_context(input: "Analyze this document...")
  .execute
```

### 3. Define Custom Tools

```ruby
class CustomAnalysisTool < CircuitBreaker::Executors::LLM::Tool
  def initialize
    super(
      name: 'custom_analysis',
      description: 'Performs specialized analysis',
      parameters: {
        content: { type: 'string', description: 'Content to analyze' }
      }
    )
  end

  def execute(content:)
    # Your custom analysis logic
    { result: analyze(content) }
  end
end
```

## Components

### 1. Workflow Engine

The workflow engine provides:
- State management
- Transition validation
- Rule enforcement
- Event tracking
- History management

Example:
```ruby
# Define rules
rule :has_reviewer,
     desc: "Document must have a reviewer assigned",
     &requires(:reviewer_id)

# Define validations
validator :title,
         desc: "Document title is required",
         &must_be_present(:title)

# Create workflow instance
workflow = DocumentWorkflow.new(document)
workflow.submit  # Transition to pending_review
```

### 2. AI Executors

Two main executor types:

1. AssistantExecutor
   - Tool-based execution
   - Context management
   - Memory persistence
   - Error handling

2. AgentExecutor
   - Autonomous task execution
   - Tool discovery
   - Planning capabilities
   - Progress tracking

### 3. Tool Framework

Tools can be:
- Basic tools with direct execution
- Chainable tools for complex pipelines
- Stateful tools with context
- Fallback-enabled tools

Example chainable tool:
```ruby
class ChainableTool < CircuitBreaker::Executors::LLM::ChainableTool
  def initialize
    super(
      name: 'chainable_tool',
      description: 'Part of processing pipeline',
      input_schema: { type: 'string' },
      output_schema: { type: 'object' }
    )
  end

  def execute(input, context)
    result = process(input)
    next_tool = context.available_tools.find { |t| t.can_handle?(result) }
    context.chain(next_tool) if next_tool
  end
end
```

### 4. Petri Net Implementation and Turing Completeness

The workflow engine is built on an extended version of Petri nets with additional features that enhance its computational capabilities:

1. Token System with State
   - Sophisticated token system maintaining state and data
   - Support for attributes and validations
   - Before and after transition hooks

2. Extended Transition Rules
   - Complex transition rules with conditions
   - Guard validations and policies
   - Synchronous and asynchronous transitions

3. Workflow Extensions
   - Multiple executor types (NATS, Step, Agent)
   - Parallel execution and flow control
   - Workflow chaining capabilities

While basic Petri nets are not Turing complete, our implementation is closer to Colored Petri Nets (CPNs) or High-level Petri Nets. The system balances theoretical power with practical utility, providing:
- Sufficient expressiveness for real-world business processes
- Analyzability for critical property verification
- Maintainable and understandable structure through the workflow DSL

## Examples

See the `examples` directory for complete examples:

1. Document Workflow
   - Complete document management system
   - AI-powered analysis
   - Review process automation
   - State tracking

2. Research Assistant
   - Autonomous research agent
   - Source gathering
   - Summary generation
   - Citation management

## Configuration

### 1. LLM Providers

```ruby
# Configure Ollama
CircuitBreaker.configure do |config|
  config.ollama_base_url = 'http://localhost:11434'
  config.default_model = 'qwen2.5-coder'
end

# Configure OpenAI
CircuitBreaker.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.default_model = 'gpt-4'
end
```

### 2. Memory Settings

```ruby
CircuitBreaker.configure do |config|
  config.max_memory_tokens = 4000
  config.memory_window_size = 10
end
```

### 3. Tool Settings

```ruby
CircuitBreaker.configure do |config|
  config.default_tools = [
    ContentAnalysisTool,
    SentimentAnalysisTool,
    ImprovementTool
  ]
  config.tool_timeout = 30  # seconds
end
```

## Best Practices

1. Workflow Design
   - Keep states and transitions clear
   - Use descriptive rule names
   - Implement proper validation
   - Track state changes

2. AI Integration
   - Choose appropriate models
   - Handle errors gracefully
   - Implement retries
   - Monitor performance

3. Tool Development
   - Keep tools focused
   - Provide clear descriptions
   - Include fallback behavior
   - Handle errors appropriately

## Contributing

1. Fork the repository
2. Create your feature branch
3. Add tests for new features
4. Submit a pull request

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
