require_relative '../lib/circuit_breaker'

# Create a simple approval workflow using Petri nets
wf = CircuitBreaker::Workflow.new

# Define places (states)
['draft', 'pending_review', 'reviewed', 'approved', 'rejected'].each do |place|
  wf.add_place(place)
end

# Define transitions
['submit', 'review', 'approve', 'reject'].each do |transition|
  wf.add_transition(transition)
end

# Connect places and transitions with proper flow
# draft -> submit -> pending_review
wf.connect('draft', 'submit')
wf.connect('submit', 'pending_review')

# pending_review -> review -> reviewed
wf.connect('pending_review', 'review')
wf.connect('review', 'reviewed')

# reviewed -> approve -> approved
wf.connect('reviewed', 'approve')
wf.connect('approve', 'approved')

# reviewed -> reject -> rejected
wf.connect('reviewed', 'reject')
wf.connect('reject', 'rejected')

# Add guard conditions
approve = wf.transitions['approve']
approve.set_guard do
  # Example guard condition - could check user permissions, etc.
  true
end

reject = wf.transitions['reject']
reject.set_guard do
  # Example guard condition - could check rejection criteria
  false  # For this example, always take the approve path
end

# Start the workflow
wf.add_tokens('draft')

# Run the workflow step by step
puts "Initial marking: #{wf.marking}"

# Each step should fire exactly one transition if enabled
3.times do |i|
  if wf.step
    puts "Step #{i + 1} marking: #{wf.marking}"
  else
    puts "No transitions enabled at step #{i + 1}"
    break
  end
end
