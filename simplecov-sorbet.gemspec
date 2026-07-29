# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "simplecov/sorbet/version"

Gem::Specification.new do |spec|
  spec.name          = "simplecov-sorbet"
  spec.version       = SimpleCov::Sorbet::VERSION
  spec.authors       = ["Jean-Philippe Duchesne"]
  spec.email         = ["jpduchesne89@gmail.com"]

  spec.summary       = "SimpleCov extension that skips type-level Sorbet constructs (T.type_alias, sig, T.absurd)."
  spec.description   = "Type-level Sorbet constructs read as coverage misses: multi-line T.type_alias and sig " \
    "blocks evaluate lazily or never, and T.absurd is unreachable by definition. This extension detects them " \
    "syntactically and feeds their line ranges into SimpleCov's skip machinery."
  spec.homepage      = "https://github.com/d3mlabs/simplecov-sorbet"
  spec.license       = "MIT"
  spec.files         = %x(git ls-files -z).split("\x0").reject do |f|
    f.match(%r{^(test|spec|features|sorbet)/})
  end
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 3.3"

  # Development dependencies live in the Gemfile (Gemspec/DevelopmentDependencies).

  # Runtime dependencies
  # simplecov ~> 1.0: Directive.disabled_ranges is the seam this gem extends.
  spec.add_runtime_dependency "simplecov", "~> 1.0"
  # ast_transform ~> 3.1: AbstractAnalysis + ASTTransform.parse (Prism-backed).
  spec.add_runtime_dependency "ast_transform", "~> 3.1"
  # sorbet-runtime backs the inline sigs; the audience is Sorbet codebases, so it is already in their bundle.
  spec.add_runtime_dependency "sorbet-runtime"
end
