module CircuitBreaker
  class Logger
    class << self
      attr_accessor :debug_enabled

      def debug(message)
        puts "[DEBUG] #{message}" if debug_enabled
      end

      def info(message)
        puts message
      end

      def error(message)
        puts "[ERROR] #{message}"
      end
    end
  end
end
