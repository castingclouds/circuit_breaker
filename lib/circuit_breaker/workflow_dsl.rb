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
      include Validators

      attr_reader :states, :transitions, :before_flows, :rules

      def initialize(rules = nil)
        @states = []
        @transitions = {}
        @before_flows = []
        @rules = rules || RulesEngine::DSL.define
        @validators = ValidatorChain.new
      end

      def states(*states)
        @states = states
        self
      end

      def flow(transition)
        if transition.is_a?(StateTransition)
          @states |= [transition.from_state, transition.to_state]
          StateTransitionBuilder.new(self, transition)
        else
          from, to = case transition
          when Hash
            transition.first
          when String
            transition.split(">>").map(&:strip).map(&:to_sym)
          else
            [transition.instance_variable_get(:@from_state), transition.instance_variable_get(:@to_state)]
          end
          @states |= [from, to]
          StateTransitionBuilder.new(self, StateTransition.new(from, to))
        end
      end

      def before_flow(&block)
        @before_flows << block
      end

      def transition(name, from:, to:)
        @current_name = name
        @transitions[name] = { from: from, to: to }
        self
      end

      def validate(*field_names)
        raise "No current transition name" unless @current_name
        @transitions[@current_name][:guard] = ->(token) { @validators.chain(token).validate(*field_names).valid? }
        @transitions[@current_name][:validations] = field_names
        self
      end

      def validate_any(*field_names)
        raise "No current transition name" unless @current_name
        @transitions[@current_name][:guard] = ->(token) { @validators.chain(token).or_validate(*field_names).valid? }
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

      def policy(options)
        raise "No current transition name" unless @current_name
        
        @transitions[@current_name][:guard] = ->(token) {
          begin
            validations_result = true
            rules_result = true

            if options[:validations]
              validations_result = case options[:validations]
              when Array
                @validators.chain(token).validate(*options[:validations]).valid?
              when Hash
                options[:validations].all? do |key, fields|
                  case key
                  when :any
                    @validators.chain(token).or_validate(*fields).valid?
                  when :all
                    @validators.chain(token).validate(*fields).valid?
                  else
                    raise "Unknown validation type: #{key}"
                  end
                end
              end
            end

            if options[:rules]
              rules_result = case options[:rules]
              when Array
                options[:rules].all? { |rule| @rules.evaluate(rule, token) }
              when Hash
                all_rules_result = true
                any_rules_result = true

                if options[:rules][:all]
                  all_rules_result = options[:rules][:all].all? do |rule|
                    begin
                      result = @rules.evaluate(rule, token)
                      puts "ALL rule '#{rule}' evaluated to #{result}"
                      result
                    rescue StandardError => e
                      puts "Rule '#{rule}' failed: #{e.message}"
                      raise
                    end
                  end
                end

                if options[:rules][:any]
                  any_rules_result = options[:rules][:any].any? do |rule|
                    begin
                      result = @rules.evaluate(rule, token)
                      puts "ANY rule '#{rule}' evaluated to #{result}"
                      result
                    rescue StandardError => e
                      puts "Rule '#{rule}' failed: #{e.message}"
                      false
                    end
                  end
                end

                all_rules_result && (options[:rules][:any].nil? || any_rules_result)
              end
            end

            result = validations_result && rules_result
            puts "Policy evaluation: validations=#{validations_result}, rules=#{rules_result}, final=#{result}"
            result
          rescue StandardError => e
            puts "Policy evaluation failed: #{e.message}"
            raise
          end
        }

        @transitions[@current_name][:policy] = options
        self
      end

      def build_workflow
        workflow = Workflow.new(
          states: @states,
          transitions: @transitions,
          before_flows: @before_flows,
          rules: @rules
        )

        # Convert policy guards into workflow rules
        @transitions.each do |name, transition|
          if transition[:policy]
            # Convert policy validations into rules
            if transition[:policy][:validations]
              case transition[:policy][:validations]
              when Array
                workflow.add_rule(name, ->(token) {
                  @validators.chain(token).validate(*transition[:policy][:validations]).valid?
                })
              when Hash
                workflow.add_rule(name, ->(token) {
                  transition[:policy][:validations].all? do |key, fields|
                    case key
                    when :any
                      @validators.chain(token).or_validate(*fields).valid?
                    when :all
                      @validators.chain(token).validate(*fields).valid?
                    else
                      raise "Unknown validation type: #{key}"
                    end
                  end
                })
              end
            end

            # Convert policy rules into workflow rules
            if transition[:policy][:rules]
              case transition[:policy][:rules]
              when Array
                transition[:policy][:rules].each do |rule|
                  workflow.add_rule(name, rule)
                end
              when Hash
                workflow.add_rule(name, ->(token) {
                  all_rules_result = true
                  any_rules_result = true

                  if transition[:policy][:rules][:all]
                    all_rules_result = transition[:policy][:rules][:all].all? do |rule|
                      @rules.evaluate(rule, token)
                    end
                  end

                  if transition[:policy][:rules][:any]
                    any_rules_result = transition[:policy][:rules][:any].any? do |rule|
                      @rules.evaluate(rule, token)
                    end
                  end

                  all_rules_result && (transition[:policy][:rules][:any].nil? || any_rules_result)
                })
              end
            end
          end
        end

        workflow.extend(PrettyPrint)
        workflow
      end
    end

    def self.define(rules: nil, &block)
      builder = WorkflowBuilder.new(rules)
      builder.instance_eval(&block)
      builder.build_workflow
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
              if transition[:policy]
                puts "      Policy:"
                if transition[:policy][:validations]
                  puts "        Validations:"
                  case transition[:policy][:validations]
                  when Array
                    puts "          All: #{transition[:policy][:validations].join(', ')}"
                  when Hash
                    transition[:policy][:validations].each do |key, fields|
                      puts "          #{key.to_s.capitalize}: #{fields.join(', ')}"
                    end
                  end
                end
                if transition[:policy][:rules]
                  puts "        Rules:"
                  case transition[:policy][:rules]
                  when Array
                    puts "          All: #{transition[:policy][:rules].join(', ')}"
                  when Hash
                    transition[:policy][:rules].each do |key, rules|
                      puts "          #{key.to_s.capitalize}: #{rules.join(', ')}"
                    end
                  end
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
