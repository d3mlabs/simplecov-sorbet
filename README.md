# SimpleCov::Sorbet

A [SimpleCov](https://github.com/simplecov-ruby/simplecov) extension for [Sorbet](https://sorbet.org) codebases: it skips constructs Sorbet makes runtime-unreachable by design, so they stop reading as coverage misses.

Today that means multi-line `T.type_alias` blocks. sorbet-runtime resolves aliases lazily and collection checks are shallow, so the block body of

```ruby
ResolvedSegment = T.type_alias do
  [
    CommentParser::Segment,
    T.nilable(String),
    T.nilable(T::Hash[Symbol, T.untyped]),
  ]
end
```

never executes — and SimpleCov (and any patch-coverage gate built on it, like Codecov's) reports those lines as uncovered. The usual workarounds are cramming the alias onto one line or sprinkling `# simplecov:disable` comments; both encode a tool-compatibility fact into every file that has an alias. This gem moves that knowledge to the layer that owns it: detection is purely syntactic (a [Prism](https://github.com/ruby/prism)-backed AST pass via [ast_transform](https://github.com/rspockframework/ast-transform)), and the found ranges feed straight into SimpleCov's skip machinery.

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

Requiring `simplecov/sorbet` prepends an extension onto `SimpleCov::Directive.disabled_ranges`, the seam SimpleCov 1.0 consults for `# simplecov:disable` ranges — for both loaded files (`SourceFile`) and tracked-but-unloaded files (`LinesClassifier`). The extension parses each covered file, collects the line range of every `T.type_alias` block (including the `::T` form), and appends those ranges to all three directive categories (`line`, `branch`, `method` — the block body is runtime-unreachable, so anything inside it is skippable). Files the parser rejects contribute no ranges and are otherwise reported untouched.

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
