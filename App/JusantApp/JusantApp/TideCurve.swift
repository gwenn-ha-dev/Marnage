import SwiftUI
import JusantKit

// MARK: - Données de tracé

/// Une journée échantillonnée pour le tracé : hauteurs à pas constant,
/// extrema du jour, domaine vertical stable (comparable d'un jour à l'autre).
struct TideCurveData {
    let station: TideStation
    let dayStart: Date
    let dayEnd: Date
    let step: TimeInterval
    let samples: [Double]
    let events: [TideEvent]
    let heightRange: ClosedRange<Double>

    init(station: TideStation, day: Date, step: TimeInterval = 300) {
        self.station = station
        dayStart = day
        dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        self.step = step
        let n = Int(dayEnd.timeIntervalSince(dayStart) / step)
        samples = (0...n).map {
            station.predictor.height(at: day.addingTimeInterval(Double($0) * step))
        }
        events = TideModel.events(for: station, from: dayStart, to: dayEnd)
        heightRange = station.heightDomain
    }

    var duration: TimeInterval { dayEnd.timeIntervalSince(dayStart) }

    func contains(_ date: Date) -> Bool { date >= dayStart && date < dayEnd }

    func date(atFraction f: Double) -> Date {
        dayStart.addingTimeInterval(f.clamped(to: 0...1) * duration)
    }
}

extension Comparable {
    func clamped(to r: ClosedRange<Self>) -> Self { min(max(self, r.lowerBound), r.upperBound) }
}

// MARK: - Palette

/// Palette marine, déclinée clair/sombre.
struct TidePalette {
    let stroke: Color
    let fillTop: Color
    let fillBottom: Color
    let grid: Color
    let marker: Color

    static func resolve(_ scheme: ColorScheme) -> TidePalette {
        scheme == .dark
            ? TidePalette(stroke: Color(red: 0.35, green: 0.78, blue: 0.98),
                          fillTop: Color(red: 0.10, green: 0.42, blue: 0.64).opacity(0.55),
                          fillBottom: Color(red: 0.03, green: 0.12, blue: 0.25).opacity(0.85),
                          grid: .white.opacity(0.08),
                          marker: Color(red: 1.0, green: 0.62, blue: 0.35))
            : TidePalette(stroke: Color(red: 0.05, green: 0.42, blue: 0.65),
                          fillTop: Color(red: 0.42, green: 0.74, blue: 0.90).opacity(0.55),
                          fillBottom: Color(red: 0.75, green: 0.89, blue: 0.96).opacity(0.9),
                          grid: .black.opacity(0.07),
                          marker: Color(red: 0.85, green: 0.42, blue: 0.10))
    }
}

// MARK: - Vue courbe

/// Courbe de marée d'une journée : remplissage façon niveau d'eau, PM/BM
/// annotées, marqueur « maintenant », lecture au survol (app uniquement).
struct TideCurveView: View {
    let data: TideCurveData
    var now: Date?
    /// Mode widget : ni axes, ni survol.
    var compact = false
    /// Heures et hauteurs des PM/BM annotées sur la courbe.
    var showsEventLabels = true

    @Environment(\.colorScheme) private var scheme
    @State private var hoverX: CGFloat?

    private var insets: EdgeInsets {
        if compact {
            return EdgeInsets(top: showsEventLabels ? 26 : 4, leading: 0,
                              bottom: showsEventLabels ? 4 : 2, trailing: 0)
        }
        return EdgeInsets(top: 34, leading: 26, bottom: 20, trailing: 10)
    }

    var body: some View {
        let palette = TidePalette.resolve(scheme)
        GeometryReader { geo in
            let plot = CGRect(x: insets.leading, y: insets.top,
                              width: geo.size.width - insets.leading - insets.trailing,
                              height: geo.size.height - insets.top - insets.bottom)
            ZStack(alignment: .topLeading) {
                canvas(plot: plot, palette: palette)
                if showsEventLabels { eventLabels(plot: plot) }
                if !compact, let hx = hoverX { hoverReadout(x: hx, plot: plot, palette: palette) }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard !compact else { return }
                switch phase {
                case .active(let pt):
                    hoverX = plot.contains(CGPoint(x: pt.x, y: plot.midY)) ? pt.x : nil
                case .ended:
                    hoverX = nil
                }
            }
        }
    }

    // MARK: dessin

    private func x(_ date: Date, _ plot: CGRect) -> CGFloat {
        plot.minX + plot.width * CGFloat(date.timeIntervalSince(data.dayStart) / data.duration)
    }

    private func y(_ h: Double, _ plot: CGRect) -> CGFloat {
        let r = data.heightRange
        let f = (h - r.lowerBound) / (r.upperBound - r.lowerBound)
        return plot.maxY - plot.height * CGFloat(f)
    }

    private func curvePath(_ plot: CGRect) -> Path {
        Path { p in
            for (i, h) in data.samples.enumerated() {
                let px = plot.minX + plot.width * CGFloat(i) / CGFloat(data.samples.count - 1)
                let pt = CGPoint(x: px, y: y(h, plot))
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
        }
    }

    private func canvas(plot: CGRect, palette: TidePalette) -> some View {
        Canvas { ctx, _ in
            // Grille et axes
            if !compact {
                let r = data.heightRange
                var h = r.lowerBound.rounded(.up)
                while h <= r.upperBound {
                    let py = y(h, plot)
                    if Int(h) % 2 == 0 {
                        ctx.stroke(Path { $0.move(to: CGPoint(x: plot.minX, y: py))
                                          $0.addLine(to: CGPoint(x: plot.maxX, y: py)) },
                                   with: .color(palette.grid), lineWidth: 1)
                        ctx.draw(Text("\(Int(h)) m").font(.caption2).foregroundStyle(.secondary),
                                 at: CGPoint(x: plot.minX - 13, y: py))
                    }
                    h += 1
                }
                for hour in stride(from: 0, through: 24, by: 6) {
                    let d = data.dayStart.addingTimeInterval(Double(hour) / 24 * data.duration)
                    let px = x(d, plot)
                    ctx.stroke(Path { $0.move(to: CGPoint(x: px, y: plot.minY))
                                      $0.addLine(to: CGPoint(x: px, y: plot.maxY)) },
                               with: .color(palette.grid), lineWidth: 1)
                    if hour < 24 {
                        ctx.draw(Text(String(format: "%02dh", hour)).font(.caption2).foregroundStyle(.secondary),
                                 at: CGPoint(x: px + (hour == 0 ? 10 : 0), y: plot.maxY + 10))
                    }
                }
            }

            // Remplissage « niveau d'eau » sous la courbe
            var fill = curvePath(plot)
            fill.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
            fill.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
            fill.closeSubpath()
            ctx.fill(fill, with: .linearGradient(
                Gradient(colors: [palette.fillTop, palette.fillBottom]),
                startPoint: CGPoint(x: plot.midX, y: plot.minY),
                endPoint: CGPoint(x: plot.midX, y: plot.maxY)))

            // Courbe
            ctx.stroke(curvePath(plot), with: .color(palette.stroke),
                       style: StrokeStyle(lineWidth: compact ? 1.8 : 2.4,
                                          lineCap: .round, lineJoin: .round))

            // Points PM/BM
            for ev in data.events {
                let pt = CGPoint(x: x(ev.time, plot), y: y(ev.height, plot))
                let d: CGFloat = compact ? 4 : 6
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - d / 2, y: pt.y - d / 2, width: d, height: d)),
                         with: .color(palette.stroke))
            }

            // Maintenant
            if let now, data.contains(now) {
                let px = x(now, plot)
                let pt = CGPoint(x: px, y: y(data.station.predictor.height(at: now), plot))
                ctx.stroke(Path { $0.move(to: CGPoint(x: px, y: pt.y))
                                  $0.addLine(to: CGPoint(x: px, y: plot.maxY)) },
                           with: .color(palette.marker.opacity(0.5)),
                           style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                let d: CGFloat = compact ? 6 : 9
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - d / 2, y: pt.y - d / 2, width: d, height: d)),
                         with: .color(palette.marker))
                ctx.stroke(Path(ellipseIn: CGRect(x: pt.x - d / 2, y: pt.y - d / 2, width: d, height: d)),
                           with: .color(.white.opacity(0.9)), lineWidth: 1.5)
            }
        }
    }

    // MARK: annotations

    private func eventLabels(plot: CGRect) -> some View {
        ForEach(data.events, id: \.time) { ev in
            let px = x(ev.time, plot).clamped(to: (plot.minX + 18)...(plot.maxX - 18))
            let py = y(ev.height, plot)
            VStack(spacing: 0) {
                Text(TideModel.timeString(ev.time))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                Text(TideModel.heightString(ev.height))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .position(x: px, y: ev.kind == .high ? py - 22 : py - 20)
        }
    }

    private func hoverReadout(x hx: CGFloat, plot: CGRect, palette: TidePalette) -> some View {
        let f = Double((hx - plot.minX) / plot.width)
        let d = data.date(atFraction: f)
        let h = data.station.predictor.height(at: d)
        return ZStack(alignment: .topLeading) {
            Path { p in
                p.move(to: CGPoint(x: hx, y: plot.minY))
                p.addLine(to: CGPoint(x: hx, y: plot.maxY))
            }
            .stroke(palette.stroke.opacity(0.35), lineWidth: 1)
            Circle()
                .fill(palette.stroke)
                .frame(width: 7, height: 7)
                .position(x: hx, y: y(h, plot))
            Text("\(TideModel.timeString(d)) · \(TideModel.heightString(h))")
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.regularMaterial, in: Capsule())
                .position(x: hx.clamped(to: (plot.minX + 55)...(plot.maxX - 55)),
                          y: plot.minY - 14)
        }
        .allowsHitTesting(false)
    }
}
