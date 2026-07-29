# typed: strict
# frozen_string_literal: true

require "simplecov"
require "sorbet-runtime"
require "ast_transform"
require "ast_transform/abstract_analysis"

require "simplecov/sorbet/version"
require "simplecov/sorbet/type_alias_ranges"
require "simplecov/sorbet/directive_extension"

module SimpleCov
  # SimpleCov extension for Sorbet codebases: skips constructs Sorbet makes runtime-unreachable by design, starting
  # with multi-line +T.type_alias+ blocks. Requiring this file installs the extension; Module#prepend is idempotent,
  # so requiring it more than once is harmless.
  module Sorbet
  end
end

SimpleCov::Directive.singleton_class.prepend(SimpleCov::Sorbet::DirectiveExtension)
