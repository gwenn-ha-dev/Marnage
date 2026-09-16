# Marnage

[![CI](https://github.com/gwenn-ha-dev/Marnage/actions/workflows/ci.yml/badge.svg)](https://github.com/gwenn-ha-dev/Marnage/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
![Platform](https://img.shields.io/badge/Platform-macOS%2026.5%2B-black?logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6-orange?logo=swift)

*🇬🇧 [English](./README.md) · 🇫🇷 Français*

Prédiction de marées pour les ports français, en Swift pur, **zéro dépendance** (pas de LAPACK, pas de package externe). Le moteur calcule ses propres constantes harmoniques à partir des observations marégraphiques publiques — il ne réutilise aucune prédiction ni constante du SHOM.

## Fonctionnalités

- **`MarnageKit`**, la bibliothèque : analyse harmonique et prédiction.
- **`marnage`**, la CLI.
- **Une app macOS avec son widget** (`App/Marnage`) couvrant 13 ports : courbe du jour, pleines et basses mers, coefficients.
- 33 constituants par défaut ; `--jeu etendu` ajoute 10 ondes composées là où les petits fonds déforment l'onde.
- Aucune dépendance — Swift pur.

## Installation

```sh
git clone https://github.com/gwenn-ha-dev/Marnage.git
cd Marnage
make build
```

## Comment ça marche

1. **Observations** : hauteurs d'eau validées des marégraphes REFMAR, téléchargées depuis `services.data.shom.fr/maregraphie` (données Shom/REFMAR, Licence Ouverte 2.0 Etalab).
2. **Analyse harmonique** : moindres carrés sur 2 ans d'observations, 33 constituants (arguments de Doodson, corrections nodales de Schureman), équations normales résolues par Cholesky.
3. **Prédiction** : somme harmonique, extrema (PM/BM) par recherche ternaire, coefficient de marée calculé à Brest par définition (pic semi-diurne / unité de hauteur 3,05 m).

Le marnage, c'est l'amplitude de la marée — l'écart vertical entre pleine et
basse mer. C'est la grandeur que ce moteur calcule, d'où le nom du projet.

## Construction

| Commande | Ce qu'elle fait |
|---|---|
| `make build` | Compilation release, tout avertissement est une erreur |
| `make test` | Lance la suite de tests |
| `make run` | Lance l'app |
| `make icon` | Régénère `Resources/AppIcon.icns` |
| `make package` | Produit un bundle distribuable dans `build/` |
| `make lint` | Vérifie la conformité à la charte |
| `make help` | Liste toutes les cibles |

## Dépendances

Aucune — frameworks Apple uniquement.

## Licence

MIT © 2026 gwenn-ha-dev — voir [LICENSE](./LICENSE).
