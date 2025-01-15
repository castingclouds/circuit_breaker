require_relative '../../lib/circuit_breaker'

module Examples
  module Document
    module Rules
      def self.define
        CircuitBreaker::Rules::DSL.define do
          # Content validation rules
          rule :valid_word_count do |token|
            analysis = context.get_result(:analysis)
            analysis && analysis[:word_count] >= 50
          end

          rule :valid_clarity do |token|
            clarity = context.get_result(:clarity)
            clarity && clarity[:score] >= 70
          end

          rule :valid_completeness do |token|
            completeness = context.get_result(:completeness)
            completeness && completeness[:score] >= 80
          end

          # Review rules
          rule :valid_review_metrics do |token|
            review = context.get_result(:review)
            review && review[:metrics][:word_count] >= 50 &&
              review[:metrics][:clarity_score] >= 70 &&
              review[:metrics][:completeness_score] >= 80
          end

          rule :is_high_priority do |token|
            token.priority == "high"
          end

          rule :is_urgent do |token|
            token.priority == "urgent"
          end

          # Approval rules
          rule :valid_approver do |token|
            final = context.get_result(:final)
            final && final[:status] == "APPROVED"
          end

          rule :approved_status do |token|
            final = context.get_result(:final)
            final && final[:status] == "APPROVED"
          end

          # Rejection rules
          rule :has_rejection_reasons do |token|
            rejection = context.get_result(:rejection)
            rejection && !rejection[:reasons].empty?
          end
        end
      end
    end
  end
end
