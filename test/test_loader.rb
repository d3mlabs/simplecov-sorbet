# typed: true
# frozen_string_literal: true

# Entry point when running tests (-r test_loader): load path, rspock, then
# ASTTransform.install — the rspock test dialect is rewritten at load time,
# so the hook must be in place before any test file loads. test_helper is
# required by each test file and provides SimpleCov and Minitest.
SIMPLECOV_SORBET_ROOT = File.expand_path("..", __dir__)
$LOAD_PATH.unshift(File.join(SIMPLECOV_SORBET_ROOT, "lib")) unless $LOAD_PATH.include?(File.join(SIMPLECOV_SORBET_ROOT, "lib"))

require "rspock"

ASTTransform.install
