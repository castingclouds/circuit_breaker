require_relative 'tool'

module CircuitBreaker
  module Tools
    class Print < Tool
      def initialize
        super(
          name: 'print',
          description: 'Print messages to output',
          parameters: {
            action: {
              type: String,
              enum: ['output']
            },
            message: {
              type: String
            }
          }
        )
      end

      def execute(args)
        action = args[:action]
        message = args[:message]

        CircuitBreaker::Logger.debug("Print tool executing action: #{action}")
        CircuitBreaker::Logger.debug("Message: #{message}")

        case action
        when 'output'
          puts message
          { success: true }
        else
          { success: false, error: "Unknown action: #{action}" }
        end
      end
    end

    # Register the print tool
    ToolRegistry.instance.register(Print.new)
  end
end
