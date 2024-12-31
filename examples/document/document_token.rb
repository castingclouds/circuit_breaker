require 'securerandom'
require 'ostruct'
require_relative '../../lib/circuit_breaker/token'
require_relative '../../lib/circuit_breaker/validators'

module Examples
  class DocumentToken < CircuitBreaker::Token
    VALID_STATES = %i[draft pending_review reviewed approved rejected].freeze

    attr_accessor :title, :content, :author_id, :reviewer_id, :approver_id,
                :reviewer_comments, :rejection_reason, :tags, :priority,
                :due_date, :word_count, :external_url, :submitted_at, :reviewed_at,
                :approved_at, :rejected_at, :completed_at

    def initialize(attributes = {})
      super()  # Initialize Token without attributes
      @state = :draft
      @history = []

      # Required fields for initialization
      required_fields = [:title, :content, :author_id, :priority]
      missing_fields = required_fields.select { |field| attributes[field].nil? }
      
      if missing_fields.any?
        raise ValidationError, "Missing required fields: #{missing_fields.join(', ')}"
      end

      # Validate priority
      unless ['low', 'medium', 'high'].include?(attributes[:priority])
        raise ValidationError, "Invalid priority: must be one of low, medium, high"
      end

      # Initialize attributes after validation
      attributes.each do |key, value|
        instance_variable_set("@#{key}", value) if instance_variable_defined?("@#{key}")
      end
    end

    # Helper methods for rules
    def has_reviewer?
      !reviewer_id.nil?
    end

    def has_comments?
      !reviewer_comments.nil? && reviewer_comments.length >= 10
    end

    def has_different_approver?
      !approver_id.nil? && approver_id != reviewer_id
    end

    def has_rejection_reason?
      !rejection_reason.nil? && rejection_reason.length >= 10
    end

    # Track timing information
    before_transition do |from, to|
      case to
      when :pending_review
        @submitted_at = Time.now
      when :reviewed
        @reviewed_at = Time.now
      when :approved
        @approved_at = Time.now
        @completed_at = Time.now
      when :rejected
        @rejected_at = Time.now
        @completed_at = Time.now
      end
    end

    # Track history
    after_transition do |from, to, actor_id|
      @history << OpenStruct.new(
        timestamp: Time.now,
        type: :state_transition,
        actor: actor_id,
        details: {
          from: from,
          to: to,
          timestamp: Time.now
        }
      )
    end

    def history
      @history
    end
  end
end
