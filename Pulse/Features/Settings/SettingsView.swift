import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @AppStorage("healthSync") private var healthSync = true
    @AppStorage("usdaKey") private var usdaKey = "DEMO_KEY"
    @AppStorage("playlistURL") private var playlistURL = ""
    @AppStorage("photoReminder") private var photoReminder = false
    @AppStorage("appLock") private var appLock = false
    @AppStorage("trainReminder") private var trainReminder = false
    @Query private var allRoutines: [Routine]
    @State private var claudeKey = KeychainStore.get(ClaudeGenerator.keychainAccount) ?? ""
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Apple Intelligence", value: AIEngine.appleStatus.label)
                    LabeledContent("In uso automaticamente", value: AIEngine.automatic.label)
                } header: {
                    Text("Intelligenza artificiale")
                } footer: {
                    Text("L'app controlla da sola se questo iPhone supporta Apple Intelligence e se è attiva. Se non lo è, usa Claude (se hai inserito una chiave) oppure le regole sul telefono, che sono gratuite. Per ora Apple Intelligence legge solo testo, quindi le foto si analizzano con Claude.")
                }

                Section {
                    Toggle("Blocca con Face ID o codice", isOn: $appLock)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("I tuoi dati restano su questo iPhone. Le foto non vanno nella libreria Foto né nei backup iCloud. Dati e foto escono dal telefono solo se scegli un servizio esterno (ricerca cibi, analisi con Claude, Salute).")
                }

                Section {
                    Toggle("Scrivi cibo, peso e allenamenti in Salute", isOn: $healthSync)
                } header: {
                    Text("Salute")
                } footer: {
                    Text("Se non vedi i dati di recupero, controlla Impostazioni → Salute → Accesso ai dati → Pulse.")
                }

                Section {
                    SecureField("sk-ant-…", text: $claudeKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .onChange(of: claudeKey) { KeychainStore.set(claudeKey, for: ClaudeGenerator.keychainAccount) }
                } header: {
                    Text("Chiave API Claude (facoltativa)")
                } footer: {
                    Text("Serve solo per creare routine con Claude. Resta nel Keychain di questo iPhone. Senza chiave puoi usare i motori Regole e Apple Intelligence.")
                }

                Section {
                    TextField("DEMO_KEY", text: $usdaKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                } header: {
                    Text("Chiave USDA (facoltativa)")
                } footer: {
                    Text("DEMO_KEY ha un limite di richieste. Una chiave gratuita si ottiene su fdc.nal.usda.gov.")
                }

                Section {
                    TextField("https://open.spotify.com/playlist/…", text: $playlistURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                } header: {
                    Text("Playlist allenamento")
                } footer: {
                    Text("Incolla il link di una playlist (Spotify, YouTube Music o Apple Music): dal menu musica nell'allenamento si apre con un tocco. Il controllo della riproduzione dentro l'app è possibile solo con Spotify e non è ancora attivo.")
                }

                Section {
                    Toggle("Promemoria allenamento (18:00 nei giorni in programma)", isOn: $trainReminder)
                        .onChange(of: trainReminder) { _, on in
                            if on { Task { await Reminders.scheduleTraining(routines: allRoutines) } } else { Reminders.cancelTraining() }
                        }
                    Toggle("Promemoria foto e riepilogo (domenica 10:00)", isOn: $photoReminder)
                        .onChange(of: photoReminder) { _, on in
                            Task { if await Reminders.setWeeklyPhoto(enabled: on) == false { photoReminder = false } }
                        }
                } header: {
                    Text("Promemoria")
                }

                Section("I tuoi dati") {
                    Button("Esporta tutto (JSON)", systemImage: "square.and.arrow.up") { export() }
                    if let exportURL {
                        ShareLink(item: exportURL) { Label("Condividi il file esportato", systemImage: "doc") }
                    }
                    if let exportError { Text(exportError).font(.footnote).foregroundStyle(Theme.move) }
                    Button("Cancella tutti i dati", systemImage: "trash", role: .destructive) { confirmReset = true }
                }

                Section("Informazioni") {
                    LabeledContent("Versione", value: "0.1")
                    Text("Le stime di calorie, grasso corporeo e recupero sono indicative e non sostituiscono il parere di un medico.")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fine") { dismiss() } }
            .confirmationDialog("Cancellare tutti i dati?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Cancella allenamenti, cibo e foto", role: .destructive) { reset() }
            } message: {
                Text("Routine, cronologia, diario e foto vengono eliminati da questo iPhone. Non si può annullare.")
            }
        }
    }

    private func export() {
        do {
            let payload = try DataExport.build(context: context)
            let url = URL.temporaryDirectory.appending(path: "pulse-export-\(Date.now.formatted(.iso8601.year().month().day())).json")
            try payload.write(to: url, options: .atomic)
            exportURL = url
            exportError = nil
        } catch {
            exportError = "Esportazione non riuscita: \(error.localizedDescription)"
        }
    }

    private func reset() {
        try? context.delete(model: Routine.self)
        try? context.delete(model: WorkoutLog.self)
        try? context.delete(model: FoodEntry.self)
        try? context.delete(model: FoodItem.self)
        if let photos = try? context.fetch(FetchDescriptor<ProgressPhoto>()) {
            photos.forEach { PhotoStorage.delete($0.filename) }
        }
        try? context.delete(model: ProgressPhoto.self)
        try? context.save()
    }
}

/// Plain JSON export of everything the user logged, so data is never locked into the app.
enum DataExport {
    static func build(context: ModelContext) throws -> Data {
        var root: [String: Any] = ["exportedAt": ISO8601DateFormatter().string(from: .now), "app": "Pulse"]
        let iso = ISO8601DateFormatter()

        let routines = try context.fetch(FetchDescriptor<Routine>())
        root["routines"] = routines.map { r in
            [
                "name": r.name, "restSeconds": r.restSeconds,
                "items": r.sortedItems.map { i in
                    ["exercise": i.exercise?.name ?? "", "key": i.exercise?.key ?? "", "sets": i.sets, "reps": i.reps,
                     "weightKg": i.weight, "note": i.note] as [String: Any]
                },
            ] as [String: Any]
        }

        let logs = try context.fetch(FetchDescriptor<WorkoutLog>(sortBy: [SortDescriptor(\.date)]))
        root["workouts"] = logs.map { l in
            [
                "date": iso.string(from: l.date), "name": l.name, "durationSeconds": l.durationSeconds, "volumeKg": l.volume,
                "exercises": l.sortedEntries.map { e in
                    [
                        "name": e.exerciseName, "key": e.exerciseKey,
                        "sets": e.sortedSets.map { ["weightKg": $0.weight, "reps": $0.reps, "personalRecord": $0.isPR] as [String: Any] },
                    ] as [String: Any]
                },
            ] as [String: Any]
        }

        let food = try context.fetch(FetchDescriptor<FoodEntry>(sortBy: [SortDescriptor(\.date)]))
        root["food"] = food.map {
            ["date": iso.string(from: $0.date), "meal": $0.mealRaw, "name": $0.name, "grams": $0.grams,
             "kcal": $0.kcal, "proteinG": $0.protein, "carbsG": $0.carbs, "fatG": $0.fat] as [String: Any]
        }

        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }
}
