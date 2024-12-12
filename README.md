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
net.add_place('draft')
net.add_place('pending_review')
net.add_place('approved')
```

### 2. Transitions
Transitions represent actions that change states:
```ruby
net.add_transition('submit')
net.add_transition('approve')
```

### 3. Tokens
Tokens mark the current state(s) of your workflow:
```ruby
net.add_tokens('draft')  # Start workflow in draft state
```

### 4. Arcs
Arcs connect places to transitions and vice versa:
```ruby
net.connect('draft', 'submit')        # Place to transition
net.connect('submit', 'under_review') # Transition to place
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
net.add_place('draft')
net.add_place('pending_review')
net.add_place('reviewed')
net.add_place('approved')
net.add_place('rejected')

# Actions (Transitions)
net.add_transition('submit')
net.add_transition('review')
net.add_transition('approve')
net.add_transition('reject')

# Flow (Arcs)
net.connect('draft', 'submit')
net.connect('submit', 'pending_review')
net.connect('pending_review', 'review')
net.connect('review', 'reviewed')
net.connect('reviewed', 'approve')
net.connect('approve', 'approved')
net.connect('reviewed', 'reject')
net.connect('reject', 'rejected')
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

## Example Walkthrough: Approval Workflow

Let's walk through how our example approval workflow works using Petri Nets:

### 1. Initial State
```ruby
net.add_tokens('draft')
puts net.marking
# => {"draft"=>1, "pending_review"=>0, "reviewed"=>0, "approved"=>0, "rejected"=>0}
```
- System starts with one token in the 'draft' state
- All other states are empty

### 2. Submit Transition
```ruby
net.step  # Fires 'submit' transition
puts net.marking
# => {"draft"=>0, "pending_review"=>1, "reviewed"=>0, "approved"=>0, "rejected"=>0}
```
- Token moves from 'draft' to 'pending_review'
- 'submit' transition consumes token from 'draft'
- 'submit' transition produces token in 'pending_review'

### 3. Review Transition
```ruby
net.step  # Fires 'review' transition
puts net.marking
# => {"draft"=>0, "pending_review"=>0, "reviewed"=>1, "approved"=>0, "rejected"=>0}
```
- Token moves from 'pending_review' to 'reviewed'
- System is now ready for approval decision

### 4. Approval Decision
```ruby
# Guard condition determines which transition can fire
approve.set_guard { true }   # Always approve
reject.set_guard { false }   # Never reject

net.step  # Fires 'approve' transition
puts net.marking
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
net.connect('rejected', 'submit')
```

2. **Parallel Reviews**
```ruby
# Add multiple tokens for parallel reviews
net.add_tokens('pending_review', 3)
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
net = CircuitBreaker::Workflow.new

# Define states (places)
['draft', 'pending_review', 'reviewed', 'approved', 'rejected'].each do |place|
  net.add_place(place)
end

# Define state transitions
['submit', 'review', 'approve', 'reject'].each do |transition|
  net.add_transition(transition)
end

# Connect states and transitions
net.connect('draft', 'submit')
net.connect('submit', 'pending_review')
net.connect('pending_review', 'review')
net.connect('review', 'reviewed')

# Add guard conditions
approve = net.transitions['approve']
approve.set_guard do
  # Add your approval logic here
  true
end

# Start the workflow
net.add_tokens('draft')

# Run the workflow
net.run_to_completion
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
git clone https://github.com/yourusername/circuit_breaker.git
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
