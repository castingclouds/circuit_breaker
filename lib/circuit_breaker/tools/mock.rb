require_relative 'tool'

module CircuitBreaker
  module Tools
    class Mock < Tool
      def initialize
        super(
          name: 'mock',
          description: 'Mock executor for document workflow actions',
          parameters: {
            action: {
              type: String,
              enum: ['analyzeDocument', 'analyzeClarity', 'analyzeCompleteness', 'reviewDocument', 'finalizeDocument', 'rejectDocument']
            },
            token: { type: Object }
          }
        )
      end

      def execute(args)
        action = args[:action]
        token = args[:token]

        CircuitBreaker::Logger.info("Mock tool executing action: #{action}")
        CircuitBreaker::Logger.info("Token state: #{token&.state}")

        # Ensure token exists
        unless token
          CircuitBreaker::Logger.error("Token is undefined")
          return { success: false, error: 'Token is undefined' }
        end

        # Get content safely
        content = token.content.to_s
        CircuitBreaker::Logger.info("Processing content length: #{content.length} characters")

        begin
          result = case action
          when 'analyzeDocument'
            CircuitBreaker::Logger.info("Analyzing document content...")
            analyze_document(content)
          when 'analyzeClarity'
            CircuitBreaker::Logger.info("Analyzing document clarity...")
            analyze_clarity(content)
          when 'analyzeCompleteness'
            CircuitBreaker::Logger.info("Analyzing document completeness...")
            analyze_completeness(content)
          when 'reviewDocument'
            CircuitBreaker::Logger.info("Reviewing document...")
            review_document
          when 'finalizeDocument'
            CircuitBreaker::Logger.info("Finalizing document...")
            finalize_document
          when 'rejectDocument'
            CircuitBreaker::Logger.info("Rejecting document...")
            reject_document
          else
            CircuitBreaker::Logger.error("Unknown action: #{action}")
            { success: false, error: "Unknown action: #{action}" }
          end

          CircuitBreaker::Logger.info("Action result: #{result.inspect}")
          result
        rescue StandardError => e
          CircuitBreaker::Logger.error("Error executing action '#{action}': #{e.message}")
          { success: false, error: e.message }
        end
      end

      private

      def analyze_document(content)
        CircuitBreaker::Logger.debug("Starting document analysis...")
        words = content.split(/\s+/).reject(&:empty?)
        word_count = words.length
        CircuitBreaker::Logger.debug("Found #{word_count} words")

        paragraphs = content.split("\n").length
        sentences = content.split(/[.!?]+/).length
        avg_length = words.empty? ? 0 : words.sum(&:length).to_f / words.length

        CircuitBreaker::Logger.debug("Analysis stats: #{paragraphs} paragraphs, #{sentences} sentences, #{avg_length.round(2)} avg word length")

        {
          success: true,
          wordCount: word_count,
          analysis: {
            paragraphs: paragraphs,
            sentences: sentences,
            averageWordLength: avg_length
          }
        }
      end

      def analyze_clarity(content)
        CircuitBreaker::Logger.debug("Starting clarity analysis...")
        words = content.split(/\s+/).reject(&:empty?)
        complex_words = words.count { |w| w.length > 8 }
        CircuitBreaker::Logger.debug("Found #{complex_words} complex words out of #{words.length} total words")

        clarity_score = words.empty? ? 100 : [85, ((1 - complex_words.to_f / words.length) * 100).floor].min
        CircuitBreaker::Logger.debug("Calculated clarity score: #{clarity_score}")

        suggestions = complex_words > 5 ? ['Consider simplifying complex terms'] : []
        CircuitBreaker::Logger.debug("Generated #{suggestions.length} suggestions")

        {
          success: true,
          score: clarity_score,
          clarity: {
            totalWords: words.length,
            complexWords: complex_words,
            readabilityIndex: clarity_score,
            suggestions: suggestions
          }
        }
      end

      def analyze_completeness(content)
        CircuitBreaker::Logger.debug("Starting completeness analysis...")
        sections = content.split("\n").count { |line| line.start_with?('#') }
        paragraphs = content.split("\n\n").length
        CircuitBreaker::Logger.debug("Found #{sections} sections and #{paragraphs} paragraphs")

        completeness_score = [90, (sections * 20 + paragraphs * 10).floor].min
        CircuitBreaker::Logger.debug("Calculated completeness score: #{completeness_score}")

        has_summary = content.downcase.include?('summary')
        has_conclusion = content.downcase.include?('conclusion')
        CircuitBreaker::Logger.debug("Document structure: summary=#{has_summary}, conclusion=#{has_conclusion}")

        {
          success: true,
          score: completeness_score,
          completeness: {
            sections: sections,
            paragraphs: paragraphs,
            hasSummary: has_summary,
            hasConclusion: has_conclusion,
            missingElements: []
          }
        }
      end

      def review_document
        CircuitBreaker::Logger.debug("Starting document review...")
        reviewer = "mock.reviewer@example.com"
        comments = [
          "Good coverage of core concepts",
          "Examples are clear and relevant"
        ]
        score = 85
        
        CircuitBreaker::Logger.debug("Review by #{reviewer} with score #{score}")
        CircuitBreaker::Logger.debug("Comments: #{comments.join(', ')}")
        
        {
          success: true,
          review: {
            reviewer: reviewer,
            comments: comments,
            score: score
          }
        }
      end

      def finalize_document
        CircuitBreaker::Logger.debug("Starting document finalization...")
        approver = "mock.approver@example.com"
        timestamp = Time.now.iso8601
        version = "1.0.0"
        
        CircuitBreaker::Logger.debug("Finalization by #{approver} at #{timestamp}")
        CircuitBreaker::Logger.debug("Setting version to #{version}")
        
        {
          success: true,
          finalization: {
            approver: approver,
            timestamp: timestamp,
            version: version
          }
        }
      end

      def reject_document
        CircuitBreaker::Logger.debug("Starting document rejection...")
        rejector = "mock.rejector@example.com"
        reason = "Needs more detailed examples"
        suggestions = [
          "Add code snippets for each scenario",
          "Include performance benchmarks"
        ]
        
        CircuitBreaker::Logger.debug("Rejection by #{rejector}")
        CircuitBreaker::Logger.debug("Reason: #{reason}")
        CircuitBreaker::Logger.debug("Suggestions: #{suggestions.join(', ')}")
        
        {
          success: true,
          rejection: {
            rejector: rejector,
            reason: reason,
            suggestions: suggestions
          }
        }
      end
    end

    # Register the mock tool
    ToolRegistry.instance.register(Mock.new)
  end
end
