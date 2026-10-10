import SwiftUI

struct WorkoutSessionView: View {
    @State private var session = WorkoutSession()
    @State private var showConfetti = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    summary
                    ForEach(Array(session.exercises.enumerated()), id: \.element.id) { e, exercise in
                        ExerciseCard(exercise: exercise, onToggle: { s in
                            withAnimation(Motion.snappy) { session.toggle(exercise: e, set: s) }
                        })
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, session.isResting ? 140 : 32)
            }

            if session.isResting {
                RestTimerBar(session: session)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            if showConfetti {
                ConfettiBurst().frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .animation(Motion.bouncy, value: session.isResting)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Push")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: session.prTrigger)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: session.completedSets)
        .onChange(of: session.prTrigger) {
            showConfetti = false
            Task {
                showConfetti = true
                try? await Task.sleep(for: .seconds(1.3))
                showConfetti = false
            }
        }
    }

    private var summary: some View {
        HStack {
            metric("Serie", "\(session.completedSets)/\(session.totalSets)")
            Divider().frame(height: 32)
            metric("Volume", "\(Int(session.totalVolume)) kg")
        }
        .padding(16)
        .card()
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title2, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
                .animation(Motion.snappy, value: value)
            Text(title).font(.caption).foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ExerciseCard: View {
    let exercise: ExerciseLog
    let onToggle: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name).font(.headline)
                Text(exercise.muscle).font(.caption).foregroundStyle(Theme.secondaryText)
            }
            HStack {
                Text("SERIE").frame(width: 40, alignment: .leading)
                Text("PRECEDENTE").frame(maxWidth: .infinity, alignment: .leading)
                Text("KG × REP").frame(width: 90)
                Spacer().frame(width: 44)
            }
            .font(.caption2.weight(.semibold)).foregroundStyle(Theme.secondaryText)

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { i, set in
                SetRow(index: i + 1, set: set) { onToggle(i) }
            }
        }
        .padding(16)
        .card()
    }
}

private struct SetRow: View {
    let index: Int
    let set: SetEntry
    let onTap: () -> Void

    var body: some View {
        HStack {
            Text("\(index)").frame(width: 40, alignment: .leading).font(.subheadline.weight(.semibold))
            Text(set.previous).frame(maxWidth: .infinity, alignment: .leading)
                .font(.subheadline).foregroundStyle(Theme.secondaryText)
            HStack(spacing: 4) {
                Text(set.weight.formatted()).fontWeight(.semibold)
                Text("×").foregroundStyle(Theme.secondaryText)
                Text("\(set.reps)").fontWeight(.semibold)
            }
            .frame(width: 90).font(.subheadline)
            Button(action: onTap) {
                Image(systemName: set.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isDone ? Theme.accent : Theme.secondaryText)
                    .symbolEffect(.bounce, value: set.isDone)
                    .frame(width: 44, height: 36)
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(set.isDone ? Theme.accent.opacity(0.14) : .clear)
                .padding(.horizontal, -8)
        )
        .overlay(alignment: .trailing) {
            if set.isPR {
                Text("PR").font(.caption2.weight(.heavy)).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.move, in: Capsule())
                    .offset(x: -52)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

private struct RestTimerBar: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Theme.recover.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: CGFloat(session.restRemaining) / CGFloat(max(session.restTotal, 1)))
                    .stroke(Theme.recover, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: session.restRemaining)
                Text("\(session.restRemaining)")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .contentTransition(.numericText(countsDown: true))
                    .animation(Motion.snappy, value: session.restRemaining)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading) {
                Text("Recupero").font(.headline)
                Text("Respira, prossima serie a breve").font(.caption).foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Button("−15") { session.adjustRest(by: -15) }
            Button("+15") { session.adjustRest(by: 15) }
            Button("Salta") { session.skipRest() }.tint(Theme.accent)
        }
        .buttonStyle(.bordered)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.cardStroke))
    }
}

#Preview { NavigationStack { WorkoutSessionView() } }
