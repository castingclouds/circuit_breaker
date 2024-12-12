require_relative 'base_function'

module CircuitBreaker
  module Functions
    class NotificationFunction < BaseFunction
      def initialize
        super
        subscribe('function.function_notification_pending')
      end
      
      protected
      
      def handle_message(msg)
        data = JSON.parse(msg.data)
        workflow_id = data['workflow_id']
        
        # Send notification
        send_notification(data)
        
        # Publish completion event
        publish_event(workflow_id, 'transition_fired', {
          transition: 'send_notification',
          notification_sent: true,
          recipient: data['recipient']
        })
      end
      
      private
      
      def send_notification(data)
        # In a real implementation, this would:
        # - Format the notification based on workflow state
        # - Send email/SMS/Slack message
        # - Record delivery status
        sleep(1) # Simulate sending notification
        
        puts "Notification sent for workflow: #{data['workflow_id']}"
      end
    end
  end
end

# Start the function if this file is run directly
if __FILE__ == $0
  puts "Starting Notification Function..."
  NotificationFunction.new
  puts "Notification Function ready for messages"
  loop { sleep 1 }
end
