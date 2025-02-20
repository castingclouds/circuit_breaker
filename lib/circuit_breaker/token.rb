require 'securerandom'
require 'json'
require 'time'

module CircuitBreaker
  class Token
    attr_accessor :id, :title, :content, :author_id, :state
    attr_reader :data, :history

    def initialize(data = {})
      @data = data
      @id = SecureRandom.uuid
      @title = data[:title]
      @content = data[:content]
      @author_id = data[:authorId]
      @state = data[:state] || 'draft'
      @history = []
      add_history_event(nil, @state)
    end

    def update_state(new_state, transition_name)
      begin
        CircuitBreaker::Logger.info("Updating token state from '#{@state}' to '#{new_state}' via '#{transition_name}'")
        old_state = @state
        @state = new_state
        add_history_event(transition_name, new_state, old_state)
        CircuitBreaker::Logger.info("State updated successfully to '#{@state}'")
      rescue StandardError => e
        CircuitBreaker::Logger.error("Error updating token state: #{e.message}")
        raise e
      end
    end

    def add_history_event(transition_name, new_state, old_state = nil)
      begin
        event = {
          timestamp: Time.now.strftime('%Y-%m-%d %H:%M:%S'),
          transition: transition_name,
          from: old_state,
          to: new_state
        }
        @history << event
        CircuitBreaker::Logger.info("Added history event: #{event.inspect}")
      rescue StandardError => e
        CircuitBreaker::Logger.error("Error adding history event: #{e.message}")
        raise e
      end
    end

    def to_h
      {
        id: @id,
        title: @title,
        content: @content,
        authorId: @author_id,
        state: @state,
        history: @history
      }
    end

    def to_json(pretty = false)
      if pretty
        JSON.pretty_generate(to_h)
      else
        to_h.to_json
      end
    end
  end
end
