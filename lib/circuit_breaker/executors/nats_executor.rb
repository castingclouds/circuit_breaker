require 'nats/client'
require 'securerandom'
require 'json'
require_relative 'base_executor'

module CircuitBreaker
  module Executors
    # Executor class that uses NATS for workflow event distribution
    # Handles workflow state management and event processing
    class NatsExecutor < BaseExecutor
      # Reader for workflow ID
      attr_reader :workflow_id
      # Reader for NATS client
      attr_reader :nats

      # Initialize a new NATS executor
      # @param context [Hash] Initialization context
      # @option context [String] :nats_url URL of the NATS server (default: 'nats://localhost:4222')
      def initialize(context = {})
        super
        @nats_url = context[:nats_url] || 'nats://localhost:4222'
        @nats = NATS.connect(@nats_url)
        setup_jetstream
      end

      def execute
        return unless @context[:petri_net]

        workflow_id = create_workflow(
          @context[:petri_net],
          workflow_id: @context[:workflow_id]
        )

        @result = {
          workflow_id: workflow_id,
          status: 'completed'
        }
      end

      private

      # Set up JetStream streams for workflow data
      # Creates streams for workflow state, events, and current states
      def setup_jetstream
        @js = @nats.jetstream
        
        # Create streams for workflow state and events
        @js.add_stream(name: 'WORKFLOWS', subjects: ['workflow.*'])
        @js.add_stream(name: 'WORKFLOW_EVENTS', subjects: ['event.*'])
        @js.add_stream(name: 'WORKFLOW_STATES', subjects: ['state.*'])
      end

      # Create a new workflow instance
      # @param petri_net [Workflow] Workflow definition
      # @param workflow_id [String, nil] Optional workflow ID
      # @return [String] Workflow ID
      def create_workflow(petri_net, workflow_id: nil)
        @workflow_id = workflow_id || SecureRandom.uuid
        puts "\n[Workflow] Creating new workflow with ID: #{@workflow_id}"
        
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

      # Handle incoming workflow events
      # @param msg [String] JSON-encoded event message
      def handle_event(msg)
        event = JSON.parse(msg)
        puts "\n[Event] Received event: #{event['type']}"
        
        case event['type']
        when 'token_added'
          handle_token_added(event)
        when 'transition_fired'
          handle_transition_fired(event)
        when 'workflow_completed'
          handle_workflow_completed(event)
        end
      end

      # Handle token added event
      # @param event [Hash] Event data
      def handle_token_added(event)
        puts "\n[Handler] Token added to place: #{event['place']} with data: #{event['data'].inspect}"
        # Publish state change
        @js.publish("state.#{@workflow_id}",
          event.to_json,
          headers: { 'Nats-Msg-Type' => 'state.token_added' }
        )
        
        # Check if any serverless functions need to be triggered
        check_and_trigger_functions(event['place'])
      end

      # Handle transition fired event
      # @param event [Hash] Event data
      def handle_transition_fired(event)
        puts "\n[Handler] Transition fired: #{event['transition']}"
        @js.publish("state.#{@workflow_id}",
          event.to_json,
          headers: { 'Nats-Msg-Type' => 'state.transition_fired' }
        )
      end

      # Handle workflow completed event
      # @param event [Hash] Event data
      def handle_workflow_completed(event)
        puts "\n[Handler] Workflow completed#{event['next_workflow'] ? ' with next workflow configured' : ''}"
        @js.publish("state.#{@workflow_id}",
          event.to_json,
          headers: { 'Nats-Msg-Type' => 'state.completed' }
        )
        
        # If there's a next workflow to trigger
        if event['next_workflow']
          trigger_next_workflow(event['next_workflow'])
        end
      end

      # Check if any serverless functions need to be triggered
      # @param place [String] Place in the workflow
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

      # Get function configuration for a given place
      # @param place [String] Place in the workflow
      # @return [Hash] Function configuration
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

      # Trigger a new workflow instance
      # @param next_workflow_config [Hash] Configuration for the next workflow
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

      # Add a token to a place in the workflow
      # @param place [String] Place in the workflow
      # @param data [Hash, nil] Optional data for the token
      def add_token(place, data = nil)
        puts "\n[Token] Adding token to place: #{place} with data: #{data.inspect}"
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

      # Fire a transition in the workflow
      # @param transition_name [String] Name of the transition
      def fire_transition(transition_name)
        puts "\n[Transition] Firing transition: #{transition_name}"
        @js.publish("event.#{@workflow_id}",
          {
            type: 'transition_fired',
            transition: transition_name,
            timestamp: Time.now.utc.iso8601
          }.to_json,
          headers: { 'Nats-Msg-Type' => 'event.transition_fired' }
        )
      end

      # Complete the workflow
      # @param next_workflow [Hash, nil] Optional configuration for the next workflow
      def complete_workflow(next_workflow = nil)
        puts "\n[Workflow] Completing workflow#{next_workflow ? ' and triggering next workflow' : ''}"
        event_data = {
          type: 'workflow_completed',
          next_workflow: next_workflow,
          timestamp: Time.now.utc.iso8601
        }
        
        @js.publish("event.#{@workflow_id}",
          event_data.to_json,
          headers: { 'Nats-Msg-Type' => 'event.workflow_completed' }
        )
      end
    end
  end
end
