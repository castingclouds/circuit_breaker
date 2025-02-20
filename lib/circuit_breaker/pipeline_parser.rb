require_relative 'tools/tool'

module CircuitBreaker
  class PipelineParser
    def initialize
      @imports = {}
      @pipelines = {}
    end

    def parse(content)
      CircuitBreaker::Logger.debug("Starting to parse pipeline file")
      parse_imports(content)
      parse_pipelines(content)
      find_pipeline_to_run(content)
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

    def parse_pipelines(content)
      CircuitBreaker::Logger.debug("Parsing pipeline definitions")
      CircuitBreaker::Logger.debug("Content: #{content}")
      
      # Find all pipeline blocks
      start_pos = 0
      while (match = content.match(/pipeline\s+(\w+)\s*\{/m, start_pos))
        name = match[1]
        block_start = match.end(0)
        CircuitBreaker::Logger.debug("Found pipeline '#{name}' starting at position #{block_start}")
        
        # Find the matching closing brace
        brace_count = 1
        pos = block_start
        while brace_count > 0 && pos < content.length
          case content[pos]
          when '{'
            brace_count += 1
            CircuitBreaker::Logger.debug("  Found opening brace at #{pos}, count = #{brace_count}")
          when '}'
            brace_count -= 1
            CircuitBreaker::Logger.debug("  Found closing brace at #{pos}, count = #{brace_count}")
          end
          pos += 1
        end
        
        if brace_count == 0
          pipeline_content = content[block_start...pos-1]
          CircuitBreaker::Logger.debug("Found pipeline: #{name}")
          CircuitBreaker::Logger.debug("Pipeline content: #{pipeline_content}")
          
          # Extract the execute block
          if (execute_match = pipeline_content.match(/execute\s*\{/m))
            execute_start = execute_match.end(0)
            CircuitBreaker::Logger.debug("Found execute block starting at #{execute_start}")
            
            # Find the matching closing brace
            brace_count = 1
            pos = execute_start
            while brace_count > 0 && pos < pipeline_content.length
              case pipeline_content[pos]
              when '{'
                brace_count += 1
                CircuitBreaker::Logger.debug("  Found opening brace at #{pos}, count = #{brace_count}")
              when '}'
                brace_count -= 1
                CircuitBreaker::Logger.debug("  Found closing brace at #{pos}, count = #{brace_count}")
              end
              pos += 1
            end
            
            if brace_count == 0
              execute_content = pipeline_content[execute_start...pos-1].strip
              CircuitBreaker::Logger.debug("Execute content: #{execute_content}")
              
              # Parse actions
              actions = []
              action_start = 0
              while (action_match = execute_content.match(/(\w+)\s*=>\s*(\w+)\s*\{/m, action_start))
                tool = action_match[1]
                action = action_match[2]
                params_start = action_match.end(0)
                CircuitBreaker::Logger.debug("Found action '#{tool} => #{action}' starting at #{params_start}")
                
                # Find the matching closing brace
                brace_count = 1
                pos = params_start
                while brace_count > 0 && pos < execute_content.length
                  case execute_content[pos]
                  when '{'
                    brace_count += 1
                    CircuitBreaker::Logger.debug("  Found opening brace at #{pos}, count = #{brace_count}")
                  when '}'
                    brace_count -= 1
                    CircuitBreaker::Logger.debug("  Found closing brace at #{pos}, count = #{brace_count}")
                  end
                  pos += 1
                end
                
                if brace_count == 0
                  params = execute_content[params_start...pos-1].strip
                  CircuitBreaker::Logger.debug("  Found action: #{tool} => #{action}")
                  CircuitBreaker::Logger.debug("  Parameters: #{params}")
                  
                  parameters = parse_parameters(params)
                  CircuitBreaker::Logger.debug("  Parsed parameters: #{parameters.inspect}")
                  actions << [tool, action, parameters]
                  action_start = pos
                else
                  CircuitBreaker::Logger.debug("  Failed to find closing brace for action parameters")
                  action_start = params_start + 1
                end
              end
              
              CircuitBreaker::Logger.debug("Actions for pipeline #{name}: #{actions.inspect}")
              if !actions.empty?
                @pipelines[name] = actions
                CircuitBreaker::Logger.debug("Added pipeline '#{name}' with #{actions.length} actions")
              else
                CircuitBreaker::Logger.debug("No actions found for pipeline '#{name}'")
              end
            else
              CircuitBreaker::Logger.debug("Failed to find closing brace for execute block")
            end
          else
            CircuitBreaker::Logger.debug("No execute block found in pipeline '#{name}'")
          end
          
          start_pos = pos
        else
          CircuitBreaker::Logger.debug("Failed to find closing brace for pipeline block")
          start_pos = block_start + 1
        end
      end
      
      CircuitBreaker::Logger.debug("Found pipelines: #{@pipelines.keys.join(', ')}")
      CircuitBreaker::Logger.debug("Pipeline contents: #{@pipelines.inspect}")
    end

    def parse_parameters(content)
      CircuitBreaker::Logger.debug("Parsing parameters: #{content}")
      parameters = {}
      
      content.scan(/(\w+)\s*:\s*"([^"]*)"/m) do |key, value|
        CircuitBreaker::Logger.debug("  Found parameter: #{key} = #{value}")
        parameters[key.to_sym] = value
      end
      
      parameters
    end

    def find_pipeline_to_run(content)
      CircuitBreaker::Logger.debug("Looking for pipeline to run")
      CircuitBreaker::Logger.debug("Content: #{content}")
      CircuitBreaker::Logger.debug("Available pipelines: #{@pipelines.keys.join(', ')}")
      
      if content =~ /run\s+(\w+)/
        pipeline_name = $1
        CircuitBreaker::Logger.debug("Found run directive: #{pipeline_name}")
        
        pipeline = @pipelines[pipeline_name]
        unless pipeline
          CircuitBreaker::Logger.error("Pipeline '#{pipeline_name}' not found in available pipelines: #{@pipelines.keys.join(', ')}")
          raise "Pipeline '#{pipeline_name}' not found"
        end
        
        CircuitBreaker::Logger.debug("Found pipeline #{pipeline_name}: #{pipeline.inspect}")
        [pipeline_name, pipeline]
      end
    end
  end
end
