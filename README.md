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

The Circuit Breaker provides a powerful DSL for defining workflows with policy-based transitions:

```ruby
workflow = CircuitBreaker::WorkflowDSL.define do
  # Configure workflow settings
  for_object 'Document'
  
  # Define all possible states
  states :draft, :pending_review, :reviewed, :approved, :rejected
  
  # Define flows with policy-based validations and rules
  flow(:draft >> :pending_review)
    .transition(:submit)
    .policy(
      validations: { 
        all: [:title, :content, :reviewer_id],
        any: [:external_url, :word_count]
      },
      rules: { 
        all: [:has_reviewer, :different_reviewer],
        any: [:high_priority, :urgent]
      }
    )
  
  flow(:pending_review >> :reviewed)
    .transition(:review)
    .policy(
      validations: { all: [:reviewer_comments] },
      rules: {
        all: [:has_comments],
        any: [:high_priority, :urgent]
      }
    )
    
  flow(:reviewed >> :approved)
    .transition(:approve)
    .policy(
      validations: {
        all: [:approver_id, :reviewer_comments],
        any: [:external_url, :word_count]
      },
      rules: {
        all: [
          :has_approver,
          :different_approver_from_reviewer,
          :different_approver_from_author
        ],
        any: [:is_admin]
      }
    )
    
  flow(:reviewed >> :rejected)
    .transition(:reject)
    .policy(
      validations: { all: [:rejection_reason] },
      rules: { all: [:has_rejection] }
    )
    
  # Simple transition without requirements
  flow(:rejected >> :draft)
    .transition(:revise)
end
```

### Token Configuration

Circuit Breaker provides a powerful DSL for configuring tokens with attributes, timestamps, and state messages:

```ruby
class DocumentToken < CircuitBreaker::Token
  # Define valid states
  states :draft, :pending_review, :reviewed, :approved, :rejected

  # Define attributes with types and validations
  attribute :title,            String
  attribute :content,          String
  attribute :priority,         String, allowed: %w[low medium high urgent]
  attribute :author_id,        String
  attribute :reviewer_id,      String
  attribute :approver_id,      String
  attribute :reviewer_comments, String
  attribute :rejection_reason,  String
  attribute :word_count,       Integer
  attribute :external_url,     String

  # Define timestamps and state messages in a single configuration block
  state_configs do
    # Configure pending_review state
    state :pending_review,
          timestamps: :submitted_at,
          message: ->(t) { "Document submitted for review by #{t.reviewer_id}" }

    # Configure reviewed state
    state :reviewed,
          timestamps: :reviewed_at,
          message: ->(t) { "Document reviewed by #{t.reviewer_id} with comments" }

    # Configure approved state
    state :approved,
          timestamps: :approved_at,
          message: ->(t) { "Document approved by #{t.approver_id}" }

    # Configure rejected state
    state :rejected,
          timestamps: :rejected_at,
          message: ->(t) { "Document rejected with reason: #{t.rejection_reason}" }

    # Configure timestamps shared across multiple states
    on_states [:approved, :rejected], timestamps: :completed_at
  end
end
```

### Policy-Based Rules

The DSL supports complex policy-based rules and validations:
1. **Validation Policies**
   ```ruby
   validations: {
     all: [:field1, :field2],     # All fields must be present
     any: [:field3, :field4]      # At least one field must be present
   }
   ```

2. **Rule Policies**
   ```ruby
   rules: {
     all: [:rule1, :rule2],       # All rules must pass
     any: [:rule3, :rule4]        # At least one rule must pass
   }
   ```

3. **Custom Rules**
   ```ruby
   rule :different_reviewer,
     desc: "Reviewer must be different from author",
     &must_be_different(:reviewer_id, :author_id)
   
   rule :is_admin,
     desc: "Approver must be an admin",
     &must_start_with(:approver_id, "admin_")
   ```

4. **Custom Validations**
   ```ruby
   validator :word_count,
     desc: "Document must have minimum word count",
     &must_have_min_words(:content, 100)
   
   validator :priority,
     desc: "Priority must be valid",
     &must_be_one_of(:priority, %w[low medium high urgent])
   ```

### Error Handling

The DSL provides clear error messages for policy violations:

```ruby
begin
  workflow.fire_transition(:approve, token)
rescue CircuitBreaker::RulesEngine::RuleValidationError => e
  puts "Rule validation failed: #{e.message}"
  # => "Rule validation failed: Rule 'different_approver_from_author' failed"
rescue CircuitBreaker::Validators::ValidationError => e
  puts "Validation failed: #{e.message}"
  # => "Validation failed: Field 'approver_id' is required"
end
```

### History Tracking

The workflow tracks the complete history of transitions:

```ruby
token.history.each do |event|
  puts "#{event.timestamp}: #{event.type} - #{event.details}"
end
```

### Debug Output

The workflow can provide detailed debug output for troubleshooting:

```ruby
workflow.debug_mode = true
workflow.fire_transition(:approve, token)
# => Rule 'has_approver' evaluated to true
# => Comparing approver_id='admin_eve789' with reviewer_id='bob456'
# => Rule 'different_approver_from_reviewer' evaluated to true
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

# Define your token class
class DocumentToken < CircuitBreaker::Token
  # Define valid states
  states :draft, :pending_review, :reviewed, :approved, :rejected

  # Define attributes
  attribute :title,            String
  attribute :content,          String
  attribute :priority,         String, allowed: %w[low medium high urgent]
  attribute :author_id,        String
  attribute :reviewer_id,      String
  attribute :approver_id,      String
  attribute :word_count,       Integer

  # Configure state behavior
  state_configs do
    # Configure pending_review state
    state :pending_review,
          timestamps: :submitted_at,
          message: ->(t) { "Document submitted by #{t.author_id}" }

    # Configure reviewed state
    state :reviewed,
          timestamps: :reviewed_at,
          message: ->(t) { "Document reviewed by #{t.reviewer_id}" }

    # Configure approved state
    state :approved,
          timestamps: [:approved_at, :completed_at],
          message: ->(t) { "Document approved by #{t.approver_id}" }
  end
end

# Create workflow
workflow = CircuitBreaker::WorkflowDSL.define do
  for_object 'Document'
  states :draft, :pending_review, :reviewed, :approved

  # Define transitions with policies
  flow(:draft >> :pending_review)
    .transition(:submit)
    .policy(
      validations: { all: [:title, :content, :author_id] },
      rules: { all: [:has_author] }
    )
end

# Create and configure token
token = DocumentToken.new(
  title: "Project Proposal",
  content: "Detailed project proposal...",
  priority: "high",
  author_id: "alice123",
  word_count: 150
)

# Add token to workflow and execute
workflow.add_token(token)
workflow.fire_transition(:submit, token)

# Check token state and history
puts token.current_state         # => "pending_review"
puts token.submitted_at         # => "2025-01-01 12:45:57 -0500"
puts token.state_message        # => "Document submitted by alice123"
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
ruby examples/document/document_workflow.rb
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
