require_relative '../../lib/circuit_breaker'
require_relative '../../lib/circuit_breaker/nats_executor'
require_relative '../../lib/circuit_breaker/workflow_dsl'

# Define the workflow using our DSL
wf = CircuitBreaker::WorkflowDSL.define do
  # Define all possible states
  states :backlog, :sprint_planning, :sprint_backlog,
        :in_progress, :in_review, :testing, :done

  # Define special states that can be entered from multiple places
  special_states :blocked

  # Define the main flow of the workflow
  flow from: :backlog,         to: :sprint_planning,  via: :move_to_sprint
  flow from: :sprint_planning, to: :sprint_backlog,   via: :plan_issue
  flow from: :sprint_backlog,  to: :in_progress,      via: :start_work
  flow from: :in_progress,     to: :in_review,        via: :submit_for_review
  flow from: :in_review,       to: :testing,          via: :approve_review
  flow from: :testing,         to: :done,             via: :pass_testing

  # Define reverse flows (when work needs to go back)
  flow from: :in_review,       to: :in_progress,      via: :reject_review
  flow from: :testing,         to: :in_progress,      via: :fail_testing

  # Define blocking flows that can happen from multiple states
  multi_flow from: [:sprint_backlog, :in_progress, :in_review, :testing],
            to: :blocked,
            via: :block_issue

  # Define unblocking flows that can go back to multiple states
  multi_flow from: :blocked,
            to_states: [:sprint_backlog, :in_progress, :in_review, :testing],
            via: :unblock_issue
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
