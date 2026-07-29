# typed: strict
# frozen_string_literal: true

module SimpleCov
  module Sorbet
    # Read-only analysis pass collecting the line ranges of type-level Sorbet constructs coverage should ignore.
    # Detection is purely syntactic — this gem never loads Sorbet's type system. Three constructs are collected:
    #
    # - +T.type_alias+ blocks: sorbet-runtime resolves aliases lazily and collection checks are shallow, so a
    #   multi-line alias body never executes and reads as a permanent coverage miss.
    # - +sig+ blocks (bare or with a receiver, e.g. +T::Sig::WithoutRuntime.sig+): sigs are type metadata whose
    #   correctness +srb tc+ owns; coverage should measure behavior. Only multi-line blocks are collected — a
    #   single-line +sig { ... }+ occupies the send's own line, which executes at load.
    # - +T.absurd+ sends: unreachable by definition when exhaustiveness holds, so in correct code the line is a
    #   permanent coverage miss.
    class IgnoredRanges < ASTTransform::AbstractAnalysis
      extend T::Sig

      # Structural patterns for the +T+ receiver (node equality ignores source locations): +T+ and its explicit
      # top-level form +::T+.
      T_RECEIVERS = T.let(
        [
          s(:const, nil, :T),
          s(:const, s(:cbase), :T),
        ].freeze,
        T::Array[Parser::AST::Node],
      )

      # One line range per ignored construct, in source order.
      sig { returns(T::Array[T::Range[Integer]]) }
      attr_reader :ranges

      sig { void }
      def initialize
        @ranges = T.let([], T::Array[T::Range[Integer]])
        super
      end

      # Collects the send's full expression range when it is a +T.absurd+ call.
      #
      # @param node [Parser::AST::Node] The send node being visited.
      #
      # @return [Parser::AST::Node] The rebuilt node (discarded by AbstractAnalysis#run).
      sig { params(node: Parser::AST::Node).returns(Parser::AST::Node) }
      def on_send(node)
        receiver, method_name = node.children
        @ranges << line_range(node) if method_name == :absurd && T_RECEIVERS.include?(receiver)

        super
      end

      # Collects the block's full expression range when the block's send is a +T.type_alias+ or a multi-line +sig+.
      #
      # @param node [Parser::AST::Node] The block node being visited.
      #
      # @return [Parser::AST::Node] The rebuilt node (discarded by AbstractAnalysis#run).
      sig { params(node: Parser::AST::Node).returns(Parser::AST::Node) }
      def on_block(node)
        receiver, method_name = node.children.first.children
        range = line_range(node)

        case method_name
        when :type_alias
          @ranges << range if T_RECEIVERS.include?(receiver)
        when :sig
          # Any receiver qualifies: bare sig blocks and forms like T::Sig::WithoutRuntime.sig are all sigs. A
          # non-Sorbet DSL also named `sig` would be over-matched, an accepted risk documented in the README.
          @ranges << range if range.first < range.last
        end

        super
      end

      private

      # @param node [Parser::AST::Node] The node whose source span to convert.
      #
      # @return [Range<Integer>] The node's 1-indexed first-to-last line range.
      sig { params(node: Parser::AST::Node).returns(T::Range[Integer]) }
      def line_range(node)
        expression = node.loc.expression
        expression.first_line..expression.last_line
      end
    end
  end
end
