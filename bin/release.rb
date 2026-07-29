#!/bin/sh
# Use PATH ruby (rbenv) if >= 3.1, fall back to Homebrew Ruby for bootstrapping.
if command -v ruby >/dev/null 2>&1; then
  if ruby -e 'exit(Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.1") ? 0 : 1)' 2>/dev/null; then
    exec ruby -x "$0" "$@"
  fi
fi
if command -v brew >/dev/null 2>&1; then
  brew_ruby="$(brew --prefix ruby 2>/dev/null)/bin/ruby"
  if [ -x "$brew_ruby" ]; then
    exec "$brew_ruby" -x "$0" "$@"
  fi
fi
echo "release: no ruby found. Install rbenv and a Ruby version, or brew install ruby." >&2
exit 1

#!ruby
# frozen_string_literal: true

# Release a new version of simplecov-sorbet: bump version.rb + Gemfile.lock,
# commit, tag, push, create GitHub release, then watch the tag-triggered
# workflow publish the gem to rubygems.org via trusted publishing.
#
# Usage:
#   ./bin/release.rb                 # auto-increments patch (0.1.0 → 0.1.1)
#   ./bin/release.rb 0.2.0           # explicit version
#   ./bin/release.rb "Release notes" # auto-increment with custom notes
#   ./bin/release.rb --yes           # skip the confirmation (non-interactive runs)

require "pathname"
require "open3"

GEM_NAME     = "simplecov-sorbet"
GEM_ROOT     = Pathname.new(File.expand_path("..", __dir__))
VERSION_FILE = GEM_ROOT.join("lib", "simplecov", "sorbet", "version.rb")
GEMFILE_LOCK = GEM_ROOT.join("Gemfile.lock")

def main
  Dir.chdir(GEM_ROOT)
  ensure_clean_tree!
  ensure_on_main!

  # --yes skips the interactive confirmation, which would otherwise hang a
  # piped or backgrounded run waiting for input it can never receive.
  assume_yes = !ARGV.delete("--yes").nil?

  current = current_version
  new_version, notes = parse_args(current)
  commits = commits_since_last_tag

  print_summary(current, new_version, notes, commits)
  abort "Aborted." unless assume_yes || confirm?("Proceed?")
  puts

  step("Bumping version #{current} → #{new_version}") do
    bump_version(current, new_version)
  end

  step("Committing and tagging v#{new_version}") do
    commit_and_tag(new_version, notes)
  end

  step("Pushing main + tag v#{new_version}") do
    push(new_version)
  end

  step("Creating GitHub release v#{new_version}") do
    create_release(new_version, notes)
  end

  # The tag push triggers .github/workflows/release.yml, which publishes to
  # rubygems.org via trusted publishing. Watch it so a failed publish (e.g.
  # a missing trusted-publisher configuration) can't slip by silently.
  step("Waiting for the rubygems publish workflow") do
    watch_publish_workflow(new_version)
  end

  puts "v#{new_version} released: https://rubygems.org/gems/#{GEM_NAME}"
end

def parse_args(current)
  case ARGV.length
  when 0
    [auto_increment(current), default_notes]
  when 1
    arg = ARGV[0]
    if arg.match?(/\A\d+\.\d+\.\d+\z/)
      [arg, default_notes]
    else
      [auto_increment(current), arg]
    end
  when 2
    [ARGV[0], ARGV[1]]
  else
    abort "Usage: #{$PROGRAM_NAME} [version] [notes]"
  end
end

def current_version
  match = VERSION_FILE.read.match(/VERSION = "(\d+\.\d+\.\d+)"/)
  abort "Could not find VERSION in #{VERSION_FILE}" unless match

  match[1]
end

def auto_increment(version)
  parts = version.split(".").map(&:to_i)
  parts[-1] += 1
  parts.join(".")
end

def default_notes
  log = `git log --oneline #{latest_tag}..HEAD`.strip
  return log unless log.empty?

  "Maintenance release."
end

def latest_tag
  `git describe --tags --abbrev=0 2>/dev/null`.strip
end

def ensure_clean_tree!
  status = `git status --porcelain`.strip
  return if status.empty?

  abort "Working tree is not clean. Commit or stash changes first.\n#{status}"
end

def ensure_on_main!
  branch = `git branch --show-current`.strip
  return if branch == "main"

  abort "Must be on main branch (currently on #{branch})."
end

def commits_since_last_tag
  tag = latest_tag
  return [] if tag.empty?

  `git log --oneline #{tag}..HEAD`.strip.lines.map(&:strip)
end

def print_summary(current, new_version, notes, commits)
  puts "Release: #{current} → #{new_version}"
  puts "Notes: #{notes}"
  puts
  if commits.empty?
    puts "Commits: (none since #{latest_tag})"
  else
    puts "Commits since #{latest_tag}:"
    commits.each { |c| puts "  #{c}" }
  end
  puts
  puts "Steps:"
  puts "  1. Bump version.rb + Gemfile.lock"
  puts "  2. Commit + tag v#{new_version}"
  puts "  3. Push main + tag to origin"
  puts "  4. Create GitHub release"
  puts "  5. Watch the trusted-publishing workflow push to rubygems.org"
  puts
end

def confirm?(question)
  print "#{question} (y/N) "
  ($stdin.gets || "").strip.downcase == "y"
end

# One release step, aborting the whole release when it fails so a broken push
# can't cascade into later steps publishing state that never reached GitHub.
def step(title)
  puts "--- #{title}"
  yield
rescue StandardError => e
  abort "Release aborted: '#{title}' failed: #{e.message}\nFix the issue, then finish the remaining steps manually."
end

def run!(*cmd)
  out, err, status = Open3.capture3(*cmd)
  raise "#{cmd.join(" ")} failed: #{err}" unless status.success?

  out
end

def bump_version(current, new_version)
  VERSION_FILE.write(VERSION_FILE.read.sub(%(VERSION = "#{current}"), %(VERSION = "#{new_version}")))

  # The gem is a PATH source in its own Gemfile.lock, pinned in both the PATH
  # specs block and the DEPENDENCIES section; gsub updates the pair.
  lock = GEMFILE_LOCK.read
  GEMFILE_LOCK.write(lock.gsub("#{GEM_NAME} (#{current})", "#{GEM_NAME} (#{new_version})"))
end

def commit_and_tag(version, notes)
  run!("git", "add", VERSION_FILE.to_s, GEMFILE_LOCK.to_s)
  run!("git", "commit", "-m", "Bump version to #{version}\n\n#{notes}")
  run!("git", "tag", "v#{version}")
end

def push(version)
  run!("git", "push", "origin", "main")
  run!("git", "push", "origin", "v#{version}")
end

def create_release(version, notes)
  run!("gh", "release", "create", "v#{version}",
    "--title", "v#{version}", "--notes", notes)
end

# Find the workflow run the tag push triggered (retrying while GitHub
# registers it) and block until it finishes, failing loudly if it failed.
def watch_publish_workflow(version)
  run_id = nil
  10.times do
    run_id = `gh run list --workflow=release.yml --branch v#{version} --limit 1 --json databaseId --jq '.[0].databaseId'`.strip
    break unless run_id.empty?

    sleep 3
  end
  raise "could not find the release.yml run for v#{version}" if run_id.empty?

  run!("gh", "run", "watch", run_id, "--exit-status")
end

main
