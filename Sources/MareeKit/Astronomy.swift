import Foundation

/// Époque J2000 : 2000-01-01 12:00:00 UTC.
public let j2000: Date = Date(timeIntervalSince1970: 946_728_000)

/// Arguments astronomiques fondamentaux, en degrés, à un instant donné.
/// Polynômes classiques (Meeus), T en siècles juliens depuis J2000.
/// UT est assimilé à TT : l'écart (ΔT ≈ 70 s) déplace les phases de moins de
/// 0,03° sur M2, largement sous notre bruit de mesure. Les décalages d'origine
/// éventuels sont sans effet : l'analyse et la prédiction utilisent la même
/// convention, seules les vitesses (dérivées) doivent être exactes.
public struct AstroState {
    public let tau: Double  // temps lunaire moyen
    public let s: Double    // longitude moyenne de la Lune
    public let h: Double    // longitude moyenne du Soleil
    public let p: Double    // longitude du périgée lunaire
    public let n: Double    // longitude du nœud ascendant lunaire
    public let p1: Double   // longitude du périhélie

    public init(date: Date) {
        let d = date.timeIntervalSince(j2000) / 86_400.0
        let t = d / 36_525.0
        s  = 218.3164477 + 481_267.88123421 * t
        h  = 280.4664567 + 36_000.7697489 * t
        p  = 83.3532465 + 4_069.0137287 * t
        n  = 125.0445479 - 1_934.1362891 * t
        p1 = 282.9373 + 1.719457 * t
        tau = 180.0 + 360.0 * d + h - s
    }
}

@inlinable public func deg2rad(_ x: Double) -> Double { x * .pi / 180.0 }
