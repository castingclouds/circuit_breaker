require_relative 'base_executor'
require_relative 'llm/memory'
require_relative 'llm/tools'

module CircuitBreaker
  module Executors
    class AgentExecutor < BaseExecutor
      MAX_ITERATIONS = 10

      executor_config do
        parameter :agent_type, type: :string, description: 'Type of agent'
        parameter :task, type: :string, description: 'Task for the agent to perform'
        parameter :model, type: :string, default: 'gpt-4', description: 'LLM model to use'
        parameter :model_provider, type: :string, description: 'Model provider (ollama/openai)'
        parameter :ollama_base_url, type: :string, default: 'http://localhost:11434', description: 'Ollama server URL'
        parameter :system_prompt, type: :string, description: 'System prompt for the agent'
        parameter :tools, type: :array, default: [], description: 'List of tools available to the agent'
        parameter :parameters, type: :hash, default: {}, description: 'Additional parameters'
      end

      def initialize(context = {})
        super
        @agent_type = context[:agent_type]
        @task = context[:task]
        @model = context[:model] || 'gpt-4'
        @model_provider = context[:model_provider] || detect_model_provider(@model)
        @ollama_base_url = context[:ollama_base_url] || 'http://localhost:11434'
        @system_prompt = context[:system_prompt]
        @memory = LLM::ChainMemory.new
        @toolkit = setup_toolkit(context[:tools] || [])
        @parameters = context[:parameters] || {}
      end

      def execute
        return unless @task

        iteration = 0
        final_output = nil

        while iteration < MAX_ITERATIONS
          # Get current state and plan next action
          current_state = prepare_state(iteration)
          action_plan = plan_next_action(current_state)

          break if action_plan[:status] == 'complete'

          # Execute planned action
          action_result = execute_action(action_plan)
          
          # Store intermediate results
          @memory.add_step_result(
            step_name: action_plan[:action],
            input: action_plan[:input],
            output: action_result,
            metadata: { iteration: iteration }
          )

          final_output = action_result
          iteration += 1
        end

        @result = {
          task: @task,
          iterations: iteration,
          final_output: final_output,
          memory: @memory.to_h,
          status: iteration < MAX_ITERATIONS ? 'completed' : 'max_iterations_reached'
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

      def prepare_state(iteration)
        {
          task: @task,
          iteration: iteration,
          tools: @toolkit.tool_descriptions,
          memory: @memory.get_step_history,
          parameters: @parameters
        }
      end

      def plan_next_action(state)
        prompt = generate_planning_prompt(state)
        
        case @model_provider
        when 'ollama'
          response = make_ollama_request(prompt)
          parse_llm_response(response)
        when 'openai'
          # Existing OpenAI logic here
          if state[:iteration] == 0
            {
              status: 'in_progress',
              action: 'search',
              input: { query: state[:task] }
            }
          else
            { status: 'complete' }
          end
        end
      end

      def generate_planning_prompt(state)
        # Generate a structured prompt for the LLM
        system_context = @system_prompt || "You are an AI agent tasked with solving problems step by step."
        available_tools = state[:tools].map { |t| "- #{t[:name]}: #{t[:description]}" }.join("\n")
        memory_context = state[:memory].map { |m| "Step #{m[:step]}: #{m[:result]}" }.join("\n")

        <<~PROMPT
          #{system_context}

          TASK: #{state[:task]}
          ITERATION: #{state[:iteration]}
          
          AVAILABLE TOOLS:
          #{available_tools}

          PREVIOUS STEPS:
          #{memory_context}

          Based on the above context, determine the next action:
          1. If the task is complete, respond with: {"status": "complete"}
          2. If more work is needed, respond with: {"status": "in_progress", "action": "[tool_name]", "input": {[tool parameters]}}
        PROMPT
      end

      def make_ollama_request(prompt)
        require 'net/http'
        require 'json'

        uri = URI("#{@ollama_base_url}/api/generate")
        http = Net::HTTP.new(uri.host, uri.port)
        
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request.body = {
          model: @model,
          prompt: prompt,
          stream: false
        }.to_json

        response = http.request(request)
        JSON.parse(response.body)
      rescue => e
        { error: "Ollama request failed: #{e.message}" }
      end

      def parse_llm_response(response)
        return { status: 'error', message: response[:error] } if response[:error]

        begin
          # Extract the JSON response from the LLM output
          json_str = response['response'].match(/\{.*\}/m)&.[](0)
          return { status: 'error', message: 'No valid JSON found in response' } unless json_str

          JSON.parse(json_str, symbolize_names: true)
        rescue JSON::ParserError => e
          { status: 'error', message: "Failed to parse LLM response: #{e.message}" }
        end
      end

      def execute_action(action_plan)
        return unless action_plan[:action]

        begin
          @toolkit.execute_tool(action_plan[:action], **action_plan[:input])
        rescue => e
          { error: e.message }
        end
      end
    end
  end
end
