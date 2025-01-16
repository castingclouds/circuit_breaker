# Circuit Breaker

A powerful Ruby library for building AI-powered workflows with Agents and Assistants powered by Petri Nets.. It seamlessly integrates with various LLM providers and offers robust tools for document analysis, workflow management, and autonomous agents.

## Features

### 1. Declarative Workflow DSL
- State-based workflow engine with intuitive syntax
- Policy-based transitions with rule chains
- Unified rules system for validation and transitions
- Comprehensive history tracking
- Event handling and state management

### 2. Rules System
- Unified DSL for defining rules and validations
- Support for complex rule chains and conditions
- Built-in helpers for common validations
- Rule composition with AND/OR logic
- Clear error reporting and handling

### 3. AI Integration
- Multiple LLM providers (OpenAI, Ollama)
- Automatic model detection
- Tool integration framework
- Memory management
- Error handling with retries

### 4. Executors
- AssistantExecutor for AI-powered tools
- AgentExecutor for autonomous tasks
- Custom executor support
- Chainable tool pipelines

### 5. Document Analysis (Example)
- Content quality assessment
- Sentiment and tone analysis
- Context detection
- Improvement suggestions
- Structure evaluation

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'circuit_breaker-wf'
```

And then execute:
```bash
$ bundle install
```

Or install it yourself as:
```bash
$ gem install circuit_breaker-wf
```

## Usage

### Action-Rule Data Flow

Circuit Breaker provides a powerful mechanism for passing data between actions and rules during workflow transitions. Here's how it works:

### Creating a Workflow
1. Define Workflow
```ruby
workflow = CircuitBreaker::Workflow::DSL.define do
  # Define states
  states :draft, :pending_review, :reviewed, :approved, :rejected

  # Define transitions with rules
  flow(:draft >> :pending_review), :submit do
     policy all: [:valid_reviewer]
  end

  flow(:pending_review >> :reviewed), :review do
    policy all: [:valid_review],
           any: [:is_high_priority, :is_urgent]
  end
end
```

# Create and add token
```ruby
token = CircuitBreaker::Token.new
workflow.add_token(token)
```

# Fire transitions
```ruby
workflow.fire_transition(:submit, token)
```

### Action-Rule Data Flow
1. **Actions with Anonymous Results**
```ruby
flow :draft >> :pending_review, :submit do
  actions do
    # Execute action and store result in context
    execute analyzer, :analyze_clarity
  end
  policy all: [:valid_clarity]
end
```

2. **Accessing Results in Rules**
```ruby
CircuitBreaker::Rules::DSL.define do
  rule :valid_clarity do |token|
    # Retrieve stored result using the same key
    clarity = context.get_result(:clarity)
    clarity && clarity[:score] >= 70
  end
end
```

3. **Data Flow Process**
   - Actions are executed first during a transition
   - Results are stored in an action context using the specified key
   - Rules can access these results through the same key
   - This enables rules to validate based on action outputs

This pattern allows for:
- Clean separation between action execution and rule validation
- Reusable actions with different validation rules
- Complex rule chains based on multiple action results
- Clear data flow tracking during transitions

### History Tracking

The workflow automatically tracks all transitions:

```ruby
token.history.each do |event|
  puts "#{event[:timestamp]}: #{event[:transition]} from #{event[:from]} to #{event[:to]}"
end
```

## Architecture

Circuit Breaker uses a hybrid architecture combining:

1. **Workflow Engine**: Based on Petri nets for formal verification
2. **Rules Engine**: Unified system for validations and transitions
3. **AI Integration**: Pluggable LLM providers for analysis
4. **Event System**: Comprehensive tracking and auditing

While basic Petri nets are not Turing complete, our implementation is closer to Colored Petri Nets (CPNs) or High-level Petri Nets. The system balances theoretical power with practical utility, providing:
- Sufficient expressiveness for real-world business processes
- Analyzability for critical property verification
- Maintainable and understandable structure through the workflow DSL

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

rule :title,
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
