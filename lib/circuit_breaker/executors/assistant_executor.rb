require_relative 'base_executor'
require_relative 'llm/memory'
require_relative 'llm/tools'

module CircuitBreaker
  module Executors
    class AssistantExecutor < BaseExecutor
      executor_config do
        parameter :model, type: :string, default: 'gpt-4', description: 'LLM model to use'
        parameter :model_provider, type: :string, description: 'Model provider (ollama/openai)'
        parameter :ollama_base_url, type: :string, default: 'http://localhost:11434', description: 'Ollama server URL'
        parameter :system_prompt, type: :string, description: 'System prompt for the assistant'
        parameter :tools, type: :array, default: [], description: 'List of tools available to the assistant'
        parameter :parameters, type: :hash, default: {}, description: 'Additional parameters'
        parameter :input, type: :string, description: 'Input message for the assistant'
      end

      def initialize(context = {})
        super
        @model = context[:model] || 'gpt-4'
        @model_provider = context[:model_provider] || detect_model_provider(@model)
        @ollama_base_url = context[:ollama_base_url] || 'http://localhost:11434'
        @system_prompt = context[:system_prompt]
        @memory = LLM::ConversationMemory.new(system_prompt: @system_prompt)
        @toolkit = setup_toolkit(context[:tools] || [])
        @parameters = context[:parameters] || {}
      end

      def update_context(new_context)
        @context.merge!(new_context)
      end

      def execute
        input = @context[:input]
        return unless input

        # Add user input to memory
        @memory.add_user_message(input)

        # Prepare conversation context
        conversation_context = prepare_context

        # Simulate LLM call (replace with actual LLM integration)
        response = simulate_llm_call(conversation_context)

        # Process response and extract any tool calls
        processed_response = process_response(response)

        # Store assistant's response in memory
        @memory.add_assistant_message(processed_response[:content])

        @result = {
          input: input,
          output: processed_response,
          conversation_history: @memory.to_h,
          status: 'completed'
        }
      end

      private

      def detect_model_provider(model)
        return 'ollama' if model.start_with?('llama', 'codellama', 'mistral', 'dolphin')
        'openai'
      end

      def setup_toolkit(tools)
        toolkit = LLM::ToolKit.new
        tools.each do |tool|
          toolkit.add_tool(tool)
        end
        toolkit
      end

      def prepare_context
        {
          messages: @memory.messages,
          tools: @toolkit.tool_descriptions,
          parameters: @parameters
        }
      end

      def simulate_llm_call(context)
        case @model_provider
        when 'ollama'
          make_ollama_request(context)
        when 'openai'
          # Replace this with actual OpenAI API call
          {
            content: "This is a simulated response to: #{context[:messages].last[:content]}",
            tool_calls: []
          }
        end
      end

      def make_ollama_request(context)
        require 'net/http'
        require 'json'

        # Convert conversation history to Ollama format
        messages = format_messages_for_ollama(context[:messages])
        tools = format_tools_for_ollama(context[:tools])

        uri = URI("#{@ollama_base_url}/api/generate")
        http = Net::HTTP.new(uri.host, uri.port)
        
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request.body = {
          model: @model,
          prompt: generate_ollama_prompt(messages, tools),
          stream: false
        }.to_json

        response = http.request(request)
        parse_ollama_response(JSON.parse(response.body))
      rescue => e
        {
          content: "Error: #{e.message}",
          tool_calls: []
        }
      end

      def format_messages_for_ollama(messages)
        messages.map do |msg|
          {
            role: msg[:role],
            content: msg[:content]
          }
        end
      end

      def format_tools_for_ollama(tools)
        tools.map do |tool|
          "#{tool[:name]}: #{tool[:description]}\nParameters: #{tool[:parameters].to_json}"
        end.join("\n\n")
      end

      def generate_ollama_prompt(messages, tools)
        system_msg = messages.find { |m| m[:role] == 'system' }
        user_msgs = messages.select { |m| m[:role] != 'system' }

        prompt = []
        prompt << "System: #{system_msg[:content]}" if system_msg
        prompt << "\nAvailable Tools:\n#{tools}" if tools.any?
        
        user_msgs.each do |msg|
          prompt << "\n#{msg[:role].capitalize}: #{msg[:content]}"
        end

        prompt << "\nAssistant: "
        prompt.join("\n")
      end

      def parse_ollama_response(response)
        return { content: "Error: #{response['error']}", tool_calls: [] } if response['error']

        content = response['response']
        tool_calls = extract_tool_calls(content)

        {
          content: clean_content(content, tool_calls),
          tool_calls: tool_calls
        }
      end

      def extract_tool_calls(content)
        # Look for tool calls in the format: `@tool_name({"param": "value"})`
        tool_calls = content.scan(/@(\w+)\((.*?)\)/)
        tool_calls.map do |name, args_str|
          begin
            {
              name: name,
              arguments: JSON.parse(args_str)
            }
          rescue JSON::ParserError
            nil
          end
        end.compact
      end

      def clean_content(content, tool_calls)
        # Remove tool call syntax from the content
        clean = content.dup
        tool_calls.each do |tool|
          clean.gsub!(/@#{tool[:name]}\(#{tool[:arguments].to_json}\)/, '')
        end
        clean.strip
      end

      def process_response(response)
        return response unless response[:tool_calls]&.any?

        # Execute any tool calls
        tool_results = response[:tool_calls].map do |tool_call|
          result = @toolkit.execute_tool(tool_call[:name], **tool_call[:arguments])
          { tool: tool_call[:name], result: result }
        end

        response.merge(tool_results: tool_results)
      end
    end
  end
end
