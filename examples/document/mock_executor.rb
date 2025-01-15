module Examples
  class MockExecutor
    def initialize(model = nil)
      @model = model
    end

    def analyze_document(token)
      text = token.content.to_s
      {
        word_count: text.split.size,
        char_count: text.size,
        avg_word_length: text.empty? ? 0 : (text.size.to_f / text.split.size).round(2)
      }
    end

    def analyze_clarity(token)
      text = token.content.to_s
      words = text.split
      return { score: 100, long_words: 0, suggestion: "Good clarity" } if words.empty?
      
      long_words = words.count { |word| word.length > 8 }
      {
        score: ((1 - (long_words.to_f / words.size)) * 100).round(2),
        long_words: long_words,
        suggestion: long_words > 3 ? "Consider using simpler words" : "Good clarity"
      }
    end

    def analyze_completeness(token)
      text = token.content.to_s
      required_sections = ["introduction", "background", "conclusion"]
      found_sections = required_sections.select { |section| text.downcase.include?(section) }
      {
        score: ((found_sections.size.to_f / required_sections.size) * 100).round(2),
        missing_sections: required_sections - found_sections,
        complete: found_sections.size == required_sections.size
      }
    end

    def review_document(token)
      analysis = analyze_document(token)
      clarity = analyze_clarity(token)
      completeness = analyze_completeness(token)

      {
        approved: analysis[:word_count] > 50 && clarity[:score] > 70 && completeness[:score] > 80,
        metrics: {
          word_count: analysis[:word_count],
          clarity_score: clarity[:score],
          completeness_score: completeness[:score]
        },
        feedback: [
          clarity[:suggestion],
          completeness[:complete] ? "All sections present" : "Missing sections: #{completeness[:missing_sections].join(', ')}"
        ],
        comments: []
      }
    end

    def final_review(token)
      review = review_document(token)
      {
        status: review[:approved] ? "APPROVED" : "REJECTED",
        metrics: review[:metrics],
        comments: review[:comments]
      }
    end

    def explain_rejection(token)
      review = review_document(token)
      reasons = []
      reasons << "Word count too low" if review[:metrics][:word_count] <= 50
      reasons << "Clarity score too low" if review[:metrics][:clarity_score] <= 70
      reasons << "Completeness score too low" if review[:metrics][:completeness_score] <= 80
      {
        reasons: reasons
      }
    end
  end
end
