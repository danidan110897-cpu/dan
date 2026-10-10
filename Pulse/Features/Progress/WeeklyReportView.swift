import SwiftUI
import SwiftData

struct WeeklyReportView: View {
    @Environment(ProfileStore.self) private var profile
    @Query(sort: \WorkoutLog.date) private var logs: [WorkoutLog]
    @Query(sort: \FoodEntry.date) private var foods: [FoodEntry]
    @Query(sort: \ProgressPhoto.date) private var photos: [ProgressPhoto]

    @State private var includePhotos = false
    @State private var confirmSend = false
    @State private var loading = false
    @State private var narrative: WeeklyNarrative?
    @State private var error: String?

    private var report: WeeklyReport {
        WeeklyReport.make(logs: logs, foods: foods, weights: profile.weights, analysis: profile.analysis)
    }

    /// Latest photo and the one closest to a week before it.
    private var photoPair: (before: ProgressPhoto, after: ProgressPhoto)? {
        guard let after = photos.last, photos.count >= 2 else { return nil }
        let target = after.date.addingTimeInterval(-7 * 86400)
        let candidates = photos.dropLast()
        guard let before = candidates.min(by: { abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target)) }) else { return nil }
        return (before, after)
    }

    var body: some View {
        let r = report
        ScrollView {
            VStack(spacing: 16) {
                numbersCard(r)
                if !r.highlights.isEmpty { listCard("Cosa è andato bene", "checkmark.seal.fill", Theme.accent, r.highlights) }
                if !r.tips.isEmpty { listCard("Su cosa lavorare", "lightbulb.fill", Theme.recover, r.tips) }
                aiCard(r)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Ultimi 7 giorni")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Inviare i dati per l'analisi?", isPresented: $confirmSend, titleVisibility: .visible) {
            Button("Invia e analizza") { runAnalysis(r, useClaude: true) }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text(includePhotos
                 ? "I numeri della settimana e due tue foto vengono inviati a \(ClaudeClient.providerName) con la tua chiave API.\(ClaudeClient.privacyNote) Leggi le loro condizioni sulla privacy prima di procedere."
                 : "I numeri della settimana vengono inviati a \(ClaudeClient.providerName) con la tua chiave API. Nessuna foto.")
        }
    }

    private func numbersCard(_ r: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                stat("Allenamenti", "\(r.workouts)", sub: "prima \(r.prevWorkouts)")
                stat("Volume", "\(Int(r.volume / 1000)) t", sub: r.volumeChangePercent.map { "\($0 >= 0 ? "+" : "")\(Int($0.rounded()))%" } ?? "—")
                stat("Record", "\(r.prCount)", sub: "questa settimana")
            }
            Divider()
            HStack {
                stat("Calorie medie", r.avgKcal.map { "\(Int($0))" } ?? "—", sub: "obiettivo \(Int(r.targetKcal))")
                stat("Proteine medie", r.avgProtein.map { "\(Int($0)) g" } ?? "—", sub: "obiettivo \(Int(r.targetProtein)) g")
                stat("Giorni cibo", "\(r.daysLogged)/7", sub: "registrati")
            }
            if r.weightChange != nil || r.waistChange != nil {
                Divider()
                HStack {
                    stat("Peso", r.weightChange.map { "\($0 >= 0 ? "+" : "")\(String(format: "%.1f", $0)) kg" } ?? "—", sub: "vs settimana scorsa")
                    stat("Vita", r.waistChange.map { "\($0 >= 0 ? "+" : "")\(String(format: "%.1f", $0)) cm" } ?? "—", sub: "vs settimana scorsa")
                }
            }
        }
        .padding(20)
        .card()
    }

    private func stat(_ title: String, _ value: String, sub: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title3, design: .rounded, weight: .bold)).contentTransition(.numericText())
            Text(title).font(.caption)
            Text(sub).font(.caption2).foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func listCard(_ title: String, _ icon: String, _ color: Color, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline).foregroundStyle(color)
            ForEach(items, id: \.self) { Text("• \($0)").font(.subheadline) }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func aiCard(_ r: WeeklyReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Analisi AI", systemImage: "sparkles").font(.headline)
            if AIEngine.appleStatus.isAvailable {
                Button { runAnalysis(r, useClaude: false) } label: {
                    HStack { if loading { ProgressView() }; Image(systemName: "apple.intelligence"); Text("Analizza sul telefono (gratis, privato)") }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).foregroundStyle(.black).disabled(loading)
            } else {
                Text("Apple Intelligence non disponibile (\(AIEngine.appleStatus.label)). Il riepilogo qui sopra funziona comunque, senza AI.")
                    .font(.footnote).foregroundStyle(Theme.secondaryText)
            }
            if ClaudeClient.hasKey {
                if photoPair != nil {
                    Toggle("Con Claude: includi il confronto tra le ultime due foto", isOn: $includePhotos).font(.subheadline)
                }
                Button { confirmSend = true } label: {
                    HStack { if loading { ProgressView() }; Text("Analizza con Claude") }.frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).disabled(loading)
            }
            if let error { Text(error).font(.footnote).foregroundStyle(Theme.move) }
            if let n = narrative {
                Text(n.summary).font(.subheadline)
                ForEach(n.observations, id: \.self) { Text("• \($0)").font(.footnote) }
                if !n.suggestions.isEmpty {
                    Text("Suggerimenti").font(.footnote.weight(.semibold))
                    ForEach(n.suggestions, id: \.self) { Text("• \($0)").font(.footnote) }
                }
                if !n.caution.isEmpty { Text(n.caution).font(.caption).foregroundStyle(Theme.secondaryText) }
            }
            Text("Analisi automatica, non consiglio medico. Le foto sono poco affidabili per giudicare i cambiamenti: contano di più i dati misurati.")
                .font(.caption2).foregroundStyle(Theme.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .animation(Motion.smooth, value: narrative?.summary)
    }

    private func runAnalysis(_ r: WeeklyReport, useClaude: Bool) {
        loading = true
        error = nil
        let pair = (useClaude && includePhotos) ? photoPair : nil
        let stats = r.statsJSON
        let (before, after) = (pair?.before.filename, pair?.after.filename)
        Task {
            do {
                narrative = useClaude
                    ? try await PhotoAnalyzer.weeklyNarrative(statsJSON: stats, beforeFile: before, afterFile: after)
                    : try await AppleHelpers.narrative(statsJSON: stats)
            } catch {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }
}
