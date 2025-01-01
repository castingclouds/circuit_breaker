require_relative '../../lib/circuit_breaker'
require_relative 'document_token'
require_relative 'document_rules'
require_relative 'document_validators'

# Example of a document workflow using a more declarative DSL approach
module Examples
  class DocumentWorkflowDSL
    def self.run
      puts "Starting Document Workflow Example (DSL Version)..."
      puts "================================================\n"

      # Initialize document-specific rules and validators
      rules = DocumentRules.define
      validators = DocumentValidators.define

      workflow = CircuitBreaker::WorkflowDSL.define(rules: rules) do
        # Define all possible document states
        # The first state listed becomes the initial state
        states :draft,           # Initial state when document is created
              :pending_review,   # Document submitted and awaiting review
              :reviewed,         # Document has been reviewed with comments
              :approved,         # Document has been approved by approver
              :rejected         # Document was rejected and needs revision

        # Define transitions with required fields and rules
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
        flow(:rejected >> :draft).transition(:revise)
      end

      puts "\nWorkflow Definition:"
      puts "==================="
      workflow.pretty_print

      puts "\nExecuting workflow steps...\n\n"

      # Create a new document token
      token = Examples::DocumentToken.new(
        id: SecureRandom.uuid,
        title: "Project Proposal",
        content: "This is a detailed project proposal that meets the minimum length requirement. " * 10,  # Make it longer
        priority: "high",
        author_id: "charlie789",
        created_at: Time.now,
        updated_at: Time.now,
        word_count: 150  # Add word count
      )

      # Add token to workflow
      workflow.add_token(token)

      puts "Initial Document State:"
      puts "State: #{token.state}\n\n"

      begin
        # Step 1: Submit document
        puts "Step 1: Submitting document..."
        token.reviewer_id = "bob456"  # Set a different reviewer_id
        workflow.fire_transition(:submit, token)
        puts "Document submitted successfully"
        puts "Current state: #{token.state}"
        puts "Reviewer: #{token.reviewer_id}\n\n"

        # Step 2: Review document
        puts "Step 2: Reviewing document..."
        token.reviewer_comments = "This is a detailed review with suggestions for improvement. The proposal needs more budget details."
        workflow.fire_transition(:review, token)
        puts "Review completed"
        puts "Current state: #{token.state}"
        puts "Review comments: #{token.reviewer_comments}\n\n"

        # Step 3: Approve document
        puts "Step 3: Approving document..."
        token.approver_id = "admin_eve789"  # Set an admin approver who is different from both reviewer and author
        workflow.fire_transition(:approve, token)
        puts "Document approved"
        puts "Current state: #{token.state}"
        puts "Approver: #{token.approver_id}\n\n"

      rescue StandardError => e
        puts "Unexpected error: #{e.message}"
        puts "Current state: #{token.state}"
      end

      puts "\nDocument History:"
      puts "----------------"
      token.history.each do |event|
        puts "#{event.timestamp}: #{event.type} - #{event.details}"
      end
    end
  end
end

# Run the example
Examples::DocumentWorkflowDSL.run if __FILE__ == $0
