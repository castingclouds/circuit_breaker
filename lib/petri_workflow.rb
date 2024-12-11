require 'concurrent'
require 'json'
require 'securerandom'

module PetriWorkflows
  class Token
    attr_reader :id, :data
    
    def initialize(id, data = {})
      @id = id
      @data = data
    end
  end

  class Place
    attr_reader :name, :tokens
    
    def initialize(name)
      @name = name
      @tokens = []
      @mutex = Mutex.new
    end
    
    def add_token(token)
      @mutex.synchronize { @tokens << token }
    end
    
    def remove_token
      @mutex.synchronize { @tokens.pop }
    end
    
    def token_count
      @tokens.size
    end
  end

  class Arc
    attr_reader :weight, :source, :target

    def initialize(source, target, weight = 1)
      @source = source
      @target = target
      @weight = weight
    end

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

  class Transition
    attr_reader :name, :input_arcs, :output_arcs, :guard

    def initialize(name)
      @name = name
      @input_arcs = []
      @output_arcs = []
      @guard = -> { true }  # Default guard always allows firing
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
      return false unless guard.call
      input_arcs.all? do |arc|
        arc.source.token_count >= arc.weight
      end
    end

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

  class PetriNet
    attr_reader :places, :transitions

    def initialize
      @places = {}
      @transitions = {}
      @mutex = Mutex.new
    end

    def add_place(name)
      @mutex.synchronize do
        place = Place.new(name)
        @places[name] = place
        place
      end
    end

    def add_transition(name)
      @mutex.synchronize do
        transition = Transition.new(name)
        @transitions[name] = transition
        transition
      end
    end

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
        raise "Invalid connection: #{source.class} to #{target.class}"
      end
    end

    def add_tokens(place_name, count = 1)
      place = @places[place_name]
      raise "Place #{place_name} not found" unless place
      
      count.times do
        place.add_token(Token.new(SecureRandom.uuid))
      end
    end

    def step
      fired = false
      enabled_transitions = @transitions.values.select(&:enabled?)
      
      enabled_transitions.each do |transition|
        if transition.fire
          fired = true
          break  # Only fire one transition per step
        end
      end
      
      fired
    end

    def run_to_completion
      steps = 0
      while step
        steps += 1
      end
      steps
    end

    def marking
      @places.transform_values(&:token_count)
    end

    def to_json
      {
        places: @places.keys,
        transitions: @transitions.keys,
        marking: marking
      }.to_json
    end
  end
end
