# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-29
### Initial release
- `T.type_alias` block skipping: requiring `simplecov/sorbet` prepends an extension onto `SimpleCov::Directive.disabled_ranges` that parses each covered file (Prism via ast_transform's analysis API) and appends every alias block's line range to all three directive categories. Multi-line alias bodies are runtime-unreachable by design and no longer read as coverage misses.
