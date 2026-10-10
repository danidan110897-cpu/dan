import SwiftUI
import SwiftData

struct WorkoutSessionView: View {
    @State private var session: WorkoutSession
    @State private var showConfetti = false
    @State private var showFinish = false
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    init(session: WorkoutSession) {
        _session = State(initialValue: session)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    summary
                    ForEach($session.exercises) { $exercise in
                        ExerciseCard(
                            exercise: $exercise,
                            onToggle: { setID in
                                withAnimation(Motion.snappy) { session.toggle(exerciseID: exercise.id, setID: setID) }
                            },
                            onAddSet: { withAnimation(Motion.snappy) { session.addSet(to: exercise.id) } },
                            onEdit: { session.onUpdate?() }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, session.isResting ? 140 : 32)
            }
            .scrollDismissesKeyboard(.interactively)

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
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Termina") { showFinish = true }.fontWeight(.semibold)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Fine") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .confirmationDialog("Terminare l'allenamento?", isPresented: $showFinish, titleVisibility: .visible) {
            Button("Salva e chiudi") { finish(save: true) }
            Button("Scarta", role: .destructive) { finish(save: false) }
            Button("Continua", role: .cancel) {}
        } message: {
            Text("Vengono salvate solo le serie completate.")
        }
        .sensoryFeedback(.success, trigger: session.prTrigger)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: session.completedSets)
        .onAppear {
            let link = Connectivity.shared
            let s = session
            s.onUpdate = { link.send(snapshot: s.snapshot) }
            link.onToggle = { s.apply($0) }
            link.activate()
            link.send(snapshot: s.snapshot)
        }
        .onChange(of: session.prTrigger) {
            showConfetti = false
            Task {
                showConfetti = true
                try? await Task.sleep(for: .seconds(1.3))
                showConfetti = false
            }
        }
    }

    private func finish(save: Bool) {
        if save { session.save(to: context) }
        session.skipRest()
        session.onUpdate = nil
        // An empty snapshot tells the Watch the workout is over.
        Connectivity.shared.send(snapshot: WorkoutSnapshot(title: "", restSeconds: 0, exercises: []))
        dismiss()
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
    @Binding var exercise: SessionExercise
    let onToggle: (UUID) -> Void
    let onAddSet: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name).font(.headline)
                    Text(exercise.muscle.label).font(.caption).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
                if exercise.superset != 0 {
                    Text("SUPERSET").font(.caption2.weight(.heavy))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Theme.recover.opacity(0.2), in: Capsule())
                        .foregroundStyle(Theme.recover)
                }
            }
            HStack {
                Text("SERIE").frame(width: 40, alignment: .leading)
                Text("PRECEDENTE").frame(maxWidth: .infinity, alignment: .leading)
                Text("KG").frame(width: 56)
                Text("REP").frame(width: 44)
                Spacer().frame(width: 44)
            }
            .font(.caption2.weight(.semibold)).foregroundStyle(Theme.secondaryText)

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { i, current in
                SetRow(index: i + 1, set: $exercise.sets[i], onTap: { onToggle(current.id) }, onEdit: onEdit)
            }

            Button(action: onAddSet) {
                Label("Aggiungi serie", systemImage: "plus")
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(16)
        .card()
    }
}

private struct SetRow: View {
    let index: Int
    @Binding var set: SessionSet
    let onTap: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Text("\(index)").frame(width: 40, alignment: .leading).font(.subheadline.weight(.semibold))
            Text(set.previous).frame(maxWidth: .infinity, alignment: .leading)
                .font(.subheadline).foregroundStyle(Theme.secondaryText)
            TextField("0", value: $set.weight, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .frame(width: 56)
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            TextField("0", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 44)
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            Button(action: onTap) {
                Image(systemName: set.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isDone ? Theme.accent : Theme.secondaryText)
                    .symbolEffect(.bounce, value: set.isDone)
                    .frame(width: 44, height: 36)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(set.isDone ? "Serie \(index) completata" : "Completa serie \(index)")
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 10).fill(set.isDone ? Theme.accent.opacity(0.14) : .clear)
                .padding(.horizontal, -8)
        )
        .overlay(alignment: .leading) {
            if set.isPR {
                Text("PR").font(.caption2.weight(.heavy)).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.move, in: Capsule())
                    .offset(x: -10, y: -16)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onChange(of: set.weight) { onEdit() }
        .onChange(of: set.reps) { onEdit() }
    }
}

private struct RestTimerBar: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 12) {
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

            Text("Recupero").font(.headline)
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
