module CircuitBreaker
  class Pipeline
    attr_reader :name, :actions

    def initialize(name:, actions:)
      @name = name
      @actions = actions
    end

    def execute
      CircuitBreaker::Logger.info("Executing pipeline '#{@name}'")
      
      results = {}
      @actions.each do |action|
        tool_name, action_name, params = action
        CircuitBreaker::Logger.info("  Executing action: #{tool_name} => #{action_name}")
        CircuitBreaker::Logger.debug("  Parameters: #{params.inspect}")
        
        begin
          tool = Tools::ToolRegistry.instance.get(tool_name)
          raise "Tool '#{tool_name}' not found" unless tool
          
          result = tool.execute(action: action_name, **params)
          CircuitBreaker::Logger.info("  Action result: #{result.inspect}")
          
          if result[:success]
            results[action_name] = result.reject { |k, _| k == :success }
          else
            error_msg = "Action '#{action_name}' failed: #{result[:error]}"
            CircuitBreaker::Logger.error("  " + error_msg)
            raise error_msg
          end
        rescue StandardError => e
          CircuitBreaker::Logger.error("Error executing action: #{e.message}")
          return { success: false, error: e.message }
        end
      end
      
      { success: true, results: results }
    end
  end
end
