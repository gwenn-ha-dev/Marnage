import Foundation

/// Échecs possibles de l'analyse. Une bibliothèque ne doit pas tuer le
/// processus de son appelant : ces cas remontent au lieu d'être des
/// `precondition`.
public enum AnalysisError: Error, CustomStringConvertible {
    case noObservations
    case notSeparable(constituent: String)

    public var description: String {
        switch self {
        case .noObservations:
            return "aucune observation dans la période demandée : rien à ajuster"
        case .notSeparable(let name):
            return "matrice normale non définie positive à hauteur de \(name) : ce "
                + "constituant n'est pas séparable des autres sur cette période "
                + "(période trop courte, ou observations trop lacunaires)"
        }
    }
}

/// Analyse harmonique par moindres carrés.
///
/// Modèle linéaire : h(t) = Z0 + Σᵢ fᵢ(t)·[Aᵢ·cos(Vᵢ+uᵢ)(t) + Bᵢ·sin(Vᵢ+uᵢ)(t)]
/// avec Aᵢ = Hᵢ·cos gᵢ, Bᵢ = Hᵢ·sin gᵢ. Les équations normales (matrice
/// (2n+1)×(2n+1), n ≈ 33) sont accumulées en streaming puis résolues par
/// Cholesky — aucune dépendance, pas même LAPACK.
public enum HarmonicAnalysis {

    /// Échec interne du solveur : indice de la ligne fautive dans la matrice
    /// normale, traduit en nom de constituant par `fit`.
    enum SolverError: Error { case notPositiveDefinite(index: Int) }

    public static func fit(
        observations: [Observation],
        constituents: [Constituent] = standardConstituents,
        station: String,
        refmarId: Int
    ) throws -> StationConstants {
        guard !observations.isEmpty else { throw AnalysisError.noObservations }
        let n = constituents.count
        let m = 2 * n + 1
        var g = [Double](repeating: 0, count: m * m)   // MᵀM
        var b = [Double](repeating: 0, count: m)        // Mᵀy
        var row = [Double](repeating: 0, count: m)

        for obs in observations {
            let a = AstroState(date: obs.time)
            let e = ElementaryNodal(a)
            row[0] = 1
            for (i, c) in constituents.enumerated() {
                let (f, vu) = c.vu(a, e)
                let phi = deg2rad(vu)
                row[1 + 2 * i] = f * cos(phi)
                row[2 + 2 * i] = f * sin(phi)
            }
            for i in 0..<m {
                let ri = row[i]
                b[i] += ri * obs.height
                for j in i..<m {
                    g[i * m + j] += ri * row[j]
                }
            }
        }
        for i in 0..<m {
            for j in 0..<i { g[i * m + j] = g[j * m + i] }
        }

        let x: [Double]
        do {
            x = try choleskySolve(g, b, m)
        } catch SolverError.notPositiveDefinite(let i) {
            throw AnalysisError.notSeparable(
                constituent: i == 0 ? "Z0 (niveau moyen)" : constituents[(i - 1) / 2].name)
        }

        // Résidu RMS du fit
        var ss = 0.0
        for obs in observations {
            let a = AstroState(date: obs.time)
            let e = ElementaryNodal(a)
            var h = x[0]
            for (i, c) in constituents.enumerated() {
                let (f, vu) = c.vu(a, e)
                let phi = deg2rad(vu)
                h += f * (x[1 + 2 * i] * cos(phi) + x[2 + 2 * i] * sin(phi))
            }
            let r = obs.height - h
            ss += r * r
        }
        let rms = (ss / Double(observations.count)).squareRoot()

        let iso = ISO8601DateFormatter()
        var constants: [HarmonicConstant] = []
        for (i, c) in constituents.enumerated() {
            let A = x[1 + 2 * i], B = x[2 + 2 * i]
            let amp = (A * A + B * B).squareRoot()
            var lag = atan2(B, A) * 180.0 / .pi
            if lag < 0 { lag += 360 }
            constants.append(HarmonicConstant(name: c.name, amplitude: amp, phaseLag: lag))
        }

        return StationConstants(
            station: station,
            refmarId: refmarId,
            meanLevel: x[0],
            fitStart: observations.first.map { iso.string(from: $0.time) } ?? "",
            fitEnd: observations.last.map { iso.string(from: $0.time) } ?? "",
            samples: observations.count,
            residualRMS: rms,
            constants: constants
        )
    }

    /// Résolution de G·x = b, G symétrique définie positive, par Cholesky.
    static func choleskySolve(_ g: [Double], _ b: [Double], _ m: Int) throws -> [Double] {
        var l = [Double](repeating: 0, count: m * m)
        for i in 0..<m {
            for j in 0...i {
                var s = g[i * m + j]
                for k in 0..<j { s -= l[i * m + k] * l[j * m + k] }
                if i == j {
                    guard s > 0 else { throw SolverError.notPositiveDefinite(index: i) }
                    l[i * m + i] = s.squareRoot()
                } else {
                    l[i * m + j] = s / l[j * m + j]
                }
            }
        }
        // L·y = b
        var y = [Double](repeating: 0, count: m)
        for i in 0..<m {
            var s = b[i]
            for k in 0..<i { s -= l[i * m + k] * y[k] }
            y[i] = s / l[i * m + i]
        }
        // Lᵀ·x = y
        var x = [Double](repeating: 0, count: m)
        for i in stride(from: m - 1, through: 0, by: -1) {
            var s = y[i]
            for k in (i + 1)..<m { s -= l[k * m + i] * x[k] }
            x[i] = s / l[i * m + i]
        }
        return x
    }
}
