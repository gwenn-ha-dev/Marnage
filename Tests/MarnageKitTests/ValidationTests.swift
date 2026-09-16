import XCTest
@testable import MarnageKit

/// Non-régression sur données réelles : rejoue la validation hors fit du README
/// (constantes stations/brest.json, observations REFMAR 2025-01 → 2026-07) avec des
/// seuils calés juste au-dessus des valeurs constatées. Toute dégradation du
/// moteur (vitesses, corrections nodales, extrema, coefficients) fait échouer
/// ces tests avant d'atteindre l'app.
final class ValidationTests: XCTestCase {
    /// Racine du repo, déduite de l'emplacement de ce fichier.
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // MarnageKitTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()

    static let predictor: TidePredictor = {
        let url = repoRoot.appendingPathComponent("stations/brest.json")
        return TidePredictor(try! StationConstants.load(from: url))
    }()

    static let observations: [Observation] = {
        let dir = repoRoot.appendingPathComponent("data/brest")
        return (try? RefmarReader.read(directory: dir,
                                       from: day(2025, 1, 1), to: day(2026, 7, 1))) ?? []
    }()

    static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    override func setUpWithError() throws {
        try XCTSkipIf(Self.observations.isEmpty,
                      "observations absentes (data/brest) — tests de non-régression sautés")
    }

    /// Hauteurs prédites vs observations réelles, 18 mois hors fit.
    /// Constaté : biais +1,0 cm, RMS 15,5 cm (surcote météo incluse), |max| 91 cm.
    func testHeightsAgainstObservations() {
        let p = Self.predictor
        var sum = 0.0, ss = 0.0, maxAbs = 0.0
        for o in Self.observations {
            let r = o.height - p.height(at: o.time)
            sum += r; ss += r * r; maxAbs = max(maxAbs, abs(r))
        }
        let n = Double(Self.observations.count)
        XCTAssertGreaterThan(n, 10_000, "période hors fit incomplète")
        XCTAssertLessThan(abs(sum / n), 0.03, "biais > 3 cm")
        XCTAssertLessThan((ss / n).squareRoot(), 0.18, "RMS > 18 cm")
        XCTAssertLessThan(maxAbs, 1.20, "résidu max aberrant")
    }

    /// Horaires de PM : extrema observés (parabole sur 3 points horaires autour
    /// des maxima locaux) vs PM prédites. Cadence horaire ⇒ tolérances larges,
    /// mais une vitesse ou correction nodale fausse dériverait bien au-delà.
    func testHighWaterTimesAgainstObservations() {
        let obs = Self.observations
        var deltas: [Double] = []
        for i in 1..<(obs.count - 1) {
            let (a, b, c) = (obs[i - 1], obs[i], obs[i + 1])
            guard b.height > a.height, b.height > c.height,
                  b.time.timeIntervalSince(a.time) == 3600,
                  c.time.timeIntervalSince(b.time) == 3600 else { continue }
            // Sommet de la parabole passant par (−1h, a), (0, b), (+1h, c)
            let denom = a.height - 2 * b.height + c.height
            guard denom < 0 else { continue }
            let offset = 0.5 * (a.height - c.height) / denom * 3600
            let tObs = b.time.addingTimeInterval(offset)
            let window = Self.predictor.extrema(from: tObs.addingTimeInterval(-4 * 3600),
                                                to: tObs.addingTimeInterval(4 * 3600))
            guard let pm = window.filter({ $0.kind == .high })
                .min(by: { abs($0.time.timeIntervalSince(tObs)) < abs($1.time.timeIntervalSince(tObs)) })
            else { continue }
            deltas.append(abs(pm.time.timeIntervalSince(tObs)))
        }
        XCTAssertGreaterThan(deltas.count, 800, "trop peu de PM appariées")
        let sorted = deltas.sorted()
        let median = sorted[sorted.count / 2]
        let p90 = sorted[Int(0.9 * Double(sorted.count))]
        XCTAssertLessThan(median, 12 * 60, "écart médian PM > 12 min")
        XCTAssertLessThan(p90, 30 * 60, "écart P90 PM > 30 min")
    }

    /// Structure des extrema sur un mois : alternance PM/BM stricte,
    /// espacement semi-diurne plausible, marnage jamais dégénéré.
    func testExtremaStructure() {
        let evs = Self.predictor.extrema(from: Self.day(2026, 3, 1), to: Self.day(2026, 4, 1))
        XCTAssertTrue((110...120).contains(evs.count), "≈ 4 extrema/jour attendus, trouvé \(evs.count)")
        for (prev, next) in zip(evs, evs.dropFirst()) {
            XCTAssertNotEqual(prev.kind, next.kind, "deux \(prev.kind.rawValue) consécutives")
            let dt = next.time.timeIntervalSince(prev.time)
            XCTAssertTrue((3.5 * 3600...9 * 3600).contains(dt), "espacement \(dt / 3600) h")
            XCTAssertGreaterThan(abs(next.height - prev.height), 0.5, "marnage dégénéré")
        }
    }

    /// La réunion des requêtes jour par jour doit être identique à la requête
    /// sur le mois entier : protège le correctif des extrema de minuit
    /// (détection dupliquée dans les deux fenêtres adjacentes).
    func testPerDayQueriesMatchFullRange() {
        let p = Self.predictor
        let full = p.extrema(from: Self.day(2026, 3, 1), to: Self.day(2026, 4, 1))
        var daily: [TideEvent] = []
        for d in 0..<31 {
            let start = Self.day(2026, 3, 1).addingTimeInterval(Double(d) * 86_400)
            daily += p.extrema(from: start, to: start.addingTimeInterval(86_400))
        }
        XCTAssertEqual(full.count, daily.count, "extrema dupliqués ou perdus aux frontières de jour")
        for (a, b) in zip(full, daily) {
            XCTAssertEqual(a.kind, b.kind)
            XCTAssertEqual(a.time.timeIntervalSince(b.time), 0, accuracy: 2)
        }
    }

    /// Validation hors fit de chaque station embarquée dans l'app contre ses
    /// observations 2025-01 → 2026-07. Seuils par station calés juste au-dessus
    /// des valeurs constatées au fit initial (2026-08) : biais ≤ 6 cm partout,
    /// RMS selon le régime (eaux peu profondes de la Manche Est et Saint-Malo
    /// plus déformées — le résidu du fit y domine la surcote météo).
    func testAllEmbeddedStationsAgainstObservations() throws {
        // (slug, RMS max en cm) — constaté : 13,6 (Cherbourg) à 21,4 (Dunkerque),
        // seuils calés ~1,5 cm au-dessus. Les six ports au jeu étendu ont vu
        // leur seuil resserré d'autant : une régression qui annulerait l'apport
        // des constituants d'eaux peu profondes ferait échouer ces tests.
        let stations: [(String, Double)] = [
            ("brest", 17), ("dunkerque", 23), ("boulogne", 22.5), ("dieppe", 21),
            ("le-havre", 21), ("cherbourg", 15), ("saint-malo", 22), ("roscoff", 17.5),
            ("le-conquet", 17), ("concarneau", 17.5), ("saint-nazaire", 19),
            ("la-rochelle", 19), ("boucau-bayonne", 16),
        ]
        let stationsDir = Self.repoRoot.appendingPathComponent("stations")
        for (slug, rmsMax) in stations {
            let constants = try StationConstants.load(from: stationsDir.appendingPathComponent("\(slug).json"))
            let obs = try RefmarReader.read(directory: Self.repoRoot.appendingPathComponent("data/\(slug)"),
                                            from: Self.day(2025, 1, 1), to: Self.day(2026, 7, 1))
            XCTAssertGreaterThan(obs.count, 10_000, "\(slug) : période hors fit incomplète")
            let p = TidePredictor(constants)
            var sum = 0.0, ss = 0.0
            for o in obs {
                let r = o.height - p.height(at: o.time)
                sum += r; ss += r * r
            }
            let n = Double(obs.count)
            XCTAssertLessThan(abs(sum / n), 0.06, "\(slug) : biais > 6 cm")
            XCTAssertLessThan((ss / n).squareRoot(), rmsMax / 100, "\(slug) : RMS > \(rmsMax) cm")
        }
    }

    /// Toute constante livrée doit être connue du moteur. Un nom non reconnu est
    /// écarté en silence par `TidePredictor`, qui prédit alors une marée fausse
    /// sans le dire : c'est exactement ce qui est arrivé en introduisant le jeu
    /// étendu, dont les 10 composés étaient ignorés à la prédiction alors que
    /// le fit les produisait.
    func testShippedConstantsAreAllKnown() throws {
        let dir = Self.repoRoot.appendingPathComponent("stations")
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        XCTAssertEqual(files.count, 13, "13 ports embarqués attendus")
        for url in files {
            let constants = try StationConstants.load(from: url)
            let p = TidePredictor(constants)
            XCTAssertEqual(p.unknownConstituents, [],
                           "\(constants.station) : constituants inconnus du moteur")
            XCTAssertTrue([33, 43].contains(constants.constants.count),
                          "\(constants.station) : \(constants.constants.count) constituants")
        }
    }

    /// Le coefficient doit être celui de la marée de Brest concomitante, même
    /// interrogé depuis la PM d'un port déphasé de plusieurs heures (Manche Est).
    func testCoefficientStableUnderPhaseShift() {
        let calc = CoefficientCalculator(brest: Self.predictor)
        for ev in Self.predictor.extrema(from: Self.day(2026, 6, 1), to: Self.day(2026, 6, 8))
        where ev.kind == .high {
            let ref = calc.coefficient(nearHighTide: ev.time)
            for shift in [-5.5, -3.0, 3.0, 5.5] {
                XCTAssertEqual(calc.coefficient(nearHighTide: ev.time.addingTimeInterval(shift * 3600)),
                               ref, "coef instable pour un décalage de \(shift) h")
            }
        }
    }

    /// Coefficients sur l'année 2026 : bornes physiques (20–120) et dynamique
    /// réelle (vives-eaux ≥ 95, mortes-eaux ≤ 40).
    func testCoefficientDynamics() {
        let calc = CoefficientCalculator(brest: Self.predictor)
        var coefs: [Int] = []
        let start = Self.day(2026, 1, 1)
        for ev in Self.predictor.extrema(from: start, to: Self.day(2027, 1, 1))
        where ev.kind == .high {
            coefs.append(calc.coefficient(nearHighTide: ev.time))
        }
        XCTAssertGreaterThan(coefs.count, 600)
        XCTAssertGreaterThanOrEqual(coefs.min()!, 20)
        XCTAssertLessThanOrEqual(coefs.max()!, 120)
        XCTAssertGreaterThanOrEqual(coefs.max()!, 95, "aucune vive-eau dans l'année ?")
        XCTAssertLessThanOrEqual(coefs.min()!, 40, "aucune morte-eau dans l'année ?")
    }
}
