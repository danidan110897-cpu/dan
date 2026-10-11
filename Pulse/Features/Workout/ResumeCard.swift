import SwiftUI

/// Shown when a workout was left open (for example the app was closed by mistake): one tap to continue where it stopped.
struct ResumeCard: View {
    let summary: (title: String, done: Int, total: Int)
    let onResume: () -> Void
    let onDiscard: () -> Void
    @State private var confirmDiscard = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.clockwise.circle.fill").font(.title2).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Allenamento in corso").font(.headline)
                    Text("\(summary.title) · \(summary.done)/\(summary.total) serie fatte")
                        .font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Button(action: onResume) {
                    Label("Riprendi", systemImage: "play.fill").font(.headline).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 12).background(Theme.accent, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                Button("Scarta", role: .destructive) { confirmDiscard = true }
                    .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .card()
        .confirmationDialog("Scartare l'allenamento in corso?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Scarta", role: .destructive, action: onDiscard)
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Le serie già fatte non vengono salvate.")
        }
    }
}
