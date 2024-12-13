require_relative '../../lib/circuit_breaker'
require_relative '../../lib/circuit_breaker/nats_executor'

# Create a new Workflow for an approval workflow
wf = CircuitBreaker::Workflow.new

# Define places (states)
wf.add_place('document_submitted')
wf.add_place('pending_review')
wf.add_place('reviewed')
wf.add_place('approved')
wf.add_place('rejected')

# Define transitions
wf.add_transition('start_review')
wf.add_transition('complete_review')
wf.add_transition('approve')
wf.add_transition('reject')

# Connect places and transitions
wf.connect('document_submitted', 'start_review')
wf.connect('start_review', 'pending_review')
wf.connect('pending_review', 'complete_review')
wf.connect('complete_review', 'reviewed')
wf.connect('reviewed', 'approve')
wf.connect('approve', 'approved')
wf.connect('reviewed', 'reject')
wf.connect('reject', 'rejected')

# Create NATS executor
executor = CircuitBreaker::NatsExecutor.new

# Start the workflow
workflow_id = executor.create_workflow(wf)
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
