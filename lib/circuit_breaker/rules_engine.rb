module CircuitBreaker
  module RulesEngine
    class Rule
      attr_reader :name, :conditions

      def initialize(name)
        @name = name
        @conditions = []
      end

      def requires(field)
        @conditions << {
          type: :presence,
          field: field,
          validate: ->(token) { !token.send(field).nil? }
        }
        self
      end

      def minimum_length(field, length)
        @conditions << {
          type: :length,
          field: field,
          validate: ->(token) { token.send(field).to_s.length >= length }
        }
        self
      end

      def different_from(field1, field2)
        @conditions << {
          type: :comparison,
          fields: [field1, field2],
          validate: ->(token) { token.send(field1) != token.send(field2) }
        }
        self
      end

      def matches(field, pattern)
        @conditions << {
          type: :format,
          field: field,
          validate: ->(token) { token.send(field).to_s.match?(pattern) }
        }
        self
      end

      def one_of(field, values)
        @conditions << {
          type: :inclusion,
          field: field,
          validate: ->(token) { values.include?(token.send(field).to_s.downcase) }
        }
        self
      end

      def evaluate(token)
        @conditions.all? { |condition| condition[:validate].call(token) }
      end
    end

    class DSL
      def initialize
        @rules = {}
      end

      def rule(name, &block)
        rule = Rule.new(name)
        rule.instance_eval(&block) if block_given?
        @rules[name] = rule
        rule
      end

      def evaluate(rule_name, token)
        rule = @rules[rule_name]
        return false unless rule
        rule.evaluate(token)
      end

      # Predefined rules
      def self.define_workflow_rules
        dsl = new

        # Submit rules
        dsl.rule(:can_submit) do
          requires(:reviewer_id)
          different_from(:reviewer_id, :author_id)
          minimum_length(:content, 10)
        end

        # Review rules
        dsl.rule(:can_review) do
          requires(:reviewer_comments)
          minimum_length(:reviewer_comments, 10)
        end

        # Approve rules
        dsl.rule(:can_approve) do
          requires(:approver_id)
          different_from(:approver_id, :reviewer_id)
        end

        # Reject rules
        dsl.rule(:can_reject) do
          requires(:rejection_reason)
          minimum_length(:rejection_reason, 1)
        end

        # Document validation rules
        dsl.rule(:valid_document) do
          requires(:title)
          matches(:title, /^[A-Z]/)
          minimum_length(:content, 10)
          one_of(:priority, ['low', 'medium', 'high'])
        end

        dsl
      end
    end
  end
end
