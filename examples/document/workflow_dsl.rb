require_relative '../../lib/circuit_breaker'
require_relative 'token_example'

# Example of a document workflow using a more declarative DSL approach
module Examples
  class DocumentWorkflowDSL
    def self.run
      puts "Starting Document Workflow Example (DSL Version)..."
      puts "================================================\n"

      # Initialize rules engine
      rules = CircuitBreaker::RulesEngine::DSL.define_workflow_rules do
        rule(:has_reviewer) do |doc|
          doc.has_reviewer?
        end

        rule(:different_reviewer) do |doc|
          doc.reviewer_id != doc.author_id
        end

        rule(:content_length) do |doc|
          doc.content.length >= 10
        end

        rule(:has_comments) do |doc|
          doc.has_comments?
        end

        rule(:comments_length) do |doc|
          doc.reviewer_comments.length >= 10
        end

        rule(:has_approver) do |doc|
          doc.has_different_approver?
        end

        rule(:different_approver) do |doc|
          doc.approver_id != doc.reviewer_id
        end

        rule(:has_rejection) do |doc|
          doc.has_rejection_reason?
        end
      end

      # Initialize validators
      validators = CircuitBreaker::Validators::DSL.define_token_validators do
        validator(:title) do |token|
          all(
            presence(:title),
            regex(:title, /^[A-Z]/, "must start with a capital letter")
          )
        end

        validator(:content) do |token|
          all(
            presence(:content),
            length(:content, min: 10)
          )
        end

        validator(:tags) do |token|
          regex(:tags, /^[a-z0-9\-_]+$/, "must contain only lowercase letters, numbers, hyphens, and underscores")
        end

        validator(:priority) do |token|
          inclusion(:priority, %w[low medium high])
        end

        validator(:reviewer) do |token|
          all(
            presence(:reviewer_id),
            custom(:reviewer_id, "cannot be the same as author") { |id| id != token.author_id }
          )
        end

        validator(:review) do |token|
          all(
            presence(:reviewer_comments),
            length(:reviewer_comments, min: 10, message: "must be at least 10 characters")
          )
        end

        validator(:approval) do |token|
          all(
            presence(:approver_id),
            custom(:approver_id, "cannot be the same as reviewer") { |id| id != token.reviewer_id }
          )
        end

        validator(:rejection) do |token|
          presence(:rejection_reason)
        end
      end

      # Define the workflow using a simple DSL
      workflow = CircuitBreaker::WorkflowDSL.define do
        # Define all possible states
        states :draft, :pending_review, :reviewed, :approved, :rejected

        # Add document validations
        validate_with validators

        # Define transitions with required fields and rules
        flow(:draft >> :pending_review)
          .transition(:submit)
          .validates(:reviewer_id, :content)
          .rules(:has_reviewer, :different_reviewer, :content_length)

        flow(:pending_review >> :reviewed)
          .transition(:review)
          .validates(:reviewer_comments)
          .rules(:has_comments, :comments_length)

        flow(:reviewed >> :approved)
          .transition(:approve)
          .validates(:approver_id)
          .rules(:has_approver, :different_approver)

        flow(:reviewed >> :rejected)
          .transition(:reject)
          .validates(:rejection_reason)
          .rule(:has_rejection)

        # Simple transition without requirements
        flow(:rejected >> :draft).transition(:revise)
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
      setup_handlers(doc)

      begin
        puts "\nExecuting workflow steps..."
        execute_workflow_steps(workflow, doc)
        
        # Export visualization
        export_visualization

        # Print history
        print_document_history(doc)

      rescue StandardError => e
        puts "\nWorkflow Error: #{e.message}"
        puts e.backtrace
      end
    end

    private

    def self.setup_handlers(doc)
      doc.on(:attribute_change) do |field, value|
        puts "\n[Event] Document updated:"
        doc.pretty_print
      end

      doc.on(:state_change) do |from, to|
        puts "\n[Event] Document state changed:"
        doc.pretty_print
        puts "[Async] Notification sent for state change to #{to}\n"
      end

      doc.on(:async_event) do |event_type, details|
        puts "[ASYNC] #{details}"
      end
    end

    def self.execute_workflow_steps(workflow, doc)
      puts "\nInitial Document State:"
      doc.state = :draft
      puts "State: #{doc.state}"

      puts "\nStep 1: Submitting document..."
      doc.submit("bob456", actor_id: doc.author_id)
      puts "Document submitted successfully"
      puts "Current state: #{doc.state}"
      puts "Reviewer: #{doc.reviewer_id}"

      puts "\nStep 2: Reviewing document..."
      doc.review("Good proposal, needs more budget details", actor_id: "bob456")
      puts "Review completed"
      puts "Current state: #{doc.state}"
      puts "Review comments: #{doc.reviewer_comments}"

      puts "\nStep 3: Approving document..."
      doc.approve("carol789", actor_id: "carol789")
      puts "Document approved"
      puts "Current state: #{doc.state}"
      puts "Approver: #{doc.approver_id}"

      processing_time = Time.now - doc.created_at
      puts "\nTotal processing time: #{processing_time.round(2)} seconds"
    end

    def self.export_visualization
      puts "\nExporting workflow visualization..."
      output_file = File.join(File.dirname(__FILE__), 'workflow_dsl.html')
      File.write(output_file, CircuitBreaker::Document.visualize(:html))
      puts "Workflow diagram exported to #{File.basename(output_file)}"
    end

    def self.print_document_history(doc)
      puts "\nDocument History:"
      puts "----------------"
      doc.history.each do |entry|
        puts "#{entry.timestamp.strftime('%Y-%m-%d %H:%M:%S')} - #{entry.type}"
        puts "  Actor: #{entry.actor_id}"
        puts "  Details: #{entry.details.inspect}\n"
      end
    end
  end
end

# Run the example
Examples::DocumentWorkflowDSL.run if __FILE__ == $0
