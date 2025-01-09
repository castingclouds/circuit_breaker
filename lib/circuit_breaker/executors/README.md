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
