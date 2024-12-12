require_relative '../../../examples/serverless/functions/base_function'

module CircuitBreaker
  module Functions
    class SprintPlanningFunction < BaseFunction
      def initialize
        super
        subscribe('function.sprint_planning')
      end
      
      protected
      
      def handle_message(msg)
        data = JSON.parse(msg.data)
        workflow_id = data['workflow_id']
        issue = data['issue']
        
        # Simulate sprint planning logic
        plan_issue(issue)
        
        # Publish completion event
        publish_event(workflow_id, 'transition_fired', {
          transition: 'plan_issue',
          issue: issue,
          sprint: current_sprint,
          story_points: estimate_story_points(issue)
        })
      end
      
      private
      
      def plan_issue(issue)
        # In a real implementation, this would:
        # - Assign the issue to the current sprint
        # - Set story points/estimate
        # - Update priority if needed
        # - Set sprint goals
        sleep(1) # Simulate planning work
        puts "Planned issue #{issue['id']} for current sprint"
      end
      
      def current_sprint
        {
          id: 'SPRINT-42',
          start_date: (Time.now + 86400).iso8601, # Tomorrow
          end_date: (Time.now + 1209600).iso8601  # 2 weeks from now
        }
      end
      
      def estimate_story_points(issue)
        # Simulate story point estimation
        # In reality, this would be based on complexity, effort, etc.
        rand(1..8)
      end
    end
  end
end

# Start the function if this file is run directly
if __FILE__ == $0
  puts "Starting Sprint Planning Function..."
  CircuitBreaker::Functions::SprintPlanningFunction.new
  puts "Sprint Planning Function ready for messages"
  loop { sleep 1 }
end
