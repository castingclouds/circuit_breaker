require_relative 'tools/tool'
require_relative 'token'

module CircuitBreaker
  class Workflow
    attr_reader :token, :states, :transitions

    def initialize(token:, states:)
      @token = token
      @states = states
      @transitions = {}
    end

    def add_transition(name:, from:, to:, actions: [], rules: [])
      @transitions[name] = {
        from: from,
        to: to,
        actions: actions,
        rules: rules
      }
    end

    def transition(name)
      Transition.new(self, name)
    end

    def fire_transition(name)
      CircuitBreaker::Logger.debug("Attempting to fire transition '#{name}' from state '#{@token.state}'")
      transition = @transitions[name]
      raise "Transition '#{name}' not found" unless transition
      raise "Invalid state transition from '#{@token.state}' to '#{transition[:to]}'" unless transition[:from] == @token.state
      CircuitBreaker::Logger.debug("Transition validation passed")

      # Execute actions
      results = {}
      CircuitBreaker::Logger.debug("Executing actions: #{transition[:actions].inspect}")
      
      transition[:actions].each do |action|
        tool_name, action_name = action
        CircuitBreaker::Logger.debug("  Executing action: #{tool_name} => #{action_name}")
        
        tool = Tools::ToolRegistry.instance.get(tool_name)
        raise "Tool '#{tool_name}' not found" unless tool
        
        result = tool.execute(action: action_name, token: @token)
        CircuitBreaker::Logger.debug("  Action result: #{result.inspect}")
        
        if result[:success]
          # Store only the result data, not the success flag
          results[action_name] = result.reject { |k, _| k == :success }
          CircuitBreaker::Logger.debug("  Stored result: #{results[action_name].inspect}")
        else
          CircuitBreaker::Logger.error("  Action failed: #{result[:error]}")
          return { success: false, error: "Action '#{action_name}' failed: #{result[:error]}" }
        end
      end

      # Validate rules
      if transition[:rules]
        CircuitBreaker::Logger.debug("Validating rules: #{transition[:rules].inspect}")
        all_rules = transition[:rules][:all] || []
        any_rules = transition[:rules][:any] || []

        # All rules must pass
        CircuitBreaker::Logger.debug("  Checking required rules: #{all_rules.inspect}")
        all_rules.each do |rule|
          CircuitBreaker::Logger.debug("    Validating rule: #{rule}")
          result = rule.validate(results)
          CircuitBreaker::Logger.debug("    Rule result: #{result}")
          
          unless result
            CircuitBreaker::Logger.error("    Rule '#{rule.name}' failed")
            return { success: false, error: "Rule '#{rule.name}' failed" }
          end
        end
        CircuitBreaker::Logger.debug("  All required rules passed") if all_rules.any?

        # At least one rule must pass
        if any_rules.any?
          CircuitBreaker::Logger.debug("  Checking optional rules: #{any_rules.inspect}")
          passed = false
          
          any_rules.each do |rule|
            CircuitBreaker::Logger.debug("    Validating rule: #{rule}")
            result = rule.validate(results)
            CircuitBreaker::Logger.debug("    Rule result: #{result}")
            
            if result
              passed = true
              CircuitBreaker::Logger.debug("    Rule '#{rule.name}' passed")
              break
            end
          end
          
          unless passed
            CircuitBreaker::Logger.error("  No optional rules passed")
            return { success: false, error: "None of the optional rules passed" }
          end
          CircuitBreaker::Logger.debug("  At least one optional rule passed")
        end
      end

      # Update token state
      CircuitBreaker::Logger.debug("All validations passed, updating state from '#{@token.state}' to '#{transition[:to]}'")
      @token.state = transition[:to]
      CircuitBreaker::Logger.debug("State updated successfully")
      
      { success: true, results: results }
    end

    class Transition
      def initialize(workflow, name)
        @workflow = workflow
        @name = name
      end

      def fire
        @workflow.fire_transition(@name)
      end
    end
  end
end
