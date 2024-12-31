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
          .validate(:reviewer_id)
          .rules(:has_reviewer, :different_reviewer)

        flow(:pending_review >> :reviewed)
          .transition(:review)
          .validate(:reviewer_comments)
          .rules(:has_comments)
          .rules_any(:high_priority, :urgent)

        flow(:reviewed >> :approved)
          .transition(:approve)
          .validate(:approver_id, :reviewer_comments)
          .validate_any(:external_url, :word_count)
          .rules(:has_approver, :different_approver_from_reviewer)
          .rules_any(:different_approver_from_author, :is_admin)

        flow(:reviewed >> :rejected)
          .transition(:reject)
          .validate(:rejection_reason)
          .rules(:has_rejection)

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
        content: "This is a detailed project proposal that meets the minimum length requirement.",
        priority: "high",
        author_id: "alice123",
        created_at: Time.now,
        updated_at: Time.now
      )

      # Add token to workflow
      workflow.add_token(token)

      puts "Initial Document State:"
      puts "State: #{token.state}\n\n"

      begin
        # Step 1: Submit document
        puts "Step 1: Submitting document..."
        token.reviewer_id = "bob456"  # Set reviewer_id before submitting
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
        token.approver_id = "carol789"
        workflow.fire_transition(:approve, token)
        puts "Document approved"
        puts "Current state: #{token.state}"
        puts "Approver: #{token.approver_id}\n\n"

        # Calculate and display processing time
        puts "Total processing time: #{Time.now - token.created_at} seconds\n\n"

      rescue CircuitBreaker::RulesEngine::RuleValidationError => e
        puts "Rule validation error: #{e.message}"
        puts "Current state: #{token.state}\n\n"
      rescue StandardError => e
        puts "Unexpected error: #{e.message}"
        puts "Current state: #{token.state}\n\n"
      end

      puts "Document History:"
      puts "----------------"
      token.history.each do |event|
        puts "#{event.timestamp} - #{event.type}"
      end
    end
  end
end

# Run the example
Examples::DocumentWorkflowDSL.run if __FILE__ == $0
