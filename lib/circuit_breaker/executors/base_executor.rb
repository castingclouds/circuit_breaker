module CircuitBreaker
  module Executors
    class BaseExecutor
      attr_reader :context, :result

      def initialize(context = {})
        @context = context
        @result = nil
      end

      def execute
        raise NotImplementedError, "#{self.class} must implement #execute"
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
