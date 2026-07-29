[![CI](https://github.com/d3mlabs/simplecov-sorbet/actions/workflows/ci.yml/badge.svg)](https://github.com/d3mlabs/simplecov-sorbet/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/d3mlabs/simplecov-sorbet/branch/main/graph/badge.svg)](https://codecov.io/gh/d3mlabs/simplecov-sorbet)

# SimpleCov::Sorbet

A [SimpleCov](https://github.com/simplecov-ruby/simplecov) extension for [Sorbet](https://sorbet.org) codebases: it skips type-level Sorbet constructs that coverage should not measure, so they stop reading as coverage misses.

Three constructs are skipped:

- **Multi-line `T.type_alias` blocks.** sorbet-runtime resolves aliases lazily and collection checks are shallow, so the block body of

```ruby
ResolvedSegment = T.type_alias do
  [
    CommentParser::Segment,
    T.nilable(String),
    T.nilable(T::Hash[Symbol, T.untyped]),
  ]
end
```

  never executes — and SimpleCov (and any patch-coverage gate built on it, like Codecov's) reports those lines as uncovered.

- **`sig` blocks** (bare or with a receiver such as `T::Sig::WithoutRuntime.sig`). Sigs are type metadata whose correctness `srb tc` owns; coverage should measure behavior. Skipping them sharpens the signal: an untested method reports its *body* as the miss, without sig-line noise — and `T::Sig::WithoutRuntime` sigs, which never evaluate at runtime, stop being permanent false positives. Detection matches any `sig` call with a multi-line block; a non-Sorbet DSL also named `sig` would be over-matched, an accepted risk in a Sorbet codebase.

- **`T.absurd` sends.** Exhaustiveness checks are unreachable by definition when the code is correct — Sorbet statically proves the `else` branch can't be taken — so in healthy code the line is a permanent miss.

The usual workarounds are cramming constructs onto one line or sprinkling `# simplecov:disable` comments; both encode a tool-compatibility fact into every file. This gem moves that knowledge to the layer that owns it: detection is purely syntactic (a [Prism](https://github.com/ruby/prism)-backed AST pass via [ast_transform](https://github.com/rspockframework/ast-transform)), and the found ranges feed straight into SimpleCov's skip machinery.

## Installation

Add the gem to your Gemfile's test group:

```ruby
gem "simplecov-sorbet", require: false
```

Then require it anywhere near your SimpleCov setup — before or after `SimpleCov.start`, both work (ranges are consumed at report time):

```ruby
require "simplecov"
require "simplecov/sorbet"

SimpleCov.start
```

## How it works

Requiring `simplecov/sorbet` prepends an extension onto `SimpleCov::Directive.disabled_ranges`, the seam SimpleCov 1.0 consults for `# simplecov:disable` ranges — for both loaded files (`SourceFile`) and tracked-but-unloaded files (`LinesClassifier`). The extension parses each covered file, collects the line range of every ignored construct (`T.type_alias` blocks including the `::T` form, multi-line `sig` blocks, and `T.absurd` sends), and appends those ranges to all three directive categories (`line`, `branch`, `method` — type-level constructs are not behavior, so anything inside them is skippable). Files the parser rejects contribute no ranges and are otherwise reported untouched.

### What is deliberately not skipped

Regular sig *behavior* is unaffected: sorbet-runtime evaluates a sig block lazily on the method's first call, so before this gem an uncovered sig always accompanied an uncovered method body. Skipping sigs removes the duplicate line, not the signal — the untested body still reports as a miss. One tradeoff to know about: a sig coverage miss on a *tested* method once exposed a real bug (`module_function` copies methods before the sig wrapper installs, silently disabling runtime validation). With sigs skipped, that class of bug is RuboCop's to catch (`Style/ModuleFunction: EnforcedStyle: extend_self`), not coverage's.

Skips apply through SimpleCov's directive machinery, which drives its line classification; if you enable branch coverage, branches inside skipped ranges are covered by the `branch` directive category the extension also populates.

## Requirements

- Ruby >= 3.3
- simplecov ~> 1.0
- A Sorbet codebase (the gem depends on sorbet-runtime for its own inline sigs; it never loads your type system)

## Development

This repo is managed with d3mlabs' `dev` tool (`dev up`, `dev test`, `dev style`, `dev typecheck`), but plain Bundler works without it: `bundle install`, then `bundle exec rake test`. The Ruby version is declared in `dependencies.rb` and mirrored in `.ruby-version`.

## Releasing a New Version

From a clean checkout of `main`:

```
dev release          # auto-increments the patch version (0.1.0 → 0.1.1)
dev release 0.2.0    # explicit version
```

The script ([bin/release.rb](bin/release.rb)) bumps `lib/simplecov/sorbet/version.rb` and `Gemfile.lock`, commits, tags `v<version>`, pushes, creates the GitHub release, and then watches the [release workflow](.github/workflows/release.yml) — which validates that the tag matches `version.rb`, builds the gem, and publishes it to [rubygems.org](https://rubygems.org) via [Trusted Publishing](https://guides.rubygems.org/trusted-publishing/) — until the publish succeeds.

## License

MIT — see [LICENSE.txt](LICENSE.txt).
