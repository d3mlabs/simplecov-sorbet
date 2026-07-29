# typed: strict
# frozen_string_literal: true

module SimpleCov
  module Sorbet
    # Read-only analysis pass collecting the line ranges of +T.type_alias+ blocks. Their bodies are
    # runtime-unreachable by design: sorbet-runtime resolves aliases lazily and collection checks are shallow, so a
    # multi-line alias block never executes and reads as a permanent coverage miss. Detection is purely syntactic —
    # this gem never loads Sorbet's type system.
    class TypeAliasRanges < ASTTransform::AbstractAnalysis
      extend T::Sig

      # Structural patterns for the alias send (node equality ignores source locations): +T.type_alias+ and its
      # explicit top-level form +::T.type_alias+.
      TYPE_ALIAS_SENDS = T.let(
        [
          s(:send, s(:const, nil, :T), :type_alias),
          s(:send, s(:const, s(:cbase), :T), :type_alias),
        ].freeze,
        T::Array[Parser::AST::Node],
      )

      # One line range per alias block, in source order.
      sig { returns(T::Array[T::Range[Integer]]) }
      attr_reader :ranges

      sig { void }
      def initialize
        @ranges = T.let([], T::Array[T::Range[Integer]])
        super
      end

      # Collects the block's full expression range when the block's send is a +T.type_alias+.
      #
      # @param node [Parser::AST::Node] The block node being visited.
      #
      # @return [Parser::AST::Node] The rebuilt node (discarded by AbstractAnalysis#run).
      sig { params(node: Parser::AST::Node).returns(Parser::AST::Node) }
      def on_block(node)
        if TYPE_ALIAS_SENDS.include?(node.children.first)
          expression = node.loc.expression
          @ranges << (expression.first_line..expression.last_line)
        end

        super
      end
    end
  end
end
