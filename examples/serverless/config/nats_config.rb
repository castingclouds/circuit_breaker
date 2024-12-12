module CircuitBreaker
  module Config
    NATS_URL = ENV['NATS_URL'] || 'nats://localhost:4222'
    
    def self.nats_connection
      @nats ||= NATS.connect(NATS_URL)
    end
    
    def self.jetstream
      @js ||= begin
        js = nats_connection.jetstream
        setup_streams(js)
        js
      end
    end

    def self.setup_streams(js)
      # Create streams for workflow state and events
      create_stream(js, 'WORKFLOWS', ['workflow.*'])
      create_stream(js, 'WORKFLOW_EVENTS', ['event.*'])
      create_stream(js, 'WORKFLOW_STATES', ['state.*'])
      create_stream(js, 'WORKFLOW_FUNCTIONS', ['function.*'])
      create_stream(js, 'WORKFLOW_ERRORS', ['error.*'])
    end

    def self.create_stream(js, name, subjects)
      begin
        js.stream_info(name)
      rescue NATS::JetStream::Error::NotFound
        js.add_stream(name: name, subjects: subjects)
        puts "Created stream: #{name} with subjects: #{subjects.join(', ')}"
      end
    end
  end
end
