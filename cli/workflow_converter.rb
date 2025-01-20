#!/usr/bin/env ruby

require 'yaml'
require 'optparse'

class WorkflowConverter
  class << self
    def dsl_to_yaml(dsl_content)
      # Extract states from DSL
      states = extract_states(dsl_content)
      transitions = extract_transitions(dsl_content)

      # Create YAML structure
      workflow = {
        'object_type' => extract_object_type(dsl_content),
        'places' => {
          'states' => states
        },
        'transitions' => {
          'regular' => transitions
        }
      }

      # Convert to YAML
      YAML.dump(workflow)
    end

    def yaml_to_dsl(yaml_content)
      workflow = YAML.safe_load(yaml_content)
      
      # Generate DSL content
      dsl = []
      dsl << "require_relative '../../lib/circuit_breaker'"
      dsl << ""
      dsl << "# Generated workflow definition"
      dsl << "CircuitBreaker::WorkflowBuilder::DSL.define do"
      
      # Add states
      states = workflow.dig('places', 'states') || []
      dsl << "  # Define all possible states"
      dsl << "  states #{states.map(&:to_sym).join(', ')}"
      dsl << ""
      
      # Add transitions
      dsl << "  # Define transitions with requirements"
      transitions = workflow.dig('transitions', 'regular') || []
      transitions.each do |transition|
        from = transition['from']
        to = transition['to']
        name = transition['name']
        requires = transition['requires'] || []
        actions = transition['actions'] || []
        
        dsl << "  flow :#{from} >> :#{to}, :#{name.downcase} do"

        # Add actions if present
        unless actions.empty?
          dsl << "    actions do"
          actions.each do |action|
            dsl << "      execute #{action['executor']}, :#{action['method']}, :#{action['result']}"
          end
          dsl << "    end"
        end

        # Add requirements if present
        unless requires.empty?
          dsl << "    policy all: [#{requires.map { |r| ":#{r}" }.join(', ')}]"
        end
        dsl << "  end"
        dsl << ""
      end
      
      dsl << "end"
      dsl.join("\n")
    end

    private

    def extract_transitions(dsl_content)
      transitions = []
      
      # Split content into flow blocks
      flow_blocks = dsl_content.split(/\s*flow\s+/)
      flow_blocks.shift  # Remove everything before first flow

      flow_blocks.each do |block|
        # Extract transition details for blocks with content
        if block =~ /^:(\w+)\s*>>\s*:(\w+),\s*:(\w+)\s*do(.*)/m
          from, to, name, content = $1, $2, $3, $4
          
          # Extract requirements
          reqs = []
          if content =~ /policy.*?all:\s*\[(.*?)\]/m
            reqs += $1.scan(/:(\w+)/).flatten
          end
          if content =~ /any:\s*\[(.*?)\]/m
            reqs += $1.scan(/:(\w+)/).flatten
          end

          # Extract actions
          actions = []
          if content =~ /actions\s+do(.*?)end/m
            actions_block = $1
            actions_block.scan(/execute\s+(\w+),\s*:(\w+),\s*:(\w+)/) do |executor, method, result|
              actions << {
                'executor' => executor,
                'method' => method,
                'result' => result
              }
            end
          end

          transition = {
            'name' => name,
            'from' => from,
            'to' => to,
            'requires' => reqs.uniq,
            'actions' => actions
          }
          transitions << transition
        # Extract simple transitions without do blocks
        elsif block =~ /^:(\w+)\s*>>\s*:(\w+),\s*:(\w+)\s*$/
          from, to, name = $1, $2, $3
          transition = {
            'name' => name,
            'from' => from,
            'to' => to,
            'requires' => [],
            'actions' => []
          }
          transitions << transition
        end
      end

      transitions
    end

    def extract_states(dsl_content)
      # Find states line and extract state names
      if dsl_content =~ /states\s+(.*?)(?=\s*flow)/m
        states_line = $1
        states = []
        states_line.scan(/:(\w+)/) do |state|
          state_name = state[0]
          next if state_name =~ /^(all|any)$/  # Skip policy keywords
          next if state_name =~ /^(submit|review|approve|reject|revise)$/  # Skip action names
          states << state_name
        end
        states
      else
        []
      end
    end

    def extract_object_type(dsl_content)
      # Try to extract object type from comments or module name
      if dsl_content =~ /Example of a (\w+) workflow/i
        $1.downcase
      elsif dsl_content =~ /module\s+(\w+)\s*$/m
        $1.downcase
      else
        'workflow'
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  options = {}
  
  OptionParser.new do |opts|
    opts.banner = "Usage: workflow_converter.rb [options]"

    opts.on("-d", "--dsl FILE", "Input DSL file") do |file|
      options[:dsl_file] = file
    end

    opts.on("-y", "--yaml FILE", "Input YAML file") do |file|
      options[:yaml_file] = file
    end

    opts.on("-o", "--output FILE", "Output file") do |file|
      options[:output_file] = file
    end

    opts.on("-h", "--help", "Show this help message") do
      puts opts
      exit
    end
  end.parse!

  if options[:dsl_file] && options[:yaml_file]
    puts "Error: Cannot specify both DSL and YAML input files"
    exit 1
  end

  if !options[:dsl_file] && !options[:yaml_file]
    puts "Error: Must specify either DSL or YAML input file"
    exit 1
  end

  if !options[:output_file]
    puts "Error: Must specify output file"
    exit 1
  end

  begin
    if options[:dsl_file]
      # Convert DSL to YAML
      dsl_content = File.read(options[:dsl_file])
      yaml_content = WorkflowConverter.dsl_to_yaml(dsl_content)
      File.write(options[:output_file], yaml_content)
      puts "Successfully converted DSL to YAML: #{options[:output_file]}"
    else
      # Convert YAML to DSL
      yaml_content = File.read(options[:yaml_file])
      dsl_content = WorkflowConverter.yaml_to_dsl(yaml_content)
      File.write(options[:output_file], dsl_content)
      puts "Successfully converted YAML to DSL: #{options[:output_file]}"
    end
  rescue => e
    puts "Error: #{e.message}"
    exit 1
  end
end
