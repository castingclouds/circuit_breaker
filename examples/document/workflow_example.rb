require_relative '../../lib/circuit_breaker'
require_relative '../../lib/circuit_breaker/workflow_dsl'
require_relative 'token_example'

# Example of a complete document workflow lifecycle
module Examples
  class DocumentWorkflow
    def self.run
      puts "Starting Document Workflow Example..."
      puts "====================================\n"

      # Define the workflow using the DSL
      workflow = CircuitBreaker::WorkflowDSL.define do
        states :draft, :pending_review, :reviewed, :approved, :rejected

        flow(:draft >> :pending_review).via(:submit).requires([:reviewer_id])
        flow(:pending_review >> :reviewed).via(:review).requires([:reviewer_comments])
        flow(:reviewed >> :approved).via(:approve).requires([:approver_id])
        flow(:reviewed >> :rejected).via(:reject).requires([:rejection_reason])
        flow(:rejected >> :draft).via(:revise)
      end

      # Create a new document
      doc = CircuitBreaker::Document.new(
        title: "Project Proposal",
        content: "This is a detailed project proposal for Q1 2024.",
        author_id: "alice123",
        tags: ["proposal", "q1-2024"],
        due_date: "2024-03-31",
        priority: "high",
        word_count: 500
      )

      # Set up event handlers
      doc.on(:state_changed) do |data|
        puts "\n[Event] State changed from '#{data[:old_state]}' to '#{data[:new_state]}'"
      end

      doc.on(:attribute_changed) do |data|
        puts "[Event] #{data[:attribute]} updated: #{data[:new_value]}"
      end

      # Async notification handler
      doc.on(:state_changed, async: true) do |data|
        puts "\n[Async] Notification sent for state change to #{data[:new_state]}"
      end

      begin
        # Add document to workflow
        workflow.add_token(doc)

        # Submit for review
        puts "\nStep 1: Submitting document for review..."
        workflow.fire_transition(:submit, doc)
        puts "Document submitted successfully"
        puts "Current state: #{doc.state}"
        puts "Time in review: #{doc.pending_time} seconds"

        # Add reviewer comments
        puts "\nStep 2: Reviewer adding comments..."
        doc.reviewer_comments = "Good proposal, but needs more budget details."
        workflow.fire_transition(:review, doc)
        puts "Review completed"
        puts "Current state: #{doc.state}"
        puts "Review duration: #{doc.review_time} seconds"

        # Try invalid approval (reviewer trying to approve)
        puts "\nStep 3: Attempting invalid approval..."
        begin
          doc.approver_id = "bob456"  # Same as reviewer
          workflow.fire_transition(:approve, doc)
        rescue StandardError => e
          puts "Expected error: #{e.message}"
        end

        # Valid approval
        puts "\nStep 4: Manager approving document..."
        doc.approver_id = "carol789"
        workflow.fire_transition(:approve, doc)
        puts "Document approved"
        puts "Current state: #{doc.state}"
        puts "Total processing time: #{doc.total_time} seconds"

        # Export workflow visualization
        puts "\nExporting workflow visualization..."
        File.write("workflow.html", CircuitBreaker::Document.visualize(:html))
        puts "Workflow diagram exported to workflow.html"

        # Print final history
        puts "\nDocument History:"
        puts "----------------"
        doc.history.each do |entry|
          puts "#{entry.timestamp.strftime('%Y-%m-%d %H:%M:%S')} - #{entry.type}"
          puts "  Actor: #{entry.actor_id}"
          puts "  Details: #{entry.details.inspect}\n"
        end

      rescue StandardError => e
        puts "\nError in workflow: #{e.message}"
        puts e.backtrace.join("\n")
      end
    end
  end
end

# Run the example
Examples::DocumentWorkflow.run if __FILE__ == $0
