import XCTest
@testable import MareeKit

/// Garde-fous sur la table des constituants : vitesses conformes aux valeurs
/// publiées, et séparabilité effective sur la durée d'analyse.
final class ConstituentTests: XCTestCase {

    /// Les composés d'eaux peu profondes sont engendrés par le code
    /// (`Constituent.compound`) : leurs vitesses doivent retomber sur les
    /// valeurs des tables (degrés/heure, IHO / Schureman).
    func testShallowWaterSpeeds() {
        let expected: [String: Double] = [
            "2SM2": 31.0158958, "SO3": 43.9430356, "SK3": 45.0410686,
            "3MS4": 56.9523126, "SN4": 58.4397295, "S4": 60.0000000,
            "MSN6": 87.4238337, "2SM6": 88.9841042, "3MS8": 116.9523127,
            "M10": 144.9205210,
        ]
        let byName = Dictionary(uniqueKeysWithValues: shallowWaterConstituents.map { ($0.name, $0) })
        XCTAssertEqual(byName.count, expected.count, "doublon de nom dans le jeu d'eaux peu profondes")
        for (name, speed) in expected {
            guard let c = byName[name] else { XCTFail("constituant \(name) absent"); continue }
            XCTAssertEqual(c.speed, speed, accuracy: 1e-4, "vitesse de \(name)")
        }
    }

    /// Deux constituants ne sont séparables par moindres carrés que si leurs
    /// vitesses diffèrent d'au moins un cycle sur la durée d'analyse (critère
    /// de Rayleigh). Les fits du dépôt portent sur 2 ans → 360/17520 h
    /// ≈ 0,0206 °/h. Ce test aurait rejeté d'emblée `2MS2` (vitesse identique
    /// à `mu2`) et `MO3` (identique à `2MK3`), qui rendaient la matrice
    /// normale singulière.
    func testSeparability() {
        let fitHours = 2 * 365.25 * 24.0
        let rayleigh = 360.0 / fitHours
        let cs = extendedConstituents
        for (i, a) in cs.enumerated() {
            // Séparabilité d'avec le niveau moyen Z0 (vitesse nulle).
            XCTAssertGreaterThan(abs(a.speed), rayleigh, "\(a.name) inséparable de Z0")
            for b in cs[(i + 1)...] {
                XCTAssertGreaterThan(abs(a.speed - b.speed), rayleigh,
                                     "\(a.name) et \(b.name) inséparables sur 2 ans "
                                     + "(Δ = \(abs(a.speed - b.speed)) °/h)")
            }
        }
    }

    /// La composition doit reproduire à l'identique un composé déjà présent
    /// dans la table standard, écrit lui à la main.
    func testCompositionMatchesHandWrittenEntries() {
        let byName = Dictionary(uniqueKeysWithValues: standardConstituents.map { ($0.name, $0) })
        let cases: [(String, [(Double, String)])] = [
            ("MS4", [(1, "M2"), (1, "S2")]),
            ("MK3", [(1, "M2"), (1, "K1")]),
            ("2MK3", [(2, "M2"), (-1, "K1")]),
            ("MN4", [(1, "M2"), (1, "N2")]),
            ("2MS6", [(2, "M2"), (1, "S2")]),
        ]
        for (name, terms) in cases {
            let hand = byName[name]!
            let built = Constituent.compound(name, terms)
            XCTAssertEqual(built.d, hand.d, "arguments de Doodson de \(name)")
            XCTAssertEqual(built.speed, hand.speed, accuracy: 1e-9, "vitesse de \(name)")
            XCTAssertEqual(built.phase.truncatingRemainder(dividingBy: 360),
                           hand.phase.truncatingRemainder(dividingBy: 360),
                           accuracy: 1e-9, "décalage de phase de \(name)")
            XCTAssertEqual(built.nodal.m2, hand.nodal.m2, accuracy: 1e-9, "exposant nodal M2 de \(name)")
            XCTAssertEqual(built.nodal.k1, hand.nodal.k1, accuracy: 1e-9, "exposant nodal K1 de \(name)")
        }
    }
}
