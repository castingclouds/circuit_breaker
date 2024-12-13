require 'yaml'
require 'json'

module CircuitBreaker
  module WorkflowDSL
    class Builder
      attr_reader :states, :special_states, :transitions, :config, :object_type, :validations

      def initialize(object_type = nil)
        @object_type = object_type
        @states = []
        @special_states = []
        @transitions = []
        @validations = []
        @config = {
          nats_url: ENV['NATS_URL'] || 'nats://localhost:4222',
          log_level: ENV['LOG_LEVEL'] || 'info',
          metrics_enabled: ENV.fetch('METRICS_ENABLED', 'true') == 'true',
          retry_attempts: ENV.fetch('RETRY_ATTEMPTS', '3').to_i
        }
      end

      def configure(&block)
        instance_eval(&block) if block_given?
      end

      def for_object(type)
        @object_type = type
      end

      def connection(opts = {})
        @config.merge!(opts)
      end

      def metrics(enabled: true, **opts)
        @config[:metrics_enabled] = enabled
        @config[:metrics_options] = opts
      end

      def logging(level: 'info', **opts)
        @config[:log_level] = level
        @config[:log_options] = opts
      end

      def states(*state_list)
        @states.concat(state_list)
      end

      def special_states(*state_list)
        @special_states.concat(state_list)
      end

      def validate(state, &block)
        @validations << { state: state, block: block }
      end

      def flow(from:, to:, via:, &block)
        transition = { 
          name: via, 
          from: from, 
          to: to,
          object_type: @object_type 
        }
        transition[:block] = block if block_given?
        @transitions << transition
      end

      def multi_flow(from:, to: nil, to_states: nil, via:, &block)
        target = to || to_states
        raise ArgumentError, "Must specify either 'to' or 'to_states'" unless target

        if to
          from_states = Array(from)
          from_states.each do |from_state|
            flow(from: from_state, to: to, via: via, &block)
          end
        else
          to_states.each do |to_state|
            flow(from: from, to: to_state, via: via, &block)
          end
        end
      end

      def load_yaml(file_path)
        yaml = YAML.load_file(file_path)
        load_config(yaml)
      end

      def load_json(file_path)
        json = JSON.parse(File.read(file_path))
        load_config(json)
      end

      def build
        validate!
        {
          object_type: @object_type,
          places: build_places,
          transitions: build_transitions,
          validations: @validations,
          config: @config
        }
      end

      def to_yaml
        build.to_yaml
      end

      def to_json
        JSON.pretty_generate(build)
      end

      private

      def load_config(config)
        config = config.transform_keys(&:to_sym)
        
        for_object(config[:object_type]) if config[:object_type]
        states(*config[:states]) if config[:states]
        special_states(*config[:special_states]) if config[:special_states]
        
        config[:transitions]&.each do |t|
          t = t.transform_keys(&:to_sym)
          if t[:from].is_a?(Array) || t[:to].is_a?(Array)
            multi_flow(**t)
          else
            flow(**t)
          end
        end

        @config.merge!(config[:config]) if config[:config]
      end

      def validate!
        raise "No object type defined" unless @object_type
        all_states = @states + @special_states
        raise "No states defined" if all_states.empty?
        raise "No transitions defined" if @transitions.empty?
        
        @transitions.each do |t|
          from_states = Array(t[:from])
          to_states = Array(t[:to])
          
          from_states.each do |from|
            unless all_states.include?(from)
              raise "Invalid 'from' state in transition '#{t[:name]}': #{from}"
            end
          end
          
          to_states.each do |to|
            unless all_states.include?(to)
              raise "Invalid 'to' state in transition '#{t[:name]}': #{to}"
            end
          end
        end
      end

      def build_places
        {
          states: @states,
          special_states: @special_states
        }
      end

      def build_transitions
        regular = []
        blocking = []

        @transitions.each do |t|
          if t[:from].is_a?(Array) || t[:to].is_a?(Array)
            blocking << t
          else
            regular << t
          end
        end

        {
          regular: regular,
          blocking: blocking
        }
      end
    end

    def self.define(object_type = nil, &block)
      builder = Builder.new(object_type)
      builder.configure(&block)
      builder.build
    end

    def self.load_yaml(file_path)
      builder = Builder.new
      builder.load_yaml(file_path)
      builder.build
    end

    def self.load_json(file_path)
      builder = Builder.new
      builder.load_json(file_path)
      builder.build
    end
  end
end
