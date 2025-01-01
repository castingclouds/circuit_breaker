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

### 1. States and Transitions
States represent the possible stages in your workflow, while transitions define how states can change:
```ruby
workflow = CircuitBreaker::WorkflowDSL.define do
  # Define all possible states (first one is initial state)
  states :draft,           # Initial state when document is created
        :pending_review,   # Document submitted and awaiting review
        :reviewed,         # Document has been reviewed with comments
        :approved,         # Document has been approved
        :rejected         # Document was rejected

  # Define transitions between states
  flow(:draft >> :pending_review).transition(:submit)
  flow(:pending_review >> :reviewed).transition(:review)
  flow(:reviewed >> :approved).transition(:approve)
  flow(:reviewed >> :rejected).transition(:reject)
end
```

### 2. Tokens and Attributes
Tokens represent objects moving through the workflow, with attributes that can be validated:
```ruby
class DocumentToken < CircuitBreaker::Token
  # Define valid states
  states :draft, :pending_review, :reviewed, :approved, :rejected

  # Define attributes with types and validations
  attribute :title,       String
  attribute :content,     String
  attribute :priority,    String, allowed: %w[low medium high urgent]
  attribute :author_id,   String
  attribute :word_count,  Integer
end
```

### 3. State Configuration
Configure how tokens behave in each state with timestamps and messages:
```ruby
class DocumentToken < CircuitBreaker::Token
  state_configs do
    # Configure state behavior
    state :pending_review,
          timestamps: :submitted_at,
          message: ->(t) { "Document submitted by #{t.author_id}" }

    state :approved,
          timestamps: [:approved_at, :completed_at],
          message: ->(t) { "Document approved by #{t.approver_id}" }
  end
end
```

### 4. Policies and Rules
Control transitions with validation and rule policies:
```ruby
workflow = CircuitBreaker::WorkflowDSL.define do
  flow(:draft >> :pending_review)
    .transition(:submit)
    .policy(
      validations: { 
        all: [:title, :content],    # Required fields
        any: [:external_url, :word_count]  # At least one required
      },
      rules: { 
        all: [:has_reviewer],       # All rules must pass
        any: [:high_priority, :urgent]  # At least one must pass
      }
    )
end
```

### 5. Workflow Execution
Execute workflow transitions and track state:
```ruby
# Create and configure token
token = DocumentToken.new(
  title: "Project Proposal",
  content: "Detailed project proposal...",
  author_id: "alice123",
  priority: "high"
)

# Add token to workflow and execute transitions
workflow.add_token(token)
workflow.fire_transition(:submit, token)

# Check token state and history
puts token.current_state    # => "pending_review"
puts token.submitted_at    # => "2025-01-01 12:57:59 -0500"
puts token.state_message   # => "Document submitted by alice123"
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
workflow = CircuitBreaker::WorkflowDSL.define do
  # Define all possible document states
  states :draft,           # Initial state when document is created
        :pending_review,   # Document submitted and awaiting review
        :reviewed,         # Document has been reviewed with comments
        :approved,         # Document has been approved
        :rejected         # Document was rejected

  # Define state transitions with policies
  flow(:draft >> :pending_review)
    .transition(:submit)
    .policy(
      validations: { all: [:reviewer_id] },
      rules: { all: [:has_reviewer, :different_reviewer] }
    )

  flow(:pending_review >> :reviewed)
    .transition(:review)
    .policy(
      validations: { all: [:reviewer_comments] },
      rules: { all: [:has_comments] }
    )

  flow(:reviewed >> :approved)
    .transition(:approve)
    .policy(
      validations: { all: [:approver_id] },
      rules: { all: [:has_approver, :is_admin] }
    )

  flow(:reviewed >> :rejected)
    .transition(:reject)
    .policy(
      validations: { all: [:rejection_reason] },
      rules: { all: [:has_rejection] }
    )

  # Allow revision of rejected documents
  flow(:rejected >> :draft).transition(:revise)
end
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

## Example Walkthrough: Document Approval

Let's walk through a complete document approval workflow:

### 1. Setup Workflow and Token
```ruby
# Define the workflow
workflow = CircuitBreaker::WorkflowDSL.define do
  states :draft, :pending_review, :reviewed, :approved, :rejected
  
  flow(:draft >> :pending_review)
    .transition(:submit)
    .policy(
      validations: { all: [:reviewer_id] },
      rules: { all: [:has_reviewer] }
    )
end

# Create initial document
token = DocumentToken.new(
  title: "Project Proposal",
  content: "Detailed project proposal...",
  author_id: "alice123"
)

# Add to workflow (automatically starts in :draft state)
workflow.add_token(token)
puts token.state  # => "draft"
```

### 2. Submit for Review
```ruby
# Set required fields for submission
token.reviewer_id = "bob456"

# Submit document
workflow.fire_transition(:submit, token)
puts token.state           # => "pending_review"
puts token.submitted_at    # => "2025-01-01 13:05:53 -0500"
puts token.state_message   # => "Document submitted for review by bob456"
```

### 3. Review Document
```ruby
# Add review comments
token.reviewer_comments = "Good proposal, needs minor revisions"

# Complete review
workflow.fire_transition(:review, token)
puts token.state          # => "reviewed"
puts token.reviewed_at    # => "2025-01-01 13:05:53 -0500"
puts token.state_message  # => "Document reviewed by bob456 with comments"
```

### 4. Approval Decision
```ruby
# Attempt to approve
token.approver_id = "admin_eve789"

begin
  # This will succeed if approver is admin and different from reviewer
  workflow.fire_transition(:approve, token)
  puts token.state          # => "approved"
  puts token.approved_at    # => "2025-01-01 13:05:53 -0500"
  puts token.completed_at   # => "2025-01-01 13:05:53 -0500"
  puts token.state_message  # => "Document approved by admin_eve789"
rescue CircuitBreaker::RulesEngine::RuleValidationError => e
  # Handle validation failures (e.g., approver not admin)
  puts "Approval failed: #{e.message}"
  
  # Reject instead
  token.rejection_reason = "Needs major revisions"
  workflow.fire_transition(:reject, token)
  puts token.state          # => "rejected"
  puts token.rejected_at    # => "2025-01-01 13:05:53 -0500"
  puts token.completed_at   # => "2025-01-01 13:05:53 -0500"
  puts token.state_message  # => "Document rejected with reason: Needs major revisions"
end
```

This walkthrough demonstrates:
- Token state tracking with timestamps
- State-specific validation rules
- Automatic message generation
- Error handling for rule violations
- Shared timestamps across states (completed_at)

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
        all: [:title, :content, :author_id],
        any: [:external_url, :word_count]
      },
      rules: { 
        all: [:has_reviewer],
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

## Advanced Patterns

The workflow DSL excels at modeling complex patterns:

1. **Reentrant Workflows**
```ruby
workflow = CircuitBreaker::WorkflowDSL.define do
  states :draft, :pending_review, :reviewed, :rejected
  
  # Allow documents to be resubmitted after rejection
  flow(:draft >> :pending_review).transition(:submit)
  flow(:rejected >> :draft).transition(:revise)
  flow(:pending_review >> :reviewed).transition(:review)
  flow(:reviewed >> :rejected).transition(:reject)
end
```

2. **Parallel Reviews**
```ruby
class MultiReviewToken < CircuitBreaker::Token
  # Track multiple reviewers
  attribute :reviewers, Array
  attribute :reviews_completed, Integer, default: 0
  
  state_configs do
    state :pending_review,
          timestamps: :review_started_at,
          message: ->(t) { "Awaiting #{t.reviewers.count} reviews" }
          
    state :reviewed,
          timestamps: :all_reviews_completed_at,
          message: ->(t) { "All #{t.reviews_completed} reviews completed" }
  end
end

workflow = CircuitBreaker::WorkflowDSL.define do
  flow(:pending_review >> :reviewed)
    .transition(:complete_review)
    .policy(
      validations: { all: [:reviewer_comments] },
      rules: { 
        all: [:has_comments],
        custom: ->(token) { token.reviews_completed >= 3 }  # Need 3 reviews
      }
    )
end
```

3. **Synchronization Points**
```ruby
class TeamApprovalToken < CircuitBreaker::Token
  attribute :team_approvals, Array
  attribute :required_approvals, Integer, default: 3
  
  state_configs do
    state :pending_approval,
          timestamps: :first_approval_at,
          message: ->(t) { "#{t.team_approvals.count}/#{t.required_approvals} approvals received" }
          
    state :approved,
          timestamps: :fully_approved_at,
          message: ->(t) { "Received all #{t.required_approvals} required approvals" }
  end
end

workflow = CircuitBreaker::WorkflowDSL.define do
  flow(:pending_approval >> :approved)
    .transition(:approve)
    .policy(
      rules: {
        custom: ->(token) { token.team_approvals.count >= token.required_approvals }
      }
    )
end
```

4. **State-Based Conditions**
```ruby
workflow = CircuitBreaker::WorkflowDSL.define do
  flow(:reviewed >> :approved)
    .transition(:approve)
    .policy(
      validations: { all: [:approver_id] },
      rules: {
        all: [:has_approver, :is_admin],
        custom: ->(token) {
          # Complex state-based rules
          token.priority == "high" ||
          (token.reviews_completed >= 2 && token.all_reviews_positive?)
        }
      }
    )
end
```

These patterns demonstrate how the workflow DSL can elegantly handle complex state-based workflows through its policy-based rules and token attributes.

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
