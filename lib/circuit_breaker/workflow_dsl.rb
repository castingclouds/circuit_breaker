require 'yaml'
require 'json'

module CircuitBreaker
  # Domain-specific language for defining workflows
  # Provides a fluent interface for creating workflow configurations
  module WorkflowDSL
    # Builder class for constructing workflow configurations
    # Uses method chaining to create a readable DSL
    class Builder
      attr_reader :states, :special_states, :transitions, :config, :object_type, :validations

      # Initialize a new workflow builder
      # @param object_type [String, nil] Optional type of objects flowing through the workflow
      def initialize(object_type = nil)
        @object_type = object_type
        @states = []
        @special_states = []
        @transitions = {}
        @validations = []
        @config = {
          nats_url: ENV['NATS_URL'] || 'nats://localhost:4222',
          log_level: ENV['LOG_LEVEL'] || 'info',
          metrics_enabled: ENV.fetch('METRICS_ENABLED', 'true') == 'true',
          retry_attempts: ENV.fetch('RETRY_ATTEMPTS', '3').to_i
        }
      end

      # Configure the workflow using a block
      # @param block [Proc] Configuration block
      def configure(&block)
        instance_eval(&block) if block_given?
      end

      # Set the type of objects that can flow through the workflow
      # @param type [String] Object type name
      def for_object(type)
        @object_type = type
      end

      # Configure connection settings
      # @param opts [Hash] Connection options
      def connection(opts = {})
        @config.merge!(opts)
      end

      # Configure metrics settings
      # @param enabled [Boolean] Whether metrics are enabled
      # @param opts [Hash] Additional metrics options
      def metrics(enabled: true, **opts)
        @config[:metrics_enabled] = enabled
        @config[:metrics_options] = opts
      end

      # Configure logging settings
      # @param level [String] Log level
      # @param opts [Hash] Additional logging options
      def logging(level: 'info', **opts)
        @config[:log_level] = level
        @config[:log_options] = opts
      end

      # Define the states in the workflow
      # @param state_list [Array<Symbol>] List of state names
      def states(*state_list)
        @states.concat(state_list)
      end

      # Define special states that can be entered from multiple places
      # @param state_list [Array<Symbol>] List of special state names
      def special_states(*state_list)
        @special_states.concat(state_list)
      end

      # Add a validation for a state
      # @param state [Symbol] State name
      # @param block [Proc] Validation block
      def validate(state, &block)
        @validations << {
          state: state,
          block: block
        }
      end

      # Define a regular flow between two states
      # @param from [Symbol] Source state
      # @param to [Symbol] Target state
      # @param via [Symbol] Transition name
      # @param requires [Array<Symbol>] Required fields for the transition
      # @param block [Proc] Optional transition block
      def flow(from:, to:, via:, requires: nil, &block)
        transition = {
          name: via,
          from: from,
          to: to,
          object_type: @object_type,
          requires: requires
        }
        transition[:block] = block if block_given?
        (@transitions[:regular] ||= []) << transition
      end

      # Define a multi-state flow (blocking or unblocking)
      # @param from [Symbol, Array<Symbol>] Source state(s)
      # @param to [Symbol, Array<Symbol>] Target state(s)
      # @param to_states [Array<Symbol>] Alternative target states
      # @param via [Symbol] Transition name
      # @param requires [Array<Symbol>] Required fields for the transition
      # @param block [Proc] Optional transition block
      def multi_flow(from:, to: nil, to_states: nil, via:, requires: nil, &block)
        target = to || to_states
        raise ArgumentError, "Must specify either 'to' or 'to_states'" unless target

        if to
          from_states = Array(from)
          from_states.each do |from_state|
            flow(from: from_state, to: to, via: via, requires: requires, &block)
          end
        else
          to_states.each do |to_state|
            flow(from: from, to: to_state, via: via, requires: requires, &block)
          end
        end
      end

      # Load a YAML configuration file
      # @param file_path [String] Path to YAML file
      def load_yaml(file_path)
        yaml = YAML.load_file(file_path)
        load_config(yaml)
      end

      # Load a JSON configuration file
      # @param file_path [String] Path to JSON file
      def load_json(file_path)
        json = JSON.parse(File.read(file_path))
        load_config(json)
      end

      # Build the final workflow configuration
      # @return [Hash] Complete workflow configuration
      def build
        validate!
        
        {
          places: {
            states: @states,
            special_states: @special_states
          },
          transitions: {
            regular: @transitions[:regular] || [],
            blocking: @transitions[:blocking] || []
          },
          config: @config,
          object_type: @object_type
        }
      end

      # Convert the workflow to YAML
      # @return [String] YAML representation
      def to_yaml
        build.to_yaml
      end

      # Convert the workflow to JSON
      # @return [String] JSON representation
      def to_json
        build.to_json
      end

      # Load configuration from a hash
      # @param config [Hash] Configuration hash
      # @return [Builder] self
      def load_config(config)
        config = deep_symbolize_keys(config)
        @object_type = config[:object_type]
        @places = config[:places] || {}
        @states = @places[:states] || []
        @special_states = @places[:special_states] || []
        @transitions = config[:transitions] || {}
        @validations = config[:validations]
        @config = config[:config] if config[:config]
        self
      end

      # Convert all hash keys to symbols recursively
      # @param obj [Hash, Array, Object] Object to convert
      # @return [Hash, Array, Object] Converted object
      def deep_symbolize_keys(obj)
        case obj
        when Hash
          obj.each_with_object({}) do |(key, value), result|
            result[key.to_sym] = deep_symbolize_keys(value)
          end
        when Array
          obj.map { |item| deep_symbolize_keys(item) }
        else
          obj
        end
      end

      private

      # Validate the workflow configuration
      # @raise [RuntimeError] If validation fails
      def validate!
        raise "No states defined" if @states.empty?
        raise "No transitions defined" if @transitions.empty?
      end
    end

    # Define a new workflow using a block
    # @param object_type [String, nil] Optional object type
    # @param block [Proc] Workflow definition block
    # @return [Hash] Workflow configuration
    def self.define(object_type = nil, &block)
      builder = Builder.new(object_type)
      builder.configure(&block)
      builder.build
    end

    # Load a workflow from a YAML file
    # @param file_path [String] Path to YAML file
    # @return [Hash] Workflow configuration
    def self.load_yaml(file_path)
      builder = Builder.new
      builder.load_yaml(file_path)
      builder.build
    end

    # Load a workflow from a JSON file
    # @param file_path [String] Path to JSON file
    # @return [Hash] Workflow configuration
    def self.load_json(file_path)
      builder = Builder.new
      builder.load_json(file_path)
      builder.build
    end
  end
end
