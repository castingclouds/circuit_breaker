require 'date'
require 'uri'
require 'json-schema'

module CircuitBreaker
  module Validators
    class DSL
      def self.define(&block)
        new.tap { |dsl| dsl.instance_eval(&block) }
      end

      def self.define_token_validators(&block)
        dsl = new
        dsl.extend(TokenValidators)
        dsl.instance_eval(&block)
        dsl
      end

      def initialize
        @validators = {}
        @descriptions = {}
      end

      def validator(name, desc: nil, &block)
        @validators[name] = block
        @descriptions[name] = desc if desc
      end

      def evaluate(field, token)
        validator = @validators[field]
        return ValidationResult.new(true) unless validator
        
        result = validator.call(token)
        case result
        when ValidationResult
          result
        when true, false
          ValidationResult.new(result, result ? nil : "validation failed for #{field}")
        else
          ValidationResult.new(!!result, result.to_s)
        end
      end

      def chain(token)
        ValidationChain.new(self, token)
      end

      def validators
        @validators.keys
      end

      def description(name)
        @descriptions[name]
      end
    end

    class ValidationChain
      def initialize(dsl, token)
        @dsl = dsl
        @token = token
        @result = ValidationResult.new(true)
      end

      def validate(*fields)
        fields.each do |field|
          @result = @result & @dsl.evaluate(field, @token)
        end
        self
      end

      def or_validate(*fields)
        sub_result = ValidationResult.new(false)
        fields.each do |field|
          sub_result = sub_result | @dsl.evaluate(field, @token)
        end
        @result = @result & sub_result
        self
      end

      def valid?
        @result.valid?
      end

      def errors
        @result.errors
      end
    end

    class ValidatorChain
      def initialize
        @token = nil
      end

      def chain(token)
        @token = token
        self
      end

      def validate(*fields)
        result = fields.all? do |field|
          value = @token.send(field)
          !value.nil? && (!value.respond_to?(:empty?) || !value.empty?)
        end
        ValidationResult.new(result)
      end

      def or_validate(*fields)
        result = fields.any? do |field|
          value = @token.send(field)
          !value.nil? && (!value.respond_to?(:empty?) || !value.empty?)
        end
        ValidationResult.new(result)
      end
    end

    module TokenValidators
      def presence(field)
        ->(token) {
          value = token.send(field)
          Rules.presence.call(value)
        }
      end

      def regex(field, pattern, message = nil)
        ->(token) {
          value = token.send(field)
          Rules.regex(pattern, message).call(value)
        }
      end

      def length(field, options = {})
        ->(token) {
          value = token.send(field)
          Rules.length(min: options[:min], max: options[:max]).call(value)
        }
      end

      def inclusion(field, values)
        ->(token) {
          value = token.send(field)
          Rules.inclusion(values).call(value)
        }
      end

      def custom(field, message = nil, &block)
        ->(token) {
          result = block.call(token)
          ValidationResult.new(result, result ? nil : message || "custom validation failed for #{field}")
        }
      end

      def all(*validators)
        ->(token) {
          validators.reduce(ValidationResult.new(true)) do |acc, validator|
            acc & validator.call(token)
          end
        }
      end
    end

    class ValidationResult
      attr_reader :valid, :errors

      def initialize(valid, errors = [])
        @valid = valid
        @errors = Array(errors)
      end

      def valid?
        @valid
      end

      def to_s
        errors.join(", ")
      end

      def &(other)
        return self unless valid?
        return other unless other.is_a?(ValidationResult)
        
        ValidationResult.new(
          valid? && other.valid?,
          errors + other.errors
        )
      end

      def |(other)
        return other unless valid?
        return self unless other.is_a?(ValidationResult)
        
        ValidationResult.new(
          valid? || other.valid?,
          valid? ? [] : other.valid? ? [] : errors + other.errors
        )
      end
    end

    class CompositeValidator
      def self.all(*validators)
        ->(value) {
          result = validators.reduce(ValidationResult.new(true)) do |acc, validator|
            acc & validator.call(value)
          end
          result
        }
      end

      def self.any(*validators)
        ->(value) {
          result = validators.reduce(ValidationResult.new(false, [])) do |acc, validator|
            acc | validator.call(value)
          end
          result
        }
      end

      def self.none(*validators)
        ->(value) {
          result = validators.all? { |v| !v.call(value).valid? }
          ValidationResult.new(result, result ? nil : "failed none validation")
        }
      end
    end

    module Rules
      def self.type(expected_type)
        ->(value) {
          valid = value.is_a?(expected_type)
          ValidationResult.new(valid, valid ? nil : "must be a #{expected_type}")
        }
      end

      def self.regex(pattern, message = nil)
        ->(value) {
          return ValidationResult.new(true) if value.nil?
          valid = value.to_s.match?(pattern)
          ValidationResult.new(valid, valid ? nil : (message || "must match pattern #{pattern}"))
        }
      end

      def self.presence
        ->(value) {
          valid = !value.nil? && (value.respond_to?(:empty?) ? !value.empty? : true)
          ValidationResult.new(valid, valid ? nil : "cannot be empty")
        }
      end

      def self.length(min: nil, max: nil)
        ->(value) {
          return ValidationResult.new(true) if value.nil?
          length = value.to_s.length
          errors = []
          errors << "must be at least #{min} characters" if min && length < min
          errors << "must be at most #{max} characters" if max && length > max
          ValidationResult.new(errors.empty?, errors)
        }
      end

      def self.inclusion(values)
        ->(value) {
          return ValidationResult.new(true) if value.nil?
          valid = values.include?(value.to_s.downcase)
          ValidationResult.new(valid, valid ? nil : "must be one of: #{values.join(', ')}")
        }
      end

      def self.exclusion(values)
        ->(value) {
          return ValidationResult.new(true) if value.nil?
          valid = !values.include?(value.to_s.downcase)
          ValidationResult.new(valid, valid ? nil : "cannot be one of: #{values.join(', ')}")
        }
      end

      def self.format(type)
        case type
        when :email
          regex(/\A[^@\s]+@[^@\s]+\z/, "must be a valid email address")
        when :url
          ->(value) {
            return ValidationResult.new(true) if value.nil?
            begin
              uri = URI.parse(value.to_s)
              valid = uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
              ValidationResult.new(valid, valid ? nil : "must be a valid URL")
            rescue URI::InvalidURIError
              ValidationResult.new(false, "must be a valid URL")
            end
          }
        when :date
          ->(value) {
            return ValidationResult.new(true) if value.nil?
            begin
              Date.parse(value.to_s)
              ValidationResult.new(true)
            rescue ArgumentError
              ValidationResult.new(false, "must be a valid date")
            end
          }
        else
          raise ArgumentError, "unknown format type: #{type}"
        end
      end

      def self.json_schema(schema)
        ->(value) {
          return ValidationResult.new(true) if value.nil?
          begin
            JSON::Validator.validate!(schema, value)
            ValidationResult.new(true)
          rescue JSON::Schema::ValidationError => e
            ValidationResult.new(false, e.message)
          end
        }
      end

      def self.each(&block)
        ->(value) {
          return ValidationResult.new(true) if value.nil?
          return ValidationResult.new(false, "must be enumerable") unless value.respond_to?(:each)

          results = value.map { |item| block.call(item) }
          valid = results.all?(&:valid?)
          errors = results.flat_map(&:errors)
          ValidationResult.new(valid, errors)
        }
      end

      def self.custom(&block)
        ->(value) {
          result = block.call(value)
          case result
          when ValidationResult
            result
          when true, false
            ValidationResult.new(result, result ? nil : "failed custom validation")
          else
            ValidationResult.new(!!result, result.to_s)
          end
        }
      end

      def self.depends_on(other_field, &block)
        ->(value, context) {
          return ValidationResult.new(true) if value.nil?
          return ValidationResult.new(false, "no context provided") unless context
          other_value = context.send(other_field)
          result = block.call(value, other_value)
          ValidationResult.new(result, result ? nil : "failed dependency validation with #{other_field}")
        }
      end

      def self.numericality(options = {})
        ->(value) {
          return ValidationResult.new(true) if value.nil?
          
          errors = []
          number = value.to_f
          
          if options[:greater_than] && !(number > options[:greater_than])
            errors << "must be greater than #{options[:greater_than]}"
          end
          
          if options[:less_than] && !(number < options[:less_than])
            errors << "must be less than #{options[:less_than]}"
          end
          
          ValidationResult.new(errors.empty?, errors)
        }
      end
    end

    def validators
      ValidatorChain.new
    end
  end
end
