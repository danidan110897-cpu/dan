import SwiftUI
import Combine

/// Hands-free flow: the app walks you through every set. You only press "Fatto" when the set is over
/// (or let it complete on its own); rest and the next set start by themselves.
struct GuidedWorkoutView: View {
    let session: WorkoutSession
    let onFinish: () -> Void
    @State private var showEnd = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tempo = Timer.publish(every: WorkoutSession.secondsPerRep / 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 18) {
            if session.allDone || session.currentExercise == nil && session.phase == .idle {
                finished
            } else {
                header
                media
                stage
                Spacer(minLength: 0)
                controls
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .animation(reduceMotion ? .none : Motion.smooth, value: session.phase)
        .sensoryFeedback(.impact(weight: .heavy), trigger: session.startTrigger)
        .sensoryFeedback(.warning, trigger: session.timeUpTrigger)
        .onReceive(tempo) { _ in
            guard session.phase == .work, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: WorkoutSession.secondsPerRep / 2 * 0.9)) { showEnd.toggle() }
        }
        .onChange(of: session.phase) { showEnd = false }
    }

    // MARK: Pieces

    private var header: some View {
        let ex = session.currentExercise
        let done = session.completedSets
        return VStack(spacing: 6) {
            ProgressView(value: Double(done), total: Double(max(session.totalSets, 1))).tint(Theme.accent)
            HStack {
                Text(ex?.name ?? "").font(.system(size: 24, weight: .bold, design: .rounded)).lineLimit(2)
                Spacer()
                Text("Serie \(session.currentSetNumber)/\(ex?.sets.count ?? 0)")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            }
            if let hint = ex?.hint {
                Text(hint).font(.caption).foregroundStyle(Theme.recover).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var media: some View {
        if let key = session.currentExercise?.key, let start = ExerciseMedia.image(key, index: 0) {
            let end = ExerciseMedia.image(key, index: 1)
            ZStack {
                Image(uiImage: start).resizable().scaledToFit().opacity(showEnd && end != nil ? 0 : 1)
                if let end { Image(uiImage: end).resizable().scaledToFit().opacity(showEnd ? 1 : 0) }
            }
            .frame(maxWidth: .infinity, maxHeight: 230)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .opacity(session.phase == .rest ? 0.55 : 1)
            .tilt3D()
        } else {
            Image(systemName: session.currentExercise?.muscle.symbol ?? "dumbbell.fill")
                .font(.system(size: 70)).foregroundStyle(Theme.accent)
                .symbolEffect(.pulse, isActive: session.phase == .work)
                .frame(maxWidth: .infinity, minHeight: 160).card()
        }
    }

    @ViewBuilder
    private var stage: some View {
        switch session.phase {
        case .getReady: readyStage
        case .work: workStage
        case .rest: restStage
        case .idle: EmptyView()
        }
    }

    private var target: some View {
        let set = session.currentSet
        return HStack(spacing: 18) {
            stepper(value: "\(formatWeight(set?.weight ?? 0)) kg", minus: { session.nudge(weight: -2.5) }, plus: { session.nudge(weight: 2.5) })
            stepper(value: "\(set?.reps ?? 0) rip", minus: { session.nudge(reps: -1) }, plus: { session.nudge(reps: 1) })
        }
    }

    private func stepper(value: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Button(action: minus) { Image(systemName: "minus.circle.fill") }
            Text(value).font(.system(.title3, design: .rounded, weight: .bold)).frame(minWidth: 70).contentTransition(.numericText())
            Button(action: plus) { Image(systemName: "plus.circle.fill") }
        }
        .font(.title2).foregroundStyle(Theme.secondaryText)
        .buttonStyle(.plain)
    }

    private var readyStage: some View {
        VStack(spacing: 10) {
            Text("PREPARATI").font(.caption.weight(.heavy)).foregroundStyle(Theme.secondaryText)
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                Text("\(max(Int(ceil(session.phaseEnd.timeIntervalSinceNow)), 0))")
                    .font(.system(size: 88, weight: .black, design: .rounded)).foregroundStyle(Theme.accent)
                    .contentTransition(.numericText(countsDown: true))
            }
            target
        }
    }

    private var workStage: some View {
        VStack(spacing: 10) {
            TimelineView(.animation(minimumInterval: 0.1)) { _ in
                let left = max(session.phaseEnd.timeIntervalSinceNow, 0)
                ZStack {
                    Circle().stroke(Theme.accent.opacity(0.18), lineWidth: 12)
                    Circle().trim(from: 0, to: CGFloat(left / Double(max(session.phaseTotal, 1))))
                        .stroke(session.timeUp ? Theme.move : Theme.accent, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: (session.timeUp ? Theme.move : Theme.accent).opacity(0.7), radius: 12)
                    VStack(spacing: 0) {
                        Text("\(session.currentSet?.reps ?? 0)")
                            .font(.system(size: 64, weight: .black, design: .rounded))
                        Text(session.timeUp ? "Tempo!" : "ripetizioni")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(session.timeUp ? Theme.move : Theme.secondaryText)
                    }
                }
                .frame(width: 190, height: 190)
            }
            Text("\(formatWeight(session.currentSet?.weight ?? 0)) kg").font(.title3.weight(.bold))
        }
    }

    private var restStage: some View {
        VStack(spacing: 10) {
            Text("RECUPERO").font(.caption.weight(.heavy)).foregroundStyle(Theme.recover)
            Text("\(session.restRemaining)")
                .font(.system(size: 88, weight: .black, design: .rounded)).foregroundStyle(Theme.recover)
                .contentTransition(.numericText(countsDown: true))
                .animation(reduceMotion ? .none : Motion.snappy, value: session.restRemaining)
            effort
            Text(session.upcomingDescription).font(.subheadline).foregroundStyle(Theme.secondaryText).multilineTextAlignment(.center)
            target
        }
    }

    /// One-tap effort check after each set: how many reps were left.
    @ViewBuilder
    private var effort: some View {
        if let d = session.lastDone, session.exercises.indices.contains(d[0]), session.exercises[d[0]].sets.indices.contains(d[1]) {
            let answered = session.exercises[d[0]].sets[d[1]].rir
            VStack(spacing: 6) {
                if answered == nil {
                    Text("Quante ripetizioni ti restavano?").font(.footnote.weight(.semibold))
                    HStack(spacing: 8) {
                        ForEach([0, 1, 2, 3], id: \.self) { value in
                            Button { withAnimation(Motion.snappy) { session.recordRIR(value) } } label: {
                                Text(value == 3 ? "3+" : "\(value)").font(.headline).frame(width: 52, height: 40)
                                    .background(Theme.recover.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    Text("0 = non ne facevi un'altra. Più vicino a 0 lavori più duro.").font(.caption2).foregroundStyle(Theme.secondaryText)
                } else if let note = session.effortNote {
                    Label(note, systemImage: "checkmark.circle.fill").font(.footnote).foregroundStyle(Theme.accent)
                        .multilineTextAlignment(.center)
                }
            }
            .transition(.opacity)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Button { session.primaryAction() } label: {
                Text(session.phase == .work ? "FATTO" : session.phase == .rest ? "Salta recupero" : "Parti ora")
                    .font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
                    .background(session.phase == .work ? Theme.accent : Theme.accent.opacity(0.7), in: Capsule())
            }
            .buttonStyle(PressableStyle())
            if session.phase == .rest {
                HStack {
                    Button("−15 s") { session.adjustRest(by: -15) }
                    Spacer()
                    Button("+15 s") { session.adjustRest(by: 15) }
                }
                .buttonStyle(.bordered)
            }
            @Bindable var s = session
            Toggle("Segna la serie da solo a fine tempo", isOn: $s.autoComplete)
                .font(.footnote).tint(Theme.accent)
        }
    }

    private var finished: some View {
        VStack(spacing: 18) {
            Spacer()
            MedalView().frame(height: 200)
            Text("Hai finito tutte le serie").font(.system(size: 26, weight: .bold, design: .rounded))
            Button(action: onFinish) {
                Text("Salva e chiudi").font(.headline).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 16).background(Theme.accent, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            Spacer()
        }
    }
}
