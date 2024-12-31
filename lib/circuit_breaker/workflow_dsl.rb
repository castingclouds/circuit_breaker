module CircuitBreaker
  module WorkflowDSL
    class ::Symbol
      def >>(other)
        StateTransition.new(self, other)
      end
    end

    def self.define(rules: nil, &block)
      builder = WorkflowBuilder.new(rules)
      builder.instance_eval(&block)
      builder.build_workflow
    end

    class WorkflowBuilder
      include Validators

      def initialize(rules = nil)
        @states = []
        @transitions = {}
        @before_flows = []
        @rules = rules || []
      end

      def states(*states)
        @states = states
        self
      end

      def flow(transition)
        if transition.is_a?(Hash)
          from, to = transition.first
        elsif transition.respond_to?(:>>)
          from = transition.instance_variable_get(:@from_state)
          to = transition.instance_variable_get(:@to_state)
        else
          from, to = transition.to_s.split(">>").map(&:strip).map(&:to_sym)
        end

        @current_transition = { from: from, to: to }
        self
      end

      def transition(name)
        raise "No current transition" unless @current_transition
        @transitions[name] = @current_transition.dup
        @current_name = name
        self
      end

      def validate(*field_names)
        raise "No current transition name" unless @current_name
        @transitions[@current_name][:guard] = ->(token) { validators.chain(token).validate(*field_names).valid? }
        @transitions[@current_name][:validations] = field_names
        self
      end

      def validate_any(*field_names)
        raise "No current transition name" unless @current_name
        @transitions[@current_name][:guard] = ->(token) { validators.chain(token).or_validate(*field_names).valid? }
        @transitions[@current_name][:validations_any] = field_names
        self
      end

      def rules(*rule_names)
        raise "No current transition name" unless @current_name
        @transitions[@current_name][:guard] = ->(token) { 
          rule_names.all? { |rule| @rules.evaluate(rule, token) }
        }
        @transitions[@current_name][:rules] = rule_names
        self
      end

      def rules_any(*rule_names)
        raise "No current transition name" unless @current_name
        @transitions[@current_name][:guard] = ->(token) { 
          rule_names.any? { |rule| @rules.evaluate(rule, token) }
        }
        @transitions[@current_name][:rules_any] = rule_names
        self
      end

      def guard(&block)
        raise "No current transition name" unless @current_name
        @transitions[@current_name][:guard] = block
        self
      end

      def build_workflow
        workflow = Workflow.new(
          states: @states,
          transitions: @transitions,
          before_flows: @before_flows,
          rules: @rules
        )
        workflow.extend(PrettyPrint)
        workflow
      end
    end

    class StateTransition
      attr_reader :from_state, :to_state

      def initialize(from_state, to_state)
        @from_state = from_state
        @to_state = to_state
      end

      def >>(other)
        if other.is_a?(StateTransition)
          StateTransition.new(from_state, other.to_state)
        else
          StateTransition.new(from_state, other)
        end
      end

      def ==(other)
        return false unless other.is_a?(Symbol) || other.is_a?(StateTransition)
        other_state = other.is_a?(Symbol) ? other : other.from_state
        from_state == other_state
      end
    end

    module PrettyPrint
      def pretty_print
        puts "\nWorkflow States and Transitions:"
        puts "=============================="
        @states.each do |state|
          puts "State: #{state}"
          transitions_from_state = @transitions.select { |_, t| t[:from] == state }
          if transitions_from_state.any?
            transitions_from_state.each do |name, transition|
              puts "  └─> #{transition[:to]} (via :#{name})"
              if transition[:rules]
                puts "      Required rules: #{transition[:rules].join(', ')}"
                transition[:rules].each do |rule|
                  desc = @rules.description(rule)
                  puts "        - #{desc}" if desc
                end
              end
              if transition[:rules_any]
                puts "      Any of these rules: #{transition[:rules_any].join(', ')}"
                transition[:rules_any].each do |rule|
                  desc = @rules.description(rule)
                  puts "        - #{desc}" if desc
                end
              end
              if transition[:validations]
                puts "      Required validations: #{transition[:validations].join(', ')}"
                transition[:validations].each do |validation|
                  desc = @validators.description(validation)
                  puts "        - #{desc}" if desc
                end
              end
              if transition[:validations_any]
                puts "      Any of these validations: #{transition[:validations_any].join(', ')}"
                transition[:validations_any].each do |validation|
                  desc = @validators.description(validation)
                  puts "        - #{desc}" if desc
                end
              end
            end
          end
          puts
        end
      end
    end
  end
end
