# Changelog

All notable changes to Marnage are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning: [SemVer](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] — 2026-10-09

First public release: a signed and notarized `.dmg`.

### Added
- The app and its widget are distributed as `Marnage-1.0.0.dmg`, signed with a
  Developer ID, notarized and stapled.
- README captures of Saint-Malo, Brest and Le Havre, in English and French.
- `make sign`, `make dmg`, `make shots`, `make release-check`.
- A project site (`site/`) for GitHub Pages.

### Fixed
- The app and widget showed French whatever the system language: high/low
  water labels, the countdown, dates and heights were written in French or
  formatted with a forced `fr_FR` locale. They now follow the system language.
- The widget's gallery name and description are localized.

## [0.1.0] — 2026-09-16

### Added
- Initial release.

[Unreleased]: https://github.com/gwenn-ha-dev/Marnage/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/gwenn-ha-dev/Marnage/releases/tag/v1.0.0
[0.1.0]: https://github.com/gwenn-ha-dev/Marnage/releases/tag/v0.1.0
