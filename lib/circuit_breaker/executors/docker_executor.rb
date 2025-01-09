require_relative 'base_executor'

module CircuitBreaker
  module Executors
    class DockerExecutor < BaseExecutor
      executor_config do
        parameter :image,
          type: :string,
          required: true,
          description: 'Docker image to run'

        parameter :command,
          type: :string,
          description: 'Command to run in the container'

        parameter :environment,
          type: :hash,
          default: {},
          description: 'Environment variables to set in the container'

        parameter :volumes,
          type: :array,
          default: [],
          description: 'Volumes to mount in the container'

        validate do |context|
          if context[:command] && !context[:command].is_a?(String)
            raise ArgumentError, 'Command must be a string'
          end
        end

        before_execute do |context|
          puts "Preparing to run Docker container with image: #{context[:image]}"
        end

        after_execute do |result|
          puts "Docker container execution completed with status: #{result[:status]}"
        end
      end

      protected

      def execute_internal
        # Implementation for Docker execution would go here
        # This would typically involve running a Docker container
        @result = {
          image: @context[:image],
          command: @context[:command],
          environment: @context[:environment],
          volumes: @context[:volumes],
          status: 'completed'
        }
      end
    end
  end
end
