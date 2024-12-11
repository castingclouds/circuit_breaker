module PetriWorkflow
  module Config
    NATS_URL = ENV['NATS_URL'] || 'nats://localhost:4222'
    
    def self.nats_connection
      @nats ||= NATS.connect(NATS_URL)
    end
    
    def self.jetstream
      @js ||= nats_connection.jetstream
    end
  end
end
