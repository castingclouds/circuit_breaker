require_relative 'base_executor'
require_relative 'llm/memory'
require_relative 'llm/tools'
require_relative 'dsl'

module CircuitBreaker
  module Executors
    class AssistantExecutor < BaseExecutor
      include DSL

      def initialize(context = {})
        super
        @memory = LLM::ConversationMemory.new(system_prompt: @context[:system_prompt])
        @toolkit = LLM::ToolKit.new
      end

      executor_config do
        parameter :model, type: :string, default: 'gpt-4', description: 'LLM model to use'
        parameter :model_provider, type: :string, description: 'Model provider (ollama/openai)'
        parameter :ollama_base_url, type: :string, default: 'http://localhost:11434', description: 'Ollama server URL'
        parameter :system_prompt, type: :string, description: 'System prompt for the assistant'
        parameter :tools, type: :array, default: [], description: 'List of tools available to the assistant'
        parameter :parameters, type: :hash, default: {}, description: 'Additional parameters'
        parameter :input, type: :string, description: 'Input message for the assistant'

        validate do |context|
          if context[:model_provider].nil?
            context[:model_provider] = if context[:model].to_s.start_with?('llama', 'codellama', 'mistral', 'dolphin', 'qwen')
              'ollama'
            else
              'openai'
            end
          end
        end

        before_execute do |context|
          @memory.system_prompt = context[:system_prompt] if context[:system_prompt]
          add_tools(context[:tools]) if context[:tools]
        end
      end

      class << self
        def define(&block)
          new.tap do |executor| 
            executor.instance_eval(&block) if block_given?
            executor.validate_parameters
          end
        end
      end

      def use_model(model_name)
        @context[:model] = model_name
        @context[:model_provider] = if model_name.to_s.start_with?('llama', 'codellama', 'mistral', 'dolphin', 'qwen')
          'ollama'
        else
          'openai'
        end
        self
      end

      def with_system_prompt(prompt)
        @context[:system_prompt] = prompt
        @memory = LLM::ConversationMemory.new(system_prompt: prompt)
        self
      end

      def with_parameters(params)
        @context[:parameters] = (@context[:parameters] || {}).merge(params)
        self
      end

      def add_tool(tool)
        @toolkit.add_tool(tool)
        self
      end

      def add_tools(tools)
        tools.each { |tool| add_tool(tool) }
        self
      end

      def update_context(new_context)
        @context.merge!(new_context)
        validate_parameters
        self
      end

      def execute
        input = @context[:input]
        return unless input

        @memory.add_user_message(input)
        conversation_context = prepare_context
        response = make_llm_call(conversation_context)
        processed_response = process_response(response)
        @memory.add_assistant_message(processed_response[:content])

        @result = {
          input: input,
          output: processed_response,
          conversation_history: @memory.to_h,
          status: 'completed'
        }
      end

      private

      def prepare_context
        {
          messages: @memory.messages,
          tools: @toolkit.tool_descriptions,
          parameters: @context[:parameters]
        }
      end

      def make_llm_call(context)
        case @context[:model_provider]
        when 'ollama'
          make_ollama_request(context)
        when 'openai'
          make_openai_request(context)
        end
      end

      def make_ollama_request(context, retries = 3)
        require 'net/http'
        require 'json'

        messages = format_messages_for_ollama(context[:messages])
        prompt = generate_ollama_prompt(messages, context[:tools])

        uri = URI("#{@context[:ollama_base_url]}/api/generate")
        http = Net::HTTP.new(uri.host, uri.port)
        http.read_timeout = 120  # Increase timeout to 120 seconds
        
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request.body = {
          model: @context[:model],
          prompt: prompt,
          stream: false,
          options: @context[:parameters]
        }.to_json

        begin
          response = http.request(request)
          
          if response.code == '200'
            result = JSON.parse(response.body)
            full_response = ""
            
            if result.is_a?(Array)
              result.each { |chunk| full_response += chunk['response'].to_s }
            else
              full_response = result['response']
            end

            {
              content: full_response,
              tool_calls: extract_tool_calls(full_response)
            }
          else
            raise "HTTP Error: #{response.message}"
          end
        rescue => e
          if retries > 0
            puts "Retrying Ollama request (#{retries} attempts left)..."
            sleep(2)  # Wait 2 seconds before retrying
            make_ollama_request(context, retries - 1)
          else
            {
              content: "Error: #{e.message}. Please try again later.",
              tool_calls: []
            }
          end
        end
      end

      def make_openai_request(context)
        # Implement OpenAI API call here
        {
          content: "OpenAI integration not implemented",
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

      def generate_ollama_prompt(messages, tools)
        system_msg = messages.find { |m| m[:role] == 'system' }
        user_msgs = messages.select { |m| m[:role] != 'system' }

        prompt = []
        prompt << "System: #{system_msg[:content]}" if system_msg
        prompt << "\nAvailable Tools:\n#{format_tools_for_ollama(tools)}" unless tools.empty?
        
        user_msgs.each do |msg|
          prompt << "\n#{msg[:role].capitalize}: #{msg[:content]}"
        end

        prompt << "\nAssistant: "
        prompt.join("\n")
      end

      def format_tools_for_ollama(tools)
        return "" if tools.nil? || tools.empty?
        tools.map do |tool|
          "#{tool[:name]}: #{tool[:description]}\nParameters: #{tool[:parameters].to_json}"
        end.join("\n\n")
      end

      def extract_tool_calls(content)
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

      def process_response(response)
        return response unless response[:tool_calls]&.any?

        tool_results = response[:tool_calls].map do |tool_call|
          result = @toolkit.execute_tool(tool_call[:name], **tool_call[:arguments])
          { tool: tool_call[:name], result: result }
        end

        response.merge(tool_results: tool_results)
      end
    end
  end
end
