module CircuitBreaker
  module RulesEngine
    class DSL
      def self.load(file_path)
        new
      end

      def evaluate(rule_name, token)
        case rule_name
        when 'can_approve'
          token.approver_id.to_s.length > 0
        when 'can_reject'
          token.rejection_reason.to_s.length > 0
        else
          false
        end
      end
    end
  end
end
