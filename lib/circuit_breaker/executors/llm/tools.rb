require 'json'

module CircuitBreaker
  module Executors
    module LLM
      class Tool
        attr_reader :name, :description, :parameters

        def initialize(name:, description:, parameters: {})
          @name = name
          @description = description
          @parameters = parameters
        end

        def execute(**args)
          raise NotImplementedError, "#{self.class} must implement #execute"
        end

        def to_h
          {
            name: @name,
            description: @description,
            parameters: @parameters
          }
        end
      end

      class ToolKit
        def initialize
          @tools = {}
        end

        def add_tool(tool)
          @tools[tool.name] = tool
        end

        def get_tool(name)
          @tools[name]
        end

        def available_tools
          @tools.values
        end

        def tool_descriptions
          @tools.values.map(&:to_h)
        end

        def execute_tool(name, **args)
          tool = get_tool(name)
          raise "Tool '#{name}' not found" unless tool
          tool.execute(**args)
        end
      end

      # Example built-in tools
      class SearchTool < Tool
        def initialize
          super(
            name: 'search',
            description: 'Search for information on a given topic',
            parameters: {
              query: { type: 'string', description: 'The search query' }
            }
          )
        end

        def execute(query:)
          # Implement actual search logic here
          { results: "Search results for: #{query}" }
        end
      end

      class CalculatorTool < Tool
        def initialize
          super(
            name: 'calculator',
            description: 'Perform mathematical calculations',
            parameters: {
              expression: { type: 'string', description: 'The mathematical expression to evaluate' }
            }
          )
        end

        def execute(expression:)
          # Implement safe evaluation logic here
          { result: eval(expression).to_s }
        rescue => e
          { error: e.message }
        end
      end
    end
  end
end
