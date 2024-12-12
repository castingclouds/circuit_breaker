require_relative '../lib/circuit_breaker'
require_relative '../lib/circuit_breaker/nats_executor'

# Create a new Workflow for an approval workflow
net = CircuitBreaker::Workflow.new

# Define places (states)
net.add_place('document_submitted')
net.add_place('pending_review')
net.add_place('reviewed')
net.add_place('approved')
net.add_place('rejected')

# Define transitions
net.add_transition('start_review')
net.add_transition('complete_review')
net.add_transition('approve')
net.add_transition('reject')

# Connect places and transitions
net.connect('document_submitted', 'start_review')
net.connect('start_review', 'pending_review')
net.connect('pending_review', 'complete_review')
net.connect('complete_review', 'reviewed')
net.connect('reviewed', 'approve')
net.connect('approve', 'approved')
net.connect('reviewed', 'reject')
net.connect('reject', 'rejected')

# Create NATS executor
executor = CircuitBreaker::NatsExecutor.new

# Start the workflow
workflow_id = executor.create_workflow(net)
puts "Created workflow: #{workflow_id}"

# Add initial token
executor.add_token('document_submitted', { document_id: '123', user: 'john.doe' })

# Example of chaining workflows
next_workflow_config = {
  'workflow' => CircuitBreaker::Workflow.new.tap do |workflow|
    workflow.add_place('notification_pending')
    workflow.add_place('notification_sent')
    workflow.add_transition('send_notification')
    workflow.connect('notification_pending', 'send_notification')
    workflow.connect('send_notification', 'notification_sent')
  end,
  'initial_place' => 'notification_pending'
}

# When the first workflow completes, trigger the next one
executor.complete_workflow(next_workflow_config)
