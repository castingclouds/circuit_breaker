require 'nats/client'
require 'securerandom'
require 'json'

module PetriWorkflow
  class NatsExecutor
    attr_reader :workflow_id, :nats

    def initialize(nats_url: 'nats://localhost:4222')
      @nats = NATS.connect(nats_url)
      setup_jetstream
    end

    def setup_jetstream
      @js = @nats.jetstream
      
      # Create streams for workflow state and events
      @js.add_stream(name: 'WORKFLOWS', subjects: ['workflow.*'])
      @js.add_stream(name: 'WORKFLOW_EVENTS', subjects: ['event.*'])
      @js.add_stream(name: 'WORKFLOW_STATES', subjects: ['state.*'])
    end

    def create_workflow(petri_net, workflow_id: nil)
      @workflow_id = workflow_id || SecureRandom.uuid
      
      # Store initial workflow state
      @js.publish("workflow.#{@workflow_id}", 
        petri_net.to_json,
        headers: { 'Nats-Msg-Type' => 'workflow.create' }
      )
      
      # Subscribe to workflow events
      @nats.subscribe("event.#{@workflow_id}") do |msg, reply, subject|
        handle_event(msg)
      end
      
      @workflow_id
    end

    def handle_event(msg)
      event = JSON.parse(msg)
      
      case event['type']
      when 'token_added'
        handle_token_added(event)
      when 'transition_fired'
        handle_transition_fired(event)
      when 'workflow_completed'
        handle_workflow_completed(event)
      end
    end

    def handle_token_added(event)
      # Publish state change
      @js.publish("state.#{@workflow_id}",
        event.to_json,
        headers: { 'Nats-Msg-Type' => 'state.token_added' }
      )
      
      # Check if any serverless functions need to be triggered
      check_and_trigger_functions(event['place'])
    end

    def handle_transition_fired(event)
      @js.publish("state.#{@workflow_id}",
        event.to_json,
        headers: { 'Nats-Msg-Type' => 'state.transition_fired' }
      )
    end

    def handle_workflow_completed(event)
      @js.publish("state.#{@workflow_id}",
        event.to_json,
        headers: { 'Nats-Msg-Type' => 'state.completed' }
      )
      
      # If there's a next workflow to trigger
      if event['next_workflow']
        trigger_next_workflow(event['next_workflow'])
      end
    end

    def check_and_trigger_functions(place)
      # Get function configuration for this place
      function_config = get_function_config(place)
      return unless function_config
      
      # Publish event to trigger serverless function
      @js.publish("function.#{function_config['name']}",
        {
          workflow_id: @workflow_id,
          place: place,
          config: function_config
        }.to_json,
        headers: { 'Nats-Msg-Type' => 'function.trigger' }
      )
    end

    def get_function_config(place)
      # This would be loaded from a configuration store
      # For now, returning a mock config
      {
        'name' => "function_#{place}",
        'runtime' => 'ruby',
        'handler' => 'handle',
        'environment' => {}
      }
    end

    def trigger_next_workflow(next_workflow_config)
      new_workflow_id = SecureRandom.uuid
      
      # Create the new workflow
      create_workflow(
        next_workflow_config['petri_net'],
        workflow_id: new_workflow_id
      )
      
      # Link the workflows
      @js.publish("workflow.#{@workflow_id}.next",
        {
          previous_workflow_id: @workflow_id,
          next_workflow_id: new_workflow_id
        }.to_json,
        headers: { 'Nats-Msg-Type' => 'workflow.link' }
      )
    end

    def add_token(place, data = nil)
      @js.publish("event.#{@workflow_id}",
        {
          type: 'token_added',
          place: place,
          data: data,
          timestamp: Time.now.utc.iso8601
        }.to_json,
        headers: { 'Nats-Msg-Type' => 'event.token_added' }
      )
    end

    def fire_transition(transition_name)
      @js.publish("event.#{@workflow_id}",
        {
          type: 'transition_fired',
          transition: transition_name,
          timestamp: Time.now.utc.iso8601
        }.to_json,
        headers: { 'Nats-Msg-Type' => 'event.transition_fired' }
      )
    end

    def complete_workflow(next_workflow = nil)
      @js.publish("event.#{@workflow_id}",
        {
          type: 'workflow_completed',
          next_workflow: next_workflow,
          timestamp: Time.now.utc.iso8601
        }.to_json,
        headers: { 'Nats-Msg-Type' => 'event.workflow_completed' }
      )
    end
  end
end
