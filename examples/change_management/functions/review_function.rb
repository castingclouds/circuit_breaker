require_relative '../../../examples/serverless/functions/base_function'

module CircuitBreaker
  module Functions
    class ReviewFunction < BaseFunction
      def initialize
        super
        subscribe('function.review_requested')
      end
      
      protected
      
      def handle_message(msg)
        data = JSON.parse(msg.data)
        workflow_id = data['workflow_id']
        issue = data['issue']
        
        # Simulate code review process
        review_result = perform_review(issue)
        
        # Determine which transition to fire based on review result
        transition = review_result[:approved] ? 'approve_review' : 'reject_review'
        
        # Publish completion event
        publish_event(workflow_id, 'transition_fired', {
          transition: transition,
          issue: issue,
          review_result: review_result
        })
      end
      
      private
      
      def perform_review(issue)
        # In a real implementation, this would:
        # - Check code quality metrics
        # - Run automated tests
        # - Check review comments
        # - Verify review approvals
        sleep(2) # Simulate review process
        
        {
          approved: rand > 0.3, # 70% chance of approval
          reviewer: 'jane.smith',
          comments: sample_review_comments,
          metrics: {
            code_coverage: rand(80..100),
            lint_issues: rand(0..5),
            security_score: rand(85..100)
          }
        }
      end
      
      def sample_review_comments
        [
          'Good separation of concerns',
          'Consider adding more test coverage',
          'Documentation could be improved',
          'Performance looks good'
        ].sample(2)
      end
    end
  end
end

# Start the function if this file is run directly
if __FILE__ == $0
  puts "Starting Review Function..."
  CircuitBreaker::Functions::ReviewFunction.new
  puts "Review Function ready for messages"
  loop { sleep 1 }
end
