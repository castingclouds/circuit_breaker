require 'json'
require 'erb'

module CircuitBreaker
  class Visualizer
    TEMPLATES_DIR = File.join(File.dirname(__FILE__), 'templates')

    class << self
      def to_mermaid(token_class)
        transitions = token_class.state_transitions
        states = transitions.keys.concat(transitions.values.flatten).uniq
        validations = token_class.state_validations

        lines = ["stateDiagram-v2"]
        
        # Add states with validation notes
        states.each do |state|
          lines << "    #{state}"
          if validations[state]
            lines << "    note right of #{state}"
            lines << "      Validations:"
            lines << "      - #{validations[state].source_location.first}"
            lines << "    end note"
          end
        end

        # Add transitions with hooks
        transitions.each do |from, to_states|
          to_states.each do |to|
            lines << "    #{from} --> #{to}"
          end
        end

        lines.join("\n")
      end

      def to_dot(token_class)
        transitions = token_class.state_transitions
        validations = token_class.state_validations
        
        lines = ["digraph {"]
        lines << "  rankdir=LR;"
        
        # Style definitions
        lines << "  node [shape=circle];"
        lines << "  edge [fontsize=10];"
        
        # Add states with validation info
        transitions.keys.concat(transitions.values.flatten).uniq.each do |state|
          validation = validations[state] ? "with validation" : "no validation"
          lines << "  #{state} [label=\"#{state}\\n#{validation}\"];"
        end
        
        # Add transitions
        transitions.each do |from, to_states|
          to_states.each do |to|
            lines << "  #{from} -> #{to};"
          end
        end
        
        lines << "}"
        lines.join("\n")
      end

      def to_plantuml(token_class)
        transitions = token_class.state_transitions
        validations = token_class.state_validations

        lines = ["@startuml"]
        lines << "skinparam monochrome true"
        lines << "skinparam defaultFontName Arial"
        
        # Add states
        transitions.keys.concat(transitions.values.flatten).uniq.each do |state|
          if validations[state]
            lines << "state #{state} {"
            lines << "  note right: Has validations"
            lines << "}"
          else
            lines << "state #{state}"
          end
        end
        
        # Add transitions
        transitions.each do |from, to_states|
          to_states.each do |to|
            lines << "#{from} --> #{to}"
          end
        end
        
        lines << "@enduml"
        lines.join("\n")
      end

      def to_html(token_class, engine = :mermaid)
        case engine
        when :mermaid
          diagram = to_mermaid(token_class)
          template_path = File.join(TEMPLATES_DIR, 'mermaid.html.erb')
        when :plantuml
          diagram = to_plantuml(token_class)
          template_path = File.join(TEMPLATES_DIR, 'plantuml.html.erb')
        else
          raise ArgumentError, "Unsupported engine: #{engine}"
        end

        template = ERB.new(File.read(template_path))
        template.result(binding)
      end

      def to_markdown(token_class)
        transitions = token_class.state_transitions
        validations = token_class.state_validations
        
        lines = ["# State Machine Documentation"]
        lines << "\n## States"
        
        # Document states and their validations
        transitions.keys.concat(transitions.values.flatten).uniq.sort.each do |state|
          lines << "\n### #{state}"
          if validation = validations[state]
            lines << "\nValidations:"
            lines << "```ruby"
            lines << validation.source
            lines << "```"
          end
        end
        
        # Document transitions
        lines << "\n## Transitions"
        transitions.each do |from, to_states|
          lines << "\n### From: #{from}"
          lines << "\nCan transition to:"
          to_states.sort.each do |to|
            lines << "- #{to}"
          end
        end
        
        # Add Mermaid diagram
        lines << "\n## Visual Representation"
        lines << "\n```mermaid"
        lines << to_mermaid(token_class)
        lines << "```"
        
        lines.join("\n")
      end

      def save(token_class, format:, filename:)
        content = case format
                 when :mermaid
                   to_mermaid(token_class)
                 when :dot
                   to_dot(token_class)
                 when :plantuml
                   to_plantuml(token_class)
                 when :html
                   to_html(token_class)
                 when :markdown
                   to_markdown(token_class)
                 else
                   raise ArgumentError, "Unsupported format: #{format}"
                 end

        File.write(filename, content)
      end
    end
  end
end
