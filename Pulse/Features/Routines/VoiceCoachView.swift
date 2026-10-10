import SwiftUI
import SwiftData

/// "Dimmi cosa alleni oggi": speak or type, get today's workout, start it. It is logged like any other workout.
struct VoiceCoachView: View {
    let onStart: (Routine) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var recorder = SpeechRecorder()
    @State private var text = ""
    @State private var result: VoiceWorkoutBuilder.Result?
    @State private var error: String?

    private let examples = ["Oggi petto e tricipiti", "Gambe e addome, 45 minuti", "Schiena e bicipiti con i manubri", "Tutto il corpo, sono stanco"]

    private var library: [LibraryEntry] {
        exercises.map { LibraryEntry(key: $0.key, name: $0.name, muscle: $0.muscle, equipment: $0.equipment) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    micButton
                    Text(recorder.isRecording ? "Ti ascolto…" : "Tocca il microfono e dimmi cosa vuoi allenare oggi")
                        .font(.subheadline).foregroundStyle(Theme.secondaryText).multilineTextAlignment(.center)

                    TextField("Oppure scrivilo qui", text: $text, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(14).background(Theme.card, in: RoundedRectangle(cornerRadius: 14))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(examples, id: \.self) { example in
                                Button(example) { text = example; build() }
                                    .font(.footnote).padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(Theme.accent.opacity(0.15), in: Capsule())
                            }
                        }
                    }

                    Button(action: build) {
                        Label("Crea l'allenamento di oggi", systemImage: "sparkles").font(.headline).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 14).background(Theme.accent, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)

                    if let error { Text(error).font(.footnote).foregroundStyle(Theme.move) }
                    if let message = recorder.error { Text(message).font(.footnote).foregroundStyle(Theme.move) }
                    if let result { preview(result) }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Assistente vocale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Chiudi") { dismiss() } }
            .animation(reduceMotion ? .none : Motion.smooth, value: result?.name)
            .onChange(of: recorder.transcript) { if !recorder.transcript.isEmpty { text = recorder.transcript } }
            .onChange(of: recorder.isRecording) { if !recorder.isRecording, !text.isEmpty, result == nil { build() } }
            .onDisappear { recorder.stop() }
        }
    }

    private var micButton: some View {
        Button {
            Task { await recorder.toggle() }
        } label: {
            ZStack {
                if recorder.isRecording && !reduceMotion {
                    PhaseAnimator([0.0, 1.0]) { phase in
                        Circle().stroke(Theme.accent.opacity(0.5 - 0.4 * phase), lineWidth: 3)
                            .scaleEffect(1 + 0.6 * phase)
                    } animation: { _ in .easeOut(duration: 1.2) }
                }
                Circle().fill(recorder.isRecording ? Theme.move : Theme.accent)
                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 40)).foregroundStyle(.black)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 110, height: 110)
            .shadow(color: Theme.accent.opacity(0.5), radius: recorder.isRecording ? 26 : 10)
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.impact, trigger: recorder.isRecording)
        .accessibilityLabel(recorder.isRecording ? "Ferma la registrazione" : "Parla")
        .padding(.top, 8)
    }

    private func preview(_ r: VoiceWorkoutBuilder.Result) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(r.name).font(.title3.weight(.bold))
            Text("\(r.exercises.count) esercizi · circa \(r.minutes) min").font(.subheadline).foregroundStyle(Theme.secondaryText)
            ForEach(r.exercises) { ex in
                HStack {
                    Text(exercises.first { $0.key == ex.key }?.name ?? ex.key).font(.subheadline)
                    Spacer()
                    Text("\(ex.sets) × \(ex.reps)").font(.subheadline.weight(.semibold))
                }
            }
            ForEach(r.notes, id: \.self) { Label($0, systemImage: "info.circle").font(.footnote).foregroundStyle(Theme.recover) }
            Button(action: { start(r) }) {
                Label("Avvia ora", systemImage: "play.fill").font(.headline).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 14).background(Theme.accent, in: Capsule())
            }
            .buttonStyle(PressableStyle())
            Text("Verrà salvato tra le tue routine e registrato nello storico come gli altri allenamenti.")
                .font(.caption).foregroundStyle(Theme.secondaryText)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).card()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func build() {
        recorder.stop()
        error = nil
        do {
            result = try VoiceWorkoutBuilder.build(from: text, library: library)
        } catch {
            result = nil
            self.error = error.localizedDescription
        }
    }

    private func start(_ r: VoiceWorkoutBuilder.Result) {
        let routine = Routine(name: r.name, restSeconds: 90)
        context.insert(routine)
        for (i, g) in r.exercises.enumerated() {
            guard let ex = exercises.first(where: { $0.key == g.key }) else { continue }
            routine.items.append(RoutineItem(order: i, exercise: ex, sets: g.sets, reps: g.reps))
        }
        try? context.save()
        dismiss()
        onStart(routine)
    }
}
