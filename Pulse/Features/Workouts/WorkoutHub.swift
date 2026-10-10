import SwiftUI
import SwiftData

struct PendingStart: Identifiable {
    let id = UUID()
    let routine: Routine
    var lighter = false
}

/// Presents the 3-2-1 countdown, then builds the session and pushes it. Attach to the view that owns the navigation stack.
private struct StartFlow: ViewModifier {
    @Binding var pending: PendingStart?
    @Binding var active: WorkoutSession?
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content.fullScreenCover(item: $pending) { p in
            CountdownView(title: p.routine.name, lighter: p.lighter, onCancel: { pending = nil }) {
                let session = WorkoutSession.make(from: p.routine, context: context, lighter: p.lighter)
                pending = nil
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    active = session
                }
            }
        }
    }
}

extension View {
    func startFlow(pending: Binding<PendingStart?>, active: Binding<WorkoutSession?>) -> some View {
        modifier(StartFlow(pending: pending, active: active))
    }
}

struct CountdownView: View {
    let title: String
    let lighter: Bool
    let onCancel: () -> Void
    let onGo: () -> Void

    @State private var step = 3
    @State private var tick = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            RadialGradient(colors: [Theme.accent.opacity(0.25), .clear], center: .center, startRadius: 10, endRadius: 360)
                .ignoresSafeArea()
                .scaleEffect(step == 0 ? 1.4 : 1)
                .animation(reduceMotion ? .none : .easeOut(duration: 0.8), value: step)
            VStack(spacing: 24) {
                Text(title).font(.title2.weight(.bold))
                if lighter { Label("Versione leggera", systemImage: "leaf.fill").font(.subheadline).foregroundStyle(Theme.recover) }
                Text(step == 0 ? "VIA!" : "\(step)")
                    .font(.system(size: 140, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .id(step)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
                Text("Respira, scalda le spalle, tieni il telefono a portata di mano.")
                    .font(.footnote).foregroundStyle(Theme.secondaryText).multilineTextAlignment(.center).padding(.horizontal, 40)
            }
            VStack {
                HStack {
                    Spacer()
                    Button("Annulla", action: onCancel).padding()
                }
                Spacer()
            }
        }
        .animation(reduceMotion ? .none : Motion.bouncy, value: step)
        .sensoryFeedback(.impact(weight: .heavy), trigger: tick)
        .task {
            for n in [3, 2, 1] {
                step = n
                tick += 1
                try? await Task.sleep(for: .seconds(0.9))
                if Task.isCancelled { return }
            }
            step = 0
            tick += 1
            try? await Task.sleep(for: .seconds(0.55))
            if !Task.isCancelled { onGo() }
        }
    }
}

/// Week strip + the plan for the selected day: scheduled session, done session, or rest with the next one.
struct WorkoutHub: View {
    let routines: [Routine]
    let logs: [WorkoutLog]
    let onStart: (Routine, Bool) -> Void

    @State private var selected = Calendar.current.startOfDay(for: .now)
    @Namespace private var ns
    private let health = HealthStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var week: [Date] { TrainingSchedule.week(containing: .now) }
    private var isToday: Bool { Calendar.current.isDateInToday(selected) }

    var body: some View {
        VStack(spacing: 16) {
            strip
            dayContent
                .id(selected)
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .scale(scale: 0.94).combined(with: .opacity), removal: .opacity))
        }
        .animation(reduceMotion ? .none : Motion.smooth, value: selected)
    }

    // MARK: Week strip

    private var strip: some View {
        HStack(spacing: 4) {
            ForEach(week, id: \.self) { day in
                let scheduled = !TrainingSchedule.routines(on: day, from: routines).isEmpty
                let done = TrainingSchedule.routines(on: day, from: routines).contains { TrainingSchedule.log(for: $0, on: day, logs: logs) != nil }
                    || logs.contains { Calendar.current.isDate($0.date, inSameDayAs: day) }
                let isSelected = Calendar.current.isDate(day, inSameDayAs: selected)
                Button {
                    withAnimation(Motion.bouncy) { selected = Calendar.current.startOfDay(for: day) }
                } label: {
                    VStack(spacing: 6) {
                        Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption2).foregroundStyle(Theme.secondaryText)
                        ZStack {
                            if isSelected {
                                Circle().fill(Theme.accent).matchedGeometryEffect(id: "selectedDay", in: ns)
                            } else if Calendar.current.isDateInToday(day) {
                                Circle().strokeBorder(Theme.accent, lineWidth: 1.5)
                            }
                            Text(day.formatted(.dateTime.day())).font(.subheadline.weight(.semibold))
                                .foregroundStyle(isSelected ? .black : .white)
                        }
                        .frame(width: 38, height: 38)
                        Group {
                            if done { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                            else if scheduled { Circle().fill(Theme.recover).frame(width: 6, height: 6) }
                            else { Color.clear.frame(width: 6, height: 6) }
                        }
                        .frame(height: 14)
                        .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month()) + (scheduled ? ", allenamento in programma" : ""))
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 8)
        .card()
        .sensoryFeedback(.selection, trigger: selected)
    }

    // MARK: Day content

    @ViewBuilder
    private var dayContent: some View {
        let todays = TrainingSchedule.routines(on: selected, from: routines)
        if todays.isEmpty {
            restCard
        } else {
            VStack(spacing: 12) {
                ForEach(todays) { routine in sessionCard(routine) }
            }
        }
    }

    private func sessionCard(_ routine: Routine) -> some View {
        let done = TrainingSchedule.log(for: routine, on: selected, logs: logs)
        let lowReadiness = isToday && (health.readiness?.score ?? 100) < 50
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(done != nil ? "COMPLETATO" : isToday ? "OGGI" : selected.formatted(.dateTime.weekday(.wide)).uppercased())
                        .font(.caption.weight(.semibold)).foregroundStyle(done != nil ? Theme.accent : Theme.secondaryText)
                    Text(routine.name).font(.system(size: 26, weight: .bold, design: .rounded))
                }
                Spacer()
                if done != nil {
                    Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(Theme.accent).symbolEffect(.bounce, value: selected)
                }
            }
            thumbnails(routine)
            HStack(spacing: 16) {
                Label("\(routine.items.count) esercizi", systemImage: "dumbbell.fill")
                Label("~\(routine.estimatedMinutes) min", systemImage: "clock")
                if let done { Label("\(Int(done.volume)) kg", systemImage: "scalemass") }
            }
            .font(.subheadline).foregroundStyle(Theme.secondaryText)

            if lowReadiness, done == nil {
                Label("Recupero basso oggi: puoi fare la versione leggera (una serie in meno per esercizio).", systemImage: "leaf.fill")
                    .font(.footnote).foregroundStyle(Theme.recover)
            }

            if done == nil {
                HStack(spacing: 10) {
                    Button { onStart(routine, false) } label: {
                        Label(isToday ? "Inizia" : "Anticipa", systemImage: "play.fill")
                            .font(.headline).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Theme.accent, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    if lowReadiness {
                        Button { onStart(routine, true) } label: {
                            Label("Leggera", systemImage: "leaf.fill").font(.headline).padding(.vertical, 14).padding(.horizontal, 18)
                                .background(Theme.recover.opacity(0.2), in: Capsule())
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            } else {
                Button { onStart(routine, false) } label: {
                    Text("Ripeti").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .card()
    }

    private func thumbnails(_ routine: Routine) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(routine.sortedItems.prefix(8)) { item in
                    ZStack {
                        if let key = item.exercise?.key, let image = ExerciseMedia.image(key, index: 0) {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            Color.white.opacity(0.08)
                            Image(systemName: item.exercise?.muscle.symbol ?? "dumbbell.fill").foregroundStyle(Theme.accent)
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel(item.exercise?.name ?? "Esercizio")
                }
            }
        }
    }

    @ViewBuilder
    private var restCard: some View {
        let missed = isToday ? TrainingSchedule.missedYesterday(routines: routines, logs: logs) : nil
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "moon.stars.fill").font(.title).foregroundStyle(Theme.recover).symbolEffect(.pulse)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isToday ? "Oggi si recupera" : "Giorno di riposo").font(.headline)
                    if let next = TrainingSchedule.next(after: selected, routines: routines) {
                        Text("Prossimo: \(next.date.formatted(.dateTime.weekday(.wide))) · \(next.routine.name)")
                            .font(.subheadline).foregroundStyle(Theme.secondaryText)
                    } else {
                        Text("Assegna una routine a un giorno per averla qui in automatico.")
                            .font(.subheadline).foregroundStyle(Theme.secondaryText)
                    }
                }
                Spacer()
            }
            if let missed {
                Button { onStart(missed, false) } label: {
                    Label("Ieri era previsto \(missed.name): recuperalo oggi", systemImage: "arrow.uturn.forward")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Theme.accent.opacity(0.2), in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
            if !routines.isEmpty {
                Menu {
                    ForEach(routines.filter { !$0.items.isEmpty }) { r in Button(r.name) { onStart(r, false) } }
                } label: {
                    Label("Allenati comunque", systemImage: "figure.strengthtraining.traditional")
                        .font(.subheadline).frame(maxWidth: .infinity).padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .card()
    }
}
