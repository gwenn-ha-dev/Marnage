import XCTest
@testable import JusantKit

/// Confrontation aux prédictions officielles du SHOM.
///
/// Remplir `official` avec des PM/BM relevées à la main (maree.shom.fr ou
/// annuaire papier, usage privé) : heure de Paris "yyyy-MM-dd HH:mm", hauteur
/// en mètres, coefficient pour les PM. Le test est sauté tant que la liste est
/// vide ; dès qu'elle contient des valeurs, il devient une non-régression
/// forte (horaires, hauteurs et coefficients à la fois).
final class OfficialPredictionTests: XCTestCase {
    struct Official {
        let time: String            // heure locale Europe/Paris, "yyyy-MM-dd HH:mm"
        let kind: TideEvent.Kind
        let height: Double
        let coefficient: Int?
    }

    /// Relevés officiels — à compléter. Exemple :
    /// Official(time: "2026-08-21 05:12", kind: .high, height: 6.85, coefficient: 52),
    static let official: [Official] = []

    func testAgainstOfficialPredictions() throws {
        try XCTSkipIf(Self.official.isEmpty, "aucun relevé officiel saisi")

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        fmt.timeZone = TimeZone(identifier: "Europe/Paris")
        fmt.locale = Locale(identifier: "en_US_POSIX")

        let predictor = ValidationTests.predictor
        let coefCalc = CoefficientCalculator(brest: predictor)
        var timeDeltas: [Double] = []

        for ref in Self.official {
            let t = try XCTUnwrap(fmt.date(from: ref.time), "date invalide : \(ref.time)")
            let window = predictor.extrema(from: t.addingTimeInterval(-2 * 3600),
                                           to: t.addingTimeInterval(2 * 3600))
            let match = try XCTUnwrap(
                window.filter { $0.kind == ref.kind }
                    .min(by: { abs($0.time.timeIntervalSince(t)) < abs($1.time.timeIntervalSince(t)) }),
                "aucune \(ref.kind.rawValue) prédite près de \(ref.time)")

            let dt = abs(match.time.timeIntervalSince(t))
            timeDeltas.append(dt)
            XCTAssertLessThan(dt, 20 * 60, "\(ref.time) : écart horaire \(Int(dt / 60)) min")
            // ~13 cm d'écart systématique documenté (époque du niveau moyen) + marge.
            XCTAssertLessThan(abs(match.height - ref.height), 0.30,
                              "\(ref.time) : écart de hauteur \(match.height - ref.height) m")
            if ref.kind == .high, let c = ref.coefficient {
                let ours = coefCalc.coefficient(nearHighTide: match.time)
                XCTAssertLessThanOrEqual(abs(ours - c), 3, "\(ref.time) : coef \(ours) vs \(c)")
            }
        }
        let median = timeDeltas.sorted()[timeDeltas.count / 2]
        XCTAssertLessThan(median, 8 * 60, "écart horaire médian \(Int(median / 60)) min")
    }
}
