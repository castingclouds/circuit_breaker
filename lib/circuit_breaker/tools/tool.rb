module CircuitBreaker
  module Tools
    # Base tool interface
    class Tool
      attr_reader :name, :description, :parameters

      def initialize(name:, description:, parameters: {})
        @name = name
        @description = description
        @parameters = parameters
      end

      def execute(args)
        raise NotImplementedError, "#{self.class} must implement #execute"
      end
    end

    # Registry for managing tools
    class ToolRegistry
      def initialize
        @tools = {}
      end

      def get(name)
        @tools[name]
      end

      def register(tool)
        @tools[tool.name] = tool
      end

      def all
        @tools.values
      end

      def self.instance
        @instance ||= new
      end
    end
  end
end
