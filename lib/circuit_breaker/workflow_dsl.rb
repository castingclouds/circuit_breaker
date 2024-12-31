module CircuitBreaker
  module WorkflowDSL
    class ::Symbol
      def >>(other)
        StateTransition.new(self, other)
      end
    end

    def self.define(&block)
      builder = Builder.new
      builder.instance_eval(&block)
      builder.build_workflow
    end

    class Builder
      attr_reader :states, :transitions, :validations, :object_type

      def initialize
        @states = []
        @transitions = []
        @validations = []
      end

      def for_object(type)
        @object_type = type
      end

      def states(*state_list)
        @states.concat(state_list)
      end

      def flow(transition)
        Action.new(self, transition.from_state, transition.to_state)
      end

      def build_workflow
        workflow = CircuitBreaker::Workflow.new
        workflow.states = @states
        
        @transitions.each do |t|
          workflow.add_transition(
            name: t[:name],
            from: t[:from],
            to: t[:to],
            requires: t[:requires],
            guard: t[:guard],
            validate: t[:validate]
          )
        end
        
        workflow
      end

      def method_missing(method_name, *args, &block)
        if @states.include?(method_name)
          flow(method_name)
        else
          super
        end
      end

      def respond_to_missing?(method_name, include_private = false)
        @states.include?(method_name) || super
      end

      def _add_transition(from:, to:, via:, options: {})
        transition = {
          name: via,
          from: from,
          to: to,
          requires: options[:requires],
          guard: options[:guard],
          validate: options[:validate]
        }

        # Add validation if provided
        if options[:validate]
          @validations << {
            state: from,
            validate: options[:validate]
          }
        end

        @transitions << transition
      end
    end

    class StateTransition
      attr_reader :from_state, :to_state

      def initialize(from_state, to_state)
        @from_state = from_state
        @to_state = to_state
      end
    end

    class Action
      def initialize(builder, from_state, to_state)
        @builder = builder
        @from_state = from_state
        @to_state = to_state
        @options = {}
      end

      def via(transition_name)
        @transition_name = transition_name
        @builder._add_transition(
          from: @from_state,
          to: @to_state,
          via: transition_name,
          options: @options
        )
        self
      end

      def requires(fields)
        @options[:requires] = fields
        self
      end

      def validate(&block)
        @options[:validate] = block
        self
      end

      def guard(&block)
        @options[:guard] = block
        self
      end
    end

    class FlowBuilder
      def initialize(builder, from_state)
        @builder = builder
        @from_state = from_state
      end

      def >>(to_state)
        @to_state = to_state
        Action.new(@builder, @from_state, @to_state)
      end

      # Keep the to method for backward compatibility
      alias_method :to, :>>
    end

    class StateFlow
      def initialize(builder, state)
        @builder = builder
        @from_state = state
      end

      def >(to_state)
        @to_state = to_state
        self
      end

      def via(transition_name, &block)
        options = {}
        
        if block_given?
          collector = OptionCollector.new
          collector.instance_eval(&block)
          options = collector.options
        end

        @builder._add_transition(
          from: @from_state,
          to: @to_state,
          via: transition_name,
          options: options
        )
      end
    end

    class OptionCollector
      attr_reader :options

      def initialize
        @options = {}
      end

      def requires(fields)
        @options[:requires] = fields
      end

      def validate(&block)
        @options[:validate] = block
      end

      def guard(&block)
        @options[:guard] = block
      end
    end
  end
end
