# typed: false — the rspock Where table (`value | value` rows) is rewritten at load time and has no static typing.
# frozen_string_literal: true

require "test_helper"

transform!(RSpock::AST::Transformation)
class SimpleCov::Sorbet::IgnoredRangesTest < Minitest::Test
  def ranges_in(source)
    ast = ASTTransform::SourceParser.new.parse(source)
    SimpleCov::Sorbet::IgnoredRanges.new.run(ast).ranges
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

  test "collects T.absurd send ranges" do
    Expect "the expected ranges"
    ranges_in(source) == expected

    Where
    source                                                           | expected
    "case x\nwhen Integer then 1\nelse T.absurd(x)\nend\n"           | [(3..3)]
    "::T.absurd(value)\n"                                             | [(1..1)]
    "T.absurd(\n  value,\n)\n"                                        | [(1..3)]
    "absurd(x)\n"                                                     | []
    "shape.absurd(x)\n"                                               | []
    "T.must(x)\n"                                                     | []
  end

  test "collects multi-line sig block ranges regardless of receiver" do
    Expect "the expected ranges"
    ranges_in(source) == expected

    Where
    source                                                           | expected
    "sig do\n  returns(Integer)\nend\n"                              | [(1..3)]
    "sig(:final) do\n  returns(Integer)\nend\n"                       | [(1..3)]
    "T::Sig::WithoutRuntime.sig do\n  returns(Integer)\nend\n"        | [(1..3)]
    "sig { returns(Integer) }\n"                                      | []
    "config.sig { returns(Integer) }\n"                               | []
  end

  test "collects mixed constructs in source order" do
    Given "a source mixing an alias, a sig, and an absurd send"
    source = <<~RUBY
      module Fixture
        Alias = T.type_alias do
          T.any(Integer, String)
        end

        sig do
          params(x: Alias).returns(Integer)
        end
        def self.check(x)
          case x
          when Integer then x
          else T.absurd(x)
          end
        end
      end
    RUBY

    Expect "one range per construct, in source order"
    ranges_in(source) == [(2..4), (6..8), (12..12)]
  end

  test "yields no ranges for source Prism recovers from tolerantly" do
    Given "broken source Prism parses with recovery nodes"
    source = "def broken(\n"

    Expect "no ranges"
    ranges_in(source) == []
  end
end
