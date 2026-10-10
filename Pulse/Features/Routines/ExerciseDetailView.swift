import SwiftUI
import SwiftData

/// Photos of the start and end position (alternating), step-by-step execution and common mistakes.
struct ExerciseDetailView: View {
    let key: String
    let name: String
    let muscle: MuscleGroup
    let equipment: Equipment

    @Query private var logs: [WorkoutLog]
    @State private var showEnd = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let timer = Timer.publish(every: 1.4, on: .main, in: .common).autoconnect()

    init(exercise: Exercise) {
        self.init(key: exercise.key, name: exercise.name, muscle: exercise.muscle, equipment: exercise.equipment)
    }

    init(key: String, name: String, muscle: MuscleGroup, equipment: Equipment) {
        self.key = key
        self.name = name
        self.muscle = muscle
        self.equipment = equipment
    }

    private var guide: ExerciseGuide? { ExerciseGuides.guide(for: key) }

    private var best: (weight: Double, reps: Int)? {
        var top: LogSet?
        for log in logs {
            for e in log.entries where e.exerciseKey == key {
                for s in e.sets where s.estimatedOneRM > (top?.estimatedOneRM ?? 0) { top = s }
            }
        }
        return top.map { ($0.weight, $0.reps) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                media
                VStack(alignment: .leading, spacing: 4) {
                    Text(name).font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("\(muscle.label) · \(equipment.label)").font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
                if let best {
                    Label("Il tuo massimo: \(formatWeight(best.weight)) kg × \(best.reps)", systemImage: "trophy.fill")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                }
                if let guide {
                    section("Come si esegue", systemImage: "list.number") {
                        ForEach(Array(guide.steps.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(i + 1)").font(.caption.weight(.bold)).foregroundStyle(.black)
                                    .frame(width: 22, height: 22).background(Theme.accent, in: Circle())
                                Text(step).font(.subheadline)
                            }
                        }
                    }
                    section("Errori comuni", systemImage: "exclamationmark.triangle.fill") {
                        ForEach(guide.mistakes, id: \.self) { m in
                            Label(m, systemImage: "xmark.circle").font(.subheadline).foregroundStyle(.white)
                                .labelStyle(MistakeLabelStyle())
                        }
                    }
                }
                Text("Le foto mostrano la posizione di partenza e quella finale. Parti con carichi leggeri finché la tecnica è pulita. Se senti dolore acuto, fermati.")
                    .font(.caption).foregroundStyle(Theme.secondaryText)
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in
            guard !reduceMotion, ExerciseMedia.hasPhotos(key) else { return }
            withAnimation(.easeInOut(duration: 0.5)) { showEnd.toggle() }
        }
    }

    @ViewBuilder
    private var media: some View {
        if let start = ExerciseMedia.image(key, index: 0) {
            let end = ExerciseMedia.image(key, index: 1)
            ZStack(alignment: .topTrailing) {
                Image(uiImage: start).resizable().scaledToFit()
                    .opacity(showEnd && end != nil ? 0 : 1)
                if let end {
                    Image(uiImage: end).resizable().scaledToFit().opacity(showEnd ? 1 : 0)
                }
                Text(showEnd ? "FINE" : "INIZIO")
                    .font(.caption2.weight(.heavy)).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.black.opacity(0.65), in: Capsule()).padding(10)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityLabel("Foto dell'esercizio \(name), posizione di \(showEnd ? "fine" : "partenza")")
        } else {
            VStack(spacing: 8) {
                Image(systemName: muscle.symbol).font(.system(size: 44)).foregroundStyle(Theme.accent)
                Text("Foto non disponibile per questo esercizio").font(.footnote).foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity).padding(40).card()
        }
    }

    private func section<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage).font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private struct MistakeLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 10) {
            configuration.icon.foregroundStyle(Theme.move)
            configuration.title
        }
    }
}
