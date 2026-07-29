# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

# test_loader runs first (-r) so rspock and ASTTransform.install are set up
# before any test file loads (the rspock dialect is rewritten at load time).
Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << File.expand_path("lib", __dir__)
  t.ruby_opts << "-r #{File.expand_path('test/test_loader.rb', __dir__)}"
  t.test_files = FileList["test/**/*_test.rb"]
  t.warning = false
end

task default: :test
