module CircuitBreaker
  module WorkflowDSL
    def self.define(&block)
      Builder.new.tap do |builder|
        builder.instance_eval(&block)
      end.build
    end

    class Builder
      def initialize
        @workflow = CircuitBreaker::Workflow.new
        @states = []
        @special_states = []
        @transitions = []
      end

      def build
        # Add all states
        (@states + @special_states).each do |state|
          @workflow.add_place(state)
        end

        # Add all transitions and connections
        @transitions.each do |transition|
          @workflow.add_transition(transition[:name])
          
          if transition[:from].is_a?(Array)
            transition[:from].each do |from_state|
              @workflow.connect(from_state, transition[:name])
              @workflow.connect(transition[:name], transition[:to])
            end
          elsif transition[:to].is_a?(Array)
            transition[:to].each do |to_state|
              @workflow.connect(transition[:from], transition[:name])
              @workflow.connect(transition[:name], to_state)
            end
          else
            @workflow.connect(transition[:from], transition[:name])
            @workflow.connect(transition[:name], transition[:to])
          end
        end

        @workflow
      end

      def states(*names)
        @states.concat(names)
      end

      def special_states(*names)
        @special_states.concat(names)
      end

      def transition(name, options = {})
        @transitions << { name: name }.merge(options)
      end

      def flow(from:, to:, via:)
        transition(via, from: from, to: to)
      end

      def multi_flow(options = {})
        name = options[:via]
        if options[:from].is_a?(Array)
          transition(name, from: options[:from], to: options[:to])
        else
          transition(name, from: options[:from], to: options[:to_states])
        end
      end
    end
  end
end
