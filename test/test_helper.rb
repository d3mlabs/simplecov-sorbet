# typed: true
# frozen_string_literal: true

# SimpleCov must start before the gem's code loads so lib/ is tracked; the
# JSON report is what CI uploads to Codecov. Requiring simplecov/sorbet right
# after is the dogfood: this suite's own coverage runs through the extension
# under test. sorbet-runtime's T must exist before the config block runs.
require "sorbet-runtime"
require "simplecov"
require "simplecov_json_formatter"

SimpleCov.start do
  # T.unsafe: SimpleCov instance_evals this block against its configuration
  # object, a rebinding Sorbet cannot see statically.
  T.unsafe(self).skip("/test/")
  T.unsafe(self).formatter(SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::JSONFormatter,
  ]))
end

require "simplecov/sorbet"
require "minitest"

begin
  require "minitest/reporters"
  Minitest::Reporters.use!
rescue LoadError
  # minitest-reporters not installed
end

Minitest.autorun
