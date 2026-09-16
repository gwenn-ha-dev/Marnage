# Marnage — agent context

## What this is

Tide prediction for French ports, in pure Swift, **zero dependencies** (no LAPACK, no external package). The engine computes its own harmonic constants from public tide-gauge observations — it reuses no SHOM prediction and no SHOM constant.

Platform: the app needs macOS 26.5+; MarnageKit and the `marnage` CLI build from macOS 13+. Build system: Swift Package Manager. Bundle ID `dev.gwennha.Marnage`.

## Build and test

```sh
make build   # release, warnings are errors
make test
make lint    # charter compliance — run before declaring anything done
```

Never invoke `swift build`, `xcodebuild` or a build script directly; go through
the `Makefile`. It is the same interface in every project here.

## Invariants — do not break these

- **No hard-coded user-visible strings.** Everything goes through
  `Resources/Localizable.xcstrings`, present in both `en` and `fr`. Adding a
  string means adding both translations in the same change.
- **No build artefacts committed.** No `.app`, no `build/`, no `.build/`.
- **Dependencies: none.** Adding one requires documenting it in the README's
  *Dependencies* section.
- **`README.md` and `README.fr.md` stay in sync.** Editing one means editing the other.
- **The icon is generated**, never hand-placed: `outils/icone.swift` is the
  source, `make icon` rebuilds `Resources/AppIcon.icns`.
- Code, comments and commit messages are in **English**.

- The test target currently has **no tests**. `make test` passes vacuously; do not read that as coverage.

## Layout

```
.github/
.gitignore
App/
CHANGELOG.md
CONTRIBUTING.md
LICENSE
Makefile
Package.swift
README.md
Resources/
Sources/
Tests/
data/
docs/
outils/
scripts/
stations/
```

## The charter

The full norm this project follows lives at `../../Charte/CHARTE.md`.
