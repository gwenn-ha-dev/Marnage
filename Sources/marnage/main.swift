import Foundation
import MarnageKit

// CLI sans dépendance : parsing d'arguments à la main.

func usage() -> Never {
    print("""
    maree — prédiction de marées à partir des observations REFMAR (Licence Ouverte 2.0, Shom)

    Commandes :
      maree analyse <dossier-data> --station <nom> --id <refmarId> -o <constantes.json>
                    [--debut AAAA-MM-JJ] [--fin AAAA-MM-JJ] [--jeu standard|etendu]
          Analyse harmonique par moindres carrés sur les observations.
          --jeu etendu ajoute 10 constituants d'eaux peu profondes, utiles là
          où l'onde de marée est fortement déformée (Manche Est, Saint-Malo).

      maree valide <constantes.json> <dossier-data> [--debut AAAA-MM-JJ] [--fin AAAA-MM-JJ]
          Compare les prédictions aux observations (période idéalement hors fit).

      maree jour --constantes <fichier.json> [--brest <brest.json>] [--date AAAA-MM-JJ] [--jours N]
          PM/BM (heure locale Europe/Paris), hauteurs et coefficients.
          --brest est requis pour tout port autre que Brest : le coefficient est
          défini au port de Brest. Sans lui, les coefficients sont omis.
    """)
    exit(1)
}

/// Sortie en erreur avec un message lisible, jamais une trace de crash Swift :
/// un chemin fautif est une faute d'usage, pas un bug du programme.
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("maree : " + message + "\n").utf8))
    exit(1)
}

func loadConstants(_ path: String) -> StationConstants {
    do {
        return try StationConstants.load(from: URL(fileURLWithPath: path))
    } catch {
        fail("constantes illisibles (\(path)) : \(error.localizedDescription)")
    }
}

func readObservations(_ path: String, from: Date?, to: Date?) -> [Observation] {
    do {
        let obs = try RefmarReader.read(directory: URL(fileURLWithPath: path), from: from, to: to)
        guard !obs.isEmpty else { fail("aucune observation dans la période demandée (\(path))") }
        return obs
    } catch {
        fail("observations illisibles (\(path)) : \(error.localizedDescription)")
    }
}

/// Un prédicteur amputé prédirait une marée fausse sans rien dire.
func check(_ p: TidePredictor) -> TidePredictor {
    guard p.unknownConstituents.isEmpty else {
        let names = p.unknownConstituents.joined(separator: ", ")
        fail("constituants inconnus dans \(p.station.station) : \(names).\n"
             + "Ces constantes viennent d'un jeu plus riche que celui de ce binaire :\n"
             + "la prédiction serait fausse. Mettre à jour `maree`.")
    }
    return p
}

func parseDay(_ s: String) -> Date? {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    fmt.timeZone = TimeZone(identifier: "UTC")
    fmt.locale = Locale(identifier: "en_US_POSIX")
    return fmt.date(from: s)
}

var args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else { usage() }
args.removeFirst()

var options: [String: String] = [:]
var positional: [String] = []
var i = 0
while i < args.count {
    if args[i].hasPrefix("--") || args[i] == "-o" {
        let key = args[i]
        guard i + 1 < args.count else { usage() }
        options[key] = args[i + 1]
        i += 2
    } else {
        positional.append(args[i])
        i += 1
    }
}

switch command {
case "analyse":
    guard positional.count == 1,
          let station = options["--station"],
          let idStr = options["--id"], let refmarId = Int(idStr),
          let outPath = options["-o"] else { usage() }
    let from = options["--debut"].flatMap(parseDay)
    let to = options["--fin"].flatMap(parseDay)
    let constituents: [Constituent]
    switch options["--jeu"] ?? "standard" {
    case "standard": constituents = standardConstituents
    case "etendu", "étendu": constituents = extendedConstituents
    default: usage()
    }
    let obs = readObservations(positional[0], from: from, to: to)
    print("observations : \(obs.count) points — \(constituents.count) constituants")
    let result: StationConstants
    do {
        result = try HarmonicAnalysis.fit(observations: obs, constituents: constituents,
                                          station: station, refmarId: refmarId)
    } catch let e as AnalysisError {
        fail("analyse impossible : \(e)")
    }
    do {
        try result.save(to: URL(fileURLWithPath: outPath))
    } catch {
        fail("écriture impossible (\(outPath)) : \(error.localizedDescription)")
    }
    print("Z0 = \(String(format: "%.3f", result.meanLevel)) m — résidu RMS du fit = \(String(format: "%.1f", result.residualRMS * 100)) cm")
    let top = result.constants.sorted { $0.amplitude > $1.amplitude }.prefix(8)
    for c in top {
        print(String(format: "  %-5@ H = %6.3f m   g = %7.2f°", c.name as NSString, c.amplitude, c.phaseLag))
    }
    print("constantes écrites dans \(outPath)")

case "valide":
    guard positional.count == 2 else { usage() }
    let constants = loadConstants(positional[0])
    let from = options["--debut"].flatMap(parseDay)
    let to = options["--fin"].flatMap(parseDay)
    let obs = readObservations(positional[1], from: from, to: to)
    let predictor = check(TidePredictor(constants))
    var ss = 0.0, sum = 0.0
    var maxAbs = 0.0
    for o in obs {
        let r = o.height - predictor.height(at: o.time)
        ss += r * r; sum += r
        maxAbs = max(maxAbs, abs(r))
    }
    let n = Double(obs.count)
    let bias = sum / n
    let rms = (ss / n).squareRoot()
    print("validation sur \(obs.count) points (\(positional[1]))")
    print(String(format: "  biais   = %+.1f cm", bias * 100))
    print(String(format: "  RMS     = %.1f cm  (inclut la surcote météo réelle)", rms * 100))
    print(String(format: "  |max|   = %.1f cm", maxAbs * 100))

case "jour":
    guard let constPath = options["--constantes"] else { usage() }
    let constants = loadConstants(constPath)
    let predictor = check(TidePredictor(constants))
    // Le coefficient est défini au port de Brest : sans référence de Brest, on
    // ne l'invente pas — on l'omet en le disant.
    let coefCalc: CoefficientCalculator?
    if let brestPath = options["--brest"] {
        coefCalc = CoefficientCalculator(
            brest: check(TidePredictor(loadConstants(brestPath))))
    } else if constants.refmarId == 3 || constants.station.lowercased() == "brest" {
        coefCalc = CoefficientCalculator(brest: predictor)
    } else {
        coefCalc = nil
        FileHandle.standardError.write(Data("""
        \(constants.station) n'est pas Brest : coefficients omis.
        Le coefficient de marée est défini au port de Brest — le calculer ici \
        donnerait une valeur fausse. Ajouter --brest <brest.json> pour l'afficher.

        """.utf8))
    }

    let paris = TimeZone(identifier: "Europe/Paris")!
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = paris
    let baseDay: Date
    if let d = options["--date"] {
        guard let parsed = parseDay(d) else { usage() }
        // interprète la date comme un jour local
        var comps = Calendar(identifier: .gregorian).dateComponents(in: TimeZone(identifier: "UTC")!, from: parsed)
        comps.timeZone = paris
        baseDay = cal.date(from: DateComponents(timeZone: paris, year: comps.year, month: comps.month, day: comps.day))!
    } else {
        baseDay = cal.startOfDay(for: Date())
    }
    let days = Int(options["--jours"] ?? "1") ?? 1

    let timeFmt = DateFormatter()
    timeFmt.dateFormat = "HH:mm"
    timeFmt.timeZone = paris
    let dayFmt = DateFormatter()
    dayFmt.dateFormat = "EEEE d MMMM yyyy"
    dayFmt.timeZone = paris
    dayFmt.locale = Locale(identifier: "fr_FR")

    for d in 0..<days {
        let start = cal.date(byAdding: .day, value: d, to: baseDay)!
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        print("\n\(constants.station) — \(dayFmt.string(from: start)) (heure de Paris)")
        for ev in predictor.extrema(from: start, to: end) {
            var line = String(format: "  %@ %@  %5.2f m", ev.kind.rawValue, timeFmt.string(from: ev.time), ev.height)
            if ev.kind == .high, let coefCalc {
                line += String(format: "   coef %3d", coefCalc.coefficient(nearHighTide: ev.time))
            }
            print(line)
        }
    }

default:
    usage()
}
