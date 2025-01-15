require 'securerandom'
require_relative '../../lib/circuit_breaker/token'

module Examples
  module Document
    class DocumentToken < CircuitBreaker::Token
      # Define valid states
      states :draft, :pending_review, :reviewed, :approved, :rejected

      # Define document attributes with types
      attribute :title,             String
      attribute :content,           String
      attribute :author_id,         String
      attribute :reviewer_id,       String
      attribute :approver_id,       String
      attribute :reviewer_comments, String
      attribute :rejection_reason,  String
      attribute :tags,             Array
      attribute :priority,          String, allowed: %w[low medium high urgent]
      attribute :due_date,          Time
      attribute :word_count,        Integer
      attribute :external_url,      String

      # Define timestamp fields and state messages
      state_configs do
        state :pending_review,
              timestamps: :submitted_at,
              message: ->(t) { "Document submitted for review by #{t.reviewer_id}" }

        state :reviewed,
              timestamps: :reviewed_at,
              message: ->(t) { "Document reviewed by #{t.reviewer_id} with comments" }

        state :approved,
              timestamps: :approved_at,
              message: ->(t) { "Document approved by #{t.approver_id}" }

        state :rejected,
              timestamps: :rejected_at,
              message: ->(t) { "Document rejected with reason: #{t.rejection_reason}" }

        # Handle shared timestamp
        on_states [:approved, :rejected], timestamps: :completed_at
      end

      def initialize
        @id = SecureRandom.uuid
        @state = :draft
        @content = <<~CONTENT
          Introduction
          This is a detailed document that shows our workflow system. We aim to create
          a robust and clear process for managing documents effectively.

          Background
          We need to ensure documents meet quality standards. This means checking the
          word count, clarity of writing, and completeness of content. Each document
          goes through several stages of review.

          The process uses smart tools to check document quality. These tools look at
          various aspects like word count and readability. They help make sure our
          documents are clear and complete.

          Conclusion
          By following these rules and steps, we keep our documents clear and useful.
          The workflow helps us maintain high standards and ensures good quality.
          Thank you for reading this example document.
        CONTENT
        @priority = "high"
        @created_at = Time.now
        @updated_at = Time.now
        @history = []
      end

      def to_json(include_private = false)
        JSON.pretty_generate(to_h(include_private))
      end

      def to_yaml(include_private = false)
        to_h(include_private).to_yaml
      end
    end
  end
end
