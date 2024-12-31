#!/usr/bin/env ruby

require_relative '../../lib/circuit_breaker'
require_relative '../../lib/circuit_breaker/workflow_dsl'
require_relative '../../lib/circuit_breaker/nats_executor'

class Issue
  attr_accessor :id, :title, :description, :assignee, :story_points, 
                :sprint, :pull_request_url, :test_coverage, :state,
                :reviewer_comments, :test_results

  def initialize(attributes = {})
    attributes.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
    @state ||= 'backlog'
  end

  def inspect
    fields = {
      id: @id,
      state: @state,
      title: @title,
      description: @description,
      assignee: @assignee,
      story_points: @story_points,
      sprint: @sprint,
      pull_request_url: @pull_request_url,
      test_coverage: @test_coverage,
      reviewer_comments: @reviewer_comments,
      test_results: @test_results
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
  for_object 'Issue'
  
  # Define all possible states
  states :backlog, :sprint_planning, :in_progress, :review, :testing, :done

  # Define the flows with their validations
  flow(:backlog >> :sprint_planning).configure do
    via(:plan_sprint)
    requires [:story_points]
    
    validate do |issue|
      !issue.story_points.nil? && issue.story_points > 0
    end
  end

  flow(:sprint_planning >> :in_progress).configure do
    via(:start_work)
    requires [:assignee]
    
    validate do |issue|
      !issue.assignee.nil? && !issue.assignee.empty?
    end
  end

  flow(:in_progress >> :review).configure do
    via(:submit_pr)
    requires [:pull_request_url]
    
    validate do |issue|
      !issue.pull_request_url.nil? && !issue.pull_request_url.empty?
    end
  end

  flow(:review >> :testing).configure do
    via(:approve_review)
    requires [:reviewer_comments]
    
    validate do |issue|
      !issue.reviewer_comments.nil? && !issue.reviewer_comments.empty?
    end
  end

  flow(:testing >> :done).configure do
    via(:pass_testing)
    requires [:test_coverage, :test_results]
    
    validate do |issue|
      !issue.test_coverage.nil? && issue.test_coverage >= 80 &&
        !issue.test_results.nil? && issue.test_results == 'pass'
    end
  end
end

# Create workflow instance from DSL definition
workflow_instance = CircuitBreaker::Workflow.from_dsl(workflow)

# Create a sample issue
issue = Issue.new(
  id: 'PROJ-123',
  title: 'Implement new feature',
  description: 'Add support for workflow DSL',
  story_points: 5
)

puts "\nInitial issue state:"
puts issue.inspect

# Start the workflow with the issue
workflow_instance.add_token(issue)

# Plan sprint
begin
  workflow_instance.fire_transition('plan_sprint', issue)
  puts "\nAfter sprint planning:"
  puts issue.inspect
rescue StandardError => e
  puts "\nSprint planning failed:"
  puts "Error: #{e.message}"
  puts issue.inspect
end

# Start work
begin
  issue.assignee = "john.doe"
  workflow_instance.fire_transition('start_work', issue)
  puts "\nAfter starting work:"
  puts issue.inspect
rescue StandardError => e
  puts "\nStarting work failed:"
  puts "Error: #{e.message}"
  puts issue.inspect
end

# Submit PR
begin
  issue.pull_request_url = "https://github.com/org/repo/pull/123"
  workflow_instance.fire_transition('submit_pr', issue)
  puts "\nAfter submitting PR:"
  puts issue.inspect
rescue StandardError => e
  puts "\nSubmitting PR failed:"
  puts "Error: #{e.message}"
  puts issue.inspect
end

# Approve review
begin
  issue.reviewer_comments = "Code looks good, approved!"
  workflow_instance.fire_transition('approve_review', issue)
  puts "\nAfter review approval:"
  puts issue.inspect
rescue StandardError => e
  puts "\nReview approval failed:"
  puts "Error: #{e.message}"
  puts issue.inspect
end

# Pass testing
begin
  issue.test_coverage = 85
  issue.test_results = 'pass'
  workflow_instance.fire_transition('pass_testing', issue)
  puts "\nAfter passing tests:"
  puts issue.inspect
rescue StandardError => e
  puts "\nTesting failed:"
  puts "Error: #{e.message}"
  puts issue.inspect
end
