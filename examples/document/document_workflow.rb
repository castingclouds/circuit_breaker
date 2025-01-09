require_relative '../../lib/circuit_breaker'
require_relative '../../lib/circuit_breaker/executors/assistant_executor'
require_relative 'document_token'
require_relative 'document_rules'
require_relative 'document_validators'

# Example of a document workflow using a more declarative DSL approach
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
        begin
          analysis = []
          analysis << "Word Count Analysis: #{word_count} words (minimum: #{min_words})"
          analysis << "Length Status: #{word_count >= min_words ? 'Meets' : 'Does not meet'} minimum requirement"
          analysis << "\nContent Analysis:"
          analysis << "- Structure: #{analyze_structure(content)}"
          analysis << "- Clarity: #{analyze_clarity(content)}"
          analysis << "- Completeness: #{analyze_completeness(content)}"
          analysis.join("\n")
        rescue => e
          "Error analyzing content: #{e.message}"
        end
      end

      private

      def analyze_structure(content)
        return "Unable to analyze structure" unless content.is_a?(String)
        paragraphs = content.split(/\n\n+/).size
        "#{paragraphs} paragraphs detected. #{paragraphs < 3 ? 'Consider adding more structure.' : 'Good paragraph structure.'}"
      end

      def analyze_clarity(content)
        return "Unable to analyze clarity" unless content.is_a?(String)
        long_sentences = content.split(/[.!?]/).count { |s| s.split.size > 20 }
        if long_sentences > 0
          "Found #{long_sentences} complex sentences. Consider simplifying for better clarity."
        else
          "Good sentence structure and clarity."
        end
      end

      def analyze_completeness(content)
        return "Unable to analyze completeness" unless content.is_a?(String)
        key_sections = ['introduction', 'background', 'conclusion'].count do |section|
          content.downcase.include?(section)
        end
        "#{key_sections}/3 key sections identified."
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
        begin
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
      end

      private

      def suggest_structure_improvements(content)
        return "Unable to analyze structure" unless content.is_a?(String)
        suggestions = []
        paragraphs = content.split(/\n\n+/)
        
        suggestions << "Consider breaking content into clear sections:" if paragraphs.size < 3
        suggestions << "- Add section headings" unless content.match?(/^#|^[A-Z].*:/)
        suggestions << "- Use bullet points for lists" unless content.match?(/^\s*[-*]/)
        suggestions << "- Add transition sentences between paragraphs" if paragraphs.size > 1
        
        suggestions.join("\n")
      end

      def suggest_clarity_improvements(content)
        return "Unable to analyze clarity" unless content.is_a?(String)
        suggestions = []
        sentences = content.split(/[.!?]/)
        
        if sentences.any? { |s| s.split.size > 20 }
          suggestions << "Break down long sentences:"
          suggestions << "- Split complex sentences into simpler ones"
          suggestions << "- Use more punctuation to improve readability"
        end
        
        suggestions << "Use active voice where possible" if content.match?(/\bis\b|\bwas\b|\bwere\b/)
        suggestions.join("\n")
      end

      def suggest_completeness_improvements(content)
        return "Unable to analyze completeness" unless content.is_a?(String)
        missing_sections = []
        missing_sections << "- Add an introduction" unless content.downcase.include?('introduction')
        missing_sections << "- Include background information" unless content.downcase.include?('background')
        missing_sections << "- Add a conclusion" unless content.downcase.include?('conclusion')
        
        if missing_sections.any?
          ["Consider adding the following sections:", *missing_sections].join("\n")
        else
          "All key sections present. Consider expanding each section with more detail."
        end
      end
    end

    def initialize(model = 'codellama')
      @executor = CircuitBreaker::Executors::AssistantExecutor.new(
        model: model,
        system_prompt: "You are a document review assistant. You help analyze documents and provide constructive feedback.",
        tools: [
          AnalyzeContentTool.new,
          SuggestImprovementsTool.new
        ]
      )
    end

    def analyze_document(token)
      @executor.update_context(input: generate_analysis_prompt(token))
      @executor.execute
      
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

        Please:
        1. Analyze the content quality and structure
        2. Suggest specific improvements
        3. Check if it meets minimum length requirements
        4. Provide any additional recommendations

        Use the available tools to perform the analysis.
      PROMPT
    end
  end

  class DocumentWorkflowDSL
    def self.run
      puts "Starting Document Workflow Example (DSL Version)..."
      puts "================================================\n"

      # Initialize document-specific rules and validators
      rules = DocumentRules.define
      validators = DocumentValidators.define

      workflow = CircuitBreaker::WorkflowDSL.define(rules: rules) do
        # Define all possible document states
        # The first state listed becomes the initial state
        states :draft,           # Initial state when document is created
              :pending_review,   # Document submitted and awaiting review
              :reviewed,         # Document has been reviewed with comments
              :approved,         # Document has been approved by approver
              :rejected         # Document was rejected and needs revision

        # Define transitions with required fields and rules
        flow(:draft >> :pending_review)
          .transition(:submit)
          .policy(
            validations: { all: [:reviewer_id] },
            rules: { all: [:has_reviewer, :different_reviewer] }
          )

        flow(:pending_review >> :reviewed)
          .transition(:review)
          .policy(
            validations: { all: [:reviewer_comments] },
            rules: {
              all: [:has_comments],
              any: [:high_priority, :urgent]
            }
          )

        flow(:reviewed >> :approved)
          .transition(:approve)
          .policy(
            validations: {
              all: [:approver_id, :reviewer_comments],
              any: [:external_url, :word_count]
            },
            rules: {
              all: [
                :has_approver,
                :different_approver_from_reviewer,
                :different_approver_from_author
              ],
              any: [:is_admin]
            }
          )

        flow(:reviewed >> :rejected)
          .transition(:reject)
          .policy(
            validations: { all: [:rejection_reason] },
            rules: { all: [:has_rejection] }
          )

        # Simple transition without requirements
        flow(:rejected >> :draft).transition(:revise)
      end

      puts "\nWorkflow Definition:"
      puts "==================="
      workflow.pretty_print

      puts "\nExecuting workflow steps...\n\n"

      # Create a new document token
      token = Examples::DocumentToken.new(
        id: SecureRandom.uuid,
        title: "Project Proposal",
        content: "This is a detailed project proposal that meets the minimum length requirement. " * 10,  # Make it longer
        priority: "high",
        author_id: "charlie789",
        created_at: Time.now,
        updated_at: Time.now,
        word_count: 150  # Add word count
      )

      # Add token to workflow
      workflow.add_token(token)

      puts "Initial Document State:"
      puts "State: #{token.state}\n\n"
      puts token.to_json(true)

      # Initialize document assistant
      assistant = DocumentAssistant.new('codellama')

      # Get initial analysis
      puts "\nInitial Document Analysis:"
      puts "========================="
      puts assistant.analyze_document(token)
      puts "\n"

      begin
        # Step 1: Submit document
        puts "Step 1: Submitting document..."
        token.reviewer_id = "bob456"  # Set a different reviewer_id
        workflow.fire_transition(:submit, token)
        puts "Document submitted successfully"
        puts "Current state: #{token.state}"
        puts "Reviewer: #{token.reviewer_id}\n\n"
        

        # Step 2: Review document
        puts "Step 2: Reviewing document..."
        token.reviewer_comments = "This is a detailed review with suggestions for improvement. The proposal needs more budget details."
        workflow.fire_transition(:review, token)
        puts "Review completed"
        puts "Current state: #{token.state}"
        puts "Review comments: #{token.reviewer_comments}\n\n"

        # Step 3: Approve document
        puts "Step 3: Approving document..."
        token.approver_id = "admin_eve789"  # Set an admin approver who is different from both reviewer and author
        workflow.fire_transition(:approve, token)
        puts "Document approved"
        puts "Current state: #{token.state}"
        puts "Approver: #{token.approver_id}\n\n"

      rescue StandardError => e
        puts "Unexpected error: #{e.message}"
        puts "Current state: #{token.state}"
      end

      puts "\nDocument History:"
      puts "----------------"
      token.history.each do |event|
        puts "#{event.timestamp}: #{event.type} - #{event.details}"
      end
    end
  end
end

# Run the example
Examples::DocumentWorkflowDSL.run if __FILE__ == $0
