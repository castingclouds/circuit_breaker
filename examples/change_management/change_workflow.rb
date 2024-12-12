require_relative '../../lib/circuit_breaker'
require_relative '../../lib/circuit_breaker/nats_executor'

# Create a new Workflow for change management
wf = CircuitBreaker::Workflow.new

# Define places (states) for the issue workflow
wf.add_place('backlog')
wf.add_place('sprint_planning')
wf.add_place('sprint_backlog')
wf.add_place('in_progress')
wf.add_place('in_review')
wf.add_place('testing')
wf.add_place('done')
wf.add_place('blocked')

# Define transitions between states
wf.add_transition('move_to_sprint')      # From backlog to sprint planning
wf.add_transition('plan_issue')          # From sprint planning to sprint backlog
wf.add_transition('start_work')          # From sprint backlog to in progress
wf.add_transition('submit_for_review')   # From in progress to in review
wf.add_transition('approve_review')      # From in review to testing
wf.add_transition('reject_review')       # From in review back to in progress
wf.add_transition('pass_testing')        # From testing to done
wf.add_transition('fail_testing')        # From testing back to in progress
wf.add_transition('block_issue')         # From any state to blocked
wf.add_transition('unblock_issue')       # From blocked back to previous state

# Connect places and transitions
wf.connect('backlog', 'move_to_sprint')
wf.connect('move_to_sprint', 'sprint_planning')
wf.connect('sprint_planning', 'plan_issue')
wf.connect('plan_issue', 'sprint_backlog')
wf.connect('sprint_backlog', 'start_work')
wf.connect('start_work', 'in_progress')
wf.connect('in_progress', 'submit_for_review')
wf.connect('submit_for_review', 'in_review')
wf.connect('in_review', 'approve_review')
wf.connect('approve_review', 'testing')
wf.connect('in_review', 'reject_review')
wf.connect('reject_review', 'in_progress')
wf.connect('testing', 'pass_testing')
wf.connect('pass_testing', 'done')
wf.connect('testing', 'fail_testing')
wf.connect('fail_testing', 'in_progress')

# Connect blocking transitions (can happen from multiple states)
['sprint_backlog', 'in_progress', 'in_review', 'testing'].each do |place|
  wf.connect(place, 'block_issue')
  wf.connect('block_issue', 'blocked')
  wf.connect('blocked', 'unblock_issue')
  wf.connect('unblock_issue', place)
end

# Create NATS executor
executor = CircuitBreaker::NatsExecutor.new

# Start the workflow
workflow_id = executor.create_workflow(wf)
puts "Created change management workflow: #{workflow_id}"

# Example: Create a new issue and move it through the workflow
issue_data = {
  id: 'PROJ-123',
  title: 'Implement new feature X',
  description: 'Add support for feature X to improve user experience',
  assignee: 'john.doe',
  priority: 'high'
}

# Add initial token (create issue in backlog)
puts "\nCreating new issue in backlog..."
executor.add_token('backlog', issue_data)

# Simulate moving the issue through the workflow
sleep(1) # Simulate some time passing

puts "\nMoving issue to sprint planning..."
executor.fire_transition('move_to_sprint')
sleep(1)

puts "\nPlanning issue for current sprint..."
executor.fire_transition('plan_issue')
sleep(1)

puts "\nStarting work on the issue..."
executor.fire_transition('start_work')
sleep(1)

puts "\nSubmitting work for review..."
executor.fire_transition('submit_for_review')
sleep(1)

puts "\nApproving review..."
executor.fire_transition('approve_review')
sleep(1)

puts "\nTesting passed..."
executor.fire_transition('pass_testing')
sleep(1)

puts "\nWorkflow completed - issue is done!"
