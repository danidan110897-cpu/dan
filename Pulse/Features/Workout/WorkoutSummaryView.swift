import SwiftUI
import SwiftData

struct WorkoutSummary: Identifiable {
    let id = UUID()
    let name: String
    let duration: Int
    let volume: Double
    let sets: Int
    let records: [String]
}

/// Celebration screen shown after saving a workout: counted-up numbers, records, and what comes next.
struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    let onClose: () -> Void

    @Query private var routines: [Routine]
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var next: (date: Date, routine: Routine)? { TrainingSchedule.next(after: .now, routines: routines) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            RadialGradient(colors: [Theme.accent.opacity(shown ? 0.25 : 0), .clear], center: .top, startRadius: 10, endRadius: 420)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 1.2), value: shown)

            VStack(spacing: 22) {
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 76)).foregroundStyle(Theme.accent)
                    .scaleEffect(shown || reduceMotion ? 1 : 0.2)
                    .opacity(shown ? 1 : 0)
                    .symbolEffect(.bounce, value: shown)
                    .animation(reduceMotion ? .none : Motion.bouncy, value: shown)
                Text("Allenamento completato").font(.system(size: 28, weight: .bold, design: .rounded))
                Text(summary.name).foregroundStyle(Theme.secondaryText)

                HStack(spacing: 12) {
                    tile("Durata", value: shown ? Double(summary.duration / 60) : 0, unit: "min", delay: 0.1)
                    tile("Volume", value: shown ? summary.volume : 0, unit: "kg", delay: 0.2)
                    tile("Serie", value: shown ? Double(summary.sets) : 0, unit: "", delay: 0.3)
                }
                .padding(.horizontal, 20)

                if !summary.records.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Nuovi record", systemImage: "trophy.fill").font(.headline).foregroundStyle(Theme.move)
                        ForEach(summary.records, id: \.self) { Text("• \($0)").font(.subheadline) }
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).card().padding(.horizontal, 20)
                    .opacity(shown ? 1 : 0).offset(y: shown ? 0 : 20)
                    .animation(reduceMotion ? .none : Motion.smooth.delay(0.5), value: shown)
                }

                if let next {
                    Text("Prossimo: \(next.date.formatted(.dateTime.weekday(.wide))) · \(next.routine.name)")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                Button(action: onClose) {
                    Text("Fatto").font(.headline).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 16).background(Theme.accent, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .padding(.horizontal, 24).padding(.bottom, 24)
            }
            if !summary.records.isEmpty && shown { ConfettiBurst() }
        }
        .sensoryFeedback(.success, trigger: shown)
        .onAppear { withAnimation(reduceMotion ? .none : .smooth(duration: 1.2).delay(0.2)) { shown = true } }
    }

    private func tile(_ title: String, value: Double, unit: String, delay: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(value))\(unit.isEmpty ? "" : " \(unit)")")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
                .animation(reduceMotion ? .none : .smooth(duration: 1.2).delay(delay), value: value)
            Text(title).font(.caption).foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14).card()
    }
}
