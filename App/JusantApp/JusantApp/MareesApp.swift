import SwiftUI
import JusantKit

@main
struct JusantApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: 540, height: 640)
    }
}

// MARK: - Vue principale

struct ContentView: View {
    @AppStorage("station.slug") private var stationSlug = "brest"
    @State private var dayOffset = 0
    @State private var curve: TideCurveData?

    private var station: TideStation { TideModel.station(slug: stationSlug) }

    private var selectedDay: Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: Date()))!
    }

    var body: some View {
        TimelineView(.everyMinute) { context in
            VStack(spacing: 12) {
                Header(station: station, stationSlug: $stationSlug,
                       day: selectedDay, events: curve?.events ?? [], now: context.date)
                DayStrip(selected: $dayOffset)
                if let curve {
                    TideCurveView(data: curve, now: context.date)
                        .frame(maxHeight: .infinity)
                    EventStrip(events: curve.events, now: context.date)
                }
            }
            .padding(16)
        }
        .frame(minWidth: 440, minHeight: 480)
        .background {
            // Flèches ← → pour naviguer entre les jours
            Group {
                Button("") { dayOffset = max(0, dayOffset - 1) }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("") { dayOffset = min(6, dayOffset + 1) }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Button("") { dayOffset = 0 }
                    .keyboardShortcut("t", modifiers: [])
            }
            .opacity(0)
            .accessibilityHidden(true)
        }
        .task(id: "\(stationSlug)#\(dayOffset)") {
            curve = TideCurveData(station: station, day: selectedDay)
        }
        .navigationTitle(station.name)
    }
}

// MARK: - En-tête

private struct Header: View {
    let station: TideStation
    @Binding var stationSlug: String
    let day: Date
    let events: [TideEvent]
    let now: Date

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Menu {
                    ForEach(TideModel.stations) { s in
                        Button {
                            stationSlug = s.slug
                        } label: {
                            if s == station {
                                Label(s.name, systemImage: "checkmark")
                            } else {
                                Text(s.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(station.name)
                            .font(.system(.title, design: .rounded).weight(.bold))
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                HStack(spacing: 8) {
                    // Majuscule initiale seulement : « Jeudi 20 août », pas « Jeudi 20 Août ».
                    let label = Self.longDay.string(from: day)
                    Text(label.prefix(1).uppercased() + label.dropFirst())
                        .foregroundStyle(.secondary)
                    if let c = events.compactMap(\.coefficient).max() {
                        Text("coef \(c)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                            .help("Coefficient de marée du jour (max)")
                    }
                }
            }
            Spacer()
            if Calendar.current.isDate(day, inSameDayAs: now),
               let next = TideModel.nextEvent(for: station, after: now) {
                NextEventBadge(event: next, now: now)
            }
        }
    }

    static let longDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        return f
    }()
}

private struct NextEventBadge: View {
    let event: TideEvent
    let now: Date

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            HStack(spacing: 5) {
                Image(systemName: event.kind == .high ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .foregroundStyle(event.kind == .high ? .blue : .teal)
                Text(event.kind == .high ? "Pleine mer" : "Basse mer")
                    .font(.callout.weight(.medium))
            }
            Text(TideModel.timeString(event.time))
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .monospacedDigit()
            Text("\(countdown(to: event.time)) · \(TideModel.heightString(event.height))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func countdown(to d: Date) -> String {
        let m = max(0, Int(d.timeIntervalSince(now) / 60))
        return m < 60 ? "dans \(m) min" : "dans \(m / 60) h \(String(format: "%02d", m % 60))"
    }
}

// MARK: - Sélecteur de jour

private struct DayStrip: View {
    @Binding var selected: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { d in
                let day = Calendar.current.date(byAdding: .day, value: d,
                                                to: Calendar.current.startOfDay(for: Date()))!
                Button {
                    selected = d
                } label: {
                    VStack(spacing: 1) {
                        Text(Self.weekday.string(from: day).uppercased())
                            .font(.caption2.weight(.semibold))
                        Text(Self.dayNum.string(from: day))
                            .font(.callout.weight(.semibold))
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(selected == d ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .foregroundStyle(selected == d ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    static let weekday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE"
        return f
    }()
    static let dayNum: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
}

// MARK: - Bandeau des marées du jour

private struct EventStrip: View {
    let events: [TideEvent]
    let now: Date

    var body: some View {
        HStack(spacing: 0) {
            ForEach(events, id: \.time) { ev in
                VStack(spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: ev.kind == .high ? "arrow.up" : "arrow.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ev.kind == .high ? .blue : .teal)
                        Text(ev.kind == .high ? "PM" : "BM")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(TideModel.timeString(ev.time))
                        .font(.system(.title3, design: .rounded).weight(ev.time > now ? .semibold : .regular))
                        .foregroundStyle(ev.time > now ? .primary : .secondary)
                        .monospacedDigit()
                    Text(TideModel.heightString(ev.height))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    if let c = ev.coefficient {
                        Text("\(c)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                            .help("Coefficient de marée")
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
