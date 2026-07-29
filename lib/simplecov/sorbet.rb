# typed: strict
# frozen_string_literal: true

require "simplecov"
require "sorbet-runtime"
require "ast_transform"
require "ast_transform/abstract_analysis"

require "simplecov/sorbet/version"
require "simplecov/sorbet/ignored_ranges"
require "simplecov/sorbet/directive_extension"

module SimpleCov
  # SimpleCov extension for Sorbet codebases: skips type-level Sorbet constructs coverage should not measure —
  # multi-line +T.type_alias+ blocks, +sig+ blocks, and +T.absurd+ sends. Requiring this file installs the
  # extension; Module#prepend is idempotent, so requiring it more than once is harmless.
  module Sorbet
  end
end

SimpleCov::Directive.singleton_class.prepend(SimpleCov::Sorbet::DirectiveExtension)
