require_relative '../../lib/circuit_breaker'
require_relative 'document_token'

# Example demonstrating various visualization formats for the document workflow
module Examples
  class DocumentVisualization
    def self.run
      puts "Document Workflow Visualization Example"
      puts "====================================="

      # Create a sample document with history
      doc = create_sample_document

      puts "\n1. Generating Mermaid.js Diagram"
      puts "------------------------------"
      mermaid_code = CircuitBreaker::Document.visualize(:mermaid)
      File.write("document_workflow_mermaid.html", create_mermaid_html(mermaid_code))
      puts "✓ Mermaid diagram saved to document_workflow_mermaid.html"
      puts "\nMermaid Code:"
      puts mermaid_code

      puts "\n2. Generating PlantUML Diagram"
      puts "----------------------------"
      plantuml_code = CircuitBreaker::Document.visualize(:plantuml)
      File.write("document_workflow_plantuml.txt", plantuml_code)
      puts "✓ PlantUML code saved to document_workflow_plantuml.txt"
      puts "\nPlantUML Code:"
      puts plantuml_code

      puts "\n3. Generating DOT Graph"
      puts "----------------------"
      dot_code = CircuitBreaker::Document.visualize(:dot)
      File.write("document_workflow.dot", dot_code)
      puts "✓ DOT graph saved to document_workflow.dot"
      puts "\nDOT Code:"
      puts dot_code

      puts "\n4. Generating Markdown Documentation"
      puts "---------------------------------"
      markdown = CircuitBreaker::Document.visualize(:markdown)
      File.write("document_workflow.md", markdown)
      puts "✓ Markdown documentation saved to document_workflow.md"
      
      puts "\n5. Generating Timeline Visualization"
      puts "--------------------------------"
      timeline_html = doc.export_history_as_timeline
      File.write("document_timeline.html", timeline_html)
      puts "✓ Timeline visualization saved to document_timeline.html"

      puts "\n6. Generating Combined HTML Documentation"
      puts "-------------------------------------"
      html = create_combined_html(doc, mermaid_code, plantuml_code, dot_code, markdown)
      File.write("document_workflow.html", html)
      puts "✓ Combined HTML documentation saved to document_workflow.html"

      puts "\nAll visualizations have been generated successfully!"
      puts "Open document_workflow.html in your browser to view all formats."
    end

    private

    def self.create_sample_document
      # Create document with some history
      doc = CircuitBreaker::Document.new(
        title: "Visualization Demo",
        content: "This document demonstrates various visualization formats.",
        author_id: "author123",
        tags: ["demo", "visualization"],
        priority: "high"
      )

      # Add some history
      doc.submit("reviewer123", actor_id: "author123")
      doc.review("Looks good!", actor_id: "reviewer123")
      doc.approve("approver123", actor_id: "approver123")

      doc
    end

    def self.create_mermaid_html(mermaid_code)
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>Document Workflow - Mermaid Diagram</title>
          <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
          <script>mermaid.initialize({startOnLoad:true});</script>
          <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .mermaid { text-align: center; }
          </style>
        </head>
        <body>
          <h1>Document Workflow State Machine</h1>
          <div class="mermaid">
            #{mermaid_code}
          </div>
        </body>
        </html>
      HTML
    end

    def self.create_combined_html(doc, mermaid_code, plantuml_code, dot_code, markdown)
      require 'redcarpet'
      markdown_renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML)

      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>Document Workflow - Complete Visualization</title>
          <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
          <script>mermaid.initialize({startOnLoad:true});</script>
          <style>
            body {
              font-family: Arial, sans-serif;
              margin: 0;
              padding: 20px;
              line-height: 1.6;
            }
            .container {
              max-width: 1200px;
              margin: 0 auto;
            }
            .section {
              margin: 40px 0;
              padding: 20px;
              background: white;
              border-radius: 8px;
              box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            h1 { color: #2c3e50; text-align: center; }
            h2 { color: #34495e; border-bottom: 2px solid #eee; padding-bottom: 10px; }
            .mermaid { text-align: center; }
            pre {
              background: #f8f9fa;
              padding: 15px;
              border-radius: 4px;
              overflow-x: auto;
            }
            .tabs {
              display: flex;
              margin-bottom: 20px;
            }
            .tab {
              padding: 10px 20px;
              cursor: pointer;
              border: none;
              background: #f8f9fa;
              margin-right: 5px;
            }
            .tab.active {
              background: #007bff;
              color: white;
            }
            .tab-content {
              display: none;
            }
            .tab-content.active {
              display: block;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>Document Workflow Visualization</h1>

            <div class="section">
              <h2>1. State Machine Diagram (Mermaid)</h2>
              <div class="mermaid">
                #{mermaid_code}
              </div>
            </div>

            <div class="section">
              <h2>2. State Machine Diagram (PlantUML)</h2>
              <pre><code>#{plantuml_code}</code></pre>
            </div>

            <div class="section">
              <h2>3. State Machine Diagram (DOT)</h2>
              <pre><code>#{dot_code}</code></pre>
            </div>

            <div class="section">
              <h2>4. Workflow Documentation</h2>
              #{markdown_renderer.render(markdown)}
            </div>

            <div class="section">
              <h2>5. Document History Timeline</h2>
              <div class="timeline">
                #{doc.history.map { |entry|
                  <<~ENTRY
                    <div class="timeline-entry">
                      <div class="timestamp">#{entry.timestamp.strftime('%Y-%m-%d %H:%M:%S')}</div>
                      <div class="event">
                        <strong>#{entry.type.to_s.gsub('_', ' ').capitalize}</strong>
                        <div class="actor">Actor: #{entry.actor_id}</div>
                        <div class="details">#{entry.details.inspect}</div>
                      </div>
                    </div>
                  ENTRY
                }.join("\n")}
              </div>
            </div>

            <div class="section">
              <h2>6. Current Document State</h2>
              <pre><code>#{doc.pretty_print(true)}</code></pre>
            </div>
          </div>

          <script>
            // Add any interactive features here
            document.addEventListener('DOMContentLoaded', function() {
              // Initialize any JavaScript-based visualizations
            });
          </script>
        </body>
        </html>
      HTML
    end
  end
end

# Run the example
Examples::DocumentVisualization.run if __FILE__ == $0
