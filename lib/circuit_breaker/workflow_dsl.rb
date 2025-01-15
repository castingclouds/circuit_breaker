module CircuitBreaker
  module WorkflowDSL
    class ::Symbol
      def >>(other)
        StateTransition.new(self, other)
      end
    end

    class StateTransition
      attr_reader :from_state, :to_state

      def initialize(from_state, to_state)
        @from_state = from_state
        @to_state = to_state
      end

      def >>(to_state)
        StateTransition.new(@from_state || @to_state, to_state)
      end

      def ==(other)
        return false unless other.is_a?(Symbol) || other.is_a?(StateTransition)
        other_state = other.is_a?(Symbol) ? other : other.from_state
        from_state == other_state
      end
    end

    class StateTransitionBuilder
      def initialize(workflow_builder, state_transition)
        @workflow_builder = workflow_builder
        @from_state = state_transition.from_state
        @to_state = state_transition.to_state
      end

      def transition(name)
        @workflow_builder.transition(name, from: @from_state, to: @to_state)
      end
    end

    class WorkflowBuilder
      attr_reader :states, :transitions, :before_flows, :rules

      def initialize(rules = nil)
        @states = []
        @transitions = {}
        @before_flows = []
        @rules = rules || Rules::DSL.define
      end

      def states(*states)
        @states = states
        self
      end

      def flow(state_transition)
        StateTransitionBuilder.new(self, state_transition)
      end

      def transition(name, from:, to:)
        @transitions[name] = TransitionBuilder.new(name, from, to)
      end

      def policy(rules: {})
        transition = @transitions.values.last
        transition.rules = rules
        self
      end

      def before_flow(&block)
        @before_flows << block
        self
      end

      def build
        Workflow.new(
          states: @states,
          transitions: @transitions.values.map(&:build),
          before_flows: @before_flows,
          rules: @rules
        )
      end
    end

    class TransitionBuilder
      attr_accessor :name, :from_state, :to_state, :rules

      def initialize(name, from_state, to_state)
        @name = name
        @from_state = from_state
        @to_state = to_state
        @rules = {}
      end

      def policy(rules: {})
        @rules = rules
        self
      end

      def build
        Transition.new(
          name: @name,
          from_state: @from_state,
          to_state: @to_state,
          rules: @rules
        )
      end
    end

    class Transition
      attr_reader :name, :from_state, :to_state, :rules

      def initialize(name:, from_state:, to_state:, rules:)
        @name = name
        @from_state = from_state
        @to_state = to_state
        @rules = rules
      end

      def validate_rules(token, rules_dsl)
        return true if @rules.empty?

        # Check all required rules
        if @rules[:all]
          @rules[:all].each do |rule|
            unless rules_dsl.evaluate(rule, token)
              raise "Rule '#{rule}' failed for transition '#{@name}'"
            end
          end
        end

        # Check any required rules
        if @rules[:any]
          unless @rules[:any].any? { |rule| rules_dsl.evaluate(rule, token) }
            raise "None of the rules #{@rules[:any]} passed for transition '#{@name}'"
          end
        end

        true
      end
    end

    module PrettyPrint
      def pretty_print
        puts "States:"
        puts "  #{@states.join(' -> ')}"
        puts "\nTransitions:"
        @transitions.each do |transition|
          puts "  #{transition.name}: #{transition.from_state} -> #{transition.to_state}"
          if transition.rules && !transition.rules.empty?
            puts "    Rules:"
            if transition.rules[:all]
              puts "      All of:"
              transition.rules[:all].each { |rule| puts "        - #{rule}" }
            end
            if transition.rules[:any]
              puts "      Any of:"
              transition.rules[:any].each { |rule| puts "        - #{rule}" }
            end
          end
        end
      end
    end

    class Workflow
      include PrettyPrint

      attr_reader :states, :transitions, :before_flows, :rules, :tokens

      def initialize(states:, transitions:, before_flows:, rules:)
        @states = states
        @transitions = transitions
        @before_flows = before_flows
        @rules = rules
        @tokens = []
      end

      def add_token(token)
        token.state = @states.first if token.state.nil?
        @tokens << token
      end

      def fire_transition(transition_name, token)
        transition = find_transition(transition_name, token.state)
        raise "Invalid transition '#{transition_name}' for state '#{token.state}'" unless transition

        # Run any before_flow blocks
        @before_flows.each { |block| block.call(token) }

        # Validate rules
        transition.validate_rules(token, @rules)

        # Update token state and record the transition
        old_state = token.state
        token.state = transition.to_state
        token.record_transition(transition_name, old_state, token.state)

        token
      end

      private

      def find_transition(name, current_state)
        @transitions.find { |t| t.name == name && t.from_state == current_state }
      end
    end

    def self.define(rules: nil, &block)
      builder = WorkflowBuilder.new(rules)
      builder.instance_eval(&block)
      builder.build
    end
  end
end
