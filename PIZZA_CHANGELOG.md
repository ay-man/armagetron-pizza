# Armagetron Pizza Changelog

All notable changes made in this repository are documented here. Changes from the
upstream Armagetron Advanced project are in [`CHANGELOG.md`](CHANGELOG.md).

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Based on upstream Armagetron Advanced `legacy_0.2.9` (commit `3198557f`).

### Added

- Repository workflow: `main`/`develop` branches, contributing guide, pull request template.
- GitHub Actions build check: builds the Linux client and runs the unit tests on every PR.

### Fixed

- Unit tests failed to compile on newer GCC (`std::ignore` used without including `<tuple>`).
