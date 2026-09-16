import Foundation

public struct TideEvent {
    public enum Kind: String { case high = "PM", low = "BM" }
    public let kind: Kind
    public let time: Date
    public let height: Double        // m au-dessus du zéro hydrographique
    public var coefficient: Int?     // renseigné pour les PM si un prédicteur de Brest est fourni
}

/// Prédicteur de marée pour une station, à partir de ses constantes harmoniques.
public struct TidePredictor {
    public let station: StationConstants
    let pairs: [(Constituent, HarmonicConstant)]

    /// Noms de constituants présents dans les constantes mais absents de la
    /// table interrogée : ils ne participent pas à la prédiction. Doit rester
    /// vide — un prédicteur amputé prédit une marée fausse sans rien signaler,
    /// ce qui arrive dès qu'on lui donne des constantes issues d'un jeu plus
    /// riche que le sien.
    public let unknownConstituents: [String]

    public init(_ station: StationConstants, constituents: [Constituent] = extendedConstituents) {
        self.station = station
        let byName = Dictionary(uniqueKeysWithValues: constituents.map { ($0.name, $0) })
        self.pairs = station.constants.compactMap { hc in
            byName[hc.name].map { ($0, hc) }
        }
        self.unknownConstituents = station.constants.map(\.name).filter { byName[$0] == nil }
        assert(unknownConstituents.isEmpty,
               "constituants inconnus : \(unknownConstituents.joined(separator: ", "))")
    }

    /// Hauteur d'eau prédite (m / zéro hydrographique) à un instant donné.
    public func height(at date: Date, speciesFilter: ((Int) -> Bool)? = nil, includeMeanLevel: Bool = true) -> Double {
        let a = AstroState(date: date)
        let e = ElementaryNodal(a)
        var h = includeMeanLevel ? station.meanLevel : 0.0
        for (c, hc) in pairs {
            if let filter = speciesFilter, !filter(c.species) { continue }
            let (f, vu) = c.vu(a, e)
            h += f * hc.amplitude * cos(deg2rad(vu - hc.phaseLag))
        }
        return h
    }

    /// Pleines et basses mers dans [start, end[.
    public func extrema(from start: Date, to end: Date) -> [TideEvent] {
        let step: TimeInterval = 600  // 10 min : bien en dessous de la demi-période de M8
        var events: [TideEvent] = []
        var t = start
        var prev = height(at: t.addingTimeInterval(-step))
        var curr = height(at: t)
        while t <= end {
            let next = height(at: t.addingTimeInterval(step))
            if curr >= prev && curr > next {
                let (te, he) = refineExtremum(around: t, halfWidth: step, maximize: true)
                // L'affinage peut sortir de [start, end[ : l'extremum appartient alors
                // à la fenêtre voisine, qui le détecte aussi — on ne le compte qu'une fois.
                if te >= start && te < end {
                    events.append(TideEvent(kind: .high, time: te, height: he, coefficient: nil))
                }
            } else if curr <= prev && curr < next {
                let (te, he) = refineExtremum(around: t, halfWidth: step, maximize: false)
                if te >= start && te < end {
                    events.append(TideEvent(kind: .low, time: te, height: he, coefficient: nil))
                }
            }
            prev = curr
            curr = next
            t = t.addingTimeInterval(step)
        }
        return events
    }

    /// Affine un extremum par recherche ternaire (précision ~1 s).
    func refineExtremum(around t: Date, halfWidth: TimeInterval, maximize: Bool,
                        speciesFilter: ((Int) -> Bool)? = nil, includeMeanLevel: Bool = true) -> (Date, Double) {
        var lo = t.timeIntervalSinceReferenceDate - halfWidth
        var hi = t.timeIntervalSinceReferenceDate + halfWidth
        func value(_ x: Double) -> Double {
            let h = height(at: Date(timeIntervalSinceReferenceDate: x),
                           speciesFilter: speciesFilter, includeMeanLevel: includeMeanLevel)
            return maximize ? h : -h
        }
        while hi - lo > 1 {
            let m1 = lo + (hi - lo) / 3
            let m2 = hi - (hi - lo) / 3
            if value(m1) < value(m2) { lo = m1 } else { hi = m2 }
        }
        let x = (lo + hi) / 2
        let d = Date(timeIntervalSinceReferenceDate: x)
        return (d, height(at: d, speciesFilter: speciesFilter, includeMeanLevel: includeMeanLevel))
    }
}

/// Coefficient de marée : défini au port de Brest, comme le rapport (×100) de
/// l'amplitude semi-diurne de la pleine mer à l'unité de hauteur U = 3,05 m.
/// Le même coefficient vaut pour tous les ports de la façade Manche-Atlantique.
public struct CoefficientCalculator {
    public static let unitHeight = 3.05  // unité de hauteur à Brest, en mètres
    let brest: TidePredictor

    public init(brest: TidePredictor) {
        self.brest = brest
    }

    /// Coefficient associé à la marée concomitante : pic semi-diurne (espèce 2,
    /// sans niveau moyen) de Brest **le plus proche** de l'instant donné,
    /// rapporté à l'unité de hauteur. La PM d'un port peut être déphasée de
    /// plusieurs heures par rapport à Brest (Manche Est) : on balaye ±9 h — il
    /// y a toujours au moins un pic (période ~12,4 h) — et on retient le plus
    /// proche en temps, pas le plus haut.
    public func coefficient(nearHighTide t: Date) -> Int {
        func semiDiurnal(_ d: Date) -> Double {
            brest.height(at: d, speciesFilter: { $0 == 2 }, includeMeanLevel: false)
        }
        let step: TimeInterval = 600
        var best: (dt: Double, peak: Double)?
        var x = t.addingTimeInterval(-9 * 3600)
        var prev = semiDiurnal(x.addingTimeInterval(-step))
        var curr = semiDiurnal(x)
        while x <= t.addingTimeInterval(9 * 3600) {
            let next = semiDiurnal(x.addingTimeInterval(step))
            if curr >= prev && curr > next {
                let (te, he) = brest.refineExtremum(around: x, halfWidth: step, maximize: true,
                                                    speciesFilter: { $0 == 2 }, includeMeanLevel: false)
                let dt = abs(te.timeIntervalSince(t))
                if best == nil || dt < best!.dt { best = (dt, he) }
            }
            prev = curr
            curr = next
            x = x.addingTimeInterval(step)
        }
        return Int((100.0 * (best?.peak ?? 0) / Self.unitHeight).rounded())
    }
}
