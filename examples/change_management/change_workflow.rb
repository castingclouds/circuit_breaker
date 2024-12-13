#!/usr/bin/env ruby

require_relative '../../lib/circuit_breaker'
require_relative '../../lib/circuit_breaker/workflow_dsl'
require_relative '../../lib/circuit_breaker/nats_executor'

class Issue
  class Builder
    def initialize
      @attributes = { state: 'backlog' }
    end

    def id(value)
      @attributes[:id] = value
      self
    end

    def title(value)
      @attributes[:title] = value
      self
    end

    def description(value)
      @attributes[:description] = value
      self
    end

    def assignee(value)
      @attributes[:assignee] = value
      self
    end

    def story_points(value)
      @attributes[:story_points] = value
      self
    end

    def sprint(value)
      @attributes[:sprint] = value
      self
    end

    def pull_request(url)
      @attributes[:pull_request_url] = url
      self
    end

    def test_coverage(value)
      @attributes[:test_coverage] = value
      self
    end

    def qa_approved(value = true)
      @attributes[:qa_approved] = value
      self
    end

    def review_approvals(value)
      @attributes[:review_approvals] = value
      self
    end

    def deployment_approved(value = true)
      @attributes[:deployment_approved] = value
      self
    end

    def review_comments(value)
      @attributes[:review_comments] = value
      self
    end

    def test_failure(reason)
      @attributes[:test_failure_reason] = reason
      self
    end

    def block(reason)
      @attributes[:blocking_reason] = reason
      self
    end

    def unblock(reason)
      @attributes[:unblocking_reason] = reason
      self
    end

    def priority(value)
      @attributes[:priority] = value
      self
    end

    def build
      Issue.new(@attributes)
    end
  end

  class << self
    def create
      builder = Builder.new
      yield(builder) if block_given?
      builder.build
    end
  end

  VALIDATIONS = {
    required: ->(value, _) { !value.nil? },
    min_value: ->(value, min) { value.to_i >= min }
  }.freeze

  attr_accessor :id, :title, :description, :assignee, :story_points,
                :sprint, :pull_request_url, :test_coverage, :qa_approved,
                :review_approvals, :deployment_approved, :review_comments,
                :test_failure_reason, :blocking_reason, :unblocking_reason,
                :priority, :state

  protected

  def initialize(attributes = {})
    attributes.each do |key, value|
      send("#{key}=", value)
    end
  end

  def validate_for_state(state, conditions)
    conditions.each do |condition|
      field = condition['field']
      field_value = send(field)
      
      condition.each do |validation_type, validation_value|
        next if validation_type == 'field'
        validator = VALIDATIONS[validation_type.to_sym]
        next unless validator
        
        unless validator.call(field_value, validation_value)
          raise validation_message(field, validation_type, validation_value, state)
        end
      end
    end
    true
  end

  private

  def validation_message(field, type, value, state)
    case type.to_sym
    when :required
      "#{field} is required for state #{state}"
    when :min_value
      "#{field} must be at least #{value} for state #{state}"
    else
      "Invalid #{field} for state #{state}"
    end
  end
end

# Try to load the YAML configuration first
yaml_path = File.join(__dir__, 'change_workflow.yml')
workflow = if File.exist?(yaml_path)
  puts "Using YAML configuration from #{yaml_path}"
  CircuitBreaker::WorkflowDSL.load_yaml(yaml_path)
else
  puts "YAML configuration not found, using Ruby DSL"
  CircuitBreaker::WorkflowDSL.define('Issue') do
    # Define all possible states
    states :backlog, :sprint_planning, :sprint_backlog,
          :in_progress, :in_review, :testing, :done

    # Define special states that can be entered from multiple places
    special_states :blocked

    # Define validations for each state
    validate :sprint_planning do |issue|
      raise "Description required" if issue.description.nil?
      raise "Assignee required" if issue.assignee.nil?
    end

    validate :in_progress do |issue|
      raise "Story points required" if issue.story_points.nil?
      raise "Sprint required" if issue.sprint.nil?
    end

    validate :in_review do |issue|
      raise "Pull request URL required" if issue.pull_request_url.nil?
    end

    validate :testing do |issue|
      raise "Test coverage must be at least 80%" if issue.test_coverage.to_i < 80
      raise "QA approval required" if !issue.qa_approved
    end

    # Define the main flow of the workflow
    flow from: :backlog, to: :sprint_planning, via: :move_to_sprint do |issue|
      raise "Description required" if issue.description.nil?
      raise "Priority required" if issue.priority.nil?
    end

    flow from: :sprint_planning, to: :sprint_backlog, via: :plan_issue do |issue|
      raise "Story points required" if issue.story_points.nil?
      raise "Sprint required" if issue.sprint.nil?
    end

    flow from: :sprint_backlog, to: :in_progress, via: :start_work do |issue|
      raise "Assignee required" if issue.assignee.nil?
    end

    flow from: :in_progress, to: :in_review, via: :submit_for_review do |issue|
      raise "Pull request URL required" if issue.pull_request_url.nil?
    end

    flow from: :in_review, to: :testing, via: :approve_review do |issue|
      raise "Review approvals required" if issue.review_approvals.nil?
      raise "Test coverage required" if issue.test_coverage.nil?
    end

    flow from: :testing, to: :done, via: :pass_testing do |issue|
      raise "QA approval required" if !issue.qa_approved
      raise "Deployment approval required" if !issue.deployment_approved
    end

    # Define reverse flows
    flow from: :in_review, to: :in_progress, via: :reject_review do |issue|
      raise "Review comments required" if issue.review_comments.nil?
    end

    flow from: :testing, to: :in_progress, via: :fail_testing do |issue|
      raise "Test failure reason required" if issue.test_failure_reason.nil?
    end

    # Define blocking flows
    multi_flow from: [:sprint_backlog, :in_progress, :in_review, :testing],
              to: :blocked,
              via: :block_issue do |issue|
      raise "Blocking reason required" if issue.blocking_reason.nil?
    end

    # Define unblocking flows
    multi_flow from: :blocked,
              to_states: [:sprint_backlog, :in_progress, :in_review, :testing],
              via: :unblock_issue do |issue|
      raise "Unblocking reason required" if issue.unblocking_reason.nil?
    end

    # Configure workflow settings
    connection nats_url: ENV['NATS_URL'] || 'nats://localhost:4222'
    
    metrics enabled: true,
            prometheus_port: 9090,
            labels: {
              app: 'change_management',
              env: 'development'
            }
    
    logging level: 'info',
            format: 'json',
            output: 'stdout'
  end
end

# Create a sample issue using the new DSL
issue = Issue.create do |i|
  i.id(1)
   .title('Implement new feature')
   .description('Add workflow validation')
   .priority('high')
   .story_points(5)
   .sprint('Sprint 23')
   .assignee('John Doe')
end

# Create and start the workflow with the issue object
workflow_instance = CircuitBreaker::Workflow.new(workflow)
workflow_instance.start(issue)

# Example of moving the issue through the workflow with the new DSL
puts "\nMoving issue through workflow..."

workflow_instance.fire_transition('move_to_sprint')
puts "Moved to sprint planning"

issue = Issue.create do |i|
  i.id(1)
   .title('Implement new feature')
   .description('Add workflow validation')
   .priority('high')
   .story_points(5)
   .sprint('Sprint 23')
   .assignee('John Doe')
   .pull_request('https://github.com/org/repo/pull/123')
   .test_coverage(85)
   .qa_approved
   .review_approvals(2)
   .deployment_approved
end

workflow_instance.fire_transition('plan_issue')
puts "Planned issue"

workflow_instance.fire_transition('start_work')
puts "Started work"

workflow_instance.fire_transition('submit_for_review')
puts "Submitted for review"

workflow_instance.fire_transition('approve_review')
puts "Review approved"

workflow_instance.fire_transition('pass_testing')
puts "Testing passed"

puts "\nWorkflow completed - issue is done!"
