import WidgetKit
import SwiftUI
import AppIntents
import MareeKit

@main
struct MareesWidgetBundle: WidgetBundle {
    var body: some Widget {
        MareesWidget()
    }
}

// MARK: - Configuration par widget (choix du port)

struct StationEntity: AppEntity {
    let id: String      // slug de la station
    let name: String

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Port"
    static let defaultQuery = StationQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(station: TideStation) {
        id = station.slug
        name = station.name
    }
}

struct StationQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [StationEntity] {
        identifiers.map { StationEntity(station: TideModel.station(slug: $0)) }
    }

    func suggestedEntities() async throws -> [StationEntity] {
        TideModel.stations.map(StationEntity.init)
    }

    func defaultResult() async -> StationEntity? {
        StationEntity(station: TideModel.brest)
    }
}

struct SelectStationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Port"
    static let description = IntentDescription("Choisir le port affiché par ce widget.")

    @Parameter(title: "Port")
    var station: StationEntity?
}

// MARK: - Timeline

struct TideTimelineEntry: TimelineEntry {
    let date: Date
    let station: TideStation
    let next: TideEvent?
    let todays: [TideEvent]
}

struct TideProvider: AppIntentTimelineProvider {
    private func station(for configuration: SelectStationIntent) -> TideStation {
        configuration.station.map { TideModel.station(slug: $0.id) } ?? TideModel.brest
    }

    private func makeEntry(at date: Date, for station: TideStation) -> TideTimelineEntry {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let end = cal.date(byAdding: .day, value: 1, to: start)!
        return TideTimelineEntry(
            date: date,
            station: station,
            next: TideModel.nextEvent(for: station, after: date),
            todays: TideModel.events(for: station, from: start, to: end)
        )
    }

    func placeholder(in context: Context) -> TideTimelineEntry {
        makeEntry(at: Date(), for: TideModel.brest)
    }

    func snapshot(for configuration: SelectStationIntent, in context: Context) async -> TideTimelineEntry {
        makeEntry(at: Date(), for: station(for: configuration))
    }

    func timeline(for configuration: SelectStationIntent, in context: Context) async -> Timeline<TideTimelineEntry> {
        // Tout est calculé en local : on fournit 24 h d'entrées au pas de 15 min,
        // puis WidgetKit redemande une timeline.
        let now = Date()
        let st = station(for: configuration)
        let entries = (0..<96).map { makeEntry(at: now.addingTimeInterval(Double($0) * 900), for: st) }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

struct MareesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "MareesWidget", intent: SelectStationIntent.self,
                               provider: TideProvider()) { entry in
            MareesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Marées")
        // Text(verbatim:) : un literal interpolé passerait par l'overload
        // LocalizedStringKey de .description, qui asserte dans WidgetKit et
        // tue l'extension à la découverte des widgets.
        .description(Text(verbatim: "Courbe de marée, pleines et basses mers, coefficient."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MareesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TideTimelineEntry

    var body: some View {
        let curve = TideCurveData(station: entry.station,
                                  day: Calendar.current.startOfDay(for: entry.date))
        switch family {
        case .systemMedium: MediumTideView(curve: curve, entry: entry)
        default: SmallTideView(curve: curve, entry: entry)
        }
    }
}

/// Small : la prochaine marée en héros, mini-courbe du jour en pied.
private struct SmallTideView: View {
    let curve: TideCurveData
    let entry: TideTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.station.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if let c = entry.todays.compactMap(\.coefficient).max() {
                    Text("\(c)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 5)
                        .background(.quaternary, in: Capsule())
                }
            }
            if let next = entry.next {
                HStack(spacing: 4) {
                    Image(systemName: next.kind == .high ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundStyle(next.kind == .high ? .blue : .teal)
                        .font(.caption)
                    Text(next.kind == .high ? "Pleine mer" : "Basse mer")
                        .font(.caption.weight(.medium))
                }
                .padding(.top, 3)
                Text(TideModel.timeString(next.time))
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Text(TideModel.heightString(next.height))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                Text("—")
            }
            Spacer(minLength: 2)
            TideCurveView(data: curve, now: entry.date, compact: true, showsEventLabels: false)
                .frame(height: 30)
        }
    }
}

/// Medium : la courbe du jour annotée, PM/BM et « maintenant » lisibles d'un coup d'œil.
private struct MediumTideView: View {
    let curve: TideCurveData
    let entry: TideTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.station.name)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                if let c = entry.todays.compactMap(\.coefficient).max() {
                    Text("coef \(c)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let next = entry.next {
                    HStack(spacing: 3) {
                        Image(systemName: next.kind == .high ? "arrow.up" : "arrow.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(next.kind == .high ? .blue : .teal)
                        Text(TideModel.timeString(next.time))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            }
            TideCurveView(data: curve, now: entry.date, compact: true)
        }
    }
}
