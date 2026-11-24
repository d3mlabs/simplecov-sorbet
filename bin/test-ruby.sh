#!/bin/sh
# dev test-ruby <minor>: run the suite under a Ruby the gemspec promises
# (>= 3.3) but dependencies.rb does not lock. `dev test` is the suite on
# the project Ruby; this answers the other question — does the gem still
# work on the older Rubies it supports.
#
# The Ruby is Homebrew's ruby@<minor>, installed here if absent and
# deliberately outside the lock: nothing ships from this run and a patch
# moving under it is something the probe should see. Bundler resolves
# into a per-minor directory under the user cache — outside the checkout,
# so SimpleCov (which tracks every file under the root) never counts the
# vendored gems — through a wrapper Gemfile that evaluates the real one
# (so `gemspec` still resolves against the repo root) with its own
# lockfile, leaving Gemfile.lock untouched. Bundler is invoked through
# that Ruby explicitly so the project shadowenv's bundler does not win on
# PATH.
set -eu

minor="${1:?usage: dev test-ruby <minor>   (e.g. dev test-ruby 3.3)}"
formula="ruby@$minor"
root="$(cd "$(dirname "$0")/.." && pwd)"
workdir="${XDG_CACHE_HOME:-$HOME/.cache}/simplecov-sorbet/test-ruby/$minor"

brew list --versions "$formula" >/dev/null 2>&1 || brew install "$formula"
ruby="$(brew --prefix "$formula")/bin/ruby"

mkdir -p "$workdir"
printf '# frozen_string_literal: true\n\neval_gemfile "%s/Gemfile"\n' "$root" > "$workdir/Gemfile"

export BUNDLE_GEMFILE="$workdir/Gemfile"
export BUNDLE_PATH="$workdir/vendor"

echo "test-ruby: $("$ruby" -v)"
"$ruby" -S bundle install --quiet
cd "$root" && exec "$ruby" -S bundle exec rake test
