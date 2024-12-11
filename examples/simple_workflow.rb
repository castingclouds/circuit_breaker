require_relative '../lib/petri_workflow'

# Create a simple approval workflow using Petri nets
net = PetriWorkflows::PetriNet.new

# Define places (states)
['draft', 'pending_review', 'reviewed', 'approved', 'rejected'].each do |place|
  net.add_place(place)
end

# Define transitions
['submit', 'review', 'approve', 'reject'].each do |transition|
  net.add_transition(transition)
end

# Connect places and transitions with proper flow
# draft -> submit -> pending_review
net.connect('draft', 'submit')
net.connect('submit', 'pending_review')

# pending_review -> review -> reviewed
net.connect('pending_review', 'review')
net.connect('review', 'reviewed')

# reviewed -> approve -> approved
net.connect('reviewed', 'approve')
net.connect('approve', 'approved')

# reviewed -> reject -> rejected
net.connect('reviewed', 'reject')
net.connect('reject', 'rejected')

# Add guard conditions
approve = net.transitions['approve']
approve.set_guard do
  # Example guard condition - could check user permissions, etc.
  true
end

reject = net.transitions['reject']
reject.set_guard do
  # Example guard condition - could check rejection criteria
  false  # For this example, always take the approve path
end

# Start the workflow
net.add_tokens('draft')

# Run the workflow step by step
puts "Initial marking: #{net.marking}"

# Each step should fire exactly one transition if enabled
3.times do |i|
  if net.step
    puts "Step #{i + 1} marking: #{net.marking}"
  else
    puts "No transitions enabled at step #{i + 1}"
    break
  end
end
