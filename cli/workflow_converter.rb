#!/usr/bin/env ruby

require 'yaml'
require 'optparse'

class WorkflowConverter
  class << self
    def dsl_to_yaml(dsl_content)
      yaml = {
        'object_type' => 'document',
        'places' => {
          'states' => extract_states(dsl_content)
        },
        'transitions' => {
          'regular' => extract_transitions(dsl_content)
        },
        'metadata' => {
          'rules' => []
        }
      }

      yaml.to_yaml
    end

    def yaml_to_dsl(yaml_content)
      workflow = YAML.safe_load(yaml_content)
      
      # Generate DSL content
      dsl = []
      dsl << "require_relative '../../lib/circuit_breaker'"
      dsl << "require_relative 'document_token'"
      dsl << "require_relative 'document_rules'"
      dsl << "require_relative 'mock_executor'"
      dsl << ""
      dsl << "# Example of a document workflow using a more declarative DSL approach"
      dsl << "module Examples"
      dsl << "  module Document"
      dsl << "    module Workflow"
      dsl << "      class DSL"
      dsl << "        def self.run"
      dsl << "          puts \"Starting Document Workflow Example (DSL Version)...\""
      dsl << "          puts \"================================================\\n\""
      dsl << ""
      dsl << "          # Create a document token"
      dsl << "          token = DocumentToken.new"
      dsl << "          puts \"Initial Document State:\""
      dsl << "          puts \"======================\""
      dsl << "          puts \"State: \#{token.state}\\n\\n\""
      dsl << "          puts token.to_json(true)"
      dsl << ""
      dsl << "          puts \"\\nWorkflow Definition:\""
      dsl << "          puts \"===================\\n\""
      dsl << ""
      dsl << "          # Initialize document-specific rules and assistant"
      dsl << "          rules = Rules.define"
      dsl << "          mock = MockExecutor.new"
      dsl << ""
      dsl << "          workflow = CircuitBreaker::WorkflowBuilder::DSL.define(rules: rules) do"
      
      # Add states
      states = workflow.dig('places', 'states') || []
      dsl << "            # Define all possible document states"
      dsl << "            # The first state listed becomes the initial state"
      state_comments = {
        'Draft' => 'Initial state when document is created',
        'Pending Review' => 'Document submitted and awaiting review',
        'Reviewed' => 'Document has been reviewed with comments',
        'Approved' => 'Document has been approved by approver',
        'Rejected' => 'Document was rejected and needs revision'
      }
      states_list = states.map { |s| 
        name = s['name'].downcase.gsub(' ', '_')
        comment = state_comments[s['name']] || ''
        comment.empty? ? ":#{name}" : "#{':' + name.ljust(15)}# #{comment}"
      }.join(",\n" + " " * 18)
      dsl << "            states #{states_list}"
      dsl << ""
      
      # Add transitions
      dsl << "            # Define transitions with required rules"
      transitions = workflow.dig('transitions', 'regular') || []
      transitions.each do |transition|
        from = transition['from'].downcase.gsub(' ', '_')
        to = transition['to'].downcase.gsub(' ', '_')
        name = transition['name'].downcase
        policy = transition['policy'] || {}
        actions = transition['actions'] || []
        
        if actions.empty? && policy.empty?
          dsl << "            # Simple transition without requirements"
          dsl << "            flow :#{from} >> :#{to}, :#{name}"
        else
          dsl << "            flow :#{from} >> :#{to}, :#{name} do"

          # Add policy requirements if present
          if policy['all']&.any? || policy['any']&.any?
            dsl << "              policy"
            if policy['all']&.any?
              all_reqs = policy['all'].map { |r| ":#{r}" }.join(', ')
              dsl << "                all #{all_reqs}"
            end
            if policy['any']&.any?
              any_reqs = policy['any'].map { |r| ":#{r}" }.join(', ')
              dsl << "                any #{any_reqs}"
            end
            dsl << "              end"
          end

          # Add actions if present
          actions.each do |action|
            dsl << "              actions do"
            action['executor'].each do |executor|
              dsl << "                execute mock, :#{executor['method']}, :#{executor['result']}"
            end
            dsl << "              end"
          end
          dsl << "            end"
        end
        dsl << ""
      end
      
      dsl << "          end"
      dsl << ""
      dsl << "          puts workflow.to_json(true)"
      dsl << "          puts \"\\nWorkflow created successfully!\""
      dsl << "        end"
      dsl << "      end"
      dsl << "    end"
      dsl << "  end"
      dsl << "end"
      
      dsl.join("\n")
    end

    private

    def extract_object_type(dsl_content)
      # For now, hardcode as 'document' since it's a document workflow
      'document'
    end

    def extract_states(dsl_content)
      # Extract states from the DSL content
      states_section = dsl_content.match(/states\s+(.*?)(?=flow|\Z)/m)
      return [] unless states_section

      states = []
      states_str = states_section[1].strip
      
      # Split by commas and extract state names, handling multiline
      states_str.split(/,\s*\n*/).each do |state_str|
        if state_str =~ /:(\w+)/
          states << { 'name' => $1.gsub('_', ' ').capitalize }
        end
      end
      
      states
    end

    def extract_transitions(dsl_content)
      transitions = []
      current_transition = nil
      current_policy = nil
      current_actions = nil
      in_policy = false
      in_actions = false

      dsl_content.each_line do |line|
        line.strip!
        next if line.empty? || line.start_with?('#')

        # Start of a new transition
        if match = line.match(/^\s*flow\s+:(\w+)\s*>>\s*:(\w+)\s*,\s*:(\w+)/)
          # Save previous transition if exists
          if current_transition
            current_transition['policy'] = current_policy if current_policy
            current_transition['actions'] = current_actions if current_actions
            transitions << current_transition
          end

          # Start new transition
          current_transition = {
            'name' => match[3].gsub('_', ' '),
            'from' => match[1].gsub('_', ' ').capitalize,
            'to' => match[2].gsub('_', ' ').capitalize
          }
          current_policy = nil
          current_actions = nil
          in_policy = false
          in_actions = false
          next
        end

        next unless current_transition

        # Policy section
        if line =~ /^\s*policy\s*$/
          in_policy = true
          in_actions = false
          current_policy = {}
          next
        end

        # Actions section
        if line =~ /^\s*actions\s+do\s*$/
          in_policy = false
          in_actions = true
          current_actions = []
          next
        end

        # End of policy or actions
        if line =~ /^\s*end\s*$/
          if in_policy
            in_policy = false
          elsif in_actions
            in_actions = false
          end
          next
        end

        # Inside policy section
        if in_policy
          if match = line.match(/^\s*all\s+(.+)$/)
            current_policy['all'] = match[1].scan(/:(\w+)/).flatten
          elsif match = line.match(/^\s*any\s+(.+)$/)
            current_policy['any'] = match[1].scan(/:(\w+)/).flatten
          end
        end

        # Inside actions section
        if in_actions && (match = line.match(/^\s*execute\s+\w+,\s*:(\w+),\s*:(\w+)/))
          current_actions << {
            'executor' => [{
              'name' => 'mock',
              'method' => match[1],
              'result' => match[2]
            }]
          }
        end
      end

      # Add the last transition
      if current_transition
        current_transition['policy'] = current_policy if current_policy
        current_transition['actions'] = current_actions if current_actions
        transitions << current_transition
      end

      transitions
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  options = {}
  
  OptionParser.new do |opts|
    opts.banner = "Usage: workflow_converter.rb [options]"
    
    opts.on("-d", "--dsl FILE", "DSL input file") do |file|
      options[:dsl_file] = file
    end
    
    opts.on("-y", "--yaml FILE", "YAML input file") do |file|
      options[:yaml_file] = file
    end
    
    opts.on("-o", "--output FILE", "Output file") do |file|
      options[:output_file] = file
    end
  end.parse!

  if options[:dsl_file]
    # Convert DSL to YAML
    dsl_content = File.read(options[:dsl_file])
    yaml_content = WorkflowConverter.dsl_to_yaml(dsl_content)
    
    if options[:output_file]
      File.write(options[:output_file], yaml_content)
    else
      puts yaml_content
    end
  elsif options[:yaml_file]
    # Convert YAML to DSL
    yaml_content = File.read(options[:yaml_file])
    dsl_content = WorkflowConverter.yaml_to_dsl(yaml_content)
    
    if options[:output_file]
      File.write(options[:output_file], dsl_content)
    else
      puts dsl_content
    end
  else
    puts "Error: Must specify either --dsl or --yaml input file"
    exit 1
  end
end
