require 'securerandom'
require 'json'
require 'yaml'
require 'async'
require_relative 'rules'
require_relative 'visualizer'
require_relative 'history'

module CircuitBreaker
  # Base class for all workflow tokens
  class Token
    include History

    class ValidationError < StandardError; end
    class StateError < StandardError; end
    class TransitionError < StandardError; end

    attr_reader :id, :created_at, :updated_at
    attr_accessor :state, :history

    # Class-level storage for hooks, validations, and transitions
    class << self
      def before_transition_hooks
        @before_transition_hooks ||= []
      end

      def after_transition_hooks
        @after_transition_hooks ||= []
      end

      def attribute_validations
        @attribute_validations ||= {}
      end

      def state_validations
        @state_validations ||= {}
      end

      def state_transitions
        @state_transitions ||= {}
      end

      def transition_rules
        @transition_rules ||= {}
      end

      # DSL methods for defining hooks and validations
      def before_transition(&block)
        before_transition_hooks << block
      end

      def after_transition(&block)
        after_transition_hooks << block
      end

      def validate_state(state, &block)
        state_validations[state] = block
      end

      def transitions_from(from, to:)
        state_transitions[from] = Array(to)
      end

      def transition_rule(from:, to:, &block)
        transition_rules[[from, to]] = block
      end

      # Enhanced DSL methods
      def states(*state_list)
        state_list.each do |state|
          state_transitions[state] ||= []
        end
        
        # Define predicate methods for states
        state_list.each do |state|
          define_method("#{state}?") do
            @state == state
          end
        end

        const_set(:VALID_STATES, state_list.freeze)
      end

      def validate_attribute(name, &block)
        attribute_validations[name] = block
      end

      def attribute(name, type = nil, **options)
        # Add to list of attributes
        attributes << name

        # Define the attribute accessor
        attr_accessor name

        # Define the validator if type is specified
        if type
          validate_attribute name do |value|
            next true if value.nil?
            next false unless value.is_a?(type)
            
            if options[:allowed]
              options[:allowed].include?(value)
            else
              true
            end
          end
        end
      end

      def attributes
        @attributes ||= []
      end

      def track_timestamp(*fields, on_state: nil, on_states: nil)
        states = on_states || [on_state]
        states.compact.each do |state|
          state_timestamps[state] ||= []
          state_timestamps[state].concat(fields)
        end
        attr_accessor(*fields)
      end

      def state_timestamps
        @state_timestamps ||= {}
      end

      def state_messages
        @state_messages ||= {}
      end

      # Default state message if none specified
      def default_state_message
        @default_state_message ||= ->(token, from, to) { "State changed from #{from} to #{to}" }
      end

      def default_state_message=(block)
        @default_state_message = block
      end

      def state_message(for_state:, &block)
        state_messages[for_state] = block
      end

      # Combined state configuration
      def state_config(state, timestamps: nil, message: nil, &block)
        # Handle timestamps
        if timestamps
          track_timestamp(*Array(timestamps), on_state: state)
        end

        # Handle message
        if block_given?
          state_message(for_state: state, &block)
        elsif message
          state_message(for_state: state) { |token| message }
        end
      end

      # Multiple state configuration
      def state_configs(&block)
        config_dsl = StateConfigDSL.new(self)
        config_dsl.instance_eval(&block)
      end

      # DSL for state configuration
      class StateConfigDSL
        def initialize(token_class)
          @token_class = token_class
        end

        def state(name, timestamps: nil, message: nil, &block)
          @token_class.state_config(name, timestamps: timestamps, message: message, &block)
        end

        def on_states(states, timestamps:)
          Array(timestamps).each do |timestamp|
            @token_class.track_timestamp(timestamp, on_states: states)
          end
        end
      end

      # Visualization methods
      def visualize(format = :mermaid)
        case format
        when :mermaid
          Visualizer.to_mermaid(self)
        when :dot
          Visualizer.to_dot(self)
        when :plantuml
          Visualizer.to_plantuml(self)
        when :html
          Visualizer.to_html(self)
        when :markdown
          Visualizer.to_markdown(self)
        else
          raise ArgumentError, "Unsupported format: #{format}"
        end
      end
    end

    def initialize(attributes = {})
      @id = SecureRandom.uuid
      @state = self.class::VALID_STATES.first
      
      # Initialize all attributes to nil
      self.class.attributes.each do |attr|
        instance_variable_set("@#{attr}", nil)
      end

      # Set provided attributes
      attributes.each do |key, value|
        send("#{key}=", value) if respond_to?("#{key}=")
      end

      # Add default transition hook for timestamps and history
      self.class.before_transition do |from, to|
        # Set timestamps for the target state
        if (timestamp_fields = self.class.state_timestamps[to.to_sym])
          timestamp_fields.each do |field|
            send("#{field}=", Time.now)
          end
        end

        # Record the transition in history with details
        record_event(
          :state_transition,
          {
            from: from,
            to: to,
            timestamp: Time.now,
            details: state_change_details(from, to)
          }
        )
      end

      @created_at = Time.now
      @updated_at = @created_at
      @event_handlers = Hash.new { |h, k| h[k] = [] }
      @async_handlers = Hash.new { |h, k| h[k] = [] }
      @observers = Hash.new { |h, k| h[k] = [] }
      @async_observers = Hash.new { |h, k| h[k] = [] }
      @history = []
    end

    def update_state(new_state, actor_id: nil)
      old_state = @state
      
      begin
        # Run before transition hooks
        self.class.before_transition_hooks.each { |hook| instance_exec(old_state, new_state, &hook) }
        
        # Run state-specific validations
        validate_transition(from: old_state, to: new_state)
        validate_current_state(new_state)

        # Run custom transition rules
        if rule = self.class.transition_rules[[old_state, new_state]]
          result = instance_exec(&rule)
          raise TransitionError, result if result.is_a?(String)
        end

        @state = new_state
        @updated_at = Time.now

        # Record the transition in history
        record_event(:state_transition, {
          from: old_state,
          to: new_state,
          timestamp: @updated_at
        }, actor_id: actor_id)

        # Run after transition hooks
        self.class.after_transition_hooks.each { |hook| instance_exec(old_state, new_state, &hook) }
        
        # Trigger state change events
        trigger(:state_changed, old_state: old_state, new_state: new_state)
        trigger_async(:state_changed, old_state: old_state, new_state: new_state)
        
        notify(:state_changed, old_state: old_state, new_state: new_state)
        
        true
      rescue StandardError => e
        # Record the failed transition
        record_event(:transition_failed, {
          from: old_state,
          to: new_state,
          error: e.message
        }, actor_id: actor_id)

        trigger(:transition_failed, error: e, from: old_state, to: new_state)
        trigger_async(:transition_failed, error: e, from: old_state, to: new_state)
        notify(:transition_failed, error: e, from: old_state, to: new_state)
        raise
      end
    end

    # Event handling
    def on(event, async: false, &handler)
      if async
        @async_handlers[event] << handler
      else
        @event_handlers[event] << handler
      end
      self
    end

    def trigger(event, **data)
      @event_handlers[event].each { |handler| handler.call(data) }
    end

    def trigger_async(event, **data)
      return if @async_handlers[event].empty?
      
      Async do |task|
        @async_handlers[event].each do |handler|
          task.async do
            begin
              handler.call(data)
            rescue => e
              # Log async handler errors and record in history
              error_msg = "[ERROR] Async handler failed: #{e.message}"
              puts error_msg
              record_event(:async_handler_error, {
                event: event,
                error: error_msg,
                data: data
              })
            end
          end
        end
      end
    end

    def on(event, async: false, &block)
      if async
        @async_observers[event] << block
      else
        @observers[event] << block
      end
    end

    def notify(event, data = {})
      @observers[event].each { |observer| observer.call(data) }
      
      @async_observers[event].each do |observer|
        Thread.new do
          observer.call(data)
        end
      end
    end

    # Serialization methods
    def to_h(include_private = false)
      if include_private
        # Get all instance variables including private state
        instance_variables.each_with_object({}) do |var, hash|
          next if [:@event_handlers, :@async_handlers, :@observers, :@async_observers].include?(var)
          key = var.to_s.delete_prefix('@').to_sym
          hash[key] = instance_variable_get(var)
        end
      else
        # Get only publicly accessible attributes
        self.class.instance_methods(false)
            .select { |method| method.to_s !~ /[=!?]$/ }
            .reject { |method| [:inspect, :pretty_print, :to_h, :to_json, :to_yaml, :to_xml].include?(method) }
            .each_with_object({}) do |method, hash|
          hash[method] = send(method)
        end
      end
    end

    def to_json(include_private = false)
      JSON.pretty_generate(to_h(include_private))
    end

    def to_yaml(include_private = false)
      to_h(include_private).to_yaml
    end

    def to_xml(include_private = false)
      require 'nokogiri'
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.token(class: self.class.name) {
          to_h(include_private).each do |key, value|
            xml.send(key, value)
          end
        }
      end
      builder.to_xml
    rescue LoadError
      raise "Nokogiri is required for XML serialization. Add it to your Gemfile."
    end

    # Pretty print the object's state
    def pretty_print(include_private = false)
      fields = to_h(include_private)

      # Find the longest key for padding
      max_key_length = fields.keys.map(&:to_s).map(&:length).max

      output = ["#<#{self.class}"]
      fields.each do |key, value|
        value_str = case value
                   when nil then "nil"
                   when String then "\"#{value}\""
                   when Time then "\"#{value.iso8601}\""
                   else value.to_s
                   end
        
        # Pad the key with spaces for alignment
        padded_key = key.to_s.ljust(max_key_length)
        output << "  #{padded_key}: #{value_str}"
      end
      output << ">"

      output.join("\n")
    end

    # Show all state in inspect for debugging
    def inspect
      pretty_print(true)
    end

    def record_transition(transition_name, old_state, new_state)
      @history << {
        transition: transition_name,
        from: old_state,
        to: new_state,
        timestamp: Time.now
      }
      @updated_at = Time.now
    end

    protected

    def validate_current_state(state = @state)
      return unless state
      if validator = self.class.state_validations[state]
        result = instance_exec(&validator)
        raise StateError, "Invalid state #{state}: #{result}" if result.is_a?(String)
      end
    end

    def validate_transition(from:, to:)
      valid_transitions = self.class.state_transitions[from&.to_sym] || []
      unless valid_transitions.include?(to.to_sym)
        raise StateError, "Cannot transition from #{from} to #{to}"
      end
    end

    def method_missing(method_name, *args)
      # Check if it's a setter method (ends with =)
      if method_name.to_s.end_with?('=')
        attr_name = method_name.to_s.chomp('=')
        if self.class.attributes.include?(attr_name.to_sym)
          self.class.send(:attr_accessor, attr_name.to_sym)
          send(method_name, *args)
        else
          super
        end
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      # Check if it's a setter method (ends with =)
      if method_name.to_s.end_with?('=')
        attr_name = method_name.to_s.chomp('=')
        self.class.attributes.include?(attr_name.to_sym)
      else
        super
      end
    end

    private

    def state_change_details(from, to)
      if (message_block = self.class.state_messages[to.to_sym])
        message_block.call(self)
      else
        self.class.default_state_message.call(self, from, to)
      end
    end
  end
end
