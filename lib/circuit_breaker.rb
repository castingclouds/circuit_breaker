require 'concurrent'
require 'json'
require 'securerandom'
require 'set'
require_relative 'circuit_breaker/token'
require_relative 'circuit_breaker/workflow_dsl'
require_relative 'circuit_breaker/rules_engine'
require_relative 'circuit_breaker/validators' 

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

    def can_fire?(token)
      return true unless @guard
      @guard.call(token)
    end
  end

  # Main workflow class that manages the Petri net
  # Can be created from a configuration or built programmatically
  class Workflow
    include Validators 

    attr_writer :states

    def initialize(states: [], transitions: {}, before_flows: [], rules: [])
      @states = states
      @transitions = {}
      @validators = {}
      @tokens = Set.new
      @rules = rules || RulesEngine::DSL.define

      # Initialize transitions
      transitions.each do |transition, data|
        add_transition(transition, data[:from], data[:to])
        add_required_fields(transition, data[:required_fields]) if data[:required_fields]
        data[:rules]&.each { |rule| add_rule(transition, rule) }
      end

      # Add before flow validators
      before_flows.each do |block|
        add_validator(:before, block)
      end
    end

    def states=(state_list)
      @states = state_list
    end

    def add_validator(type, validator)
      @validators[type] ||= []
      @validators[type] << validator
    end

    def validate_token(token)
      return unless @validators

      @validators.each do |type, validators|
        validators.each do |validator|
          result = validator.call(token)
          case result
          when ValidationResult
            unless result.valid?
              raise Token::ValidationError, "Validation failed: #{result}"
            end
          when false
            raise Token::ValidationError, "Validation failed"
          end
        end
      end
    end

    def add_transition(name, from, to)
      @transitions[name] = {
        from: from,
        to: to
      }
    end

    def add_required_fields(transition, fields)
      @transitions[transition][:required_fields] = fields
    end

    def add_rule(transition, rule)
      @transitions[transition][:rules] ||= []
      @transitions[transition][:rules] << rule
    end

    def add_token(token)
      token.state ||= @states.first
      validate_token(token)
      @tokens << token
      token
    end

    def fire_transition(transition_name, token)
      raise Token::TransitionError, "Token not in workflow" unless @tokens.include?(token)
      
      transition = @transitions[transition_name]
      raise Token::TransitionError, "Unknown transition: #{transition_name}" unless transition
      
      # Validate current state
      unless token.state == transition[:from]
        raise Token::TransitionError, "Token in wrong state: expected #{transition[:from]}, got #{token.state}"
      end
      
      validate_token(token)

      # Validate required fields
      if transition[:required_fields]
        transition[:required_fields].each do |field|
          value = token.send(field)
          if value.nil? || (value.respond_to?(:empty?) && value.empty?)
            raise Token::ValidationError, "Required field '#{field}' is missing"
          end
        end
      end
      
      # Validate transition rules
      if transition[:rules]
        transition[:rules].each do |rule|
          begin
            result = rule.is_a?(Proc) ? rule.call(token) : @rules.evaluate(rule, token)
            unless result
              raise Token::TransitionError, "Rule '#{rule}' failed for transition #{transition_name}"
            end
          rescue StandardError => e
            raise Token::TransitionError, "Rule evaluation failed: #{e.message}"
          end
        end
      end

      # Update token state
      old_state = token.state
      token.state = transition[:to]
      token.notify(:state_changed, old_state: old_state, new_state: token.state)
    end
  end
end
