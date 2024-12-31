require_relative '../../lib/circuit_breaker'
require_relative '../../lib/circuit_breaker/nats_executor'
require_relative '../../lib/circuit_breaker/workflow_dsl'

class Document
  attr_accessor :document_id, :user, :title, :content, :state,
                :reviewer_id, :reviewer_comments, :approver_id

  def initialize(attributes = {})
    attributes.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
    @state ||= 'document_submitted'
  end

  def inspect
    fields = {
      document_id: @document_id,
      state: @state,
      user: @user,
      title: @title,
      content: @content,
      reviewer_id: @reviewer_id,
      reviewer_comments: @reviewer_comments,
      approver_id: @approver_id
    }

    # Find the longest key for padding
    max_key_length = fields.keys.map(&:to_s).map(&:length).max

    output = ["#<#{self.class}"]
    fields.each do |key, value|
      value_str = case value
                 when nil then "nil"
                 when String then "\"#{value}\""
                 else value.to_s
                 end
      
      # Pad the key with spaces for alignment
      padded_key = key.to_s.ljust(max_key_length)
      output << "  #{padded_key}: #{value_str}"
    end
    output << ">"

    output.join("\n")
  end
end

# Define the workflow using DSL
workflow = CircuitBreaker::WorkflowDSL.define do
  # Configure workflow settings
  for_object 'Document'
  
  # Define all possible states
  states :document_submitted, :pending_review, :reviewed, :approved, :rejected

  # Define the flows with their validations
  flow(:document_submitted >> :pending_review).configure do
    via(:start_review)
    requires [:document_id, :user]
  end

  flow(:pending_review >> :reviewed).configure do
    via(:complete_review)
    requires [:reviewer_id, :reviewer_comments]
  end

  flow(:reviewed >> :approved).configure do
    via(:approve)
    requires [:approver_id]
  end

  flow(:reviewed >> :rejected).configure do
    via(:reject)
    requires [:reviewer_comments]
  end
end

# Create workflow instance from DSL definition
wf = CircuitBreaker::Workflow.from_dsl(workflow)

# Create NATS executor
executor = CircuitBreaker::NatsExecutor.new

# Start the workflow
workflow_id = executor.create_workflow(wf)
puts "Created workflow: #{workflow_id}"

# Create initial document
document = Document.new(
  document_id: '123',
  user: 'john.doe',
  title: 'Important Document',
  content: 'This needs review'
)

puts "\nInitial document state:"
puts document.inspect

# Add initial token
executor.add_token(document)

# Example of chaining workflows using DSL
notification_workflow = CircuitBreaker::WorkflowDSL.define do
  states :notification_pending, :notification_sent

  flow(:notification_pending >> :notification_sent).configure do
    via(:send_notification)
    requires [:recipient, :message]
  end
end

next_workflow_config = {
  'workflow' => CircuitBreaker::Workflow.from_dsl(notification_workflow),
  'initial_place' => 'notification_pending'
}

# When the first workflow completes, trigger the next one
executor.complete_workflow(next_workflow_config)
