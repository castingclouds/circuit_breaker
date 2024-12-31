require 'concurrent'
require 'json'
require 'securerandom'
require 'set'
require_relative 'circuit_breaker/token'

# Module for implementing a Circuit Breaker pattern using a Petri net
module CircuitBreaker
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
    attr_reader :name, :from, :to, :input_arcs, :output_arcs, :guard

    def initialize(name:, from:, to:)
      @name = name
      @from = from
      @to = to
      @input_arcs = []
      @output_arcs = []
      @guard = nil
    end

    def add_input_arc(place, weight = 1)
      arc = Arc.new(place, self, weight)
      @input_arcs << arc
      arc
    end

    def add_output_arc(place, weight = 1)
      arc = Arc.new(self, place, weight)
      @output_arcs << arc
      arc
    end

    def set_guard(&block)
      @guard = block
    end

    def enabled?
      return false unless @guard.nil? || @guard.call
      @input_arcs.all?(&:enabled?) && @output_arcs.all?(&:enabled?)
    end
  end

  # Main workflow class that manages the Petri net
  # Can be created from a configuration or built programmatically
  class Workflow
    attr_reader :places, :transitions, :tokens

    def initialize
      @places = {}
      @transitions = {}
      @tokens = Set.new
    end

    def states=(state_list)
      state_list.each do |state|
        @places[state] = Place.new(state)
      end
    end

    # Add a new transition to the workflow
    def add_transition(name:, from:, to:, requires: nil, guard: nil, validate: nil)
      transition = Transition.new(name: name, from: from, to: to)
      
      # Set up guard condition that checks requirements and validation
      transition.set_guard do |token|
        # Check required fields
        if requires
          return false unless requires.all? { |field| token.respond_to?(field) && !token.send(field).nil? }
        end

        # Run guard condition if present
        return false if guard && !guard.call(token)

        # Run validation if present
        if validate
          begin
            validate.call(token)
            true
          rescue => e
            false
          end
        else
          true
        end
      end

      # Connect places with transitions
      @places[from].add_output_arc(transition)
      @places[to].add_input_arc(transition)
      
      @transitions[name] = transition
      transition
    end

    # Add a token to the workflow
    def add_token(token)
      @tokens.add(token)
      @places[token.state.to_sym]&.add_token(token) if token.state
    end

    # Fire a specific transition for a token
    def fire_transition(transition_name, token)
      transition = @transitions[transition_name]
      raise "Transition not found: #{transition_name}" unless transition
      
      # Find the source place
      source_place = @places.values.find { |p| p.tokens.include?(token) }
      raise "Token not found in any place" unless source_place
      
      # Find the target place
      target_place = @places.values.find { |p| p.input_arcs.any? { |arc| arc.source == transition } }
      raise "Target place not found for transition" unless target_place
      
      if transition.enabled?
        source_place.remove_token
        target_place.add_token(token)
        token.state = target_place.name.to_s
        true
      else
        raise "Unable to fire transition: #{transition_name}"
      end
    end
  end
end
