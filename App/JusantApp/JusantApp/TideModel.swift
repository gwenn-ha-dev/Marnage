import Foundation
import JusantKit

/// Un port embarqué : constantes harmoniques + prédicteur prêt à l'emploi.
struct TideStation: Identifiable, Hashable {
    let slug: String            // nom du fichier de constantes, clé de persistance
    let name: String            // nom affiché ("Le Havre")
    let predictor: TidePredictor

    var id: String { slug }

    /// Domaine vertical stable pour les tracés : couvre les plus grandes
    /// vives-eaux (niveau moyen ± somme des amplitudes), arrondi au mètre.
    var heightDomain: ClosedRange<Double> {
        let amp = predictor.station.constants.map(\.amplitude).reduce(0, +)
        let lo = max(0, (predictor.station.meanLevel - amp).rounded(.down))
        return lo...(predictor.station.meanLevel + amp).rounded(.up)
    }

    static func == (a: TideStation, b: TideStation) -> Bool { a.slug == b.slug }
    func hash(into hasher: inout Hasher) { hasher.combine(slug) }
}

/// Accès partagé (app + widget) aux stations embarquées et aux prédictions.
enum TideModel {
    /// Toutes les stations du bundle (fichiers .json de constantes), triées par nom.
    static let stations: [TideStation] = {
        let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "stations") ?? []
        let found = urls.compactMap { url -> TideStation? in
            guard let constants = try? StationConstants.load(from: url) else { return nil }
            return TideStation(slug: url.deletingPathExtension().lastPathComponent,
                               name: constants.station,
                               predictor: TidePredictor(constants))
        }
        guard !found.isEmpty else {
            fatalError("aucune constante de station dans le bundle — vérifier la target membership")
        }
        return found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }()

    /// Brest sert de référence aux coefficients quel que soit le port affiché.
    static let brest: TideStation = station(slug: "brest")

    static let coefficients = CoefficientCalculator(brest: brest.predictor)

    /// Station par slug, Brest en repli (widget dont le port a disparu, etc.).
    static func station(slug: String) -> TideStation {
        stations.first { $0.slug == slug }
            ?? stations.first { $0.slug == "brest" }
            ?? stations[0]
    }

    /// PM/BM entre deux instants, coefficients renseignés sur les PM.
    static func events(for station: TideStation, from: Date, to: Date) -> [TideEvent] {
        var evs = station.predictor.extrema(from: from, to: to)
        for i in evs.indices where evs[i].kind == .high {
            evs[i].coefficient = coefficients.coefficient(nearHighTide: evs[i].time)
        }
        return evs
    }

    /// Prochain événement après un instant donné (pour le widget small).
    static func nextEvent(for station: TideStation, after date: Date) -> TideEvent? {
        events(for: station, from: date, to: date.addingTimeInterval(15 * 3600))
            .first { $0.time > date }
    }

    /// Formateurs partagés : `DateFormatter` est coûteux à construire, et ces
    /// libellés sont rendus des dizaines de fois par entrée de widget.
    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let french = Locale(identifier: "fr_FR")

    static func timeString(_ d: Date) -> String { hourFormatter.string(from: d) }

    static func heightString(_ h: Double) -> String {
        String(format: "%.2f m", locale: french, h)
    }
}
