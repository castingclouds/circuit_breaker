module CircuitBreaker
  module Executors
    module DSL
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def executor_config(&block)
          @config_builder ||= ConfigBuilder.new
          @config_builder.instance_eval(&block) if block_given?
          @config_builder
        end

        def get_config
          @config_builder&.to_h || {}
        end
      end

      class ConfigBuilder
        def initialize
          @config = {
            parameters: {},
            validations: [],
            before_execute: [],
            after_execute: []
          }
        end

        def parameter(name, type: nil, required: false, default: nil, description: nil)
          @config[:parameters][name] = {
            type: type,
            required: required,
            default: default,
            description: description
          }
        end

        def validate(&block)
          @config[:validations] << block
        end

        def before_execute(&block)
          @config[:before_execute] << block
        end

        def after_execute(&block)
          @config[:after_execute] << block
        end

        def to_h
          @config
        end
      end

      def validate_parameters
        config = self.class.get_config
        parameters = config[:parameters]

        parameters.each do |name, opts|
          if opts[:required] && !@context.key?(name)
            raise ArgumentError, "Missing required parameter: #{name}"
          end

          if @context.key?(name)
            validate_parameter_type(name, @context[name], opts[:type]) if opts[:type]
          elsif opts[:default]
            @context[name] = opts[:default]
          end
        end

        config[:validations].each do |validation|
          instance_exec(@context, &validation)
        end
      end

      private

      def validate_parameter_type(name, value, expected_type)
        case expected_type
        when :string
          raise TypeError, "#{name} must be a String" unless value.is_a?(String)
        when :integer
          raise TypeError, "#{name} must be an Integer" unless value.is_a?(Integer)
        when :array
          raise TypeError, "#{name} must be an Array" unless value.is_a?(Array)
        when :hash
          raise TypeError, "#{name} must be a Hash" unless value.is_a?(Hash)
        when :boolean
          unless [true, false].include?(value)
            raise TypeError, "#{name} must be a Boolean"
          end
        end
      end
    end
  end
end
