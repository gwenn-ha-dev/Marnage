# Jusant

[![CI](https://github.com/gwenn-ha-dev/Jusant/actions/workflows/ci.yml/badge.svg)](https://github.com/gwenn-ha-dev/Jusant/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
![Platform](https://img.shields.io/badge/Platform-macOS%2014%2B-black?logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6-orange?logo=swift)

*🇬🇧 English · 🇫🇷 [Français](./README.fr.md)*

Tide prediction for French ports, in pure Swift, **zero dependencies** (no LAPACK, no external package). The engine computes its own harmonic constants from public tide-gauge observations — it reuses no SHOM prediction and no SHOM constant.

## Features

- **`JusantKit`**, the library: harmonic analysis and prediction.
- **`jusant`**, the CLI.
- **A macOS app with its widget** (`App/JusantApp`) covering 13 ports: day curve, high and low waters, coefficients.
- 33 constituents by default; `--jeu etendu` adds 10 compound waves where shallow water distorts the tide.
- No dependencies — pure Swift.

## Install

```sh
git clone https://github.com/gwenn-ha-dev/Jusant.git
cd Jusant
make build
```

## How it works

1. **Observations**: validated water heights from REFMAR tide gauges, downloaded from `services.data.shom.fr/maregraphie` (Shom/REFMAR data, Etalab Open Licence 2.0).
2. **Harmonic analysis**: least squares over 2 years of observations, 33 constituents (Doodson arguments, Schureman nodal corrections), normal equations solved by Cholesky.
3. **Prediction**: harmonic sum, extrema found by ternary search, tide coefficient computed at Brest by definition (semi-diurnal peak / 3.05 m height unit).

## Build

| Command | What it does |
|---|---|
| `make build` | Release build, warnings are errors |
| `make test` | Run the test suite |
| `make run` | Launch the app |
| `make icon` | Regenerate `Resources/AppIcon.icns` |
| `make package` | Produce a distributable bundle in `build/` |
| `make lint` | Check compliance with the project charter |
| `make help` | List every target |

## Dependencies

None — Apple frameworks only.

## License

MIT © 2026 gwenn-ha-dev — see [LICENSE](./LICENSE).
