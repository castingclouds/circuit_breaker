require_relative '../../lib/circuit_breaker'
require_relative 'document_token'
require_relative 'document_rules'
require_relative 'mock_executor'

# Example of a document workflow using a more declarative DSL approach
module Examples
  module Document
    module Workflow
      class DSL
        def self.run
          puts "Starting Document Workflow Example (DSL Version)..."
          puts "================================================\n"

          # Create a document token
          token = DocumentToken.new
          puts "Initial Document State:"
          puts "======================"
          puts "State: #{token.state}\n\n"
          puts token.to_json(true)

          puts "\nWorkflow Definition:"
          puts "===================\n"

          # Initialize document-specific rules and assistant
          rules = Rules.define
          mock = MockExecutor.new

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
              actions do
                execute mock, :analyze_document, :analysis
                execute mock, :analyze_clarity, :clarity
                execute mock, :analyze_completeness, :completeness
              end
              policy all: [:valid_word_count, :valid_clarity, :valid_completeness]
            end

            flow :pending_review >> :reviewed, :review do
              actions do
                execute mock, :review_document, :review
              end
              policy all: [:valid_review_metrics],
                     any: [:is_high_priority, :is_urgent]
            end

            flow :reviewed >> :approved, :approve do
              actions do
                execute mock, :final_review, :final
              end
              policy all: [:valid_approver, :approved_status]
            end

            flow :reviewed >> :rejected, :reject do
              actions do
                execute mock, :explain_rejection, :rejection
              end
              policy all: [:has_rejection_reasons]
            end

            # Simple transition without requirements
            flow :rejected >> :draft, :revise
          end

          puts "\nWorkflow Definition:"
          puts "==================="
          workflow.pretty_print

          puts "\nExecuting workflow steps...\n\n"

          # Try each transition
          begin
            puts "\nTrying draft -> pending_review transition..."
            token = workflow.transition!(token, :submit)
            puts "Success! New state: #{token.state}"

            puts "\nTrying pending_review -> reviewed transition..."
            token = workflow.transition!(token, :review)
            puts "Success! New state: #{token.state}"

            puts "\nTrying reviewed -> approved transition..."
            token = workflow.transition!(token, :approve)
            puts "Success! New state: #{token.state}"
          rescue => e
            puts "Error: #{e.message}"
          end

          puts "\nFinal Document State:"
          puts "===================="
          puts "State: #{token.state}\n\n"
          puts token.to_json(true)

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
