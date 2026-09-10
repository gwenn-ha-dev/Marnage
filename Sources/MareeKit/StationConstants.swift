import Foundation

/// Constante harmonique d'un constituant : amplitude H (m) et situation g (degrés),
/// dans la convention h(t) = Z0 + Σ f·H·cos(V + u − g) propre à ce moteur.
public struct HarmonicConstant: Codable {
    public let name: String
    public let amplitude: Double
    public let phaseLag: Double
}

/// Constantes harmoniques d'une station, résultat de l'analyse.
/// Les hauteurs sont rapportées au zéro hydrographique (comme les données REFMAR).
public struct StationConstants: Codable {
    public let station: String
    public let refmarId: Int
    public let meanLevel: Double          // Z0, en mètres au-dessus du zéro hydrographique
    public let fitStart: String           // période d'analyse (ISO, UTC)
    public let fitEnd: String
    public let samples: Int
    public let residualRMS: Double        // résidu du fit, en mètres
    public let constants: [HarmonicConstant]

    public func save(to url: URL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(self).write(to: url)
    }

    public static func load(from url: URL) throws -> StationConstants {
        try JSONDecoder().decode(StationConstants.self, from: Data(contentsOf: url))
    }
}

/// Une observation marégraphique : instant UTC et hauteur (m / zéro hydrographique).
public struct Observation {
    public let time: Date
    public let height: Double
}

/// Lecture des fichiers JSON REFMAR (services.data.shom.fr/maregraphie).
public enum RefmarReader {
    struct File: Decodable {
        struct Point: Decodable {
            let value: Double
            let timestamp: String
        }
        let data: [Point]
    }

    public static func read(directory: URL, from: Date? = nil, to: Date? = nil) throws -> [Observation] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy/MM/dd HH:mm:ss"
        fmt.timeZone = TimeZone(identifier: "UTC")
        fmt.locale = Locale(identifier: "en_US_POSIX")

        var out: [Observation] = []
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for url in files {
            let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
            for pt in file.data {
                guard let t = fmt.date(from: pt.timestamp) else { continue }
                if let from, t < from { continue }
                if let to, t >= to { continue }
                out.append(Observation(time: t, height: pt.value))
            }
        }
        out.sort { $0.time < $1.time }
        // Dédoublonnage (chevauchements de fichiers mensuels aux minuit de frontière)
        var dedup: [Observation] = []
        dedup.reserveCapacity(out.count)
        for o in out where dedup.last?.time != o.time {
            dedup.append(o)
        }
        return dedup
    }
}
