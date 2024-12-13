require 'concurrent'
require 'json'
require 'securerandom'

# Module for implementing a Circuit Breaker pattern using a Petri net
module CircuitBreaker
  # Represents a token that flows through the workflow
  # Each token has a unique ID and can carry arbitrary data
  class Token
    # @!attribute [r] id
    #   @return [String] Unique identifier for the token
    attr_reader :id
    
    # @!attribute [r] data
    #   @return [Hash] Optional data to be carried by the token
    attr_reader :data
    
    # Initialize a new token with a unique ID and optional data
    # @param id [String] Unique identifier for the token
    # @param data [Hash] Optional data to be carried by the token
    def initialize(id, data = {})
      @id = id
      @data = data
    end
  end

  # Represents a place in the Petri net workflow
  # Places can hold tokens and connect to transitions via arcs
  class Place
    # @!attribute [r] name
    #   @return [Symbol] Name of the place
    attr_reader :name
    
    # @!attribute [r] tokens
    #   @return [Array<Token>] Tokens currently in this place
    attr_reader :tokens
    
    # @!attribute [r] input_arcs
    #   @return [Array<Arc>] Input arcs connected to this place
    attr_reader :input_arcs
    
    # @!attribute [r] output_arcs
    #   @return [Array<Arc>] Output arcs connected to this place
    attr_reader :output_arcs
    
    # Initialize a new place with a given name
    # @param name [Symbol] Name of the place
    def initialize(name)
      @name = name
      @tokens = []
      @input_arcs = []
      @output_arcs = []
      @mutex = Mutex.new
    end
    
    # Add a token to this place
    # @param token [Token] Token to add
    def add_token(token)
      @mutex.synchronize { @tokens << token }
    end
    
    # Remove and return the most recently added token
    # @return [Token, nil] The removed token or nil if no tokens
    def remove_token
      @mutex.synchronize { @tokens.pop }
    end
    
    # Get the current number of tokens in this place
    # @return [Integer] Number of tokens
    def token_count
      @tokens.size
    end

    # Add an input arc from a source to this place
    # @param source [Transition] Source transition
    # @param weight [Integer] Weight of the arc (default: 1)
    # @return [Arc] The created arc
    def add_input_arc(source, weight = 1)
      arc = Arc.new(source, self, weight)
      @input_arcs << arc
      arc
    end

    # Add an output arc from this place to a target
    # @param target [Transition] Target transition
    # @param weight [Integer] Weight of the arc (default: 1)
    # @return [Arc] The created arc
    def add_output_arc(target, weight = 1)
      arc = Arc.new(self, target, weight)
      @output_arcs << arc
      arc
    end
  end

  # Represents an arc connecting places and transitions in the Petri net
  # Arcs can have weights to specify how many tokens are required/produced
  class Arc
    # @!attribute [r] weight
    #   @return [Integer] Weight of the arc
    attr_reader :weight
    
    # @!attribute [r] source
    #   @return [Place, Transition] Source node
    attr_reader :source
    
    # @!attribute [r] target
    #   @return [Place, Transition] Target node
    attr_reader :target

    # Initialize a new arc
    # @param source [Place, Transition] Source node
    # @param target [Place, Transition] Target node
    # @param weight [Integer] Weight of the arc (default: 1)
    def initialize(source, target, weight = 1)
      @source = source
      @target = target
      @weight = weight
    end

    # Check if this arc is enabled (can fire)
    # @return [Boolean] True if the arc can fire
    def enabled?
      case source
      when Place
        source.token_count >= weight
      when Transition
        true  # Transitions can always produce tokens
      else
        false
      end
    end
  end

  # Represents a transition in the Petri net workflow
  # Transitions connect places and can have guard conditions
  class Transition
    # @!attribute [r] name
    #   @return [Symbol] Name of the transition
    attr_reader :name
    
    # @!attribute [r] input_arcs
    #   @return [Array<Arc>] Input arcs connected to this transition
    attr_reader :input_arcs
    
    # @!attribute [r] output_arcs
    #   @return [Array<Arc>] Output arcs connected to this transition
    attr_reader :output_arcs
    
    # @!attribute [r] guard
    #   @return [Proc] Guard condition that takes token data and returns boolean
    attr_reader :guard

    # Initialize a new transition
    # @param name [Symbol] Name of the transition
    def initialize(name)
      @name = name
      @input_arcs = []
      @output_arcs = []
      @guard = -> (_) { true }  # Default guard always allows firing
    end

    # Add an input arc from a place to this transition
    # @param place [Place] Source place
    # @param weight [Integer] Weight of the arc (default: 1)
    # @return [Arc] The created arc
    def add_input_arc(place, weight = 1)
      arc = Arc.new(place, self, weight)
      @input_arcs << arc
      arc
    end

    # Add an output arc from this transition to a place
    # @param place [Place] Target place
    # @param weight [Integer] Weight of the arc (default: 1)
    # @return [Arc] The created arc
    def add_output_arc(place, weight = 1)
      arc = Arc.new(self, place, weight)
      @output_arcs << arc
      arc
    end

    # Set a guard condition for this transition
    # @param block [Proc] Guard condition that takes token data and returns boolean
    def set_guard(&block)
      @guard = block
    end

    # Check if this transition is enabled (can fire)
    # @return [Boolean] True if the transition can fire
    def enabled?
      # Get input token data
      input_data = input_arcs.first&.source&.tokens&.last&.data
      return false unless guard.call(input_data)
      
      input_arcs.all? do |arc|
        arc.source.token_count >= arc.weight
      end
    end

    # Fire this transition if enabled
    # Consumes input tokens and produces output tokens
    # @return [Boolean] True if the transition fired successfully
    def fire
      return unless enabled?

      # First check if we can consume all required tokens
      input_tokens = input_arcs.map do |arc|
        tokens = []
        arc.weight.times do
          token = arc.source.remove_token
          return false unless token
          tokens << token
        end
        tokens
      end.flatten

      # Then produce output tokens
      output_arcs.each do |arc|
        arc.weight.times do
          # Create new token with new ID but preserve data from input tokens
          data = input_tokens.first&.data || {}
          arc.target.add_token(Token.new(SecureRandom.uuid, data))
        end
      end

      true
    end
  end

  # Main workflow class that manages the Petri net
  # Can be created from a configuration or built programmatically
  class Workflow
    # @!attribute [r] places
    #   @return [Hash<Symbol, Place>] Places in the workflow
    attr_reader :places
    
    # @!attribute [r] transitions
    #   @return [Hash<Symbol, Transition>] Transitions in the workflow
    attr_reader :transitions
    
    # @!attribute [r] config
    #   @return [Hash] Configuration hash
    attr_reader :config
    
    # @!attribute [r] object_type
    #   @return [Class] Expected type of objects flowing through the workflow
    attr_reader :object_type

    # Initialize a new workflow
    # @param config [Hash, nil] Optional configuration hash
    def initialize(config = nil)
      @places = {}
      @transitions = {}
      @mutex = Mutex.new
      
      if config
        @config = config[:config]
        @object_type = config[:object_type]
        setup_from_config(config)
      end
    end

    # Add a new place to the workflow
    # @param name [Symbol] Name of the place
    # @return [Place] The created place
    def add_place(name)
      @mutex.synchronize do
        place = Place.new(name)
        @places[name] = place
        place
      end
    end

    # Add a new transition to the workflow
    # @param name [Symbol] Name of the transition
    # @return [Transition] The created transition
    def add_transition(name)
      @mutex.synchronize do
        transition = Transition.new(name)
        @transitions[name] = transition
        transition
      end
    end

    # Connect two nodes (places/transitions) with an arc
    # @param source_name [Symbol] Name of the source node
    # @param target_name [Symbol] Name of the target node
    # @param weight [Integer] Weight of the arc (default: 1)
    def connect(source_name, target_name, weight = 1)
      source = @places[source_name] || @transitions[source_name]
      target = @places[target_name] || @transitions[target_name]
      
      raise "Source #{source_name} not found" unless source
      raise "Target #{target_name} not found" unless target

      case [source.class, target.class]
      when [Place, Transition]
        target.add_input_arc(source, weight)
      when [Transition, Place]
        source.add_output_arc(target, weight)
      else
        raise "Invalid connection between #{source.class} and #{target.class}"
      end
    end

    # Start the workflow with an initial object
    # @param initial_object [Object, nil] Optional initial object
    def start(initial_object = nil)
      validate_object(initial_object) if initial_object
      # Add initial token to start place
      start_place = places.values.first
      start_place.add_token(Token.new(SecureRandom.uuid, initial_object))
    end

    # Fire a transition by name
    # @param transition_name [Symbol] Name of the transition to fire
    # @return [Boolean] True if the transition fired successfully
    def fire_transition(transition_name)
      transition = transitions[transition_name]
      raise "Transition #{transition_name} not found" unless transition
      
      # Get the input token data before firing
      input_data = transition.input_arcs.first&.source&.tokens&.last&.data

      # Validate requirements if specified
      if input_data && transition.respond_to?(:requires)
        validate_requirements(transition.requires, input_data)
      end

      transition.fire
    end

    private

    # Set up the workflow from a configuration hash
    # @param config [Hash] Configuration hash
    def setup_from_config(config)
      # Add places
      states = Array(config.dig(:places, :states))
      special_states = Array(config.dig(:places, :special_states))

      states.each { |state| add_place(state) }
      special_states.each { |state| add_place(state) }

      # Add transitions and connections
      Array(config.dig(:transitions, :regular)).each do |t|
        transition = add_transition(t[:name])
        connect(t[:from], t[:name])
        connect(t[:name], t[:to])
        
        # Add requirements as guard conditions
        if t[:requires]
          transition.set_guard do |data|
            validate_requirements(t[:requires], data) rescue false
          end
        end
      end

      Array(config.dig(:transitions, :blocking)).each do |t|
        transition = add_transition(t[:name])
        Array(t[:from]).each { |from| connect(from, t[:name]) }
        Array(t[:to]).each { |to| connect(t[:name], to) }
        
        if t[:requires]
          transition.set_guard do |data|
            validate_requirements(t[:requires], data) rescue false
          end
        end
      end
    end

    # Validate that an object matches the expected type
    # @param obj [Object] Object to validate
    # @raise [RuntimeError] If object type doesn't match
    def validate_object(obj)
      raise "Object type mismatch" if @object_type && !obj.is_a?(Object.const_get(@object_type))
    end

    # Validate that required fields are present in data
    # @param required_fields [Array<Symbol>] Required field names
    # @param data [Object] Object to validate
    # @return [Boolean] True if validation passes
    # @raise [RuntimeError] If validation fails
    def validate_requirements(required_fields, data)
      required_fields.each do |field|
        raise "Missing required field: #{field}" if data.nil? || !data.respond_to?(field) || data.send(field).nil?
      end
      true
    end
  end
end
