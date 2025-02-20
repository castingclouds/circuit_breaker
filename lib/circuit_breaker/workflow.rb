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
      begin
        CircuitBreaker::Logger.info("Attempting to fire transition '#{name}' from state '#{@token.state}'")
        transition = @transitions[name]
        CircuitBreaker::Logger.info("Found transition: #{transition.inspect}")
        
        unless transition
          CircuitBreaker::Logger.error("Transition '#{name}' not found")
          raise "Transition '#{name}' not found"
        end
        
        unless transition[:from] == @token.state
          CircuitBreaker::Logger.error("Invalid state transition from '#{@token.state}' to '#{transition[:to]}'")
          raise "Invalid state transition from '#{@token.state}' to '#{transition[:to]}'"
        end
        
        CircuitBreaker::Logger.info("Current token state: #{@token.state}")
        CircuitBreaker::Logger.info("Target state: #{transition[:to]}")
      
      CircuitBreaker::Logger.info("Transition validation passed")

      # Execute actions
      results = {}
      CircuitBreaker::Logger.debug("Executing actions: #{transition[:actions].inspect}")
      
      transition[:actions].each do |action|
        tool_name, action_name = action
        CircuitBreaker::Logger.info("  Executing action: #{tool_name} => #{action_name}")
        
        begin
          tool = Tools::ToolRegistry.instance.get(tool_name)
          raise "Tool '#{tool_name}' not found" unless tool
          
          result = tool.execute(action: action_name, token: @token)
          CircuitBreaker::Logger.info("  Action result: #{result.inspect}")
          
          if result[:success]
            # Store only the result data, not the success flag
            results[action_name] = result.reject { |k, _| k == :success }
            CircuitBreaker::Logger.info("  Stored result for #{action_name}:")
            results[action_name].each do |key, value|
              CircuitBreaker::Logger.info("    #{key}: #{value.inspect}")
            end
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
      
      # Validate rules
      begin
        if transition[:rules]
          CircuitBreaker::Logger.info("Validating rules: #{transition[:rules].inspect}")
          all_rules = transition[:rules][:all] || []
          any_rules = transition[:rules][:any] || []

          # All rules must pass
          CircuitBreaker::Logger.info("  Checking required rules: #{all_rules.inspect}")
          all_rules.each do |rule|
            begin
              CircuitBreaker::Logger.info("    Validating rule: #{rule.name}")
              result = rule.validate(results)
              CircuitBreaker::Logger.info("    Rule result: #{result}")
              
              unless result
                error_msg = "Rule '#{rule.name}' failed"
                CircuitBreaker::Logger.error("    " + error_msg)
                raise error_msg
              end
            rescue StandardError => e
              CircuitBreaker::Logger.error("Error validating rule '#{rule.name}': #{e.message}")
              return { success: false, error: e.message }
            end
          end
          CircuitBreaker::Logger.info("  All required rules passed") if all_rules.any?

          # At least one rule must pass
          if any_rules.any?
            CircuitBreaker::Logger.info("  Checking optional rules: #{any_rules.map(&:name).inspect}")
            passed = false
            errors = []
            
            any_rules.each do |rule|
              begin
                CircuitBreaker::Logger.info("    Validating rule: #{rule.name}")
                result = rule.validate(results)
                CircuitBreaker::Logger.info("    Rule result: #{result}")
                
                if result
                  passed = true
                  CircuitBreaker::Logger.info("    Rule '#{rule.name}' passed")
                  break
                else
                  CircuitBreaker::Logger.info("    Rule '#{rule.name}' failed")
                  errors << "Rule '#{rule.name}' failed"
                end
              rescue StandardError => e
                CircuitBreaker::Logger.error("Error validating rule '#{rule.name}': #{e.message}")
                errors << e.message
              end
            end
            
            unless passed
              error_msg = "No optional rules passed: #{errors.join(', ')}"
              CircuitBreaker::Logger.error("  " + error_msg)
              return { success: false, error: error_msg }
            end
            CircuitBreaker::Logger.info("  At least one optional rule passed")
          end
        end
      rescue StandardError => e
        CircuitBreaker::Logger.error("Error during rule validation: #{e.message}")
        return { success: false, error: e.message }
      end
      
      # Update token state and history
      begin
        CircuitBreaker::Logger.info("All validations passed, updating state from '#{@token.state}' to '#{transition[:to]}'")
        @token.update_state(transition[:to], name)
        CircuitBreaker::Logger.info("State updated successfully")
        CircuitBreaker::Logger.info("New token state: #{@token.state}")
        
        { success: true, results: results }
      rescue StandardError => e
        CircuitBreaker::Logger.error("Error updating state: #{e.message}")
        CircuitBreaker::Logger.error(e.backtrace.join("\n"))
        { success: false, error: e.message }
      end
      
      rescue StandardError => e
        CircuitBreaker::Logger.error("Error during transition: #{e.message}")
        CircuitBreaker::Logger.error(e.backtrace.join("\n"))
        { success: false, error: e.message }
      end
    end

    class Transition
      def initialize(workflow, name)
        @workflow = workflow
        @name = name
      end

      def fire
        result = @workflow.fire_transition(@name)
        unless result[:success]
          CircuitBreaker::Logger.error("Transition failed: #{result[:error]}")
          raise result[:error]
        end
        result
      end
    end
  end
end
