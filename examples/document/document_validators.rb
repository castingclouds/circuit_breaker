require_relative '../../lib/circuit_breaker'

module Examples
  module DocumentValidators
    def self.define
      CircuitBreaker::Validators::DSL.define_token_validators do
        # DSL methods for more natural validation definitions
        def must_be_present(field)
          ->(token) { presence(field).call(token) }
        end

        def must_be_one_of(field, allowed_values)
          ->(token) { inclusion(field, allowed_values).call(token) }
        end

        def must_be_url(field)
          ->(token) {
            all(
              presence(field),
              custom(field) { |url| url.start_with?('http') }
            ).call(token)
          }
        end

        def must_have_min_words(field, min_count)
          ->(token) {
            all(
              presence(field),
              custom(field) { |count| count.is_a?(Integer) && count >= min_count }
            ).call(token)
          }
        end

        # Document Fields
        # Basic Document Information
        validator :title,
                 desc: "Document title is required",
                 &must_be_present(:title)

        validator :content,
                 desc: "Document content is required",
                 &must_be_present(:content)

        validator :priority,
                 desc: "Priority must be low, medium, or high",
                 &must_be_one_of(:priority, %w[low medium high])

        # Participant Information
        validator :author_id,
                 desc: "Document must have an author",
                 &must_be_present(:author_id)

        validator :reviewer_id,
                 desc: "Document must have a reviewer",
                 &must_be_present(:reviewer_id)

        validator :reviewer_comments,
                 desc: "Review comments are required",
                 &must_be_present(:reviewer_comments)

        validator :approver_id,
                 desc: "Document must have an approver",
                 &must_be_present(:approver_id)

        # Metadata
        validator :due_date,
                 desc: "Due date is required",
                 &must_be_present(:due_date)

        # Complex Validations
        validator :external_url,
                 desc: "URL must be valid and start with http",
                 &must_be_url(:external_url)

        validator :word_count,
                 desc: "Document must have at least 100 words",
                 &must_have_min_words(:word_count, 100)

        validator :rejection_reason,
                 desc: "Rejection reason is required",
                 &must_be_present(:rejection_reason)
      end
    end
  end
end
