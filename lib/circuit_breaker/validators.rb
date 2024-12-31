require 'date'
require 'uri'
require 'json-schema'

module CircuitBreaker
  module Validators
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
          valid = values.include?(value)
          ValidationResult.new(valid, valid ? nil : "must be one of: #{values.join(', ')}")
        }
      end

      def self.exclusion(values)
        ->(value) {
          valid = !values.include?(value)
          ValidationResult.new(valid, valid ? nil : "cannot be one of: #{values.join(', ')}")
        }
      end

      def self.format(type)
        case type
        when :email
          regex(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i, "must be a valid email address")
        when :url
          ->(value) {
            return ValidationResult.new(true) if value.nil?
            begin
              uri = URI.parse(value)
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
        when :time
          ->(value) {
            return ValidationResult.new(true) if value.nil?
            begin
              Time.parse(value.to_s)
              ValidationResult.new(true)
            rescue ArgumentError
              ValidationResult.new(false, "must be a valid time")
            end
          }
        else
          raise ArgumentError, "Unsupported format type: #{type}"
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
          errors = results.reject(&:valid?).flat_map(&:errors)
          ValidationResult.new(errors.empty?, errors)
        }
      end

      def self.custom(&block)
        ->(value) {
          result = block.call(value)
          if result.is_a?(ValidationResult)
            result
          else
            ValidationResult.new(result != false && !result.is_a?(String), result.is_a?(String) ? result : nil)
          end
        }
      end

      def self.depends_on(other_field, &block)
        ->(value, context) {
          other_value = context.send(other_field)
          result = block.call(value, other_value)
          if result.is_a?(ValidationResult)
            result
          else
            ValidationResult.new(result != false && !result.is_a?(String), result.is_a?(String) ? result : nil)
          end
        }
      end

      def self.numericality(options = {})
        ->(value) {
          return ValidationResult.new(true) if value.nil?
          
          begin
            num = Float(value)
            errors = []
            
            errors << "must be greater than #{options[:greater_than]}" if options[:greater_than] && num <= options[:greater_than]
            errors << "must be less than #{options[:less_than]}" if options[:less_than] && num >= options[:less_than]
            errors << "must be an integer" if options[:only_integer] && !num.to_i.eql?(num)
            
            ValidationResult.new(errors.empty?, errors)
          rescue ArgumentError
            ValidationResult.new(false, "must be a number")
          end
        }
      end
    end
  end
end
