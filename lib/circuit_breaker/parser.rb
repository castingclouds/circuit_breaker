require_relative 'workflow'
require_relative 'tools/tool'
require_relative 'rules'

module CircuitBreaker
  class Parser
    def initialize
      @imports = {}
      @token = nil
      @states = []
      @workflow = nil
    end

    def parse(content)
      CircuitBreaker::Logger.debug("Starting to parse workflow file")
      parse_imports(content)
      parse_token(content)
      parse_states(content)
      parse_workflow(content)
      @workflow
    end

    private

    def parse_imports(content)
      CircuitBreaker::Logger.debug("Parsing imports section")
      if content =~ /^use\s*{([^}]+)}\s*from\s*"([^"]+)"/
        tools = $1
        source = $2
        CircuitBreaker::Logger.debug("Found imports: #{tools} from #{source}")
        
        tools.split(',').map(&:strip).each do |tool|
          CircuitBreaker::Logger.debug("  Registering import: #{tool}")
          @imports[tool] = source
        end
      end
    end

    def parse_token(content)
      CircuitBreaker::Logger.debug("Parsing token section")
      if content =~ /^token\s*{([^}]+)}/m
        token_content = $1
        CircuitBreaker::Logger.debug("Found token content:")
        CircuitBreaker::Logger.debug(token_content)

        data = {}
        token_content.scan(/(\w+):\s*"([^"]+)"/) do |key, value|
          CircuitBreaker::Logger.debug("  Found token field: #{key} = #{value}")
          data[key.to_sym] = value
        end

        @token = Token.new(data)
        CircuitBreaker::Logger.debug("Created token: #{@token.inspect}")
      end
    end

    def parse_states(content)
      CircuitBreaker::Logger.debug("Parsing states section")
      if content =~ /states\s*=\s*\[([^\]]+)\]/
        states_content = $1
        CircuitBreaker::Logger.debug("Found states: #{states_content}")
        
        @states = states_content.scan(/['"]([^'"]+)['"]/).flatten
        CircuitBreaker::Logger.debug("Parsed states: #{@states.inspect}")
      end
    end

    def parse_workflow(content)
      CircuitBreaker::Logger.debug("Parsing workflow section")
      workflow_start = content.index(/workflow\s*{/)
      if workflow_start
        # Find the matching closing brace by counting braces
        depth = 0
        pos = workflow_start
        workflow_content = nil
        
        while pos < content.length
          case content[pos]
          when '{'
            depth += 1
          when '}'
            depth -= 1
            if depth == 0
              workflow_content = content[workflow_start..pos]
              break
            end
          end
          pos += 1
        end

        if workflow_content
          CircuitBreaker::Logger.debug("Found workflow content:")
          CircuitBreaker::Logger.debug(workflow_content)

          @workflow = Workflow.new(token: @token, states: @states)
          parse_transitions(workflow_content[/workflow\s*{(.*)}/m, 1])
        end
      end
    end

    def parse_transitions(content)
      return unless content

      CircuitBreaker::Logger.debug("Parsing transitions")
      pos = 0
      
      while pos < content.length
        # Find next transition
        if content[pos..-1] =~ /\G\s*transition\s*\(([^)]+)\)\s*{/m
          transition_start = pos + $&.length
          spec = $1
          
          # Find matching closing brace
          depth = 1
          pos = transition_start
          
          while pos < content.length
            case content[pos]
            when '{'
              depth += 1
            when '}'
              depth -= 1
              if depth == 0
                body = content[transition_start...pos]
                parse_single_transition(spec, body)
                break
              end
            end
            pos += 1
          end
        else
          pos += 1
        end
      end
    end

    def parse_single_transition(spec, body)
      CircuitBreaker::Logger.debug("\nFound transition: #{spec}")
      CircuitBreaker::Logger.debug("Transition body:")
      CircuitBreaker::Logger.debug(body)

      name, states = parse_transition_spec(spec)
      from_state, to_state = states.split('->').map(&:strip)

      CircuitBreaker::Logger.debug("  Name: #{name}")
      CircuitBreaker::Logger.debug("  From: #{from_state}")
      CircuitBreaker::Logger.debug("  To: #{to_state}")

      actions = parse_actions(body)
      rules = parse_rules(body)

      @workflow.add_transition(
        name: name.strip,
        from: from_state,
        to: to_state,
        actions: actions,
        rules: rules
      )
    end

    def parse_transition_spec(spec)
      parts = spec.split(',').map(&:strip)
      [parts[0], parts[1]]
    end

    def parse_actions(body)
      CircuitBreaker::Logger.debug("  Parsing actions")
      actions = []

      # Find the actions block using balanced brace matching
      if body =~ /actions\s*{/
        start_pos = $&.length + $`.length
        depth = 1
        pos = start_pos
        
        while pos < body.length
          case body[pos]
          when '{'
            depth += 1
          when '}'
            depth -= 1
            if depth == 0
              actions_block = body[start_pos...pos]
              CircuitBreaker::Logger.debug("  Found actions block:")
              CircuitBreaker::Logger.debug(actions_block)

              actions_block.each_line do |line|
                line = line.strip
                next if line.empty?

                if line =~ /(\w+)\s*=>\s*(\w+)/
                  tool_name = $1
                  action_name = $2
                  CircuitBreaker::Logger.debug("    Found action: #{tool_name} => #{action_name}")
                  actions << [tool_name, action_name]
                end
              end
              break
            end
          end
          pos += 1
        end
      end

      CircuitBreaker::Logger.debug("  Parsed actions: #{actions.inspect}")
      actions
    end

    def parse_rules(body)
      CircuitBreaker::Logger.debug("  Parsing rules")
      rules = { all: [], any: [] }

      # Find the policy block using balanced brace matching
      if body =~ /policy\s*{/
        start_pos = $&.length + $`.length
        depth = 1
        pos = start_pos
        
        while pos < body.length
          case body[pos]
          when '{'
            depth += 1
          when '}'
            depth -= 1
            if depth == 0
              policy_block = body[start_pos...pos]
              CircuitBreaker::Logger.debug("  Found policy block:")
              CircuitBreaker::Logger.debug(policy_block)

              # Parse required rules (all)
              if policy_block =~ /all:\s*\[([^\]]+)\]/
                rule_list = $1
                CircuitBreaker::Logger.debug("    Found required rules: #{rule_list}")
                rules[:all] = rule_list.split(',').map(&:strip).map { |name| Rule.new(name) }
              end

              # Parse optional rules (any)
              if policy_block =~ /any:\s*\[([^\]]+)\]/
                rule_list = $1
                CircuitBreaker::Logger.debug("    Found optional rules: #{rule_list}")
                rules[:any] = rule_list.split(',').map(&:strip).map { |name| Rule.new(name) }
              end
              break
            end
          end
          pos += 1
        end
      end

      CircuitBreaker::Logger.debug("  Parsed rules: #{rules.inspect}")
      rules
    end
  end
end
