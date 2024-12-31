module CircuitBreaker
  module History
    class Entry
      attr_reader :timestamp, :type, :details, :actor_id

      def initialize(type:, details:, actor_id: nil)
        @timestamp = Time.now
        @type = type
        @details = details
        @actor_id = actor_id
      end

      def to_h
        {
          timestamp: timestamp,
          type: type,
          details: details,
          actor_id: actor_id
        }
      end
    end

    def self.included(base)
      base.class_eval do
        attr_reader :history

        # Add history initialization to existing initialize method
        original_initialize = instance_method(:initialize)
        define_method(:initialize) do |*args, **kwargs|
          original_initialize.bind(self).call(*args, **kwargs)
          @history = []
          record_event(:created, "Object created")
        end
      end
    end

    def record_event(type, details, actor_id: nil)
      entry = Entry.new(type: type, details: details, actor_id: actor_id)
      @history << entry
      trigger(:history_updated, entry: entry)
      entry
    end

    def history_since(timestamp)
      history.select { |entry| entry.timestamp >= timestamp }
    end

    def history_by_type(type)
      history.select { |entry| entry.type == type }
    end

    def history_by_actor(actor_id)
      history.select { |entry| entry.actor_id == actor_id }
    end

    def export_history(format = :json)
      history_data = history.map(&:to_h)
      case format
      when :json
        JSON.pretty_generate(history_data)
      when :yaml
        history_data.to_yaml
      when :csv
        require 'csv'
        CSV.generate do |csv|
          csv << ['Timestamp', 'Type', 'Details', 'Actor']
          history_data.each do |entry|
            csv << [
              entry[:timestamp].iso8601,
              entry[:type],
              entry[:details],
              entry[:actor_id]
            ]
          end
        end
      else
        raise ArgumentError, "Unsupported format: #{format}"
      end
    end
  end
end
