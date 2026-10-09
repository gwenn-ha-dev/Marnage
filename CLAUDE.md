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
- Identifiers, commit messages and both READMEs are in **English**; comments may
  be in English or French (charter §2).

- `make test` runs 16 XCTest cases (Cholesky, constituent speeds, predictions);
  `testAgainstOfficialPredictions` stays skipped until official SHOM readings are
  entered — it waits for data, not code.
- **`Text(cond ? "a" : "b")` is never translated**: a ternary yields a `String`,
  which takes `Text`'s verbatim overload. Write `cond ? Text("a") : Text("b")`.
  No `Locale(identifier: "fr_FR")` either: dates and numbers follow the app's
  language. The app and the widget each have their own `Localizable.xcstrings`.

## Public identity and releases (charter §12)

- Commit as `gwenn-ha-dev <13298867+gwenn-ha-dev@users.noreply.github.com>` (set
  in this repo's git config) and in UTC: `TZ=UTC git commit …`. No personal name,
  email or `/Users/…` path in tracked files. `../../Charte/outils/identite.sh .` checks.
- A release: `make package && make sign && make dmg && make shots && make release-check`,
  then tag `v<version>` and attach `build/Marnage-<version>.dmg` — see
  `../../Charte/DISTRIBUTION-AGENT.md`, phase 3. The version is `MARKETING_VERSION`
  in `App/Marnage/Marnage.xcodeproj`.
- The app is built by Xcode (`outils/package.sh`), signed "Apple Development"
  with `get-task-allow`; `make sign` re-signs every piece with the Developer ID,
  keeping each one's own entitlements (the widget keeps its sandbox) minus
  `get-task-allow`, which the notary refuses.

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
