module Examples
  # Document Assistant using Ollama for content analysis and suggestions
  class DocumentAssistant
    class AnalyzeContentTool < CircuitBreaker::Executors::LLM::Tool
      def initialize
        super(
          name: 'analyze_content',
          description: 'Analyze document content and provide feedback',
          parameters: {
            content: { type: 'string', description: 'Document content to analyze' },
            word_count: { type: 'integer', description: 'Current word count' },
            min_words: { type: 'integer', description: 'Minimum required words' }
          }
        )
      end

      def execute(content:, word_count:, min_words: 100)
        analysis = []
        analysis << analyze_length(word_count, min_words)
        analysis << analyze_structure(content)
        analysis << analyze_clarity(content)
        analysis << analyze_completeness(content)
        analysis.join("\n\n")
      rescue => e
        "Error analyzing content: #{e.message}"
      end

      private

      def analyze_length(word_count, min_words)
        <<~ANALYSIS
          Word Count Analysis:
          - Current count: #{word_count} words
          - Minimum required: #{min_words} words
          - Status: #{word_count >= min_words ? 'Meets' : 'Does not meet'} requirement
        ANALYSIS
      end

      def analyze_structure(content)
        return "Unable to analyze structure" unless content.is_a?(String)
        
        paragraphs = content.split(/\n\n+/).size
        sections = content.scan(/^[A-Z][^.!?]*[:|\n]/).size
        
        <<~ANALYSIS
          Structure Analysis:
          - Paragraphs: #{paragraphs}
          - Sections: #{sections}
          - Assessment: #{assess_structure(paragraphs, sections)}
        ANALYSIS
      end

      def assess_structure(paragraphs, sections)
        if paragraphs < 3
          "Consider adding more paragraphs for better organization"
        elsif sections < 2
          "Consider adding section headings for better structure"
        else
          "Good structural organization"
        end
      end

      def analyze_clarity(content)
        return "Unable to analyze clarity" unless content.is_a?(String)
        
        sentences = content.split(/[.!?]/).map(&:strip).reject(&:empty?)
        long_sentences = sentences.select { |s| s.split.size > 20 }
        passive_voice = content.scan(/\b(?:is|are|was|were|be|been|being)\s+\w+ed\b/i).size
        
        <<~ANALYSIS
          Clarity Analysis:
          - Long sentences: #{long_sentences.size}
          - Passive voice instances: #{passive_voice}
          - Recommendations: #{clarity_recommendations(long_sentences.size, passive_voice)}
        ANALYSIS
      end

      def clarity_recommendations(long_sentences, passive_voice)
        recommendations = []
        recommendations << "Break down long sentences" if long_sentences > 0
        recommendations << "Use more active voice" if passive_voice > 2
        recommendations.empty? ? "Good clarity" : recommendations.join(", ")
      end

      def analyze_completeness(content)
        return "Unable to analyze completeness" unless content.is_a?(String)
        
        key_sections = {
          introduction: content.downcase.include?('introduction'),
          background: content.downcase.include?('background'),
          methodology: content.downcase.include?('methodology'),
          conclusion: content.downcase.include?('conclusion')
        }
        
        <<~ANALYSIS
          Completeness Analysis:
          - Key sections present: #{key_sections.count { |_, present| present }}/#{key_sections.size}
          - Missing sections: #{missing_sections(key_sections)}
        ANALYSIS
      end

      def missing_sections(sections)
        missing = sections.reject { |_, present| present }.keys
        missing.empty? ? "None" : missing.map(&:to_s).join(", ")
      end
    end

    class SuggestImprovementsTool < CircuitBreaker::Executors::LLM::Tool
      def initialize
        super(
          name: 'suggest_improvements',
          description: 'Suggest specific improvements for the document',
          parameters: {
            content: { type: 'string', description: 'Document content' },
            feedback_type: { type: 'string', description: 'Type of feedback (structure/clarity/completeness)' }
          }
        )
      end

      def execute(content:, feedback_type:)
        case feedback_type.downcase
        when 'structure'
          suggest_structure_improvements(content)
        when 'clarity'
          suggest_clarity_improvements(content)
        when 'completeness'
          suggest_completeness_improvements(content)
        else
          "Unknown feedback type: #{feedback_type}"
        end
      rescue => e
        "Error suggesting improvements: #{e.message}"
      end

      private

      def suggest_structure_improvements(content)
        return "Unable to analyze structure" unless content.is_a?(String)
        
        paragraphs = content.split(/\n\n+/)
        suggestions = []
        
        suggestions << structure_organization_suggestions(paragraphs)
        suggestions << structure_formatting_suggestions(content)
        suggestions << structure_transition_suggestions(paragraphs)
        
        format_suggestions("Structure Improvements", suggestions.flatten)
      end

      def structure_organization_suggestions(paragraphs)
        suggestions = []
        suggestions << "Break content into more sections" if paragraphs.size < 3
        suggestions << "Add clear section headings" unless content.match?(/^#|^[A-Z].*:/)
        suggestions
      end

      def structure_formatting_suggestions(content)
        suggestions = []
        suggestions << "Use bullet points for lists" unless content.match?(/^\s*[-*]/)
        suggestions << "Add emphasis using bold or italics" unless content.match?(/\*\*|\*/)
        suggestions
      end

      def structure_transition_suggestions(paragraphs)
        return [] if paragraphs.size <= 1
        ["Add transition sentences between paragraphs"]
      end

      def suggest_clarity_improvements(content)
        return "Unable to analyze clarity" unless content.is_a?(String)
        
        sentences = content.split(/[.!?]/).map(&:strip).reject(&:empty?)
        suggestions = []
        
        suggestions << clarity_sentence_suggestions(sentences)
        suggestions << clarity_voice_suggestions(content)
        suggestions << clarity_word_choice_suggestions(content)
        
        format_suggestions("Clarity Improvements", suggestions.flatten)
      end

      def clarity_sentence_suggestions(sentences)
        suggestions = []
        if sentences.any? { |s| s.split.size > 20 }
          suggestions << "Break down long sentences into shorter ones"
          suggestions << "Use more punctuation to improve readability"
        end
        suggestions
      end

      def clarity_voice_suggestions(content)
        suggestions = []
        if content.match?(/\b(?:is|are|was|were)\s+\w+ed\b/i)
          suggestions << "Use active voice instead of passive voice"
          suggestions << "Make sentences more direct"
        end
        suggestions
      end

      def clarity_word_choice_suggestions(content)
        suggestions = []
        if content.match?(/\b(?:very|really|quite|extremely)\b/i)
          suggestions << "Use stronger, more specific words"
          suggestions << "Remove unnecessary intensifiers"
        end
        suggestions
      end

      def suggest_completeness_improvements(content)
        return "Unable to analyze completeness" unless content.is_a?(String)
        
        suggestions = []
        suggestions << completeness_section_suggestions(content)
        suggestions << completeness_detail_suggestions(content)
        suggestions << completeness_reference_suggestions(content)
        
        format_suggestions("Completeness Improvements", suggestions.flatten)
      end

      def completeness_section_suggestions(content)
        suggestions = []
        %w[introduction background methodology results conclusion].each do |section|
          suggestions << "Add #{section} section" unless content.downcase.include?(section)
        end
        suggestions
      end

      def completeness_detail_suggestions(content)
        suggestions = []
        suggestions << "Include more specific examples" if content.scan(/(?:for example|such as|like)/).size < 2
        suggestions << "Add supporting data or evidence" if content.scan(/\d+%|\d+\.\d+/).size < 2
        suggestions
      end

      def completeness_reference_suggestions(content)
        suggestions = []
        suggestions << "Add citations or references" unless content.match?(/\[\d+\]|\(\w+,\s*\d{4}\)/)
        suggestions
      end

      def format_suggestions(title, suggestions)
        return "No improvements needed" if suggestions.empty?
        
        [
          title,
          "=" * title.length,
          "",
          suggestions.map { |s| "- #{s}" }
        ].flatten.join("\n")
      end
    end

    class SentimentAnalysisTool < CircuitBreaker::Executors::LLM::Tool
      def initialize
        super(
          name: 'analyze_sentiment',
          description: 'Analyze the sentiment and tone of the document',
          parameters: {
            content: { type: 'string', description: 'Document content to analyze' },
            context: { type: 'string', description: 'Document context or type', default: 'general' }
          }
        )
      end

      def execute(content:, context: 'general')
        return "Unable to analyze sentiment" unless content.is_a?(String)

        analysis = []
        analysis << analyze_overall_sentiment(content)
        analysis << analyze_emotional_tone(content)
        analysis << analyze_formality(content)
        analysis << context_specific_analysis(content, context)
        analysis.join("\n\n")
      rescue => e
        "Error analyzing sentiment: #{e.message}"
      end

      private

      def analyze_overall_sentiment(content)
        # Simple sentiment indicators
        positive_words = %w[good great excellent amazing wonderful positive success successful achieve accomplished beneficial effective]
        negative_words = %w[bad poor terrible horrible negative fail failure difficult problem issue concern]
        
        positive_count = count_matches(content, positive_words)
        negative_count = count_matches(content, negative_words)
        
        sentiment_score = calculate_sentiment_score(positive_count, negative_count)
        
        <<~ANALYSIS
          Overall Sentiment Analysis:
          - Sentiment Score: #{sentiment_score}/10
          - Positive Indicators: #{positive_count}
          - Negative Indicators: #{negative_count}
          - Overall Tone: #{describe_sentiment(sentiment_score)}
        ANALYSIS
      end

      def analyze_emotional_tone(content)
        emotional_indicators = {
          confidence: %w[confident assured certain definitely clearly],
          uncertainty: %w[maybe perhaps possibly might potentially],
          urgency: %w[urgent immediate critical essential crucial],
          caution: %w[careful cautious warning risk concern]
        }

        tone_analysis = emotional_indicators.transform_values { |words| count_matches(content, words) }
        
        <<~ANALYSIS
          Emotional Tone Analysis:
          - Confidence Level: #{describe_intensity(tone_analysis[:confidence])}
          - Uncertainty Level: #{describe_intensity(tone_analysis[:uncertainty])}
          - Urgency Level: #{describe_intensity(tone_analysis[:urgency])}
          - Caution Level: #{describe_intensity(tone_analysis[:caution])}
        ANALYSIS
      end

      def analyze_formality(content)
        formal_indicators = %w[furthermore moreover consequently therefore thus accordingly]
        informal_indicators = %w[like well anyway actually basically]
        
        formal_count = count_matches(content, formal_indicators)
        informal_count = count_matches(content, informal_indicators)
        
        formality_level = calculate_formality_level(formal_count, informal_count)
        
        <<~ANALYSIS
          Formality Analysis:
          - Formality Level: #{formality_level}
          - Formal Language Usage: #{describe_intensity(formal_count)}
          - Informal Language Usage: #{describe_intensity(informal_count)}
          #{formality_recommendations(formality_level)}
        ANALYSIS
      end

      def context_specific_analysis(content, context)
        case context.downcase
        when 'technical'
          analyze_technical_tone(content)
        when 'business'
          analyze_business_tone(content)
        when 'academic'
          analyze_academic_tone(content)
        else
          analyze_general_tone(content)
        end
      end

      private

      def count_matches(content, words)
        words.sum { |word| content.downcase.scan(/\b#{word}\b/).count }
      end

      def calculate_sentiment_score(positive, negative)
        return 5 if positive == 0 && negative == 0
        total = positive + negative
        return 5 if total == 0
        ((positive.to_f / total) * 10).round(1)
      end

      def describe_sentiment(score)
        case score
        when 0..3 then "Strongly Negative"
        when 3..4 then "Negative"
        when 4..6 then "Neutral"
        when 6..8 then "Positive"
        else "Strongly Positive"
        end
      end

      def describe_intensity(count)
        case count
        when 0 then "Very Low"
        when 1..2 then "Low"
        when 3..5 then "Moderate"
        when 6..8 then "High"
        else "Very High"
        end
      end

      def calculate_formality_level(formal, informal)
        total = formal + informal
        return "Neutral" if total == 0
        
        ratio = formal.to_f / (formal + informal)
        case ratio
        when 0..0.2 then "Very Informal"
        when 0.2..0.4 then "Informal"
        when 0.4..0.6 then "Neutral"
        when 0.6..0.8 then "Formal"
        else "Very Formal"
        end
      end

      def formality_recommendations(level)
        case level
        when "Very Informal"
          "Recommendation: Consider using more formal language for professional documents"
        when "Informal"
          "Recommendation: Slightly increase formal language usage"
        when "Very Formal"
          "Recommendation: Consider adding some less formal elements for better engagement"
        else
          "Recommendation: Current formality level is appropriate"
        end
      end

      def analyze_technical_tone(content)
        technical_terms = %w[implementation algorithm framework architecture database api interface]
        jargon_count = count_matches(content, technical_terms)
        
        <<~ANALYSIS
          Technical Context Analysis:
          - Technical Term Usage: #{describe_intensity(jargon_count)}
          - Technical Depth: #{jargon_count > 5 ? "High" : "Moderate"}
        ANALYSIS
      end

      def analyze_business_tone(content)
        business_terms = %w[roi stakeholder deliverable milestone objective strategic]
        business_focus = count_matches(content, business_terms)
        
        <<~ANALYSIS
          Business Context Analysis:
          - Business Term Usage: #{describe_intensity(business_focus)}
          - Business Focus: #{business_focus > 5 ? "Strong" : "Moderate"}
        ANALYSIS
      end

      def analyze_academic_tone(content)
        academic_terms = %w[research study analysis methodology hypothesis conclusion evidence]
        academic_focus = count_matches(content, academic_terms)
        
        <<~ANALYSIS
          Academic Context Analysis:
          - Academic Term Usage: #{describe_intensity(academic_focus)}
          - Academic Rigor: #{academic_focus > 5 ? "High" : "Moderate"}
        ANALYSIS
      end

      def analyze_general_tone(content)
        <<~ANALYSIS
          General Tone Analysis:
          - Accessibility: #{analyze_accessibility(content)}
          - Engagement Level: #{analyze_engagement(content)}
        ANALYSIS
      end

      def analyze_accessibility(content)
        complex_words = content.scan(/\b\w{12,}\b/).size
        average_sentence_length = content.split(/[.!?]/).map(&:split).map(&:size).sum.to_f / content.split(/[.!?]/).size
        
        if complex_words > 5 || average_sentence_length > 20
          "Complex - Consider simplifying"
        else
          "Good - Easy to understand"
        end
      end

      def analyze_engagement(content)
        engagement_markers = %w[you your we our they them it his her imagine consider note]
        engagement_level = count_matches(content, engagement_markers)
        
        describe_intensity(engagement_level)
      end
    end

    class << self
      def define(&block)
        new.tap { |assistant| assistant.instance_eval(&block) if block_given? }
      end
    end

    def initialize(model = 'qwen2.5-coder')
      @executor = CircuitBreaker::Executors::AssistantExecutor.define do
        use_model model
        with_system_prompt "You are a document review assistant. You help analyze documents and provide constructive feedback."
        with_parameters(
          temperature: 0.7,
          top_p: 0.9,
          top_k: 40
        )
        add_tools [
          AnalyzeContentTool.new,
          SuggestImprovementsTool.new,
          SentimentAnalysisTool.new
        ]
      end
    end

    def analyze_document(token)
      @executor
        .update_context(input: generate_analysis_prompt(token))
        .execute

      result = @executor.result
      if result && result[:output]
        result[:output][:content]
      else
        "Error analyzing document"
      end
    end

    private

    def generate_analysis_prompt(token)
      <<~PROMPT
        Please analyze this document and provide feedback:

        Title: #{token.title}
        Content: #{token.content}
        Current Word Count: #{token.word_count}
        Priority: #{token.priority}
        Context: #{determine_document_context(token)}

        Please:
        1. Analyze the content quality and structure
        2. Analyze the sentiment and tone
        3. Suggest specific improvements
        4. Check if it meets minimum length requirements
        5. Provide any additional recommendations

        Use the available tools to perform the analysis.
      PROMPT
    end

    def determine_document_context(token)
      return 'technical' if token.content.downcase.match?(/\b(?:code|algorithm|implementation|api|database)\b/)
      return 'business' if token.content.downcase.match?(/\b(?:roi|stakeholder|business|market|strategy)\b/)
      return 'academic' if token.content.downcase.match?(/\b(?:research|study|hypothesis|methodology)\b/)
      'general'
    end
  end
end