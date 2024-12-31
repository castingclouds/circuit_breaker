module CircuitBreaker
  module WorkflowDSL
    class ::Symbol
      def >>(other)
        StateTransition.new(self, other)
      end
    end

    def self.define(&block)
      builder = WorkflowBuilder.new
      builder.instance_eval(&block)
      builder.build_workflow
    end

    class ValidationBuilder
      def initialize(builder)
        @builder = builder
        @validations = []
      end

      def title
        FieldValidator.new(:title, @validations)
      end

      def content
        FieldValidator.new(:content, @validations)
      end

      def tags
        FieldValidator.new(:tags, @validations)
      end

      def priority
        FieldValidator.new(:priority, @validations)
      end

      def validations
        @validations
      end
    end

    class FieldValidator
      def initialize(field, validations)
        @field = field
        @validations = validations
      end

      def must_be_present
        @validations << {
          field: @field,
          type: :presence,
          validate: ->(value) { !value.nil? && !value.to_s.empty? }
        }
        self
      end

      def must_start_with_capital
        @validations << {
          field: @field,
          type: :format,
          validate: ->(value) { value.to_s.match?(/^[A-Z]/) }
        }
        self
      end

      def minimum_length(length)
        @validations << {
          field: @field,
          type: :length,
          validate: ->(value) { value.to_s.length >= length }
        }
        self
      end

      def must_match(pattern)
        @validations << {
          field: @field,
          type: :format,
          validate: ->(value) { 
            value.is_a?(Array) ? value.all? { |v| v.to_s.match?(pattern) } : value.to_s.match?(pattern)
          }
        }
        self
      end

      def must_be_one_of(values)
        @validations << {
          field: @field,
          type: :inclusion,
          validate: ->(value) { values.include?(value.to_s.downcase) }
        }
        self
      end
    end

    class WorkflowBuilder
      include Validators

      def initialize
        @states = []
        @transitions = {}
        @before_flows = []
        @rules = []
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

      def validates(*fields)
        raise "No current transition name" unless @current_name
        @transitions[@current_name][:required_fields] ||= []
        @transitions[@current_name][:required_fields].concat(fields)
        self
      end
      alias_method :needs, :validates

      def rule(*rule_names)
        raise "No current transition name" unless @current_name
        @transitions[@current_name][:rules] ||= []
        @transitions[@current_name][:rules].concat(rule_names)
        self
      end
      alias_method :rules, :rule

      def before_flow(&block)
        @before_flows << block
        self
      end

      def validate_with(validators)
        @validators = validators.validators
        before_flow do |token|
          @validators.each do |field, validator|
            result = validator.call(token)
            case result
            when ValidationResult
              unless result.valid?
                raise Token::ValidationError, "Invalid #{field}: #{result}"
              end
            when Proc
              validator_result = result.call(token)
              unless validator_result
                raise Token::ValidationError, "Invalid #{field}"
              end
            else
              raise Token::ValidationError, "Invalid validator type for #{field}"
            end
          end
        end
      end

      def build_workflow
        Workflow.new(
          states: @states,
          transitions: @transitions,
          before_flows: @before_flows,
          rules: @rules
        )
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
    end

    class Action
      def initialize(builder, from_state, to_state)
        @builder = builder
        @from_state = from_state
        @to_state = to_state
        @options = {}
      end

      def transition(name)
        @transition_name = name
        @builder._add_transition(
          from: @from_state,
          to: @to_state,
          via: name,
          options: @options
        )
        self
      end
      alias_method :via, :transition
      alias_method :named, :transition

      def validates(*fields)
        @options[:requires] = fields.flatten
        self
      end
      alias_method :requires, :validates

      def rule(rule_name)
        @options[:rule] = rule_name
        self
      end

      def when(&block)
        @options[:validate] = block
        self
      end
      alias_method :validate, :when

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
