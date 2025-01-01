module CircuitBreaker
  module RulesEngine
    class RuleValidationError < StandardError; end

    # DSL for defining workflow rules
    class DSL
      def initialize
        @rules = {}
        @conditions = {}
        @descriptions = {}
      end

      def rule(name, desc: nil, &block)
        if block_given?
          @rules[name] = block
          @descriptions[name] = desc if desc
        else
          @rules[name]
        end
      end

      # Get all defined rules
      def rules
        @rules.keys
      end

      class RuleChain
        def initialize(engine, token)
          @engine = engine
          @token = token
          @result = true
        end

        def check(*rule_names)
          @result = @result && rule_names.all? { |rule| @engine.evaluate(rule, @token) }
          self
        end

        def or_check(*rule_names)
          @result = @result || rule_names.any? { |rule| @engine.evaluate(rule, @token) }
          self
        end

        def valid?
          @result
        end
      end

      # Start a new rule chain
      def chain(token)
        RuleChain.new(self, token)
      end

      # Evaluate a rule against a token
      def evaluate(rule_name, token)
        raise "Unknown rule: #{rule_name}" unless @rules.key?(rule_name)
        rule = @rules[rule_name]
        begin
          result = rule.call(token)
          puts "Rule '#{rule_name}' evaluated to #{result} for token #{token.id}"
          unless result
            raise RuleValidationError, "Rule '#{rule_name}' failed for token #{token.id}"
          end
          result
        rescue StandardError => e
          puts "Rule '#{rule_name}' failed with error: #{e.message}"
          raise RuleValidationError, "Rule '#{rule_name}' failed for token #{token.id}: #{e.message}"
        end
      end

      # Chain multiple rule evaluations
      def check(token, *rule_names)
        rule_names.each { |rule| evaluate(rule, token) }
        self
      end

      # Helper methods for common rule conditions
      def requires(field)
        ->(token) { !token.send(field).nil? }
      end

      def minimum_length(field, length)
        ->(token) { token.send(field).to_s.length >= length }
      end

      def matches(field, pattern)
        ->(token) { token.send(field).to_s.match?(pattern) }
      end

      def one_of(field, values)
        ->(token) { values.include?(token.send(field)) }
      end

      def different_from(field1, field2)
        ->(token) { token.send(field1) != token.send(field2) }
      end

      def all(*conditions)
        ->(token) { conditions.all? { |condition| condition.call(token) } }
      end

      def any(*conditions)
        ->(token) { conditions.any? { |condition| condition.call(token) } }
      end

      def none(*conditions)
        ->(token) { conditions.none? { |condition| condition.call(token) } }
      end

      def description(name)
        @descriptions[name]
      end

      # Class methods for creating and combining rules
      class << self
        def define(&block)
          dsl = new
          dsl.instance_eval(&block) if block_given?
          dsl
        end

        def combine(*rule_sets)
          combined = new
          rule_sets.each do |rules|
            rules.rules.each do |name, rule|
              combined.rule(name, &rule)
            end
          end
          combined
        end
      end
    end
  end
end
