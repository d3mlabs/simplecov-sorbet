# typed: true
# frozen_string_literal: true

require "test_helper"

transform!(RSpock::AST::Transformation)
class SimpleCov::Sorbet::DirectiveExtensionTest < Minitest::Test
  test "appends the alias range to every directive category" do
    Given "source lines with a multi-line alias"
    src_lines = <<~RUBY.lines
      module Fixture
        Alias = T.type_alias do
          T.any(Integer, String)
        end
      end
    RUBY

    When "SimpleCov computes the disabled ranges"
    ranges = SimpleCov::Directive.disabled_ranges(src_lines)

    Then "the alias range joins line, branch, and method alike"
    ranges == { line: [(2..4)], branch: [(2..4)], method: [(2..4)] }
  end

  test "keeps simplecov:disable directive ranges alongside alias ranges" do
    Given "source lines with a disable region and an alias"
    src_lines = <<~RUBY.lines
      # simplecov:disable line
      def skipped
        :ok
      end
      # simplecov:enable line
      Alias = T.type_alias do
        Integer
      end
    RUBY

    When "SimpleCov computes the disabled ranges"
    ranges = SimpleCov::Directive.disabled_ranges(src_lines)

    Then "both contributions land in :line, and the alias alone reaches :branch and :method"
    ranges.fetch(:line) == [(1..5), (6..8)]
    ranges.fetch(:branch) == [(6..8)]
    ranges.fetch(:method) == [(6..8)]
  end

  test "returns directive ranges untouched when the source has no aliases" do
    Given "alias-free source lines"
    src_lines = ["def plain\n", "  :ok\n", "end\n"]

    Expect "the categories stay empty"
    SimpleCov::Directive.disabled_ranges(src_lines) == { line: [], branch: [], method: [] }
  end

  test "returns directive ranges untouched for unparseable source" do
    Given "unparseable source lines that still carry a directive"
    src_lines = ["# simplecov:disable line\n", "def x(1) end\n"]

    When "SimpleCov computes the disabled ranges"
    ranges = SimpleCov::Directive.disabled_ranges(src_lines)

    Then "the directive's own range survives with no alias additions"
    ranges == { line: [(1..2)], branch: [], method: [] }
  end
end
