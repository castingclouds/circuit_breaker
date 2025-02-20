require 'securerandom'
require_relative 'circuit_breaker/parser'
require_relative 'circuit_breaker/pipeline_parser'
require_relative 'circuit_breaker/workflow'
require_relative 'circuit_breaker/pipeline'
require_relative 'circuit_breaker/token'
require_relative 'circuit_breaker/tools/tool'
require_relative 'circuit_breaker/tools/mock'
require_relative 'circuit_breaker/tools/print'
require_relative 'circuit_breaker/logger'

module CircuitBreaker
  class Error < StandardError; end

  def self.load_workflow(file_path)
    content = File.read(file_path)
    parser = Parser.new
    parser.parse(content)
  end

  def self.load_pipeline(file_path)
    content = File.read(file_path)
    parser = PipelineParser.new
    pipeline_name, actions = parser.parse(content)
    Pipeline.new(name: pipeline_name, actions: actions)
  end
end
