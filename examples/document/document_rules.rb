require_relative '../../lib/circuit_breaker'

module Examples
  module DocumentRules
    def self.define
      CircuitBreaker::Rules::DSL.define do
        # Basic Document Rules
        rule :valid_title,
             desc: "Document title is required" do |token|
          presence(:title)
        end

        rule :valid_content,
             desc: "Document content is required" do |token|
          presence(:content)
        end

        rule :valid_priority,
             desc: "Priority must be low, medium, or high" do |token|
          one_of(:priority, %w[low medium high])
        end

        # Participant Rules
        rule :valid_author,
             desc: "Document must have an author" do |token|
          presence(:author_id)
        end

        rule :valid_reviewer,
             desc: "Document must have a reviewer different from author" do |token|
          all(
            presence(:reviewer_id),
            different_values(:reviewer_id, :author_id)
          )
        end

        rule :valid_review,
             desc: "Review comments are required" do |token|
          presence(:reviewer_comments)
        end

        rule :valid_approver,
             desc: "Document must have an approver different from author and reviewer" do |token|
          all(
            presence(:approver_id),
            different_values(:approver_id, :author_id),
            different_values(:approver_id, :reviewer_id)
          )
        end

        # Metadata Rules
        rule :valid_due_date,
             desc: "Due date is required" do |token|
          presence(:due_date)
        end

        rule :valid_external_url,
             desc: "URL must be valid and start with http" do |token|
          all(
            presence(:external_url),
            custom(:external_url, "URL must start with http") { |url| url.start_with?('http') }
          )
        end

        rule :valid_word_count,
             desc: "Document must have at least 100 words" do |token|
          all(
            presence(:word_count),
            custom(:word_count, "Must have at least 100 words") { |count| count.is_a?(Integer) && count >= 100 }
          )
        end

        # Priority-based Rules
        rule :is_high_priority,
             desc: "Document must be marked as high priority" do |token|
          one_of(:priority, ['high'])
        end

        rule :is_urgent,
             desc: "Document must be marked as urgent" do |token|
          one_of(:priority, ['urgent'])
        end

        # Admin Rules
        rule :is_admin_approver,
             desc: "Approver must be an admin user" do |token|
          custom(:approver_id, "Approver ID must start with 'admin_'") { |id| id.start_with?('admin_') }
        end

        # Rejection Rules
        rule :valid_rejection,
             desc: "Rejection must include a reason" do |token|
          presence(:rejection_reason)
        end

        # Common Rule Combinations
        rule :valid_document,
             desc: "Document must have all required fields" do |token|
          all(
            presence(:title),
            presence(:content),
            one_of(:priority, %w[low medium high]),
            presence(:author_id),
            presence(:due_date)
          )
        end

        rule :valid_review_process,
             desc: "Document must have valid review process" do |token|
          all(
            presence(:reviewer_id),
            different_values(:reviewer_id, :author_id),
            presence(:reviewer_comments),
            presence(:approver_id),
            different_values(:approver_id, :author_id),
            different_values(:approver_id, :reviewer_id)
          )
        end

        rule :valid_rejection_process,
             desc: "Document must have valid rejection process" do |token|
          all(
            presence(:reviewer_id),
            presence(:reviewer_comments),
            presence(:rejection_reason)
          )
        end

        # DSL methods for more natural rule definitions
        def requires(field)
          ->(doc) { !doc.send(field).nil? && !doc.send(field).empty? }
        end

        def must_be_different(field1, field2)
          ->(doc) { 
            val1 = doc.send(field1)
            val2 = doc.send(field2)
            puts "Comparing #{field1}='#{val1}' with #{field2}='#{val2}'"
            # Both fields must be present and different
            !val1.nil? && !val2.nil? && !val1.empty? && !val2.empty? && val1 != val2 
          }
        end

        def must_be(field, value)
          ->(doc) { doc.send(field) == value }
        end

        def must_start_with(field, prefix)
          ->(doc) { doc.send(field)&.start_with?(prefix) }
        end

        # Document Rules
        # Reviewer Rules
        rule :has_reviewer,
             desc: "Document must have a reviewer assigned",
             &requires(:reviewer_id)

        rule :different_reviewer,
             desc: "Reviewer must be different from author",
             &must_be_different(:reviewer_id, :author_id)

        # Review Rules
        rule :has_comments,
             desc: "Review must include comments",
             &requires(:reviewer_comments)

        # Approval Rules
        rule :has_approver,
             desc: "Document must have an approver assigned",
             &requires(:approver_id)

        rule :different_approver_from_reviewer,
             desc: "Approver must be different from reviewer",
             &must_be_different(:approver_id, :reviewer_id)

        rule :different_approver_from_author,
             desc: "Approver must be different from author",
             &must_be_different(:approver_id, :author_id)

        # Priority Rules
        rule :high_priority,
             desc: "Document must be marked as high priority",
             &must_be(:priority, 'high')

        rule :urgent,
             desc: "Document must be marked as urgent",
             &must_be(:priority, 'urgent')

        # Admin Rules
        rule :is_admin,
             desc: "Approver must be an admin user",
             &must_start_with(:approver_id, 'admin_')

        # Rejection Rules
        rule :has_rejection,
             desc: "Rejection must include a reason",
             &requires(:rejection_reason)
      end
    end
  end
end
