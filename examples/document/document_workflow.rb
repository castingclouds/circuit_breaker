require_relative '../../lib/circuit_breaker'
require_relative '../../lib/circuit_breaker/executors/assistant_executor'
require_relative 'document_token'
require_relative 'document_rules'
require_relative 'document_assistant'

# Example of a document workflow using a more declarative DSL approach
module Examples
  module Document
    module Workflow
      class DSL
        def self.run
          puts "Starting Document Workflow Example (DSL Version)..."
          puts "================================================\n"

          # Initialize document-specific rules
          rules = DocumentRules.define

          workflow = CircuitBreaker::WorkflowBuilder::DSL.define(rules: rules) do
            # Define all possible document states
            # The first state listed becomes the initial state
            states :draft,           # Initial state when document is created
                  :pending_review,   # Document submitted and awaiting review
                  :reviewed,         # Document has been reviewed with comments
                  :approved,         # Document has been approved by approver
                  :rejected         # Document was rejected and needs revision

            # Define transitions with required rules
            flow :draft >> :pending_review, :submit do
              policy all: [:valid_reviewer]
            end

            flow :pending_review >> :reviewed, :review do
              policy all: [:valid_review],
                     any: [:is_high_priority, :is_urgent]
            end

            flow :reviewed >> :approved, :approve do
              policy all: [
                :valid_approver,
                :valid_review,
                :is_admin_approver
              ],
              any: [:valid_external_url, :valid_word_count]
            end

            flow :reviewed >> :rejected, :reject do
              policy all: [:valid_rejection_process]
            end

            # Simple transition without requirements
            flow :rejected >> :draft, :revise
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
          puts token.to_json(true)

          # Initialize document assistant
          assistant = DocumentAssistant.new('llama3.1')

          # Get initial analysis
          puts "\nInitial Document Analysis:"
          puts "========================="
          puts assistant.analyze_document(token)
          puts "\n"

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
            puts "#{event[:timestamp]}: #{event[:transition]} from #{event[:from]} to #{event[:to]}"
          end
        end
      end
    end
  end

  # Run the example
  Examples::Document::Workflow::DSL.run if __FILE__ == $0
end
