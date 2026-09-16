import XCTest
@testable import JusantKit

final class JusantKitTests: XCTestCase {
    /// Les vitesses angulaires des constituants principaux doivent correspondre
    /// aux valeurs de référence (degrés/heure, table IHO).
    func testConstituentSpeeds() {
        let expected: [String: Double] = [
            "M2": 28.9841042, "S2": 30.0000000, "N2": 28.4397295, "K2": 30.0821373,
            "K1": 15.0410686, "O1": 13.9430356, "P1": 14.9589314, "Q1": 13.3986609,
            "M4": 57.9682084, "Mf": 1.0980331, "Sa": 0.0410686,
        ]
        let byName = Dictionary(uniqueKeysWithValues: standardConstituents.map { ($0.name, $0) })
        for (name, speed) in expected {
            guard let c = byName[name] else { XCTFail("constituant \(name) absent"); continue }
            XCTAssertEqual(c.speed, speed, accuracy: 1e-4, "vitesse de \(name)")
        }
    }

    /// Une matrice normale singulière doit remonter une erreur, pas tuer le
    /// processus : `maree analyse` sur une période trop courte est une faute
    /// d'usage courante, pas un bug.
    func testCholeskyRejectsSingularSystem() {
        // Pivot nul en position 1 : G n'est pas définie positive.
        let g = [1.0, 0, 0, 0, 0, 0, 0, 0, 1]
        XCTAssertThrowsError(try HarmonicAnalysis.choleskySolve(g, [1.0, 0, 1], 3)) { error in
            guard case HarmonicAnalysis.SolverError.notPositiveDefinite(let i) = error else {
                return XCTFail("erreur inattendue : \(error)")
            }
            XCTAssertEqual(i, 1)
        }
    }

    /// Une analyse sans observation doit être refusée explicitement.
    func testFitRejectsEmptyObservations() {
        XCTAssertThrowsError(try HarmonicAnalysis.fit(observations: [], station: "Nulle part",
                                                      refmarId: 0)) { error in
            XCTAssertEqual("\(error)", "\(AnalysisError.noObservations)")
        }
    }

    /// Le solveur de Cholesky doit retrouver une solution connue.
    func testCholesky() throws {
        // G = AᵀA avec A inversible, b = G·[1, 2, 3]
        let g = [4.0, 2, 0, 2, 5, 1, 0, 1, 3]
        let b = [8.0, 15, 11]
        let x = try HarmonicAnalysis.choleskySolve(g, b, 3)
        XCTAssertEqual(x[0], 1, accuracy: 1e-10)
        XCTAssertEqual(x[1], 2, accuracy: 1e-10)
        XCTAssertEqual(x[2], 3, accuracy: 1e-10)
    }
}
