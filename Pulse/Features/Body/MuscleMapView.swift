import SwiftUI

/// How recovered one muscle group is, estimated from the sets logged in the last two weeks.
struct MuscleStatus: Identifiable {
    let muscle: MuscleGroup
    /// 0 = just trained, 1 = fully recovered.
    let recovery: Double
    let lastTrained: Date?
    let sets: Int
    let hoursLeft: Int
    var id: MuscleGroup { muscle }
}

enum MuscleRecovery {
    static let tracked: [MuscleGroup] = [.chest, .back, .shoulders, .biceps, .triceps, .core, .quads, .hamstrings, .glutes, .calves]

    /// Big muscles need longer to recover than small ones.
    static func baseHours(_ muscle: MuscleGroup) -> Double {
        switch muscle {
        case .chest, .back, .quads, .hamstrings, .glutes: 72
        default: 48
        }
    }

    /// A simple, transparent estimate: base hours scaled by how many sets you did last time. Not a measurement.
    static func status(from logs: [WorkoutLog], now: Date = .now) -> [MuscleGroup: MuscleStatus] {
        let cutoff = now.addingTimeInterval(-14 * 86_400)
        var result: [MuscleGroup: MuscleStatus] = [:]
        for muscle in tracked {
            var last: Date?
            var sets = 0
            for log in logs where log.date >= cutoff && log.date <= now {
                var n = 0.0
                for entry in log.entries {
                    let count = Double(entry.sets.count)
                    if entry.muscleRaw == muscle.rawValue {
                        n += count
                    } else if entry.muscleRaw == MuscleGroup.fullBody.rawValue {
                        n += count * 0.5
                    }
                }
                guard n > 0 else { continue }
                if last == nil || log.date > last! {
                    last = log.date
                    sets = Int(n.rounded(.up))
                }
            }
            guard let last else {
                result[muscle] = MuscleStatus(muscle: muscle, recovery: 1, lastTrained: nil, sets: 0, hoursLeft: 0)
                continue
            }
            let required = baseHours(muscle) * (0.75 + Double(min(sets, 8)) * 0.08)
            let elapsed = now.timeIntervalSince(last) / 3600
            result[muscle] = MuscleStatus(
                muscle: muscle,
                recovery: min(max(elapsed / required, 0), 1),
                lastTrained: last,
                sets: sets,
                hoursLeft: Int(max(required - elapsed, 0).rounded(.up))
            )
        }
        return result
    }
}

/// Front and back body figure; each muscle is coloured from red (just trained) to green (recovered).
struct MuscleMapView: View {
    let logs: [WorkoutLog]
    @State private var showBack = false
    @State private var selected: MuscleGroup?

    private var statuses: [MuscleGroup: MuscleStatus] { MuscleRecovery.status(from: logs) }

    var body: some View {
        let statuses = statuses
        VStack(alignment: .leading, spacing: 14) {
            Text("RECUPERO MUSCOLARE").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)

            Picker("Lato", selection: $showBack) {
                Text("Davanti").tag(false)
                Text("Dietro").tag(true)
            }
            .pickerStyle(.segmented)

            figure(statuses)
                .frame(maxWidth: .infinity)
                .frame(height: 470)

            legend

            detail(statuses)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(MuscleRecovery.tracked) { muscle in
                    if let s = statuses[muscle] {
                        Button { selected = muscle } label: {
                            HStack(spacing: 6) {
                                Circle().fill(Self.color(s)).frame(width: 10, height: 10)
                                Text(muscle.label).font(.caption).lineLimit(1)
                                Spacer(minLength: 0)
                                Text("\(Int(s.recovery * 100))%").font(.caption.weight(.semibold)).monospacedDigit()
                            }
                            .padding(.horizontal, 10).padding(.vertical, 8)
                            .background(selected == muscle ? Color.white.opacity(0.14) : Color.white.opacity(0.06),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Text("Stima basata sulle serie che hai registrato e su quante ore passano dall'ultimo allenamento. Non è una misura: se senti dolore o fatica, ascolta il corpo.")
                .font(.caption2).foregroundStyle(Theme.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .animation(Motion.smooth, value: showBack)
    }

    // MARK: Figure

    private func figure(_ statuses: [MuscleGroup: MuscleStatus]) -> some View {
        let zones = MuscleShapes.zones(back: showBack)
        return GeometryReader { geo in
            let s = min(geo.size.width / 100, geo.size.height / MuscleShapes.boxHeight)
            let t = CGAffineTransform(scaleX: s, y: s)
            let offsetX = (geo.size.width - 100 * s) / 2
            ZStack(alignment: .topLeading) {
                ForEach(zones) { zone in
                    let path = zone.path.applying(t)
                    let status = zone.muscle.flatMap { statuses[$0] }
                    let isSelected = zone.muscle != nil && selected == zone.muscle
                    path.fill(status.map { Self.color($0) } ?? Color.white.opacity(0.10))
                        .overlay(path.stroke(isSelected ? Color.white : Theme.background, lineWidth: isSelected ? 2.2 : 1.2)
                            .shadow(color: isSelected ? .white.opacity(0.5) : .clear, radius: 4))
                }
            }
            .offset(x: offsetX)
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    let point = CGPoint(x: (value.location.x - offsetX) / s, y: value.location.y / s)
                    selected = zones.first { $0.path.contains(point) }?.muscle
                }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Figura del corpo con il recupero di ogni muscolo. L'elenco sotto riporta gli stessi valori.")
    }

    private var legend: some View {
        VStack(spacing: 4) {
            LinearGradient(colors: (0...6).map { Self.color(recovery: Double($0) / 6) }, startPoint: .leading, endPoint: .trailing)
                .frame(height: 8).clipShape(Capsule())
            HStack {
                Text("Appena allenato").font(.caption2).foregroundStyle(Theme.secondaryText)
                Spacer()
                Text("Recuperato").font(.caption2).foregroundStyle(Theme.secondaryText)
            }
        }
    }

    @ViewBuilder
    private func detail(_ statuses: [MuscleGroup: MuscleStatus]) -> some View {
        if let muscle = selected, let s = statuses[muscle] {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(muscle.label): \(Int(s.recovery * 100))% recuperato").font(.headline)
                if let last = s.lastTrained {
                    Text("Ultimo allenamento \(last.formatted(.relative(presentation: .named))), \(s.sets) serie. "
                         + (s.hoursLeft > 0 ? "Ancora circa \(Self.remaining(hours: s.hoursLeft)) per essere pronto." : "È pronto per un nuovo allenamento."))
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                } else {
                    Text("Non lo alleni da più di due settimane: è fresco.")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }
            }
        } else {
            Text("Tocca un muscolo per vedere i dettagli.").font(.footnote).foregroundStyle(Theme.secondaryText)
        }
    }

    // MARK: Colour

    static func color(recovery: Double) -> Color {
        Color(hue: 0.33 * min(max(recovery, 0), 1), saturation: 0.85, brightness: 0.95)
    }

    static func color(_ status: MuscleStatus) -> Color {
        color(recovery: status.recovery).opacity(status.lastTrained == nil ? 0.5 : 0.9)
    }

    static func remaining(hours: Int) -> String {
        hours >= 36 ? "\(Int((Double(hours) / 24).rounded())) giorni" : "\(hours) ore"
    }
}

/// Anatomical outlines (see MuscleMapData). Each piece is a muscle, drawn with softened corners; pieces that are not
/// one of the tracked groups (head, forearms, knees...) are drawn in a neutral colour.
enum MuscleShapes {
    struct Zone: Identifiable {
        let id = UUID()
        let muscle: MuscleGroup?
        let path: Path
    }

    /// Height of the drawing box (width is 100); the back view has feet, the front view stops earlier.
    static let boxHeight: CGFloat = 222

    private static func group(for id: String) -> MuscleGroup? {
        switch id {
        case "CHEST": .chest
        case "ABS", "OBLIQUES": .core
        case "BICEPS": .biceps
        case "TRICEPS": .triceps
        case "FRONT_DELTOIDS", "BACK_DELTOIDS": .shoulders
        case "QUADRICEPS": .quads
        case "CALVES", "LEFT_SOLEUS", "RIGHT_SOLEUS": .calves
        case "NECK", "TRAPEZIUS", "UPPER_BACK", "LOWER_BACK": .back
        case "GLUTEAL": .glutes
        case "HAMSTRING": .hamstrings
        default: nil
        }
    }

    /// Polygon with every corner cut at 30 % of the adjacent edges and joined by a curve through the vertex.
    private static func softened(_ flat: [Double], k: Double = 0.3) -> Path {
        let pts = stride(from: 0, to: flat.count - 1, by: 2).map { CGPoint(x: flat[$0], y: flat[$0 + 1]) }
        guard pts.count >= 3 else { return Path() }
        func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
        var path = Path()
        for i in pts.indices {
            let prev = pts[(i + pts.count - 1) % pts.count], cur = pts[i], next = pts[(i + 1) % pts.count]
            let start = lerp(cur, prev, k), end = lerp(cur, next, k)
            if i == 0 { path.move(to: start) } else { path.addLine(to: start) }
            path.addQuadCurve(to: end, control: cur)
        }
        path.closeSubpath()
        return path
    }

    private static func build(_ pieces: [MuscleMapData.Piece]) -> [Zone] {
        pieces.flatMap { piece in piece.polygons.map { Zone(muscle: group(for: piece.id), path: softened($0)) } }
    }

    private static let frontZones = build(MuscleMapData.front)
    private static let backZones = build(MuscleMapData.back)

    static func zones(back: Bool) -> [Zone] { back ? backZones : frontZones }
}
