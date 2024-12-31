require_relative '../../lib/circuit_breaker'

module Examples
  module DocumentRules
    def self.define
      CircuitBreaker::RulesEngine::DSL.define do
        # DSL methods for more natural rule definitions
        def requires(field)
          ->(doc) { !doc.send(field).nil? && !doc.send(field).empty? }
        end

        def must_be_different(field1, field2)
          ->(doc) { doc.send(field1) != doc.send(field2) }
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
