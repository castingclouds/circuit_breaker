require_relative 'lib/circuit_breaker/version'

Gem::Specification.new do |spec|
  spec.name          = "circuit_breaker-wf"
  spec.version       = CircuitBreaker::VERSION
  spec.authors       = ["Lee Faus"]
  spec.email         = ["lfaus@gitlab.com"]

  spec.summary       = %q{A Petri Net workflow system implementation}
  spec.description   = %q{CircuitBreaker is a Ruby implementation of a Petri Net workflow system, allowing for complex AI workflow definitions and executions}
  spec.homepage      = "https://github.com/castingclouds/circuit_breaker"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "concurrent-ruby", "~> 1.2"
  spec.add_dependency "nats-pure", "~> 2.4"
  spec.add_dependency "json", "~> 2.6"
  spec.add_dependency "json-schema", "~> 5.1"
  spec.add_dependency "redcarpet", "~> 3.6"
  spec.add_dependency "nokogiri", "~> 1.18"
  spec.add_dependency "async", "~> 2.21"

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.21"
end
