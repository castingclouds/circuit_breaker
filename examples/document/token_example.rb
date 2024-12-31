require 'securerandom'
require_relative '../../lib/circuit_breaker/token'
require_relative '../../lib/circuit_breaker/validators'

module CircuitBreaker
  class Document < Token
    VALID_STATES = %i[draft pending_review reviewed approved rejected].freeze

    attr_accessor :title, :content, :author_id, :reviewer_id, :approver_id,
                :reviewer_comments, :rejection_reason, :tags, :priority,
                :due_date, :word_count, :external_url, :submitted_at, :reviewed_at,
                :approved_at, :rejected_at, :completed_at

    # Define state transitions
    transitions_from :draft, to: [:pending_review]
    transitions_from :pending_review, to: [:reviewed]
    transitions_from :reviewed, to: [:approved, :rejected]
    transitions_from :rejected, to: [:draft]

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

    # Define custom transition rules
    transition_rule from: :draft, to: :pending_review do
      errors = []
      errors << "Content too short" if content.to_s.length < 10
      errors << "Reviewer cannot be author" if reviewer_id == author_id
      errors.empty? ? nil : errors.join(", ")
    end

    transition_rule from: :pending_review, to: :reviewed do
      errors = []
      errors << "Reviewer comments required" if reviewer_comments.to_s.strip.empty?
      errors << "Comments too short" if reviewer_comments.to_s.length < 10
      errors.empty? ? nil : errors.join(", ")
    end

    transition_rule from: :reviewed, to: :approved do
      errors = []
      errors << "Approver cannot be reviewer" if approver_id == reviewer_id
      errors << "Approver cannot be author" if approver_id == author_id
      errors.empty? ? nil : errors.join(", ")
    end

    transition_rule from: :reviewed, to: :rejected do
      errors = []
      errors << "Rejection reason required" if rejection_reason.to_s.strip.empty?
      errors << "Rejection reason too short" if rejection_reason.to_s.length < 10
      errors.empty? ? nil : errors.join(", ")
    end

    transition_rule from: :rejected, to: :draft do
      nil # Always allow resubmission
    end

    # State validations
    validate_state :draft do
      return "Title required" if title.nil? || title.strip.empty?
      return "Content required" if content.nil? || content.strip.empty?
      return "Author ID required" if author_id.nil? || author_id.strip.empty?
      nil
    end

    validate_state :pending_review do
      return "Title required" if title.nil? || title.strip.empty?
      return "Content required" if content.nil? || content.strip.empty?
      return "Content too short" if content.length < 10
      return "Author ID required" if author_id.nil?
      return "Reviewer ID required" if reviewer_id.nil?
      return "Reviewer cannot be author" if reviewer_id == author_id
      nil
    end

    validate_state :reviewed do
      return "Reviewer comments required" if reviewer_comments.nil? || reviewer_comments.strip.empty?
      return "Reviewer comments too short" if reviewer_comments.length < 10
      nil
    end

    validate_state :approved do
      return "Approver ID required" if approver_id.nil?
      return "Approver cannot be reviewer" if approver_id == reviewer_id
      return "Approver cannot be author" if approver_id == author_id
      nil
    end

    validate_state :rejected do
      return "Rejection reason required" if rejection_reason.nil? || rejection_reason.strip.empty?
      return "Rejection reason too short" if rejection_reason.length < 10
      nil
    end

    # Define attributes with enhanced validations
    define_attribute :title, validates: Validators::Rules.custom { |value|
      return "cannot be empty" if value.nil? || value.strip.empty?
      return "must start with a capital letter" unless value =~ /^[A-Z]/
      return "must be between 3 and 100 characters" unless (3..100).include?(value.length)
      nil
    }

    define_attribute :content, validates: Validators::Rules.custom { |value|
      return "cannot be empty" if value.nil? || value.strip.empty?
      return "must be at least 10 characters" if value.strip.length < 10
      nil
    }

    define_attribute :author_id, validates: Validators::Rules.custom { |value|
      return "cannot be empty" if value.nil? || value.strip.empty?
      nil
    }

    define_attribute :reviewer_id, validates: Validators::Rules.custom { |value, instance|
      return "cannot be empty" if value.nil? || value.strip.empty?
      return "cannot be the author" if value == instance.instance_variable_get('@author_id')
      nil
    }

    define_attribute :reviewer_comments, validates: Validators::Rules.custom { |value, instance|
      if instance.instance_variable_get('@state') == :reviewed
        return "cannot be empty" if value.nil? || value.strip.empty?
        return "must be at least 10 characters" if value.strip.length < 10
      end
      nil
    }

    define_attribute :approver_id, validates: Validators::Rules.custom { |value, instance|
      return nil if value.nil? || value.strip.empty?
      errors = []
      errors << "cannot be the reviewer" if value == instance.instance_variable_get('@reviewer_id')
      errors << "cannot be the author" if value == instance.instance_variable_get('@author_id')
      errors.empty? ? nil : errors.join(", ")
    }

    define_attribute :rejection_reason, validates: Validators::Rules.custom { |value, instance|
      if instance.instance_variable_get('@state') == :rejected
        return "cannot be empty" if value.nil? || value.strip.empty?
        return "must be at least 10 characters" if value.strip.length < 10
      end
      nil
    }

    define_attribute :tags, validates: Validators::Rules.custom { |tags|
      return nil if tags.nil?
      return "must be an array" unless tags.is_a?(Array)
      
      invalid_tags = tags.reject { |tag| tag.to_s =~ /^[a-z0-9-]+$/ }
      invalid_tags.empty? ? nil : "invalid tags: #{invalid_tags.join(', ')}"
    }

    define_attribute :due_date, validates: Validators::Rules.custom { |value|
      return nil if value.nil?
      begin
        Date.parse(value.to_s)
        nil
      rescue ArgumentError
        "invalid date format"
      end
    }

    define_attribute :priority, validates: Validators::Rules.custom { |value|
      return nil if value.nil?
      %w[low medium high].include?(value.to_s) ? nil : "must be one of: low, medium, high"
    }

    define_attribute :external_url, validates: Validators::Rules.custom { |value|
      return nil if value.nil?
      begin
        uri = URI.parse(value.to_s)
        uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS) ? nil : "invalid URL format"
      rescue URI::InvalidURIError
        "invalid URL format"
      end
    }

    define_attribute :word_count, validates: Validators::Rules.custom { |value|
      return nil if value.nil?
      return "must be a number" unless value.to_s =~ /^\d+$/
      value.to_i > 0 ? nil : "must be greater than 0"
    }

    # Timing calculations
    def pending_time
      return 0 unless submitted_at
      (reviewed_at || Time.now) - submitted_at
    end

    def review_time
      return 0 unless reviewed_at
      ((approved_at || rejected_at || Time.now) - reviewed_at).to_i
    end

    def total_time
      return 0 unless submitted_at
      ((approved_at || rejected_at || Time.now) - submitted_at).to_i
    end

    # Transition hooks
    before_transition do |from, to|
      # Log the transition attempt
      puts "[Document #{id}] Attempting transition from #{from} to #{to}"
    end

    # Event handlers
    def initialize(metadata = {})
      # Validate title before calling super
      if metadata[:title].nil? || metadata[:title].strip.empty?
        raise ValidationError, "Title cannot be empty"
      end
      
      if metadata[:title] && !metadata[:title].match?(/^[A-Z]/)
        raise ValidationError, "Title must start with a capital letter"
      end

      # Validate tags if present
      if metadata[:tags]
        invalid_tags = metadata[:tags].reject { |tag| tag.match?(/^[a-z0-9-]+$/) }
        if invalid_tags.any?
          raise ValidationError, "Tags must be lowercase alphanumeric with hyphens only: #{invalid_tags.join(', ')}"
        end
      end

      # Validate priority if present
      if metadata[:priority] && !%w[low medium high].include?(metadata[:priority].to_s.downcase)
        raise ValidationError, "Priority must be one of: low, medium, high"
      end

      super(state: :draft, metadata: metadata)

      # Set up event handlers
      on(:state_changed) do |data|
        puts "\n[Event] State changed from '#{data[:old_state]}' to '#{data[:new_state]}'\n"
        puts "[Async] Notification sent for state change to #{data[:new_state]}"
      end

      on(:state_changed, async: true) do |data|
        puts "[ASYNC] Notifying external systems about state change: #{data[:new_state]}"
      end

      on(:attribute_changed) do |data|
        puts "[Event] #{data[:attribute]} updated: #{data[:new_value]}"
      end

      on(:attribute_changed, async: true) do |data|
        puts "[ASYNC] Logging attribute change to audit system: #{data[:attribute]}"
      end

      # Run initial validations
      validate_current_state if @state
    end

    # Document workflow methods
    def submit(reviewer_id, actor_id:)
      self.reviewer_id = reviewer_id
      update_state(:pending_review, actor_id: actor_id)
    end

    def review(comments, actor_id:)
      self.reviewer_comments = comments
      update_state(:reviewed, actor_id: actor_id)
    end

    def approve(approver_id, actor_id:)
      self.approver_id = approver_id
      update_state(:approved, actor_id: actor_id)
    end

    def reject(reason, actor_id:)
      self.rejection_reason = reason
      update_state(:rejected, actor_id: actor_id)
    end

    def resubmit(actor_id: nil)
      return unless state == :rejected
      update_state(:draft, actor_id: actor_id)
    end

    # Export methods
    def to_html
      require 'redcarpet'
      markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>#{title}</title>
          <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .metadata { color: #666; }
            .content { margin-top: 20px; }
          </style>
        </head>
        <body>
          <h1>#{title}</h1>
          <div class="metadata">
            <p>Author: #{author_id}</p>
            <p>State: #{state}</p>
            <p>Created: #{created_at}</p>
            #{reviewer_id ? "<p>Reviewer: #{reviewer_id}</p>" : ""}
            #{approver_id ? "<p>Approver: #{approver_id}</p>" : ""}
          </div>
          <div class="content">
            #{markdown.render(content)}
          </div>
        </body>
        </html>
      HTML
    rescue LoadError
      raise "Redcarpet is required for HTML export. Add it to your Gemfile."
    end

    def export_history_as_timeline
      require 'erb'
      template = ERB.new(<<~HTML)
        <!DOCTYPE html>
        <html>
        <head>
          <title>Document Timeline - <%= title %></title>
          <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .timeline { position: relative; max-width: 1200px; margin: 0 auto; }
            .timeline::after {
              content: '';
              position: absolute;
              width: 6px;
              background-color: #999;
              top: 0;
              bottom: 0;
              left: 50%;
              margin-left: -3px;
            }
            .entry {
              padding: 10px 40px;
              position: relative;
              width: 50%;
              box-sizing: border-box;
            }
            .entry::after {
              content: '';
              position: absolute;
              width: 20px;
              height: 20px;
              right: -10px;
              background-color: white;
              border: 4px solid #FF9F55;
              top: 15px;
              border-radius: 50%;
              z-index: 1;
            }
            .entry:nth-child(odd) { left: 0; }
            .entry:nth-child(even) { left: 50%; }
            .entry:nth-child(even)::after { left: -10px; }
            .content {
              padding: 20px;
              background-color: white;
              border-radius: 6px;
              box-shadow: 0 0 10px rgba(0,0,0,0.1);
            }
          </style>
        </head>
        <body>
          <h1>Document Timeline - <%= title %></h1>
          <div class="timeline">
            <% history.each do |entry| %>
              <div class="entry">
                <div class="content">
                  <h3><%= entry.type.to_s.gsub('_', ' ').capitalize %></h3>
                  <p><%= entry.timestamp.strftime('%Y-%m-%d %H:%M:%S') %></p>
                  <% if entry.actor_id %>
                    <p>Actor: <%= entry.actor_id %></p>
                  <% end %>
                  <pre><%= JSON.pretty_generate(entry.details) %></pre>
                </div>
              </div>
            <% end %>
          </div>
        </body>
        </html>
      HTML
      template.result(binding)
    end

    protected

    def validate_transition(from:, to:)
      super
      
      # Validate state sequence
      valid_transitions = {
        draft: [:pending_review],
        pending_review: [:reviewed],
        reviewed: [:approved, :rejected],
        approved: [],
        rejected: [:draft]  # Allow resubmission
      }

      unless valid_transitions[from&.to_sym]&.include?(to.to_sym)
        raise StateError, "Cannot transition from #{from} to #{to}"
      end
    end
  end
end
