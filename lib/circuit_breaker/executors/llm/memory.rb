module CircuitBreaker
  module Executors
    module LLM
      class Memory
        attr_reader :messages, :metadata

        def initialize
          @messages = []
          @metadata = {}
        end

        def add_message(role:, content:, metadata: {})
          message = {
            role: role,
            content: content,
            timestamp: Time.now.utc,
            metadata: metadata
          }
          @messages << message
          message
        end

        def get_context(window_size: nil)
          messages_to_return = window_size ? @messages.last(window_size) : @messages
          messages_to_return.map { |m| "#{m[:role]}: #{m[:content]}" }.join("\n")
        end

        def clear
          @messages.clear
          @metadata.clear
        end

        def to_h
          {
            messages: @messages,
            metadata: @metadata
          }
        end
      end

      class ConversationMemory < Memory
        def initialize(system_prompt: nil)
          super()
          add_message(role: 'system', content: system_prompt) if system_prompt
        end

        def add_user_message(content, metadata: {})
          add_message(role: 'user', content: content, metadata: metadata)
        end

        def add_assistant_message(content, metadata: {})
          add_message(role: 'assistant', content: content, metadata: metadata)
        end
      end

      class ChainMemory < Memory
        def initialize
          super
          @intermediate_steps = []
        end

        def add_step_result(step_name:, input:, output:, metadata: {})
          @intermediate_steps << {
            step_name: step_name,
            input: input,
            output: output,
            timestamp: Time.now.utc,
            metadata: metadata
          }
        end

        def get_step_history
          @intermediate_steps
        end

        def to_h
          super.merge(intermediate_steps: @intermediate_steps)
        end
      end
    end
  end
end
