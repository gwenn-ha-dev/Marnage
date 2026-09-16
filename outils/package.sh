#!/bin/bash
# Fabrique build/Marnage.app — l'app et son widget.
#
# Le paquet SPM ne produit que MarnageKit et la CLI `marnage`. L'app AppKit et
# l'extension MarnageWidgetExtension (dev.gwennha.Marnage.Widget) n'existent
# que dans le projet Xcode d'App/Marnage/, qui en est la seule vérité — voir
# App/GUIDE_XCODE.md. Le Makefile délègue ici pour `make package` : c'est le
# seul chemin vers le .app, et il ne réimplémente rien.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=${1:-Release}
PROJET="App/Marnage/Marnage.xcodeproj"
SYMROOT="$PWD/build/xcode"
APP="build/Marnage.app"

[ -d "$PROJET" ] || { echo "!! $PROJET introuvable"; exit 1; }

# `-target` plutôt que `-scheme` : le dépôt ne versionne aucun .xcscheme (ils
# vivent dans xcuserdata/, ignoré par git), donc sur une machine qui n'a jamais
# ouvert le projet dans Xcode il n'y a pas de schéma à nommer. La target porte
# le widget en dépendance et l'embarque : le .appex suit tout seul.
# Les produits atterrissent sous build/, pas dans le DerivedData partagé
# d'Xcode : `make clean` doit suffire à tout effacer. On règle SYMROOT plutôt
# que -derivedDataPath, que xcodebuild refuse sans -scheme.
xcodebuild -project "$PROJET" -target Marnage -configuration "$CONFIG" \
  -destination 'platform=macOS' SYMROOT="$SYMROOT" OBJROOT="$SYMROOT/obj" build

BUILT="$SYMROOT/$CONFIG/Marnage.app"
[ -d "$BUILT" ] || { echo "!! $BUILT introuvable après compilation"; exit 1; }

# ditto, pas cp -R : il conserve les attributs étendus, donc la signature du
# bundle et celle de l'extension qu'il contient.
rm -rf "$APP"
ditto "$BUILT" "$APP"

codesign --verify --deep --verbose=1 "$APP"
echo "→ $PWD/$APP"

# `./outils/package.sh Release install` : installe dans /Applications et
# enregistre le bundle auprès de LaunchServices. Sans cela le widget « Marées »
# ne figure pas dans « Modifier les widgets… » : la galerie ne liste que les
# extensions d'une app connue du système et lancée au moins une fois.
if [ "${2:-}" = "install" ]; then
  rsync -a --delete "$APP/" /Applications/Marnage.app/
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Marnage.app
  echo "→ /Applications/Marnage.app mise à jour — lance-la une fois, puis Bureau → Modifier les widgets…"
fi
