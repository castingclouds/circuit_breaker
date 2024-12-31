# Circuit Breaker

A Ruby implementation of workflow orchestration using Petri Nets, designed as an alternative approach to Argo Workflows' DAG-based system. This project explores modeling workflows through states and transitions rather than tasks, offering a more natural way to represent complex state-based processes.

## Motivation

Traditional workflow engines like Argo Workflows use Directed Acyclic Graphs (DAGs) to model task dependencies. While DAGs excel at representing task sequences and dependencies, they can become complex when modeling state-based systems where:

- Multiple conditions affect state transitions
- States can have multiple active tokens (parallel executions)
- Complex synchronization patterns are needed
- State transitions depend on runtime conditions

Petri Nets provide a formal mathematical model that naturally represents these concepts through:
- Places (states)
- Transitions (state changes)
- Tokens (current state markers)
- Arcs (flow relationships)

## Core Components

### 1. Places (States)
Places represent possible states in your workflow:
```ruby
wf.add_place('draft')
wf.add_place('pending_review')
wf.add_place('approved')
```

### 2. Transitions
Transitions represent actions that change states:
```ruby
wf.add_transition('submit')
wf.add_transition('approve')
```

### 3. Tokens
Tokens mark the current state(s) of your workflow:
```ruby
wf.add_tokens('draft')  # Start workflow in draft state
```

### 4. Arcs
Arcs connect places to transitions and vice versa:
```ruby
wf.connect('draft', 'submit')        # Place to transition
wf.connect('submit', 'under_review') # Transition to place
```

### 5. Guard Conditions
Guard conditions control when transitions can fire:
```ruby
approve_transition.set_guard do
  # Check if user has permission to approve
  user.has_permission?(:approve)
end
```

## Key Features

1. **State-Based Modeling**
   - Natural representation of system states
   - Clear visualization of possible state transitions
   - Support for parallel state activations

2. **Thread-Safe Operations**
   - Atomic token operations
   - Safe concurrent execution
   - Mutex-protected state changes

3. **Rich Flow Control**
   - Weighted arcs for complex flow patterns
   - Guard conditions for conditional transitions
   - Token-based parallel execution

4. **Formal Semantics**
   - Based on Petri Net mathematics
   - Clear execution rules
   - Analyzable properties

## Understanding Petri Nets vs DAGs

### Directed Acyclic Graphs (DAGs)
In Argo Workflows, workflows are modeled as DAGs where:
- Nodes represent **tasks** to be executed
- Edges represent **dependencies** between tasks
- Execution flows from start to end nodes
- Each task runs exactly once
- Tasks can run in parallel if their dependencies are met

For example, an approval workflow in Argo might look like:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Workflow
spec:
  entrypoint: approval-dag
  templates:
  - name: approval-dag
    dag:
      tasks:
      - name: submit
        template: submit-template
      - name: review
        template: review-template
        dependencies: [submit]
      - name: approve
        template: approve-template
        dependencies: [review]
      - name: reject
        template: reject-template
        dependencies: [review]
```

### Petri Nets
In **Circuit Breaker**, workflows are modeled as Petri Nets where:
- Places represent **states** of the system
- Transitions represent **actions** that change states
- Tokens represent **current state markers**
- Arcs connect places to transitions and vice versa
- Multiple tokens can exist simultaneously
- States can be active multiple times
- Transitions fire when their input places have tokens and guards are satisfied

The same approval workflow in Petri Nets looks quite different:
```ruby
# States (Places)
wf.add_place('draft')
wf.add_place('pending_review')
wf.add_place('reviewed')
wf.add_place('approved')
wf.add_place('rejected')

# Actions (Transitions)
wf.add_transition('submit')
wf.add_transition('review')
wf.add_transition('approve')
wf.add_transition('reject')

# Flow (Arcs)
wf.connect('draft', 'submit')
wf.connect('submit', 'pending_review')
wf.connect('pending_review', 'review')
wf.connect('review', 'reviewed')
wf.connect('reviewed', 'approve')
wf.connect('approve', 'approved')
wf.connect('reviewed', 'reject')
wf.connect('reject', 'rejected')
```

### Key Differences

1. **State vs Task Focus**
   - DAG: Focuses on what tasks need to be done
   - Petri Net: Focuses on what states the system can be in

2. **Execution Model**
   - DAG: Tasks execute once when dependencies are met
   - Petri Net: States can be entered/exited multiple times as tokens flow

3. **Parallelism**
   - DAG: Tasks run in parallel if dependencies allow
   - Petri Net: Multiple tokens can exist in different places simultaneously

4. **Decision Making**
   - DAG: Uses conditional tasks and branches
   - Petri Net: Uses guard conditions on transitions and token flow

5. **Reentrance**
   - DAG: Tasks typically execute exactly once
   - Petri Net: Places can receive tokens multiple times

## Using the Workflow DSL

The Circuit Breaker provides a clean DSL for defining workflows:

```ruby
workflow = CircuitBreaker::WorkflowDSL.define do
  # Configure workflow settings
  for_object 'Document'
  
  # Define all possible states
  states :draft, :pending_review, :reviewed, :approved, :rejected
  
  # Define the flows with their validations
  flow(:draft >> :pending_review).configure do
    via(:submit)
    requires [:title, :content]
    
    validate do |doc|
      doc.title.to_s.length >= 3 && doc.content.to_s.length >= 10
    end
  end
  
  flow(:pending_review >> :reviewed).configure do
    via(:review)
    requires [:reviewer_comments]
    
    validate do |doc|
      !doc.reviewer_id.nil? && !doc.reviewer_id.empty?
    end
  end
  
  flow(:reviewed >> :approved).configure do
    via(:approve)
    requires [:approver_id]
    
    guard do |metadata|
      rules_engine.evaluate('can_approve', metadata)
    end
  end
end
```

### DSL Components

1. **State Definition**
   ```ruby
   states :draft, :pending_review, :reviewed, :approved, :rejected
   ```

2. **Flow Definition**
   ```ruby
   flow(:state1 >> :state2).configure do
     via(:action_name)
   end
   ```

3. **Requirements**
   ```ruby
   flow(:draft >> :pending_review).configure do
     via(:submit)
     requires [:title, :content]
   end
   ```

4. **Validations**
   ```ruby
   flow(:draft >> :pending_review).configure do
     via(:submit)
     validate do |doc|
       doc.title.to_s.length >= 3
     end
   end
   ```

5. **Guard Conditions**
   ```ruby
   flow(:reviewed >> :approved).configure do
     via(:approve)
     guard do |metadata|
       rules_engine.evaluate('can_approve', metadata)
     end
   end
   ```

## Example Walkthrough: Approval Workflow

Let's walk through how our example approval workflow works using Petri Nets:

### 1. Initial State
```ruby
wf.add_tokens('draft')
puts wf.marking
# => {"draft"=>1, "pending_review"=>0, "reviewed"=>0, "approved"=>0, "rejected"=>0}
```
- System starts with one token in the 'draft' state
- All other states are empty

### 2. Submit Transition
```ruby
wf.step  # Fires 'submit' transition
puts wf.marking
# => {"draft"=>0, "pending_review"=>1, "reviewed"=>0, "approved"=>0, "rejected"=>0}
```
- Token moves from 'draft' to 'pending_review'
- 'submit' transition consumes token from 'draft'
- 'submit' transition produces token in 'pending_review'

### 3. Review Transition
```ruby
wf.step  # Fires 'review' transition
puts wf.marking
# => {"draft"=>0, "pending_review"=>0, "reviewed"=>1, "approved"=>0, "rejected"=>0}
```
- Token moves from 'pending_review' to 'reviewed'
- System is now ready for approval decision

### 4. Approval Decision
```ruby
# Guard condition determines which transition can fire
approve.set_guard { true }   # Always approve
reject.set_guard { false }   # Never reject

wf.step  # Fires 'approve' transition
puts wf.marking
# => {"draft"=>0, "pending_review"=>0, "reviewed"=>0, "approved"=>1, "rejected"=>0}
```
- Token moves from 'reviewed' to 'approved'
- Guard conditions determine which transition fires
- Only one transition can fire, preventing double-approval

### Advanced Patterns

Petri Nets excel at modeling complex patterns that are difficult with DAGs:

1. **Reentrant Workflows**
```ruby
# Allow resubmission from rejected state
wf.connect('rejected', 'submit')
```

2. **Parallel Reviews**
```ruby
# Add multiple tokens for parallel reviews
wf.add_tokens('pending_review', 3)
```

3. **Synchronization Points**
```ruby
# Require multiple approvals
approve.set_guard do
  reviewed_place.token_count >= 3  # Need 3 review tokens
end
```

4. **State-Based Conditions**
```ruby
# Conditional transitions based on system state
approve.set_guard do
  reviewed_place.token_count > 0 && 
    user.has_permission?(:approve)
end
```

These patterns demonstrate how Petri Nets can naturally model complex state-based workflows that would be cumbersome to represent with DAGs.

## Example Usage

```ruby
require_relative 'lib/circuit_breaker'

# Create a new Petri Net
wf = CircuitBreaker::Workflow.new

# Define states (places)
['draft', 'pending_review', 'reviewed', 'approved', 'rejected'].each do |place|
  wf.add_place(place)
end

# Define state transitions
['submit', 'review', 'approve', 'reject'].each do |transition|
  wf.add_transition(transition)
end

# Connect states and transitions
wf.connect('draft', 'submit')
wf.connect('submit', 'pending_review')
wf.connect('pending_review', 'review')
wf.connect('review', 'reviewed')

# Add guard conditions
approve = wf.transitions['approve']
approve.set_guard do
  # Add your approval logic here
  true
end

# Start the workflow
wf.add_tokens('draft')

# Run the workflow
wf.run_to_completion
```

## Differences from Argo Workflows

1. **State-Centric vs Task-Centric**
   - Argo: Models workflows as task dependencies
   - Petri Workflows: Models workflows as state transitions

2. **Execution Model**
   - Argo: Sequential task execution based on DAG
   - Petri Workflows: Concurrent state transitions based on token availability

3. **Flow Control**
   - Argo: Task-level conditions and dependencies
   - Petri Workflows: State-based transitions with guard conditions

4. **Parallelism**
   - Argo: Parallel task execution
   - Petri Workflows: Multiple active states with token-based synchronization

## Installation

1. Clone the repository:
```bash
git clone https://github.com/castingclouds/circuit_breaker.git
```

2. Install dependencies:
```bash
bundle install
```

## Running the Examples

```bash
ruby examples/simple_workflow.rb
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
