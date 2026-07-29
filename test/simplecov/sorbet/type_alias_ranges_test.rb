# typed: false — the rspock Where table (`value | value` rows) is rewritten at load time and has no static typing.
# frozen_string_literal: true

require "test_helper"

transform!(RSpock::AST::Transformation)
class SimpleCov::Sorbet::TypeAliasRangesTest < Minitest::Test
  def ranges_in(source)
    ast = ASTTransform::SourceParser.new.parse(source)
    SimpleCov::Sorbet::TypeAliasRanges.new.run(ast).ranges
  end

  test "collects the full line range of a multi-line do/end alias" do
    Given "a source with a multi-line T.type_alias block"
    source = <<~RUBY
      module Fixture
        Alias = T.type_alias do
          T.any(Integer, String)
        end
      end
    RUBY

    Expect "the block's full expression range, 1-indexed"
    ranges_in(source) == [(2..4)]
  end

  test "collects alias ranges across source forms" do
    Expect "the expected ranges"
    ranges_in(source) == expected

    Where
    source                                                            | expected
    "X = T.type_alias { Integer }\n"                                  | [(1..1)]
    "X = ::T.type_alias do\n  Integer\nend\n"                         | [(1..3)]
    "class A\n  class B\n    X = T.type_alias do\n      Integer\n    end\n  end\nend\n" | [(3..5)]
    "A = T.type_alias { Integer }\nB = T.type_alias do\n  String\nend\n" | [(1..1), (2..4)]
    "items.each do\n  work\nend\n"                                    | []
    "X = T.type_alias(Integer)\n"                                     | []
    "X = Foo.type_alias { Integer }\n"                                | []
    "def plain_method\n  :ok\nend\n"                                  | []
  end

  test "yields no ranges for source Prism recovers from tolerantly" do
    Given "broken source Prism parses with recovery nodes"
    source = "def broken(\n"

    Expect "no ranges"
    ranges_in(source) == []
  end
end
