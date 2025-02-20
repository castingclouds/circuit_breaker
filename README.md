# Circuit Breaker

A powerful Ruby library for building AI-powered workflows and pipelines. It seamlessly integrates with various LLM providers and offers robust tools for data analysis, workflow management, and autonomous agents.

## Features

### Declarative Workflow DSL
- State-based workflow engine with intuitive syntax
- Policy-based transitions with rule chains
- Unified rules system for validation and transitions
- Comprehensive history tracking
- Event handling and state management

### Pipeline System
- Simple and powerful pipeline definition syntax
- Tool-based action execution
- Parameter passing between actions
- Modular and reusable pipeline components
- Easy integration with custom tools

### Rules System
- Unified DSL for defining rules and validations
- Support for complex rule chains and conditions
- Built-in helpers for common validations
- Rule composition with AND/OR logic
- Clear error reporting and handling

### AI Integration
- Multiple LLM providers (OpenAI, Ollama)
- Automatic model detection
- Tool integration framework
- Memory management
- Error handling with retries

### Executors
- AssistantExecutor for AI-powered tools
- AgentExecutor for autonomous tasks
- Custom executor support
- Chainable tool pipelines

### Document Analysis (Example)
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

### Creating and Running a Pipeline

Circuit Breaker supports both workflows and pipelines. Here's how to use each:

### Pipeline Example

```ruby
# tool-execution.cb
use { print } from "tools"

pipeline hello_world {
  execute {
    print => output {
      message: "Hello, World!"
    }
  }
}

run hello_world
```

Run the pipeline:
```bash
$ cb pipeline examples/executors/tool-execution.cb
```

### Creating a Workflow

```ruby
# document-workflow.cb
use { mock, log, rule } from "tools"

token {
  title: "Circuit Breaker Documentation",
  content: "...",
  authorId: "author@example.com",
  state: "draft"
}

workflow {
  transition (submit, draft -> pending_review) {
    actions {
      mock => analyzeDocument
      mock => analyzeClarity
    }
    policy {
      all: [valid_word_count, valid_clarity],
      any: [has_summary, has_examples]
    }
  }
}
```

Run the workflow:
```bash
$ cb workflow examples/document/document-workflow.cb
```

## Tool Development

### Creating a Custom Tool

```ruby
module CircuitBreaker
  module Tools
    class Print < Tool
      def output(args)
        message = args[:message]
        puts message
        { success: true }
      end
    end
  end
end
```

### Using Tools in Pipelines

```ruby
# Import the tool
use { print } from "tools"

# Use it in a pipeline
pipeline log_message {
  execute {
    print => output {
      message: "Processing started..."
    }
  }
}
```

### Tool Parameters

Tools can accept various parameters:
- Simple values: `message: "Hello"`
- Objects: `config: { timeout: 30 }`
- Arrays: `tags: ["draft", "review"]`

## Command Line Interface

Circuit Breaker provides a command-line interface (CLI) for running workflows and pipelines:

### Running Workflows
```bash
$ cb workflow path/to/workflow.cb [--debug]
```

### Running Pipelines
```bash
$ cb pipeline path/to/pipeline.cb [--debug]
```

Options:
- `--debug`: Enable debug logging for detailed execution information

## Examples

The repository includes several example workflows and pipelines:

### Document Processing Workflow
- `examples/document/document-workflow.cb`: A workflow for document review and approval
- Demonstrates state transitions, actions, and policy rules
- Uses mock tools for document analysis

### Simple Pipeline
- `examples/executors/tool-execution.cb`: A simple pipeline that prints a message
- Demonstrates tool imports and basic pipeline execution
- Uses the print tool for output

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
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

### Core Components

1. **Pipeline Engine**
   - Tool-based execution flow
   - Parameter passing between actions
   - Simple and intuitive syntax
   - Modular pipeline definitions

2. **Workflow Engine**
   - State management
   - Transition validation
   - Rule enforcement
   - Event tracking
   - History management

### Pipeline Example

```ruby
# Define a pipeline
pipeline process_document {
  execute {
    analyze => content {
      text: token.content,
      options: { detailed: true }
    }
    
    summarize => text {
      input: analyze.output,
      max_length: 100
    }
  }
}
```

### Workflow Example

```ruby
# Define a workflow
workflow {
  transition (submit, draft -> review) {
    actions {
      analyze => document
      validate => content
    }
    policy {
      all: [has_reviewer, valid_content]
    }
  }
}
```

### Tool Framework

Tools are the building blocks of both pipelines and workflows:

1. **Basic Tools**
   ```ruby
   class Print < Tool
     def output(args)
       message = args[:message]
       puts message
       { success: true }
     end
   end
   ```

2. **Chainable Tools**
   ```ruby
   class DocumentAnalyzer < Tool
     def analyze(args)
       content = args[:content]
       result = process_content(content)
       { 
         success: true,
         analysis: result,
         next_action: 'validate'
       }
     end
   end
   ```

3. **AI-Powered Tools**
   ```ruby
   class ContentImprover < Tool
     def improve(args)
       text = args[:text]
       suggestions = llm.generate_improvements(text)
       {
         success: true,
         improvements: suggestions
       }
     end
   end
   ```

## Configuration

### LLM Integration
```ruby
CircuitBreaker.configure do |config|
  # Ollama Configuration
  config.ollama_base_url = 'http://localhost:11434'
  config.default_model = 'qwen2.5-coder'

  # OpenAI Configuration
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.openai_model = 'gpt-4'

  # Memory Settings
  config.max_memory_tokens = 4000
  config.memory_window_size = 10

  # Tool Settings
  config.default_tools = [
    DocumentAnalyzer,
    ContentImprover,
    Print
  ]
  config.tool_timeout = 30  # seconds
end
```

## Examples

See the `examples` directory for complete examples:

1. **Document Processing**
   - `examples/document/document-workflow.cb`: Document review workflow
   - `examples/pipelines/document-pipeline.cb`: Document analysis pipeline
   - Demonstrates both workflow and pipeline approaches

2. **Tool Examples**
   - `examples/executors/tool-execution.cb`: Basic tool usage
   - `examples/tools/custom-tool.rb`: Custom tool implementation
   - Shows different tool patterns and best practices

## Best Practices

1. **Pipeline Design**
   - Keep pipelines focused and modular
   - Use clear action and parameter names
   - Chain tools effectively
   - Handle errors gracefully

2. **Workflow Design**
   - Define clear states and transitions
   - Use descriptive rule names
   - Implement proper validation
   - Track state changes

3. **Tool Development**
   - Keep tools single-purpose
   - Provide clear documentation
   - Include error handling
   - Support both pipeline and workflow usage

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Add tests for new features
4. Submit a pull request

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
