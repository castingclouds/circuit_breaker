require_relative '../lib/petri_workflow'
require_relative '../lib/petri_workflow/nats_executor'

# Create a new Petri Net for an approval workflow
net = PetriWorkflow::PetriNet.new

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
executor = PetriWorkflow::NatsExecutor.new

# Start the workflow
workflow_id = executor.create_workflow(net)
puts "Created workflow: #{workflow_id}"

# Add initial token
executor.add_token('document_submitted', { document_id: '123', user: 'john.doe' })

# Example of chaining workflows
next_workflow_config = {
  'petri_net' => PetriWorkflow::PetriNet.new.tap do |petri_net|
    petri_net.add_place('notification_pending')
    petri_net.add_place('notification_sent')
    petri_net.add_transition('send_notification')
    petri_net.connect('notification_pending', 'send_notification')
    petri_net.connect('send_notification', 'notification_sent')
  end,
  'initial_place' => 'notification_pending'
}

# When the first workflow completes, trigger the next one
executor.complete_workflow(next_workflow_config)
