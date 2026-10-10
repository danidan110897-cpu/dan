import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(Router.self) private var router
    @Query(sort: \WorkoutLog.date, order: .reverse) private var logs: [WorkoutLog]
    @Query(sort: \Routine.createdAt) private var routines: [Routine]

    @State private var shown = false
    @State private var active: WorkoutSession?
    @Namespace private var zoom
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let dayLetters = ["L", "M", "M", "G", "V", "S", "D"]

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }

    private var weekStart: Date { cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now }
    private var thisWeekLogs: [WorkoutLog] { logs.filter { $0.date >= weekStart } }
    private var todayMinutes: Int {
        logs.filter { cal.isDateInToday($0.date) }.reduce(0) { $0 + $1.durationSeconds } / 60
    }

    private var activeDays: Set<Int> {
        Set(thisWeekLogs.compactMap { cal.dateComponents([.day], from: weekStart, to: $0.date).day })
    }

    /// Consecutive weeks (ending now) with at least two workouts. The current week doesn't break the streak while it's still in progress.
    private var streakWeeks: Int {
        var count = 0
        var start = weekStart
        var first = true
        while true {
            let end = cal.date(byAdding: .day, value: 7, to: start)!
            let n = logs.filter { $0.date >= start && $0.date < end }.count
            if n >= 2 { count += 1 } else if !first { break }
            first = false
            guard let prev = cal.date(byAdding: .day, value: -7, to: start) else { break }
            start = prev
            if count > 520 { break }
        }
        return count
    }

    /// The routine done least recently (or never) is next.
    private var nextRoutine: Routine? {
        routines.filter { !$0.items.isEmpty }.min { a, b in
            let da = logs.first { $0.name == a.name }?.date ?? .distantPast
            let db = logs.first { $0.name == b.name }?.date ?? .distantPast
            return da < db
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header.entrance(0, shown: shown, reduceMotion: reduceMotion)
                    ringsCard.entrance(1, shown: shown, reduceMotion: reduceMotion)
                    streakCard.entrance(2, shown: shown, reduceMotion: reduceMotion)
                    workoutCard.entrance(3, shown: shown, reduceMotion: reduceMotion)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationDestination(item: $active) { session in
                WorkoutSessionView(session: session)
                    .navigationTransition(.zoom(sourceID: "workout", in: zoom))
            }
            .onAppear { shown = true }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                .font(.subheadline).foregroundStyle(Theme.secondaryText)
            Text("Pronto a spingere?").font(.system(size: 32, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var ringsCard: some View {
        HStack(spacing: 20) {
            ZStack {
                ProgressRing(progress: Double(todayMinutes) / 45, color: Theme.train, lineWidth: 16)
                ProgressRing(progress: Double(thisWeekLogs.count) / 3, color: Theme.move, lineWidth: 16, delay: 0.15)
                    .padding(22)
            }
            .frame(width: 130, height: 130)
            .animation(Motion.smooth, value: logs.count)

            VStack(alignment: .leading, spacing: 14) {
                stat("Oggi", "\(todayMinutes) / 45 min", Theme.train)
                stat("Settimana", "\(thisWeekLogs.count) / 3 allenamenti", Theme.move)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .card()
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(Theme.secondaryText)
            Text(value).font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(color)
                .contentTransition(.numericText())
        }
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion && streakWeeks > 0)
                Text(streakWeeks == 0 ? "Inizia la tua serie" : "\(streakWeeks) settimane di fila").font(.headline)
                Spacer()
            }
            HStack {
                ForEach(0..<7, id: \.self) { i in
                    let done = activeDays.contains(i)
                    VStack(spacing: 6) {
                        Text(dayLetters[i]).font(.caption2).foregroundStyle(Theme.secondaryText)
                        Circle()
                            .fill(done ? Theme.accent : Color.white.opacity(0.1))
                            .frame(width: 30, height: 30)
                            .overlay {
                                if done {
                                    Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.black)
                                }
                            }
                            .scaleEffect(shown ? 1 : 0.3)
                            .opacity(shown ? 1 : 0)
                            .animation(reduceMotion ? .none : Motion.bouncy.delay(0.5 + Double(i) * 0.05), value: shown)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text("Una settimana conta con almeno 2 allenamenti.")
                .font(.caption).foregroundStyle(Theme.secondaryText)
        }
        .padding(20)
        .card()
    }

    @ViewBuilder
    private var workoutCard: some View {
        if let routine = nextRoutine {
            Button {
                active = WorkoutSession.make(from: routine, context: context)
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("PROSSIMO ALLENAMENTO").font(.caption.weight(.semibold)).foregroundStyle(.black.opacity(0.6))
                    Text(routine.name).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(.black)
                    HStack {
                        Label("\(routine.items.count) esercizi", systemImage: "dumbbell.fill")
                        Label("~\(routine.estimatedMinutes) min", systemImage: "clock")
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill").font(.title)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.black.opacity(0.75))
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .matchedTransitionSource(id: "workout", in: zoom)
            .sensoryFeedback(.impact(weight: .medium), trigger: active)
        } else {
            Button { router.tab = .workouts } label: {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill").font(.largeTitle).foregroundStyle(Theme.accent)
                    Text("Crea la tua prima routine").font(.headline)
                    Text("Scegli gli esercizi o fai fare la bozza all'AI.")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }
                .frame(maxWidth: .infinity).padding(24)
                .card()
            }
            .buttonStyle(PressableStyle())
        }
    }
}
