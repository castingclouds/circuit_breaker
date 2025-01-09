# Circuit Breaker Executors

The Circuit Breaker executor system provides a flexible, DSL-driven approach to defining and running various types of execution environments. Each executor follows a consistent pattern while allowing for specialized configuration and behavior.

## Table of Contents

- [Executor DSL](#executor-dsl)
- [Available Executors](#available-executors)
- [Creating Custom Executors](#creating-custom-executors)
- [Examples](#examples)

## Executor DSL

The executor DSL provides a declarative way to define:
- Required and optional parameters
- Type validations
- Custom validation rules
- Execution lifecycle hooks

### Basic Structure

```ruby
class MyExecutor < BaseExecutor
  executor_config do
    # Parameter definitions
    parameter :name,
      type: :string,
      required: true,
      description: 'Description of the parameter'

    # Validation rules
    validate do |context|
      # Custom validation logic
    end

    # Lifecycle hooks
    before_execute do |context|
      # Setup logic
    end

    after_execute do |result|
      # Cleanup or logging logic
    end
  end

  protected

  def execute_internal
    # Implementation
    @result = { status: 'completed' }
  end
end
```

### Parameter Types

The DSL supports the following parameter types:
- `:string`
- `:integer`
- `:array`
- `:hash`
- `:boolean`

Each parameter can be configured with:
- `required: true/false` - Whether the parameter must be provided
- `default: value` - Default value if not provided
- `description: 'text'` - Documentation for the parameter

## Available Executors

### Docker Executor

Runs containers with configurable images, commands, and environment.

```ruby
docker = DockerExecutor.new(
  image: 'nginx:latest',
  command: 'nginx -g "daemon off;"',
  environment: { 'PORT' => '8080' },
  volumes: ['/host/path:/container/path']
)
result = docker.execute
```

### NATS Executor

Manages workflow state and event distribution using NATS.

```ruby
nats = NatsExecutor.new(
  nats_url: 'nats://localhost:4222',
  petri_net: workflow_definition,
  workflow_id: 'custom-id'
)
result = nats.execute
```

### Assistant Executor

Interacts with AI assistants for natural language processing tasks.

```ruby
assistant = AssistantExecutor.new(
  model: 'gpt-4',
  system_prompt: 'You are a helpful data analysis assistant',
  input: 'Analyze this data set',
  tools: [DataAnalysisTool.new]
)
result = assistant.execute
```

### Agent Executor

Runs autonomous agents that can perform complex multi-step tasks.

```ruby
agent = AgentExecutor.new(
  task: 'Analyze the data and create a summary report',
  tools: [DataAnalysisTool.new, SearchTool.new],
  system_prompt: 'You are a data analysis agent',
  max_iterations: 5
)
result = agent.execute
```

### Serverless Executor

Invokes serverless functions with configurable runtimes and payloads.

```ruby
serverless = ServerlessExecutor.new(
  function_name: 'process-data',
  runtime: 'ruby',
  payload: { data: [1, 2, 3] },
  environment: { 'STAGE' => 'production' }
)
result = serverless.execute
```

### Step Executor

Runs multiple executors in sequence or parallel.

```ruby
step = StepExecutor.new(
  steps: [
    {
      executor: DockerExecutor,
      context: { image: 'preprocessor:latest' }
    },
    {
      executor: AssistantExecutor,
      context: { prompt: 'Analyze the data' }
    }
  ],
  parallel: true
)
result = step.execute
```

## Creating Custom Executors

To create a custom executor:

1. Create a new class inheriting from `BaseExecutor`
2. Define your configuration using the executor DSL
3. Implement the `execute_internal` method

Example:

```ruby
class CustomExecutor < BaseExecutor
  executor_config do
    parameter :input_data,
      type: :hash,
      required: true,
      description: 'Data to process'

    parameter :options,
      type: :hash,
      default: {},
      description: 'Processing options'

    validate do |context|
      unless context[:input_data].key?(:type)
        raise ArgumentError, 'Input data must specify a type'
      end
    end

    before_execute do |context|
      puts "Processing #{context[:input_data][:type]} data"
    end
  end

  protected

  def execute_internal
    # Process the data
    @result = {
      processed_data: process_data(@context[:input_data]),
      options_used: @context[:options],
      status: 'completed'
    }
  end

  private

  def process_data(data)
    # Implementation
  end
end
```

## Using in Workflows

Executors can be integrated with Circuit Breaker's rules engine and workflow DSL for sophisticated process control. Here's an example:

```ruby
# Define rules for executor results
module ExecutorRules
  def self.define
    CircuitBreaker::RulesEngine::DSL.define do
      # Helper methods for rule conditions
      def meets_quality(threshold)
        ->(token) { token.data[:quality_score] >= threshold }
      end

      def has_confidence(threshold)
        ->(token) { token.data[:confidence_score] >= threshold }
      end

      def requires(field)
        ->(token) { !token.data[field].nil? && !token.data[field].empty? }
      end

      def has_error
        ->(token) { token.data[:status] == 'error' }
      end

      # Quality Rules
      rule :meets_quality_threshold,
           desc: "Data meets minimum quality requirements",
           &meets_quality(0.8)

      rule :high_confidence,
           desc: "Analysis has high confidence score",
           &has_confidence(0.9)

      # Data Rules
      rule :has_processed_data,
           desc: "Processing step produced output data",
           &requires(:processed_output)

      rule :has_analysis_results,
           desc: "Analysis step produced results",
           &requires(:analysis_results)

      # Error Rules
      rule :processing_error,
           desc: "Processing step encountered an error",
           &has_error
    end
  end
end

# Define the workflow
workflow = CircuitBreaker::WorkflowDSL.define(rules: ExecutorRules.define) do
  # Define all possible states
  states :raw_data,          # Initial state with raw data
        :processed,          # Data has been processed
        :analyzed,          # Data has been analyzed
        :human_review,      # Needs human review
        :completed          # Process completed

  # Process raw data
  flow(:raw_data >> :processed)
    .transition(:process)
    .policy(
      validations: { all: [:input_file] },
      rules: { all: [:has_processed_data] }
    ) do
      docker = DockerExecutor.new(
        image: 'data-processor:latest',
        command: './process.sh',
        environment: { 'INPUT': token.data[:input_file] }
      )
      result = docker.execute
      token.data.merge!(result)
    end

  # Analyze processed data
  flow(:processed >> :analyzed)
    .transition(:analyze)
    .policy(
      validations: { all: [:processed_output] },
      rules: { 
        all: [:meets_quality_threshold],
        any: [:high_confidence]
      }
    ) do
      assistant = AssistantExecutor.new(
        model: 'gpt-4',
        input: "Analyze the processed data: #{token.data[:processed_output]}",
        tools: [DataAnalysisTool.new]
      )
      result = assistant.execute
      token.data.merge!(result)
    end

  # Route to human review if needed
  flow(:analyzed >> :human_review)
    .transition(:request_review)
    .policy(
      rules: { 
        any: [:processing_error]
      }
    ) do
      agent = AgentExecutor.new(
        task: 'Prepare data for human review',
        tools: [ReportGeneratorTool.new],
        context: { data: token.data }
      )
      result = agent.execute
      token.data[:review_package] = result[:report]
    end

  # Complete the process
  flow(:analyzed >> :completed)
    .transition(:complete)
    .policy(
      rules: { 
        all: [:has_analysis_results, :high_confidence]
      }
    )
end

# Start the workflow with initial data
token = CircuitBreaker::Token.new(
  data: {
    input_file: 'data.json',
    quality_threshold: 0.8,
    confidence_threshold: 0.9
  }
)
workflow.add_token(token)
```

This example demonstrates:

1. **Rule Definition**
   - Rules are defined using the DSL pattern
   - Helper methods create reusable conditions
   - Rules focus on executor results and data quality

2. **Workflow Structure**
   - Clear state definitions
   - Transitions with policies
   - Validation and rule requirements

3. **Executor Integration**
   - Results stored in token data
   - Rules evaluate executor outputs
   - Data flows between executors

4. **Policy Controls**
   - Quality thresholds
   - Confidence requirements
   - Error handling paths

The workflow ensures that:
- Data meets quality requirements before analysis
- Low confidence results get human review
- Errors are properly handled
- Process completion requires all quality checks

## Best Practices

1. Always define parameter types and requirements clearly
2. Use validation rules to catch configuration errors early
3. Implement before/after hooks for setup and cleanup
4. Return structured results that can be used by other executors
5. Handle errors gracefully and provide meaningful error messages
6. Document any special requirements or dependencies

## Assistant Executor

A DSL-driven executor for building AI assistants with tool integration and context management.

```ruby
assistant = CircuitBreaker::Executors::AssistantExecutor.define do
  use_model 'qwen2.5-coder'
  with_system_prompt "You are a specialized assistant..."
  with_parameters temperature: 0.7, top_p: 0.9
  add_tools [AnalysisTool.new, SentimentTool.new]
end

result = assistant
  .update_context(input: "Analyze this document...")
  .execute
```

Features:
- Fluent DSL interface
- Automatic model provider detection
- Tool integration and management
- Context persistence
- Error handling with retries
- Parameter validation

Configuration Options:
```ruby
executor_config do
  parameter :model, type: :string, default: 'gpt-4'
  parameter :model_provider, type: :string
  parameter :ollama_base_url, type: :string, default: 'http://localhost:11434'
  parameter :system_prompt, type: :string
  parameter :tools, type: :array, default: []
  parameter :parameters, type: :hash, default: {}
  parameter :input, type: :string

  validate do |context|
    # Automatic model provider detection
    if context[:model_provider].nil?
      context[:model_provider] = if context[:model].to_s.start_with?('llama', 'codellama', 'mistral')
        'ollama'
      else
        'openai'
      end
    end
  end

  before_execute do |context|
    # Initialize memory and tools
    @memory.system_prompt = context[:system_prompt] if context[:system_prompt]
    add_tools(context[:tools]) if context[:tools]
  end
end
```

### Tool Integration

#### Creating Custom Tools

1. Basic Tool:
```ruby
class CustomTool < CircuitBreaker::Executors::LLM::Tool
  def initialize
    super(
      name: 'custom_tool',
      description: 'Performs custom analysis',
      parameters: {
        input: { type: 'string', description: 'Input to analyze' }
      }
    )
  end

  def execute(input:)
    # Tool implementation
    { result: analyze(input) }
  end
end
```

2. Chainable Tool:
```ruby
class ChainableTool < CircuitBreaker::Executors::LLM::ChainableTool
  def initialize
    super(
      name: 'chainable_tool',
      description: 'Can be chained with other tools',
      input_schema: { type: 'string' },
      output_schema: { type: 'object' }
    )
  end

  def execute(input, context)
    # Implementation with access to execution context
    next_tool = context.available_tools.find { |t| t.can_handle?(result) }
    context.chain(next_tool) if next_tool
  end
end
```

#### Tool Management

```ruby
# Add individual tools
assistant.add_tool(CustomTool.new)

# Add multiple tools
assistant.add_tools([
  AnalysisTool.new,
  SentimentTool.new,
  CustomTool.new
])

# Remove tool
assistant.remove_tool('custom_tool')

# Clear all tools
assistant.clear_tools
```

## Agent Executor

A powerful executor for autonomous agents that can plan and execute multi-step tasks.

```ruby
agent = CircuitBreaker::Executors::AgentExecutor.define do
  use_model 'gpt-4'
  with_system_prompt "You are a task planning agent..."
  with_tools AgentTools.default_toolset
  with_memory_size 10
end

result = agent
  .update_context(task: "Research and summarize...")
  .execute
```

Features:
- Task planning and execution
- Tool discovery and selection
- Memory management
- Error recovery
- Progress tracking

## Error Handling

The executors include comprehensive error handling:

1. Connection Errors:
```ruby
def make_ollama_request(context, retries = 3)
  # ... request setup ...
  begin
    response = http.request(request)
    # ... process response ...
  rescue => e
    if retries > 0
      sleep(2)
      make_ollama_request(context, retries - 1)
    else
      handle_error(e)
    end
  end
end
```

2. Validation Errors:
```ruby
validate do |context|
  raise "Missing required parameter: model" if context[:model].nil?
  raise "Invalid temperature value" unless valid_temperature?(context[:parameters][:temperature])
end
```

3. Tool Execution Errors:
```ruby
def execute_tool(tool, params)
  tool.execute(**params)
rescue => e
  {
    error: "Tool execution failed: #{e.message}",
    fallback: tool.fallback_response
  }
end
```

## Memory Management

Both executors support conversation memory management:

```ruby
# Initialize memory
@memory = LLM::ConversationMemory.new(
  system_prompt: "Initial prompt...",
  max_tokens: 4000
)

# Update memory
@memory.add_message(role: :user, content: "New message")
@memory.add_message(role: :assistant, content: "Response")

# Clear memory
@memory.clear

# Get conversation history
history = @memory.messages
```

## Best Practices

1. Model Selection:
   - Use appropriate models for tasks
   - Consider token limits
   - Balance performance and cost

2. Tool Design:
   - Keep tools focused and simple
   - Provide clear descriptions
   - Include fallback responses
   - Handle errors gracefully

3. Memory Management:
   - Set appropriate memory limits
   - Clear memory when needed
   - Monitor token usage

4. Error Handling:
   - Implement retries for transient errors
   - Provide helpful error messages
   - Include fallback behaviors

## Configuration Examples

### 1. Document Analysis Assistant

```ruby
assistant = AssistantExecutor.define do
  use_model 'qwen2.5-coder'
  with_system_prompt <<~PROMPT
    You are a document analysis assistant...
  PROMPT
  with_parameters(
    temperature: 0.7,
    top_p: 0.9,
    top_k: 40
  )
  add_tools [
    ContentAnalysisTool.new,
    SentimentAnalysisTool.new,
    ImprovementTool.new
  ]
end
```

### 2. Research Agent

```ruby
agent = AgentExecutor.define do
  use_model 'gpt-4'
  with_system_prompt <<~PROMPT
    You are a research agent...
  PROMPT
  with_tools [
    SearchTool.new,
    SummarizeTool.new,
    CitationTool.new
  ]
  with_memory_size 5
end
```

## Contributing

1. Follow the DSL patterns
2. Add comprehensive tests
3. Document new features
4. Handle errors appropriately

## License

This module is part of the Circuit Breaker library and is available under the MIT license.
