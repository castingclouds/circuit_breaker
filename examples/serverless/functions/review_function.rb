require_relative 'base_function'

module CircuitBreaker
  module Functions
    class ReviewFunction < BaseFunction
      def initialize
        super
        subscribe('function.function_pending_review')
      end
      
      protected
      
      def handle_message(msg)
        data = JSON.parse(msg.data)
        workflow_id = data['workflow_id']
        
        # Simulate review process
        review_result = perform_review(data)
        
        # Publish completion event
        publish_event(workflow_id, 'transition_fired', {
          transition: 'complete_review',
          result: review_result,
          reviewer: 'auto_reviewer'
        })
      end
      
      private
      
      def perform_review(data)
        # Simulate some review logic
        # In a real implementation, this might:
        # - Check document contents
        # - Apply business rules
        # - Call external services
        sleep(1) # Simulate work
        
        # Return approval recommendation
        rand > 0.3 ? 'approved' : 'rejected'
      end
    end
  end
end

# Start the function if this file is run directly
if __FILE__ == $0
  puts "Starting Review Function..."
  ReviewFunction.new
  puts "Review Function ready for messages"
  loop { sleep 1 }
end
