require 'date'
require 'uri'
require 'json-schema'

module CircuitBreaker
  module Rules
    class RuleError < StandardError; end
    class RuleResult
      attr_reader :valid, :errors

      def initialize(valid, errors = [])
        @valid = valid
        @errors = Array(errors)
      end

      def valid?
        @valid
      end

      def to_s
        valid? ? "valid" : "invalid: #{errors.join(', ')}"
      end

      def &(other)
        RuleResult.new(
          valid? && other.valid?,
          errors + other.errors
        )
      end

      def |(other)
        RuleResult.new(
          valid? || other.valid?,
          valid? || other.valid? ? [] : errors + other.errors
        )
      end
    end

    class DSL
      def initialize
        @rules = {}
        @descriptions = {}
        @context = nil
      end

      def self.define(&block)
        dsl = new
        dsl.instance_eval(&block) if block_given?
        dsl
      end

      def rule(name, desc = nil, &block)
        @rules[name] = block
        @descriptions[name] = desc if desc
      end

      def evaluate(rule_name, token)
        raise RuleError, "Unknown rule: #{rule_name}" unless @rules.key?(rule_name)
        
        puts "Evaluating rule '#{rule_name}' for token #{token.id}"
        puts "  Context: #{@context.inspect}"
        result = @rules[rule_name].call(token)
        puts "  Result: #{result.inspect}"
        case result
        when RuleResult
          result.valid?
        when true, false
          result
        else
          !!result
        end
      rescue StandardError => e
        raise RuleError, "Rule '#{rule_name}' failed for token #{token.id}: #{e.message}"
      end

      def chain(token)
        RuleChain.new(self, token)
      end

      def rules
        @rules.keys
      end

      def description(name)
        @descriptions[name]
      end

      def with_context(context)
        old_context = @context
        @context = context
        yield
      ensure
        @context = old_context
      end

      def context
        @context
      end

      # Helper methods for common rule conditions
      def presence(field)
        ->(token) { 
          val = token.send(field)
          result = !val.nil? && (!val.respond_to?(:empty?) || !val.empty?)
          RuleResult.new(result, result ? [] : ["#{field} must be present"])
        }
      end

      def different_values(field1, field2)
        ->(token) {
          val1, val2 = token.send(field1), token.send(field2)
          result = presence(field1).call(token).valid? && 
                  presence(field2).call(token).valid? && 
                  val1 != val2
          RuleResult.new(result, result ? [] : ["#{field1} must be different from #{field2}"])
        }
      end

      def matches(field, pattern, message = nil)
        ->(token) { 
          result = token.send(field).to_s.match?(pattern)
          RuleResult.new(result, result ? [] : [message || "#{field} does not match pattern"])
        }
      end

      def one_of(field, values)
        ->(token) { 
          result = values.include?(token.send(field))
          RuleResult.new(result, result ? [] : ["#{field} must be one of: #{values.join(', ')}"])
        }
      end

      def length(field, options = {})
        ->(token) {
          val = token.send(field).to_s
          min_valid = !options[:min] || val.length >= options[:min]
          max_valid = !options[:max] || val.length <= options[:max]
          result = min_valid && max_valid
          
          errors = []
          errors << "#{field} must be at least #{options[:min]} characters" if !min_valid
          errors << "#{field} must be at most #{options[:max]} characters" if !max_valid
          
          RuleResult.new(result, errors)
        }
      end

      def json_schema(field, schema)
        ->(token) {
          begin
            JSON::Validator.validate!(schema, token.send(field))
            RuleResult.new(true)
          rescue JSON::Schema::ValidationError => e
            RuleResult.new(false, [e.message])
          end
        }
      end

      def numericality(field, options = {})
        ->(token) {
          val = token.send(field)
          return RuleResult.new(false, ["#{field} must be a number"]) unless val.is_a?(Numeric)
          
          errors = []
          errors << "must be greater than #{options[:greater_than]}" if options[:greater_than] && !(val > options[:greater_than])
          errors << "must be greater than or equal to #{options[:greater_than_or_equal_to]}" if options[:greater_than_or_equal_to] && !(val >= options[:greater_than_or_equal_to])
          errors << "must be less than #{options[:less_than]}" if options[:less_than] && !(val < options[:less_than])
          errors << "must be less than or equal to #{options[:less_than_or_equal_to]}" if options[:less_than_or_equal_to] && !(val <= options[:less_than_or_equal_to])
          errors << "must be equal to #{options[:equal_to]}" if options[:equal_to] && val != options[:equal_to]
          errors << "must not be equal to #{options[:other_than]}" if options[:other_than] && val == options[:other_than]
          
          RuleResult.new(errors.empty?, errors.map { |e| "#{field} #{e}" })
        }
      end

      def all(*rules)
        ->(token) { 
          results = rules.map { |rule| rule.call(token) }
          results.reduce(RuleResult.new(true)) { |acc, result| acc & (result.is_a?(RuleResult) ? result : RuleResult.new(result)) }
        }
      end

      def any(*rules)
        ->(token) { 
          results = rules.map { |rule| rule.call(token) }
          results.reduce(RuleResult.new(false)) { |acc, result| acc | (result.is_a?(RuleResult) ? result : RuleResult.new(result)) }
        }
      end

      def none(*rules)
        ->(token) { 
          results = rules.map { |rule| rule.call(token) }
          result = results.none? { |r| r.is_a?(RuleResult) ? r.valid? : r }
          RuleResult.new(result, result ? [] : ["none of the rules should pass"])
        }
      end

      def custom(field = nil, message = nil, &block)
        if field
          ->(token) { 
            result = block.call(token.send(field))
            result.is_a?(RuleResult) ? result : RuleResult.new(result, message ? [message] : [])
          }
        else
          ->(token) {
            result = block.call(token)
            result.is_a?(RuleResult) ? result : RuleResult.new(result, message ? [message] : [])
          }
        end
      end

      def depends_on(field, other_field, &block)
        ->(token) {
          other_value = token.send(other_field)
          return RuleResult.new(true) if other_value.nil?
          
          result = block.call(token.send(field), other_value)
          result.is_a?(RuleResult) ? result : RuleResult.new(result, ["#{field} dependency on #{other_field} failed"])
        }
      end
    end

    class RuleChain
      def initialize(dsl, token)
        @dsl = dsl
        @token = token
        @result = RuleResult.new(true)
      end

      def requires(*rule_names)
        results = rule_names.map { |rule| RuleResult.new(@dsl.evaluate(rule, @token)) }
        @result = results.reduce(@result) { |acc, result| acc & result }
        self
      end

      def requires_any(*rule_names)
        results = rule_names.map { |rule| RuleResult.new(@dsl.evaluate(rule, @token)) }
        @result = @result & results.reduce(RuleResult.new(false)) { |acc, result| acc | result }
        self
      end

      def valid?
        @result.valid?
      end

      def errors
        @result.errors
      end
    end
  end
end
