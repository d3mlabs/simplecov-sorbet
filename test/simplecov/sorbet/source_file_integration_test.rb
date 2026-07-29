# typed: true
# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "test_helper"

transform!(RSpock::AST::Transformation)
class SimpleCov::Sorbet::SourceFileIntegrationTest < Minitest::Test
  test "a multi-line alias body is skipped, not missed" do
    Given "a real fixture file whose alias body never executed"
    dir = Dir.mktmpdir
    path = File.join(dir, "fixture.rb")
    File.write(path, <<~RUBY)
      module Fixture
        Alias = T.type_alias do
          T.any(Integer, String)
        end
      end
    RUBY

    When "SimpleCov processes it with the runtime's coverage result"
    source_file = SimpleCov::SourceFile.new(path, { "lines" => [1, 1, 0, nil, nil] })

    Then "the alias block's lines are skipped and the file reports fully covered"
    source_file.skipped_lines.map(&:line_number) == [2, 3, 4]
    source_file.missed_lines.empty?
    source_file.covered_percent == 100.0

    Cleanup
    FileUtils.remove_entry(dir)
  end
end
