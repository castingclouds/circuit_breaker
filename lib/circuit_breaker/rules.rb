module CircuitBreaker
  class Rule
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def validate(results)
      CircuitBreaker::Logger.debug("Validating rule: #{@name}")
      CircuitBreaker::Logger.debug("Results available: #{results.keys.inspect}")

      result = case @name
      when 'valid_word_count'
        word_count = results['analyzeDocument'][:wordCount]
        sentences = results['analyzeDocument'][:analysis][:sentences]
        CircuitBreaker::Logger.debug("  Checking word count (#{word_count} >= 50) and sentences (#{sentences} >= 3)")
        word_count >= 50 && sentences >= 3

      when 'valid_clarity'
        score = results['analyzeClarity'][:score]
        readability = results['analyzeClarity'][:clarity][:readabilityIndex]
        CircuitBreaker::Logger.debug("  Checking clarity score (#{score} >= 70) and readability (#{readability} >= 60)")
        score >= 70 && readability >= 60

      when 'has_summary'
        has_summary = results['analyzeCompleteness'][:completeness][:hasSummary]
        CircuitBreaker::Logger.debug("  Checking for summary section: #{has_summary}")
        has_summary

      when 'has_examples'
        paragraphs = results['analyzeDocument'][:analysis][:paragraphs]
        CircuitBreaker::Logger.debug("  Checking for examples (paragraphs >= 2): #{paragraphs}")
        paragraphs >= 2

      when 'has_conclusion'
        has_conclusion = results['analyzeCompleteness'][:completeness][:hasConclusion]
        CircuitBreaker::Logger.debug("  Checking for conclusion section: #{has_conclusion}")
        has_conclusion

      when 'valid_review'
        score = results['reviewDocument'][:review][:score]
        CircuitBreaker::Logger.debug("  Checking review score (#{score} >= 80)")
        score >= 80

      when 'valid_approval'
        begin
          CircuitBreaker::Logger.debug("  Checking valid_approval rule")
          CircuitBreaker::Logger.debug("  Results: #{results.inspect}")
          
          unless results['finalizeDocument']
            CircuitBreaker::Logger.error("  Missing finalizeDocument results")
            return false
          end
          
          finalization = results['finalizeDocument'][:finalization]
          CircuitBreaker::Logger.debug("  Checking finalization data: #{finalization.inspect}")
          
          unless finalization.is_a?(Hash)
            CircuitBreaker::Logger.error("  Invalid finalization data type")
            return false
          end
          
          required_fields = ['approver', 'timestamp', 'version']
          missing_fields = required_fields - finalization.keys.map(&:to_s)
          
          if missing_fields.any?
            CircuitBreaker::Logger.error("  Missing required fields: #{missing_fields.join(', ')}")
            return false
          end
          
          CircuitBreaker::Logger.debug("  Rule passed: all required fields present")
          true
        rescue StandardError => e
          CircuitBreaker::Logger.error("  Error validating approval: #{e.message}")
          false
        end

      when 'valid_rejection'
        begin
          CircuitBreaker::Logger.debug("  Checking valid_rejection rule")
          CircuitBreaker::Logger.debug("  Results: #{results.inspect}")
          
          unless results['rejectDocument']
            CircuitBreaker::Logger.error("  Missing rejectDocument results")
            return false
          end
          
          rejection = results['rejectDocument'][:rejection]
          CircuitBreaker::Logger.debug("  Checking rejection data: #{rejection.inspect}")
          
          unless rejection.is_a?(Hash)
            CircuitBreaker::Logger.error("  Invalid rejection data type")
            return false
          end
          
          required_fields = ['rejector', 'reason', 'suggestions']
          missing_fields = required_fields - rejection.keys.map(&:to_s)
          
          if missing_fields.any?
            CircuitBreaker::Logger.error("  Missing required fields: #{missing_fields.join(', ')}")
            return false
          end
          
          CircuitBreaker::Logger.debug("  Rule passed: all required fields present")
          true
        rescue StandardError => e
          CircuitBreaker::Logger.error("  Error validating rejection: #{e.message}")
          false
        end

      else
        CircuitBreaker::Logger.error("  Unknown rule: #{@name}")
        false
      end

      CircuitBreaker::Logger.debug("Rule '#{@name}' result: #{result}")
      result
    end
  end
end
