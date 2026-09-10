# Créer l'app + le widget dans Xcode (~5 min)

> Fait le 2026-08-20. Les sources vivent désormais directement dans le projet
> Xcode (`App/MareesApp/`), qui est la seule vérité. Ce guide documente la
> procédure pour la reproduire (autre machine, autre port, contributeur).

Aucun compte développeur payant nécessaire : tout se signe en local.

## 1. Créer le projet

1. Xcode → **File → New → Project… → macOS → App**.
2. Product Name : `MareesApp` — Interface : SwiftUI, Language : Swift,
   Testing System : None, Storage : None.
3. Emplacement : le dossier `Marees/App/`. Xcode crée `Marees/App/MareesApp/`.

## 2. Signature (sans compte payant)

Projet → target `MareesApp` → **Signing & Capabilities** :

- Option A (aucun compte) : Team = *None*, puis onglet Build Settings →
  `Code Signing Identity` = **Sign to Run Locally**.
- Option B (si le widget n'apparaît pas dans la galerie avec l'option A) :
  Xcode → Settings → Accounts → ajouter ton identifiant Apple (gratuit),
  puis Team = *ton nom (Personal Team)*.

## 3. Brancher MareeKit

1. **File → Add Package Dependencies… → Add Local…** et choisir le dossier
   `Marees/` (la racine du package, pas `App/`).
2. Ajouter le produit **MareeKit** à la target `MareesApp`.

## 4. Ajouter la target widget

1. **File → New → Target… → macOS → Widget Extension**.
2. Product Name : `MareesWidget`. **Décocher** « Include Configuration App Intent ».
3. « Activate scheme » : oui.
4. Target `MareesWidget` → General → Frameworks and Libraries : ajouter
   **MareeKit**, et même réglage de signature qu'à l'étape 2.

## 5. Mettre en place les sources

Xcode 16+ adosse chaque target à un **dossier synchronisé** : tout fichier
déposé dans `App/MareesApp/MareesApp/` (resp. `MareesWidget/`) entre de
lui-même dans la target correspondante. Il n'y a donc rien à glisser dans le
navigateur — on copie dans le Finder, et l'unique réglage manuel est la
double appartenance des fichiers partagés avec le widget (point 3).

1. Supprimer (Move to Trash) les fichiers Swift générés par Xcode :
   - dossier `MareesApp` : `ContentView.swift` et `MareesAppApp.swift` ;
   - dossier `MareesWidget` : tous les `.swift` générés (garder `Info.plist`
     et l'asset catalog).
2. Copier les sources de ce dépôt dans les dossiers du projet :
   - `App/MareesApp/MareesApp/` : `MareesApp.swift`, `TideCurve.swift`,
     `TideModel.swift` ;
   - `App/MareesApp/MareesWidget/` : `MareesWidget.swift`.
   Les constantes des ports n'y figurent pas : elles restent dans `stations/`
   à la racine du dépôt (étape 4 ci-dessous).
3. Le widget affiche la même courbe et le même choix de ports que l'app : il
   lui faut donc aussi le moteur d'affichage. Sélectionner `TideModel.swift`
   et `TideCurve.swift` dans le navigateur, puis File Inspector →
   **Target Membership** → cocher `MareesWidgetExtension` en plus de
   `MareesApp`. `MareesApp.swift` reste réservé à l'app. (Xcode inscrit ces
   cases comme `membershipExceptions` dans le projet — c'est l'état attendu du
   `project.pbxproj` versionné.)
4. Embarquer les constantes **sans les dupliquer** : File → **Add Files to
   "MareesApp"…** → choisir le dossier `stations/` à la racine du dépôt, avec
   *Copy items if needed* **décoché** et **Create folder references** (dossier
   bleu, pas jaune) ; cocher les deux targets. Le dossier est copié tel quel
   dans les bundles, d'où le `subdirectory: "stations"` de `TideModel`.
   Dans le projet versionné, cela se lit `path = ../../stations` avec
   `lastKnownFileType = folder`.

⚠️ Il n'existe qu'un seul exemplaire des constantes, partagé par la CLI, les
tests et l'app : après un re-calcul (`maree analyse -o stations/<slug>.json`),
il n'y a rien d'autre à recopier nulle part.

## 6. Lancer

1. Scheme `MareesApp` → **Run** : la fenêtre affiche les marées de la semaine.
   Lancer l'app au moins une fois enregistre le widget auprès du système.
2. Bureau → clic droit → **Modifier les widgets…** → chercher « Marées » →
   ajouter en small ou medium.

Si le widget ne figure pas dans la galerie : vérifier la signature (étape 2,
option B), relancer l'app, au besoin `killall NotificationCenter`.
