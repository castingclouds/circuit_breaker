module CircuitBreaker
  module WorkflowBuilder
    module DSL
      class ::Symbol
        def >>(other)
          StateTransition.new(self, other)
        end
      end

      class StateTransition
        attr_reader :from, :to

        def initialize(from, to)
          @from = from
          @to = to
        end

        def >>(other)
          StateTransition.new(from, other)
        end

        def to_s
          "#{from} -> #{to}"
        end
      end

      class ActionContext
        attr_reader :results

        def initialize
          @results = {}
        end

        def add_result(name, result)
          @results[name] = result if name
        end

        def get_result(name)
          @results[name]
        end

        def method_missing(name, *args)
          @results[name]
        end

        def respond_to_missing?(name, include_private = false)
          @results.key?(name) || super
        end
      end

      class ActionBuilder
        attr_reader :context, :actions

        def initialize(workflow_builder)
          @workflow_builder = workflow_builder
          @context = ActionContext.new
          @actions = []
        end

        def execute(executor, method, result_name = nil, **params)
          @actions << [executor, method, result_name, params]
        end

        def execute_actions(token)
          puts "Executing actions for token #{token.id}..."
          @actions.each do |executor, method, result_name, params|
            puts "  Executing #{method} -> #{result_name}"
            result = executor.send(method, token, **params)
            puts "  Result: #{result.inspect}"
            @context.add_result(result_name, result) if result_name
          end
        end
      end

      class StateTransitionBuilder
        def initialize(workflow_builder, state_transition)
          @workflow_builder = workflow_builder
          @from_state = state_transition.from
          @to_state = state_transition.to
        end

        def transition(name)
          @workflow_builder.transition(name, from: @from_state, to: @to_state)
        end

        def policy(rules)
          @workflow_builder.policy(rules)
        end

        def actions(&block)
          builder = ActionBuilder.new(@workflow_builder)
          builder.instance_eval(&block)
          @workflow_builder.set_action_context(builder.context)
        end
      end

      class WorkflowBuilder
        attr_reader :states, :transitions, :before_flows, :rules, :current_token

        def initialize(rules = nil)
          @states = []
          @transitions = []
          @before_flows = []
          @rules = rules || Rules::DSL.define
          @current_token = nil
        end

        def states(*states)
          @states = states
        end

        def flow(transition_spec, name = nil, &block)
          from_state, to_state = parse_transition_spec(transition_spec)
          raise "Invalid transition spec" unless from_state && to_state

          transition = Transition.new(name || "#{from_state}_to_#{to_state}", from_state, to_state, self)
          transition.instance_eval(&block) if block_given?
          @transitions << transition
          transition
        end

        def before_flow(&block)
          @before_flows << block
        end

        def find_transition(name, from_state = nil)
          @transitions.find do |t|
            t.name == name && (from_state.nil? || t.from_state == from_state)
          end
        end

        def transition!(token, transition_name)
          transition = @transitions.find { |t| t.name == transition_name }
          raise "Invalid transition '#{transition_name}'" unless transition
          raise "Invalid from state '#{token.state}' (expected #{transition.from_state})" unless token.state.to_s == transition.from_state.to_s

          old_state = token.state
          @current_token = token  # Set current token before executing actions

          begin
            # Execute actions first
            transition.execute_actions(token)

            # Then validate rules
            transition.validate_rules(token, @rules)

            # Finally update state
            token.state = transition.to_state.to_sym
            token.record_transition(transition_name, old_state, token.state)

            token
          ensure
            @current_token = nil  # Clear current token after execution
          end
        end

        def build
          self  # Return self since we're already a workflow
        end

        def pretty_print
          puts "States:"
          puts "  #{@states.join(' -> ')}\n\n"

          puts "Transitions:"
          @transitions.each do |t|
            puts "  #{t.name}: #{t.from_state} -> #{t.to_state}"
            puts "    Rules:"
            if t.rules.is_a?(Hash)
              if t.rules[:all]
                puts "      All of:"
                t.rules[:all].each { |r| puts "        - #{r}" }
              end
              if t.rules[:any]
                puts "      Any of:"
                t.rules[:any].each { |r| puts "        - #{r}" }
              end
            else
              t.rules.each { |r| puts "        - #{r}" }
            end
            puts "    Actions:"
            if t.action_builder&.actions
              t.action_builder.actions.each do |executor, method, result_name, params|
                result = executor.send(method, @current_token, **params) if @current_token
                puts "      #{result_name}: #{result.inspect}"
              end
            end
          end
        end

        private

        def parse_transition_spec(spec)
          case spec
          when String
            spec.split(">>").map(&:strip)
          when Symbol
            [spec.to_s]
          when StateTransition
            [spec.from.to_s, spec.to.to_s]
          else
            raise "Invalid transition spec: #{spec}"
          end
        end
      end

      class TransitionBuilder
        attr_accessor :name, :from_state, :to_state, :rules, :action_context

        def initialize(name, from_state, to_state)
          @name = name
          @from_state = from_state
          @to_state = to_state
          @rules = []
          @action_context = nil
        end

        def build
          Transition.new(
            name: @name,
            from_state: @from_state,
            to_state: @to_state,
            rules: @rules,
            action_context: @action_context
          )
        end
      end

      class Transition
        attr_reader :name, :from_state, :to_state, :rules, :workflow_builder
        attr_accessor :action_context, :action_builder

        def initialize(name, from_state, to_state, workflow_builder)
          @name = name
          @from_state = from_state
          @to_state = to_state
          @rules = []
          @action_context = nil
          @action_builder = nil
          @workflow_builder = workflow_builder
        end

        def actions(&block)
          @action_builder = ActionBuilder.new(@workflow_builder)
          @action_builder.instance_eval(&block) if block_given?
          @action_context = @action_builder.context
        end

        def policy(rules)
          @rules = rules
        end

        def execute_actions(token)
          @action_builder&.execute_actions(token)
        end

        def validate_rules(token, rules_dsl)
          return unless @rules
          
          rules_dsl.with_context(@action_context) do
            # Handle :all rules
            if @rules[:all]
              @rules[:all].each do |rule|
                raise "Rule '#{rule}' failed for transition '#{name}'" unless rules_dsl.evaluate(rule, token)
              end
            end

            # Handle :any rules
            if @rules[:any]
              any_passed = @rules[:any].any? { |rule| rules_dsl.evaluate(rule, token) }
              raise "None of the rules #{@rules[:any]} passed for transition '#{name}'" unless any_passed
            end
          end
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
            if transition.action_context && !transition.action_context.results.empty?
              puts "    Actions:"
              transition.action_context.results.each do |name, result|
                puts "      #{name}: #{result}"
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

        def transition!(token, transition_name)
          transition = @transitions.find { |t| t.name == transition_name }
          raise "Invalid transition '#{transition_name}'" unless transition
          raise "Invalid from state '#{token.state}'" unless token.state == transition.from_state

          old_state = token.state
          @current_token = token  # Set current token

          # Then validate rules
          transition.validate_rules(token, @rules)

          # Execute actions first
          transition.execute_actions(token)

          # Finally update state
          token.state = transition.to_state
          token.record_transition(transition_name, old_state, token.state)

          @current_token = nil  # Clear current token
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
end
