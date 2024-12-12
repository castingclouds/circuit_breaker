require 'nats/client'
require 'json'
require_relative '../config/nats_config'

module CircuitBreaker
  module Functions
    class BaseFunction
      attr_reader :nats, :js
      
      def initialize
        @nats = Config.nats_connection
        @js = Config.jetstream
      end
      
      def subscribe(subject)
        js.subscribe(subject) do |msg|
          begin
            handle_message(msg)
          rescue StandardError => e
            publish_error(msg, e)
          end
        end
      end
      
      protected
      
      def handle_message(msg)
        raise NotImplementedError, "Subclasses must implement handle_message"
      end
      
      def publish_event(workflow_id, event_type, data = {})
        js.publish("event.#{workflow_id}",
          {
            type: event_type,
            data: data,
            timestamp: Time.now.utc.iso8601
          }.to_json,
          headers: { 'Nats-Msg-Type' => "event.#{event_type}" }
        )
      end
      
      private
      
      def publish_error(msg, error)
        data = JSON.parse(msg.data)
        workflow_id = data['workflow_id']
        
        js.publish("error.#{workflow_id}",
          {
            error: error.message,
            backtrace: error.backtrace,
            original_message: data,
            timestamp: Time.now.utc.iso8601
          }.to_json,
          headers: { 'Nats-Msg-Type' => 'error' }
        )
      end
    end
  end
end
