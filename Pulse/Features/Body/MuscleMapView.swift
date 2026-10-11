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
                .frame(height: 380)

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
            let s = min(geo.size.width / 100, geo.size.height / 210)
            let t = CGAffineTransform(scaleX: s, y: s)
            let offsetX = (geo.size.width - 100 * s) / 2
            ZStack(alignment: .topLeading) {
                MuscleShapes.silhouette.applying(t).fill(Color.white.opacity(0.08))
                ForEach(zones) { zone in
                    let path = zone.path.applying(t)
                    let status = statuses[zone.muscle]
                    path.fill(status.map { Self.color($0) } ?? Color.white.opacity(0.1))
                        .overlay(path.stroke(Color.white.opacity(selected == zone.muscle ? 0.95 : 0.25),
                                             lineWidth: selected == zone.muscle ? 2 : 0.6))
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

/// Hand-drawn outlines in a 100 x 210 box. Everything is drawn for the left half and mirrored.
enum MuscleShapes {
    struct Zone: Identifiable {
        let muscle: MuscleGroup
        let path: Path
        var id: MuscleGroup { muscle }
    }

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    private static func both(_ left: Path) -> Path {
        var full = left
        full.addPath(left.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 100, ty: 0)))
        return full
    }

    static let silhouette: Path = {
        var head = Path(ellipseIn: CGRect(x: 39, y: 3, width: 22, height: 26))
        head.addRect(CGRect(x: 44, y: 26, width: 12, height: 8))

        var torso = Path()
        torso.move(to: p(50, 30))
        torso.addLine(to: p(44, 31))
        torso.addQuadCurve(to: p(29, 40), control: p(34, 34))
        torso.addQuadCurve(to: p(33, 78), control: p(30, 60))
        torso.addQuadCurve(to: p(37, 106), control: p(36, 92))
        torso.addQuadCurve(to: p(38, 120), control: p(36, 114))
        torso.addLine(to: p(50, 120))
        torso.closeSubpath()

        var arm = Path()
        arm.move(to: p(29, 40))
        arm.addQuadCurve(to: p(19, 52), control: p(21, 42))
        arm.addLine(to: p(16, 80))
        arm.addQuadCurve(to: p(11, 116), control: p(14, 96))
        arm.addLine(to: p(15, 122))
        arm.addLine(to: p(21, 120))
        arm.addQuadCurve(to: p(25, 84), control: p(22, 100))
        arm.addLine(to: p(31, 60))
        arm.closeSubpath()

        var leg = Path()
        leg.move(to: p(50, 118))
        leg.addLine(to: p(36, 118))
        leg.addQuadCurve(to: p(35, 160), control: p(33, 140))
        leg.addQuadCurve(to: p(37, 192), control: p(33, 176))
        leg.addLine(to: p(36, 204))
        leg.addLine(to: p(46, 204))
        leg.addLine(to: p(46, 190))
        leg.addQuadCurve(to: p(48, 160), control: p(48, 176))
        leg.addLine(to: p(50, 130))
        leg.closeSubpath()

        let foot = Path(ellipseIn: CGRect(x: 33, y: 203, width: 15, height: 6))

        var left = Path()
        left.addPath(torso); left.addPath(arm); left.addPath(leg); left.addPath(foot)
        var all = both(left)
        all.addPath(head)
        return all
    }()

    private static let deltoid: Path = {
        var d = Path()
        d.move(to: p(33, 40))
        d.addQuadCurve(to: p(25, 48), control: p(27, 40))
        d.addQuadCurve(to: p(30, 60), control: p(24, 58))
        d.addQuadCurve(to: p(34, 46), control: p(33, 54))
        d.closeSubpath()
        return d
    }()

    private static let armUpper: Path = {
        var a = Path()
        a.move(to: p(19, 60))
        a.addLine(to: p(30, 60))
        a.addLine(to: p(26, 82))
        a.addLine(to: p(16.5, 82))
        a.closeSubpath()
        return a
    }()

    private static let calf: Path = {
        var c = Path()
        c.move(to: p(37, 166))
        c.addQuadCurve(to: p(38, 192), control: p(33, 178))
        c.addLine(to: p(45, 192))
        c.addQuadCurve(to: p(46, 166), control: p(49, 178))
        c.closeSubpath()
        return c
    }()

    static func zones(back: Bool) -> [Zone] {
        var out: [Zone] = []
        func add(_ m: MuscleGroup, _ path: Path) { out.append(Zone(muscle: m, path: both(path))) }

        add(.shoulders, deltoid)
        add(back ? .triceps : .biceps, armUpper)
        add(.calves, calf)

        if back {
            var lats = Path()
            lats.move(to: p(49, 36))
            lats.addQuadCurve(to: p(32, 42), control: p(40, 36))
            lats.addQuadCurve(to: p(36, 82), control: p(31, 60))
            lats.addQuadCurve(to: p(49, 92), control: p(42, 92))
            lats.closeSubpath()
            add(.back, lats)

            var glutes = Path()
            glutes.move(to: p(49, 106))
            glutes.addQuadCurve(to: p(36, 114), control: p(38, 104))
            glutes.addQuadCurve(to: p(44, 128), control: p(36, 126))
            glutes.addQuadCurve(to: p(49, 120), control: p(49, 127))
            glutes.closeSubpath()
            add(.glutes, glutes)

            var ham = Path()
            ham.move(to: p(49, 131))
            ham.addLine(to: p(38, 131))
            ham.addQuadCurve(to: p(37, 162), control: p(35, 146))
            ham.addLine(to: p(45, 162))
            ham.addQuadCurve(to: p(49, 138), control: p(48, 150))
            ham.closeSubpath()
            add(.hamstrings, ham)
        } else {
            var chest = Path()
            chest.move(to: p(49, 42))
            chest.addQuadCurve(to: p(33, 44), control: p(40, 40))
            chest.addQuadCurve(to: p(37, 60), control: p(31, 54))
            chest.addQuadCurve(to: p(49, 58), control: p(45, 62))
            chest.closeSubpath()
            add(.chest, chest)

            var abs = Path()
            abs.move(to: p(49, 64))
            abs.addLine(to: p(41, 64))
            abs.addQuadCurve(to: p(40, 96), control: p(39, 80))
            abs.addQuadCurve(to: p(49, 104), control: p(44, 104))
            abs.closeSubpath()
            add(.core, abs)

            var quads = Path()
            quads.move(to: p(49, 122))
            quads.addLine(to: p(38, 122))
            quads.addQuadCurve(to: p(36, 160), control: p(35, 140))
            quads.addLine(to: p(45, 162))
            quads.addQuadCurve(to: p(49, 130), control: p(48, 145))
            quads.closeSubpath()
            add(.quads, quads)
        }
        return out
    }
}
