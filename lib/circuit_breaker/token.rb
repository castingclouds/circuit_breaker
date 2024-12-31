require 'securerandom'
require 'json'
require 'yaml'
require 'async'
require_relative 'validators'
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
    attr_accessor :state

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

    def initialize(state: nil, metadata: {})
      @id = SecureRandom.uuid
      @state = state || :draft
      @created_at = Time.now
      @updated_at = @created_at
      @event_handlers = Hash.new { |h, k| h[k] = [] }
      @async_handlers = Hash.new { |h, k| h[k] = [] }
      @history = []
      
      # Initialize instance variables from metadata
      metadata.each do |key, value|
        instance_variable_set("@#{key}", value)
        self.class.send(:attr_accessor, key) unless respond_to?(key)
      end

      # Run initial validations
      validate_current_state if @state
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

    # Serialization methods
    def to_h(include_private = false)
      if include_private
        # Get all instance variables including private state
        instance_variables.each_with_object({}) do |var, hash|
          next if [:@event_handlers, :@async_handlers].include?(var)
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

    protected

    # Helper method to define attributes with validation
    def self.define_attribute(name, options = {})
      attr_reader name

      # Convert simple validations to ValidationResult objects
      if validator = options[:validates]
        if validator.is_a?(Array)
          # Composite validation using AND
          validator = Validators::CompositeValidator.all(*validator)
        end
      end

      # Store validations for later use
      attribute_validations[name] = validator if validator

      # Define setter with validation
      define_method("#{name}=") do |value|
        old_value = instance_variable_get("@#{name}")
        
        # Run validation if provided
        if validator = self.class.attribute_validations[name]
          result = validator.call(value)
          raise ValidationError, "Invalid value for #{name}: #{result}" unless result.valid?
        end

        instance_variable_set("@#{name}", value)
        @updated_at = Time.now
        
        # Record the change in history
        record_event(:attribute_changed, {
          attribute: name,
          old_value: old_value,
          new_value: value
        })
        
        # Trigger attribute change events
        trigger(:attribute_changed, 
                attribute: name, 
                old_value: old_value, 
                new_value: value)
        trigger_async(:attribute_changed,
                     attribute: name,
                     old_value: old_value,
                     new_value: value)
        
        value
      end
    end

    private

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
      var_name = "@#{method_name}"
      if instance_variable_defined?(var_name)
        instance_variable_get(var_name)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      instance_variable_defined?("@#{method_name}") || super
    end
  end
end
