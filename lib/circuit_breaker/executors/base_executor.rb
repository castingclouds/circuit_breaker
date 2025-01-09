require_relative 'dsl'

module CircuitBreaker
  module Executors
    class BaseExecutor
      include DSL

      attr_reader :context, :result

      def initialize(context = {})
        @context = context
        @result = nil
        validate_parameters
      end

      def execute
        run_before_hooks
        execute_internal
        run_after_hooks
        @result
      end

      protected

      def execute_internal
        raise NotImplementedError, "#{self.class} must implement #execute_internal"
      end

      private

      def run_before_hooks
        self.class.get_config[:before_execute].each do |hook|
          instance_exec(@context, &hook)
        end
      end

      def run_after_hooks
        self.class.get_config[:after_execute].each do |hook|
          instance_exec(@result, &hook)
        end
      end

      def to_h
        {
          executor: self.class.name,
          context: @context,
          result: @result
        }
      end

      def to_json(*args)
        to_h.to_json(*args)
      end
    end
  end
end
