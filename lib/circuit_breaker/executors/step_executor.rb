require_relative 'base_executor'

module CircuitBreaker
  module Executors
    class StepExecutor < BaseExecutor
      def initialize(context = {})
        super
        @steps = context[:steps] || []
        @parallel = context[:parallel] || false
      end

      def execute
        results = if @parallel
          execute_parallel
        else
          execute_sequential
        end

        @result = {
          steps: results,
          status: 'completed'
        }
      end

      private

      def execute_sequential
        @steps.map do |step|
          executor = step[:executor].new(step[:context])
          executor.execute
          executor.to_h
        end
      end

      def execute_parallel
        threads = @steps.map do |step|
          Thread.new do
            executor = step[:executor].new(step[:context])
            executor.execute
            executor.to_h
          end
        end
        threads.map(&:value)
      end
    end
  end
end
