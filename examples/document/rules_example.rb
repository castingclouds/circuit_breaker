require_relative '../../lib/circuit_breaker'
require_relative '../../lib/circuit_breaker/workflow_dsl'
require_relative 'token_example'

# Example demonstrating various document validation rules and constraints
module Examples
  class DocumentRules
    class << self
      def test_validation(description)
        puts "\nTesting: #{description}"
        puts "-" * (description.length + 9)
        yield
        puts "✓ Success"
      rescue StandardError => e
        puts "✗ Failed: #{e.message}"
      end

      def run
        puts "Document Rules and Validation Example"
        puts "==================================\n"

        # Define the workflow
        workflow = CircuitBreaker::WorkflowDSL.define do
          states :draft, :pending_review, :reviewed, :approved, :rejected

          flow(:draft >> :pending_review).via(:submit)
            .requires([:reviewer_id])
            .validate { |token| token.content.length >= 10 }

          flow(:pending_review >> :reviewed).via(:review)
            .requires([:reviewer_comments])
            .validate { |token| token.reviewer_comments.length >= 10 }

          flow(:reviewed >> :approved).via(:approve)
            .requires([:approver_id])
            .validate { |token| token.approver_id != token.reviewer_id }

          flow(:reviewed >> :rejected).via(:reject)
            .requires([:rejection_reason])
        end

        # Test 1: Title validation
        test_validation("Title validation rules") do
          # Invalid: Empty title
          begin
            CircuitBreaker::Document.new(title: "", content: "Test")
            raise "Expected validation error for empty title"
          rescue CircuitBreaker::Token::ValidationError => e
            puts "  Caught expected error: #{e.message}"
          end

          # Invalid: Title not starting with capital
          begin
            CircuitBreaker::Document.new(title: "invalid title", content: "Test")
            raise "Expected validation error for lowercase title"
          rescue CircuitBreaker::Token::ValidationError => e
            puts "  Caught expected error: #{e.message}"
          end

          # Valid title
          doc = CircuitBreaker::Document.new(
            title: "Valid Title",
            content: "Test content",
            author_id: "test123"
          )
          puts "  Created document with valid title: #{doc.title}"
        end

        # Test 2: Content length rules
        test_validation("Content length rules") do
          doc = CircuitBreaker::Document.new(
            title: "Test Doc",
            content: "Too short",
            author_id: "test123"
          )
          workflow.add_token(doc)

          begin
            doc.reviewer_id = "reviewer123"
            workflow.fire_transition(:submit, doc)
            raise "Expected validation error for short content"
          rescue CircuitBreaker::Token::TransitionError => e
            puts "  Caught expected error: #{e.message}"
          end

          doc.content = "This content is now long enough to be valid for submission."
          workflow.fire_transition(:submit, doc)
          puts "  Successfully submitted with valid content length"
        end

        # Test 3: Reviewer rules
        test_validation("Reviewer validation rules") do
          doc = CircuitBreaker::Document.new(
            title: "Test Doc",
            content: "Valid content for testing reviewer rules",
            author_id: "author123"
          )
          workflow.add_token(doc)

          # Try to set reviewer same as author
          begin
            doc.reviewer_id = "author123"
            workflow.fire_transition(:submit, doc)
            raise "Expected validation error for self-review"
          rescue CircuitBreaker::Token::TransitionError => e
            puts "  Caught expected error: #{e.message}"
          end

          # Valid reviewer
          doc.reviewer_id = "reviewer123"
          workflow.fire_transition(:submit, doc)
          puts "  Successfully set different reviewer"
        end

        # Test 4: Review comments rules
        test_validation("Review comments validation") do
          doc = CircuitBreaker::Document.new(
            title: "Test Doc",
            content: "Valid content for testing review comments",
            author_id: "author123"
          )
          workflow.add_token(doc)
          
          doc.reviewer_id = "reviewer123"
          workflow.fire_transition(:submit, doc)

          # Try empty comments
          begin
            doc.reviewer_comments = ""
            workflow.fire_transition(:review, doc)
            raise "Expected validation error for empty comments"
          rescue CircuitBreaker::Token::TransitionError => e
            puts "  Caught expected error: #{e.message}"
          end

          # Valid comments
          doc.reviewer_comments = "These are valid review comments that meet the length requirement."
          workflow.fire_transition(:review, doc)
          puts "  Successfully added valid review comments"
        end

        # Test 5: Approval validation rules
        test_validation("Approval validation rules") do
          doc = CircuitBreaker::Document.new(
            title: "Test Doc",
            content: "Valid content for testing approval rules",
            author_id: "author123"
          )
          workflow.add_token(doc)
          
          doc.reviewer_id = "reviewer123"
          workflow.fire_transition(:submit, doc)
          
          doc.reviewer_comments = "Valid review comments for testing approval"
          workflow.fire_transition(:review, doc)

          # Try to approve with same person as reviewer
          begin
            doc.approver_id = "reviewer123"
            workflow.fire_transition(:approve, doc)
            raise "Expected validation error for self-approval"
          rescue CircuitBreaker::Token::TransitionError => e
            puts "  Caught expected error: #{e.message}"
          end

          # Valid approval
          doc.approver_id = "approver123"
          workflow.fire_transition(:approve, doc)
          puts "  Successfully approved with different approver"
        end

        # Test 6: Metadata validation rules
        test_validation("Metadata validation rules") do
          # Test invalid tag format
          begin
            CircuitBreaker::Document.new(
              title: "Test Doc",
              content: "Test content",
              author_id: "test123",
              tags: ["Invalid Tag"]
            )
            raise "Expected validation error for invalid tag format"
          rescue CircuitBreaker::Token::ValidationError => e
            puts "  Caught expected error: #{e.message}"
          end

          # Test invalid priority
          begin
            CircuitBreaker::Document.new(
              title: "Test Doc",
              content: "Test content",
              author_id: "test123",
              priority: "invalid"
            )
            raise "Expected validation error for invalid priority"
          rescue CircuitBreaker::Token::ValidationError => e
            puts "  Caught expected error: #{e.message}"
          end

          # Test valid metadata
          doc = CircuitBreaker::Document.new(
            title: "Test Doc",
            content: "Test content",
            author_id: "test123",
            tags: ["proposal", "draft"],
            priority: "high"
          )
          puts "  Successfully created document with valid metadata"
        end
      end
    end
  end
end

# Run the example
Examples::DocumentRules.run if __FILE__ == $0
