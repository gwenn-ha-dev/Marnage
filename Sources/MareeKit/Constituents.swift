import Foundation

/// Corrections nodales élémentaires (Schureman), fonctions du nœud lunaire N.
/// f = facteur d'amplitude, u = correction de phase en degrés.
struct ElementaryNodal {
    let fM2, fK1, fO1, fK2, fJ1, fOO1, fMf, fMm: Double
    let uM2, uK1, uO1, uK2, uJ1, uOO1, uMf: Double

    init(_ a: AstroState) {
        let n = deg2rad(a.n)
        let c1 = cos(n), c2 = cos(2 * n), c3 = cos(3 * n)
        let s1 = sin(n), s2 = sin(2 * n), s3 = sin(3 * n)
        fM2 = 1.0004 - 0.0373 * c1 + 0.0002 * c2
        uM2 = -2.14 * s1
        fK1 = 1.0060 + 0.1150 * c1 - 0.0088 * c2 + 0.0006 * c3
        uK1 = -8.86 * s1 + 0.68 * s2 - 0.07 * s3
        fO1 = 1.0089 + 0.1871 * c1 - 0.0147 * c2 + 0.0014 * c3
        uO1 = 10.80 * s1 - 1.34 * s2 + 0.19 * s3
        fK2 = 1.0241 + 0.2863 * c1 + 0.0083 * c2 - 0.0015 * c3
        uK2 = -17.74 * s1 + 0.68 * s2 - 0.04 * s3
        fJ1 = 1.0129 + 0.1676 * c1 - 0.0170 * c2 + 0.0016 * c3
        uJ1 = -12.94 * s1 + 1.34 * s2 - 0.19 * s3
        fOO1 = 1.1027 + 0.6504 * c1 + 0.0317 * c2 - 0.0014 * c3
        uOO1 = -36.11 * s1 + 4.92 * s2 - 0.76 * s3
        fMf = 1.0429 + 0.4135 * c1 - 0.0040 * c2
        uMf = -23.74 * s1 + 2.68 * s2 - 0.38 * s3
        fMm = 1.0000 - 0.1300 * c1 + 0.0013 * c2
    }
}

/// Exposants (signés) sur les corrections élémentaires. Le facteur f d'un
/// composé est le produit des f élémentaires (exposants en valeur absolue),
/// la phase u est la somme signée.
public struct NodalExponents {
    var m2 = 0.0, k1 = 0.0, o1 = 0.0, k2 = 0.0, j1 = 0.0, oo1 = 0.0, mf = 0.0, mm = 0.0
}

public struct Constituent {
    public let name: String
    /// Coefficients entiers sur (τ, s, h, p, N, p1).
    public let d: [Double]
    /// Décalage de phase constant en degrés (multiples de 90°).
    public let phase: Double
    let nodal: NodalExponents

    /// Vitesse angulaire en degrés/heure.
    public var speed: Double {
        let rates = [14.4920521, 0.5490165, 0.0410686, 0.0046418, -0.00220641, 0.00000196]
        return zip(d, rates).map(*).reduce(0, +)
    }

    /// Espèce : 0 = longue période, 1 = diurne, 2 = semi-diurne, etc.
    public var species: Int { Int(d[0]) }

    func argument(_ a: AstroState) -> Double {
        var v = d[0] * a.tau
        v += d[1] * a.s
        v += d[2] * a.h
        v += d[3] * a.p
        v += d[4] * a.n
        v += d[5] * a.p1
        return v + phase
    }

    func nodalCorrection(_ e: ElementaryNodal) -> (f: Double, u: Double) {
        var f = 1.0, u = 0.0
        let terms: [(Double, Double, Double)] = [
            (nodal.m2, e.fM2, e.uM2), (nodal.k1, e.fK1, e.uK1),
            (nodal.o1, e.fO1, e.uO1), (nodal.k2, e.fK2, e.uK2),
            (nodal.j1, e.fJ1, e.uJ1), (nodal.oo1, e.fOO1, e.uOO1),
            (nodal.mf, e.fMf, e.uMf), (nodal.mm, e.fMm, 0.0),
        ]
        for (exp, fe, ue) in terms where exp != 0 {
            f *= pow(fe, abs(exp))
            u += exp * ue
        }
        return (f, u)
    }

    /// Phase totale V + u en degrés, et facteur f, à un instant donné.
    func vu(_ a: AstroState, _ e: ElementaryNodal) -> (f: Double, vu: Double) {
        let (f, u) = nodalCorrection(e)
        return (f, argument(a) + u)
    }
}

extension NodalExponents {
    static func + (a: NodalExponents, b: NodalExponents) -> NodalExponents {
        NodalExponents(m2: a.m2 + b.m2, k1: a.k1 + b.k1, o1: a.o1 + b.o1, k2: a.k2 + b.k2,
                       j1: a.j1 + b.j1, oo1: a.oo1 + b.oo1, mf: a.mf + b.mf, mm: a.mm + b.mm)
    }
    static func * (k: Double, e: NodalExponents) -> NodalExponents {
        NodalExponents(m2: k * e.m2, k1: k * e.k1, o1: k * e.o1, k2: k * e.k2,
                       j1: k * e.j1, oo1: k * e.oo1, mf: k * e.mf, mm: k * e.mm)
    }
}

extension Constituent {
    /// Constituant composé, engendré par les non-linéarités de petit fond :
    /// combinaison linéaire entière d'ondes astronomiques. Arguments de
    /// Doodson, décalages de phase et exposants nodaux s'additionnent avec les
    /// mêmes coefficients — c'est la règle qui produit déjà MS4 (M2+S2),
    /// MK3 (M2+K1) ou 2MK3 (2M2−K1) dans la table standard, ici appliquée par
    /// le code plutôt que recopiée à la main.
    ///
    /// Limite du schéma : les corrections nodales élémentaires se composent
    /// correctement tant qu'une même onde n'apparaît pas avec des signes
    /// opposés (le facteur f serait alors un produit, la phase u une
    /// différence — que le couple (exposant signé, |exposant|) ne peut pas
    /// représenter). Aucun des composés ci-dessous n'est dans ce cas.
    static func compound(_ name: String, _ terms: [(Double, String)]) -> Constituent {
        let byName = Dictionary(uniqueKeysWithValues: standardConstituents.map { ($0.name, $0) })
        var d = [Double](repeating: 0, count: 6)
        var phase = 0.0
        var nodal = NodalExponents()
        for (k, componentName) in terms {
            guard let c = byName[componentName] else {
                preconditionFailure("composant inconnu : \(componentName)")
            }
            for i in 0..<6 { d[i] += k * c.d[i] }
            phase += k * c.phase
            nodal = nodal + k * c.nodal
        }
        return Constituent(name: name, d: d, phase: phase, nodal: nodal)
    }
}

/// Constituants d'eaux peu profondes supplémentaires, engendrés par la
/// déformation de l'onde sur les petits fonds. Inutiles à Brest, ils portent
/// une part réelle du signal là où la marée est fortement déformée (Manche
/// Est, Saint-Malo) — voir `maree analyse --jeu etendu`.
///
/// Deux composés classiques manquent volontairement à cette liste : `2MS2`
/// (2M2−S2) et `MO3` (M2+O1), dont les vitesses coïncident exactement avec
/// celles de `mu2` et de `2MK3` déjà présents — les ajouter rendrait les
/// équations normales singulières. `ConstituentTests.testSeparability` monte
/// la garde sur ce point.
public let shallowWaterConstituents: [Constituent] = [
    .compound("2SM2", [(2, "S2"), (-1, "M2")]),
    .compound("SO3",  [(1, "S2"), (1, "O1")]),
    .compound("SK3",  [(1, "S2"), (1, "K1")]),
    .compound("3MS4", [(3, "M2"), (-1, "S2")]),
    .compound("SN4",  [(1, "S2"), (1, "N2")]),
    .compound("S4",   [(2, "S2")]),
    .compound("MSN6", [(1, "M2"), (1, "S2"), (1, "N2")]),
    .compound("2SM6", [(2, "S2"), (1, "M2")]),
    .compound("3MS8", [(3, "M2"), (1, "S2")]),
    .compound("M10",  [(5, "M2")]),
]

/// Jeu standard + eaux peu profondes (43 constituants).
public let extendedConstituents: [Constituent] = standardConstituents + shallowWaterConstituents

/// Jeu standard de 33 constituants, suffisant pour un port semi-diurne
/// atlantique au niveau centimétrique. L2 utilise la correction nodale de M2
/// (approximation documentée de la formule exacte de Schureman).
public let standardConstituents: [Constituent] = [
    // Longues périodes
    .init(name: "Sa",   d: [0, 0, 1, 0, 0, 0],  phase: 0,   nodal: .init()),
    .init(name: "Ssa",  d: [0, 0, 2, 0, 0, 0],  phase: 0,   nodal: .init()),
    .init(name: "Mm",   d: [0, 1, 0, -1, 0, 0], phase: 0,   nodal: .init(mm: 1)),
    .init(name: "Mf",   d: [0, 2, 0, 0, 0, 0],  phase: 0,   nodal: .init(mf: 1)),
    .init(name: "MSf",  d: [0, 2, -2, 0, 0, 0], phase: 0,   nodal: .init(m2: -1)),
    // Diurnes
    .init(name: "2Q1",  d: [1, -3, 0, 2, 0, 0], phase: 90,  nodal: .init(o1: 1)),
    .init(name: "Q1",   d: [1, -2, 0, 1, 0, 0], phase: 90,  nodal: .init(o1: 1)),
    .init(name: "rho1", d: [1, -2, 2, -1, 0, 0], phase: 90, nodal: .init(o1: 1)),
    .init(name: "O1",   d: [1, -1, 0, 0, 0, 0], phase: 90,  nodal: .init(o1: 1)),
    .init(name: "P1",   d: [1, 1, -2, 0, 0, 0], phase: 90,  nodal: .init()),
    .init(name: "K1",   d: [1, 1, 0, 0, 0, 0],  phase: -90, nodal: .init(k1: 1)),
    .init(name: "J1",   d: [1, 2, 0, -1, 0, 0], phase: -90, nodal: .init(j1: 1)),
    .init(name: "OO1",  d: [1, 3, 0, 0, 0, 0],  phase: -90, nodal: .init(oo1: 1)),
    // Semi-diurnes
    .init(name: "2N2",  d: [2, -2, 0, 2, 0, 0], phase: 0,   nodal: .init(m2: 1)),
    .init(name: "mu2",  d: [2, -2, 2, 0, 0, 0], phase: 0,   nodal: .init(m2: 1)),
    .init(name: "N2",   d: [2, -1, 0, 1, 0, 0], phase: 0,   nodal: .init(m2: 1)),
    .init(name: "nu2",  d: [2, -1, 2, -1, 0, 0], phase: 0,  nodal: .init(m2: 1)),
    .init(name: "M2",   d: [2, 0, 0, 0, 0, 0],  phase: 0,   nodal: .init(m2: 1)),
    .init(name: "lda2", d: [2, 1, -2, 1, 0, 0], phase: 180, nodal: .init(m2: 1)),
    .init(name: "L2",   d: [2, 1, 0, -1, 0, 0], phase: 180, nodal: .init(m2: 1)),
    .init(name: "T2",   d: [2, 2, -3, 0, 0, 1], phase: 0,   nodal: .init()),
    .init(name: "S2",   d: [2, 2, -2, 0, 0, 0], phase: 0,   nodal: .init()),
    .init(name: "K2",   d: [2, 2, 0, 0, 0, 0],  phase: 0,   nodal: .init(k2: 1)),
    // Tiers-diurnes et eaux peu profondes
    .init(name: "MK3",  d: [3, 1, 0, 0, 0, 0],  phase: -90, nodal: .init(m2: 1, k1: 1)),
    .init(name: "2MK3", d: [3, -1, 0, 0, 0, 0], phase: 90,  nodal: .init(m2: 2, k1: -1)),
    .init(name: "M4",   d: [4, 0, 0, 0, 0, 0],  phase: 0,   nodal: .init(m2: 2)),
    .init(name: "MN4",  d: [4, -1, 0, 1, 0, 0], phase: 0,   nodal: .init(m2: 2)),
    .init(name: "MS4",  d: [4, 2, -2, 0, 0, 0], phase: 0,   nodal: .init(m2: 1)),
    .init(name: "MK4",  d: [4, 2, 0, 0, 0, 0],  phase: 0,   nodal: .init(m2: 1, k2: 1)),
    .init(name: "M6",   d: [6, 0, 0, 0, 0, 0],  phase: 0,   nodal: .init(m2: 3)),
    .init(name: "2MN6", d: [6, -1, 0, 1, 0, 0], phase: 0,   nodal: .init(m2: 3)),
    .init(name: "2MS6", d: [6, 2, -2, 0, 0, 0], phase: 0,   nodal: .init(m2: 2)),
    .init(name: "M8",   d: [8, 0, 0, 0, 0, 0],  phase: 0,   nodal: .init(m2: 4)),
]
