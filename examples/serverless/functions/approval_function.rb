require_relative 'base_function'

module CircuitBreaker
  module Functions
    class ApprovalFunction < BaseFunction
      def initialize
        super
        subscribe('function.function_reviewed')
      end
      
      protected
      
      def handle_message(msg)
        data = JSON.parse(msg.data)
        workflow_id = data['workflow_id']
        
        # Get the review result from the previous state
        review_result = get_review_result(workflow_id)
        
        # Determine which transition to fire based on review
        transition = review_result == 'approved' ? 'approve' : 'reject'
        
        # Publish the transition event
        publish_event(workflow_id, 'transition_fired', {
          transition: transition,
          approver: 'auto_approver',
          review_result: review_result
        })
      end
      
      private
      
      def get_review_result(workflow_id)
        # In a real implementation, we would:
        # 1. Query the workflow state from NATS JetStream
        # 2. Find the most recent review result
        # 3. Apply any additional business rules
        
        # For demo, we'll use the review result from the review function
        # You could implement this by reading from the WORKFLOW_STATES stream
        'approved' # Simplified for demo
      end
    end
  end
end

# Start the function if this file is run directly
if __FILE__ == $0
  puts "Starting Approval Function..."
  ApprovalFunction.new
  puts "Approval Function ready for messages"
  loop { sleep 1 }
end
