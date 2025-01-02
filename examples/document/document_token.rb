require 'securerandom'
require_relative '../../lib/circuit_breaker/token'

module Examples
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

    def to_json(include_private = false)
      JSON.pretty_generate(to_h(include_private))
    end

    def to_yaml(include_private = false)
      to_h(include_private).to_yaml
    end
  end
end
