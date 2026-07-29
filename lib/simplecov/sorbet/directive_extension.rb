# typed: strict
# frozen_string_literal: true

module SimpleCov
  module Sorbet
    # Prepended onto SimpleCov::Directive's singleton class. Directive.disabled_ranges is the one choke point both
    # SourceFile (loaded files) and LinesClassifier (tracked-but-unloaded files) consult for skip ranges, so
    # extending its result covers every path SimpleCov classifies lines through. Alias ranges join all three
    # categories: the block body is runtime-unreachable, so any line, branch, or method inside it is skippable.
    module DirectiveExtension
      extend T::Sig

      sig { params(src_lines: T::Array[String]).returns(T::Hash[Symbol, T::Array[T::Range[Integer]]]) }
      def disabled_ranges(src_lines)
        ranges = T.let(super, T::Hash[Symbol, T::Array[T::Range[Integer]]])
        alias_ranges = type_alias_ranges(src_lines.join)
        return ranges if alias_ranges.empty?

        ranges.each_value { |category_ranges| category_ranges.concat(alias_ranges) }
        ranges
      end

      private

      # Scans +source+ for +T.type_alias+ blocks. Unparseable source yields no ranges: coverage annotation must
      # never take down a suite's reporting, and a file Ruby executed but this parser rejects has no aliases we
      # could trust anyway. The rescue is deliberately wide — Prism parses most broken source tolerantly, and what
      # escapes is not Parser::SyntaxError but arbitrary errors from the whitequark builder choking on
      # error-recovered trees (e.g. NoMethodError in join_exprs).
      #
      # @param source [String] The Ruby source to scan.
      #
      # @return [Array<Range<Integer>>] One line range per alias block, in source order.
      sig { params(source: String).returns(T::Array[T::Range[Integer]]) }
      def type_alias_ranges(source)
        TypeAliasRanges.new.run(source_parser.parse(source)).ranges
      rescue StandardError
        []
      end

      # The parser is fixed for the extension's lifetime. Prepended onto SimpleCov::Directive's singleton class,
      # this module has no constructor to own it, so the singleton's ivar plays that role.
      #
      # @return [ASTTransform::SourceParser] The memoized parser.
      sig { returns(ASTTransform::SourceParser) }
      def source_parser
        @source_parser ||= T.let(ASTTransform::SourceParser.new, T.nilable(ASTTransform::SourceParser))
      end
    end
  end
end
