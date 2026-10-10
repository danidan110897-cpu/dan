import SwiftUI
import SwiftData
import PhotosUI

/// First-launch flow: welcome, privacy, your data, goal and training, optional first photo, then your calorie plan and first workouts.
struct OnboardingView: View {
    @Environment(ProfileStore.self) private var store
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    let onFinish: () -> Void

    enum Place: String, CaseIterable, Identifiable {
        case gym, home, bodyweight
        var id: String { rawValue }
        var label: String {
            switch self {
            case .gym: "Palestra completa"
            case .home: "Casa con manubri"
            case .bodyweight: "Solo corpo libero"
            }
        }
        var equipment: Set<Equipment> {
            switch self {
            case .gym: Set(Equipment.allCases)
            case .home: [.dumbbell, .bodyweight, .kettlebell]
            case .bodyweight: [.bodyweight]
            }
        }
    }

    private let lastPage = 5

    @State private var page = 0
    @State private var forward = true
    @State private var appeared = false
    @State private var acceptedPrivacy = false

    @State private var level: TrainingLevel = .beginner
    @State private var days = 3
    @State private var place: Place = .gym

    @State private var pickedPhoto: PhotosPickerItem?
    @State private var showCamera = false
    @State private var photoFile: String?
    @State private var estimating = false
    @State private var estimateText: String?
    @State private var estimateError: String?
    @State private var confirmSend = false
    @State private var claudeKey = KeychainStore.get(ClaudeGenerator.keychainAccount) ?? ""

    @State private var outcome: RoutinePlanner.Outcome?
    @State private var planning = false
    @State private var planError: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 0) {
            ZStack {
                switch page {
                case 0: welcome
                case 1: privacy
                case 2: basics($store.profile)
                case 3: goal($store.profile)
                case 4: photo
                default: summary
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                    removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
            .id(page)

            dots
            controls
        }
        .background(Theme.background.ignoresSafeArea())
        .animation(reduceMotion ? .none : Motion.smooth, value: page)
        .onAppear { appeared = true }
        .confirmationDialog("Inviare la foto per la stima?", isPresented: $confirmSend, titleVisibility: .visible) {
            Button("Invia e stima") { estimate() }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("La foto viene inviata ad Anthropic con la tua chiave API solo per questa stima. Leggi le loro condizioni sulla privacy prima di procedere.")
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { data in savePhoto(data); showCamera = false }.ignoresSafeArea()
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { savePhoto(data) }
                pickedPhoto = nil
            }
        }
    }

    // MARK: Chrome

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(0...lastPage, id: \.self) { i in
                Capsule()
                    .fill(i == page ? Theme.accent : Color.white.opacity(0.2))
                    .frame(width: i == page ? 24 : 8, height: 8)
                    .animation(Motion.bouncy, value: page)
            }
        }
        .padding(.bottom, 12)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if page > 0 {
                Button { go(-1) } label: {
                    Image(systemName: "chevron.left").font(.headline).foregroundStyle(.white)
                        .frame(width: 54, height: 54).background(Color.white.opacity(0.1), in: Circle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Indietro")
            }
            Button {
                if page < lastPage { go(1) } else { finish() }
            } label: {
                Text(page == lastPage ? "Inizia" : page == 4 && photoFile == nil ? "Salta questo passaggio" : "Continua")
                    .font(.headline).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(canContinue ? Theme.accent : Color.gray.opacity(0.4), in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .disabled(!canContinue || (page == lastPage && planning))
            .sensoryFeedback(.selection, trigger: page)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var canContinue: Bool { page != 1 || acceptedPrivacy }

    private func go(_ delta: Int) {
        forward = delta > 0
        page = min(max(page + delta, 0), lastPage)
        if page == lastPage { buildPlan() }
    }

    // MARK: Pages

    private var welcome: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: 80)).foregroundStyle(Theme.accent)
                .symbolEffect(.bounce, value: appeared)
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)
                .animation(reduceMotion ? .none : Motion.bouncy, value: appeared)
            Text("Pulse").font(.system(size: 44, weight: .bold, design: .rounded))
            Text("Allenamenti, cibo e recupero in un posto solo.\nTi chiediamo qualche dato per calcolare calorie e primo programma.")
                .multilineTextAlignment(.center).foregroundStyle(Theme.secondaryText)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    private var privacy: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("La tua privacy").font(.system(size: 30, weight: .bold, design: .rounded)).padding(.top, 32)
                point("iphone", "Tutto resta sul tuo iPhone", "Nessun account e nessun nostro server: allenamenti, cibo, peso e foto sono salvati solo sul telefono.")
                point("lock.shield", "Foto protette", "Le foto sono salvate nell'app con protezione dei file, non entrano nella libreria Foto e sono escluse dai backup iCloud.")
                point("eye.slash", "Niente pubblicità, niente vendita di dati", "Non condividiamo nulla con nessuno.")
                point("paperplane", "Esce dal telefono solo se lo scegli tu", "Ricerca di cibi (il testo cercato va a Open Food Facts e USDA), analisi con Claude con la tua chiave e dopo conferma, e Salute di Apple se acconsenti.")
                point("faceid", "Blocco e cancellazione", "Puoi bloccare l'app con Face ID o codice, esportare tutto in JSON e cancellare ogni dato dalle Impostazioni.")
                Toggle("Ho capito e voglio continuare", isOn: $acceptedPrivacy)
                    .font(.headline)
                    .padding(16).card()
                    .sensoryFeedback(.selection, trigger: acceptedPrivacy)
            }
            .padding(.horizontal, 24)
        }
    }

    private func point(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title3).foregroundStyle(Theme.accent).frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func basics(_ profile: Binding<BodyProfile>) -> some View {
        VStack(spacing: 8) {
            Text("Parlaci di te").font(.system(size: 30, weight: .bold, design: .rounded)).padding(.top, 32)
            Text("Servono per stimare calorie e composizione corporea.")
                .font(.subheadline).foregroundStyle(Theme.secondaryText)
            Form {
                Picker("Sesso", selection: profile.sex) {
                    ForEach(Sex.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Stepper("Età: \(profile.wrappedValue.age)", value: profile.age, in: 14...90)
                Stepper("Altezza: \(Int(profile.wrappedValue.heightCm)) cm", value: profile.heightCm, in: 120...230)
                Stepper("Peso: \(profile.wrappedValue.weightKg.formatted(.number.precision(.fractionLength(1)))) kg",
                        value: profile.weightKg, in: 35...250, step: 0.5)
                Section {
                    TextField("Vita (cm)", value: profile.waistCm, format: .number).keyboardType(.decimalPad)
                    TextField("Collo (cm)", value: profile.neckCm, format: .number).keyboardType(.decimalPad)
                    if profile.wrappedValue.sex == .female {
                        TextField("Fianchi (cm)", value: profile.hipCm, format: .number).keyboardType(.decimalPad)
                    }
                } header: { Text("Misure (facoltative)") } footer: { Text("Rendono molto più precisa la stima del grasso corporeo. Vita all'altezza dell'ombelico.") }
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func goal(_ profile: Binding<BodyProfile>) -> some View {
        VStack(spacing: 8) {
            Text("Obiettivo e allenamento").font(.system(size: 28, weight: .bold, design: .rounded)).padding(.top, 32)
            Form {
                Section("Il tuo obiettivo") {
                    Picker("Obiettivo", selection: profile.goal) {
                        ForEach(Goal.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Attività quotidiana", selection: profile.activity) {
                        ForEach(ActivityLevel.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Corporatura", selection: profile.bodyType) {
                        ForEach(BodyType.allCases) { Text($0.label).tag($0) }
                    }
                }
                Section("Come ti alleni") {
                    Picker("Esperienza", selection: $level) {
                        ForEach(TrainingLevel.allCases) { Text($0.label).tag($0) }
                    }
                    Stepper("Giorni a settimana: \(days)", value: $days, in: 1...6)
                    Picker("Dove", selection: $place) {
                        ForEach(Place.allCases) { Text($0.label).tag($0) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    private var photo: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Foto iniziale").font(.system(size: 30, weight: .bold, design: .rounded)).padding(.top, 32)
                Text("Facoltativa. Serve come punto di partenza per i confronti e, se vuoi, per stimare il grasso corporeo e calcolare meglio il deficit.")
                    .font(.subheadline).foregroundStyle(Theme.secondaryText).multilineTextAlignment(.center)

                if let photoFile, let image = PhotoStorage.image(photoFile) {
                    ZStack(alignment: .bottomLeading) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(height: 240).frame(maxWidth: .infinity).clipped()
                        Label("Salvata solo su questo iPhone", systemImage: "lock.fill")
                            .font(.caption.weight(.semibold)).padding(8)
                            .background(.black.opacity(0.65), in: Capsule()).padding(10)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .transition(.scale.combined(with: .opacity))
                }

                HStack {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button("Scatta", systemImage: "camera.fill") { showCamera = true }
                    }
                    PhotosPicker(selection: $pickedPhoto, matching: .images) { Label("Libreria", systemImage: "photo") }
                }
                .buttonStyle(.bordered)

                Text("Meglio in piedi, frontale, luce uniforme, abbigliamento aderente. Nessuno vede la foto: resta nell'app.")
                    .font(.caption).foregroundStyle(Theme.secondaryText).multilineTextAlignment(.center)

                if photoFile != nil { estimateSection }
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var estimateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.profile.age < 18 {
                Text("La stima dalla foto è disponibile solo per maggiorenni.").font(.footnote).foregroundStyle(Theme.secondaryText)
            } else if ClaudeClient.hasKey {
                Button { confirmSend = true } label: {
                    HStack { if estimating { ProgressView() }; Image(systemName: "sparkles"); Text("Stima il grasso corporeo dalla foto") }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).foregroundStyle(.black).disabled(estimating)
            } else {
                Text("La lettura delle foto richiede per ora la chiave API di Anthropic (facoltativa): l'Apple Intelligence sul telefono, per ora, legge solo testo. Senza chiave useremo le tue misure o il BMI.")
                    .font(.footnote).foregroundStyle(Theme.secondaryText)
                SecureField("Chiave API (sk-ant-…)", text: $claudeKey)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(10).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                    .onSubmit { KeychainStore.set(claudeKey, for: ClaudeGenerator.keychainAccount) }
                Button("Salva chiave") { KeychainStore.set(claudeKey, for: ClaudeGenerator.keychainAccount); estimateError = nil }
                    .buttonStyle(.bordered).disabled(claudeKey.isEmpty)
            }
            if let estimateText {
                Label(estimateText, systemImage: "checkmark.seal.fill").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
            }
            if let estimateError { Text(estimateError).font(.footnote).foregroundStyle(Theme.move) }
            Text("È una stima, con un margine di errore di diversi punti percentuali. Non è una misura medica.")
                .font(.caption2).foregroundStyle(Theme.secondaryText)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private var summary: some View {
        let a = store.analysis
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Il tuo piano").font(.system(size: 30, weight: .bold, design: .rounded)).padding(.top, 32)

                VStack(alignment: .leading, spacing: 10) {
                    Text("CALORIE").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                    Text("\(Int(a.targetCalories)) kcal al giorno")
                        .font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(Theme.accent)
                    Text(deltaText(a)).font(.subheadline)
                    if let note = a.adjustmentNote { Text(note).font(.footnote).foregroundStyle(.orange) }
                    Divider()
                    Text("Grasso corporeo stimato: \(Int(a.bodyFat.percent.rounded()))% · \(a.bodyFat.method)")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                    Text("Metabolismo basale \(Int(a.bmr)) · mantenimento \(Int(a.tdee)) · proteine \(Int(a.proteinG)) g")
                        .font(.footnote).foregroundStyle(Theme.secondaryText)
                }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading).card()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("PRIMO PROGRAMMA").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                        Spacer()
                        if planning { ProgressView() }
                    }
                    if let outcome {
                        ForEach(outcome.plan.routines) { r in
                            HStack {
                                Image(systemName: "dumbbell.fill").foregroundStyle(Theme.accent)
                                Text(r.name).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text("\(r.exercises.count) esercizi").font(.caption).foregroundStyle(Theme.secondaryText)
                            }
                        }
                        Text("Creato con: \(outcome.used.label)").font(.caption).foregroundStyle(Theme.recover)
                        if let reason = outcome.fallbackReason {
                            Text("L'AI non ha risposto (\(reason)): ho usato le regole sul telefono.").font(.caption).foregroundStyle(.orange)
                        }
                    } else if let planError {
                        Text(planError).font(.footnote).foregroundStyle(Theme.move)
                    } else {
                        Text("Sto preparando gli allenamenti in base a obiettivo, esperienza e giorni…")
                            .font(.footnote).foregroundStyle(Theme.secondaryText)
                    }
                }
                .padding(20).frame(maxWidth: .infinity, alignment: .leading).card()

                Text("Sono stime e una bozza modificabile, non indicazioni mediche. Puoi cambiare tutto quando vuoi dal tab Corpo e da Allenamenti.")
                    .font(.caption).foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, 24)
        }
    }

    private func deltaText(_ a: BodyAnalysis) -> String {
        let delta = Int(a.calorieDelta)
        if delta == 0 { return "Mantenimento: nessun deficit né surplus." }
        let weekly = String(format: "%.2f", abs(a.expectedWeeklyChangeKg))
        return delta < 0
            ? "Deficit di \(-delta) kcal al giorno: circa \(weekly) kg in meno a settimana."
            : "Surplus di \(delta) kcal al giorno: circa \(weekly) kg in più a settimana."
    }

    // MARK: Actions

    private func savePhoto(_ data: Data) {
        guard let name = PhotoStorage.save(data) else { return }
        if let old = photoFile { PhotoStorage.delete(old) }
        photoFile = name
        estimateText = nil
        estimateError = nil
        withAnimation(Motion.smooth) {}
    }

    private func estimate() {
        guard let photoFile else { return }
        estimating = true
        estimateError = nil
        let profile = store.profile
        Task {
            do {
                let result = try await PhotoAnalyzer.estimate(photoFile: photoFile, profile: profile)
                store.profile.photoBodyFat = (result.low + result.high) / 2
                estimateText = "Stima: \(Int(result.low.rounded()))–\(Int(result.high.rounded()))% di grasso corporeo"
            } catch {
                estimateError = error.localizedDescription
            }
            estimating = false
        }
    }

    private func buildPlan() {
        planning = true
        planError = nil
        outcome = nil
        ExerciseSeed.seedIfNeeded(context)
        let library = ExerciseSeed.libraryEntries
        var request = GenerationRequest()
        switch store.profile.goal {
        case .cut: request.goal = .fatLoss
        case .bulk: request.goal = .hypertrophy
        case .maintain: request.goal = .general
        }
        request.level = level
        request.daysPerWeek = days
        request.equipment = place.equipment
        Task {
            do {
                outcome = try await RoutinePlanner.generate(request, library: library, choice: AIEngine.automatic, allowFallback: true)
            } catch {
                planError = "Non sono riuscito a creare il programma: lo puoi fare dopo da Allenamenti."
            }
            planning = false
        }
    }

    private func finish() {
        store.profile.trainingDays = days
        store.profile.trainingLevel = level.rawValue
        store.profile.trainingPlace = place.rawValue
        store.logWeight(store.profile.weightKg)

        if let photoFile {
            context.insert(ProgressPhoto(date: .now, filename: photoFile, note: "Foto iniziale", weightKg: store.profile.weightKg))
        }
        if let outcome {
            let fetched = (try? context.fetch(FetchDescriptor<Exercise>())) ?? exercises
            RoutinePlanner.save(outcome.plan, restSeconds: store.profile.goal == .bulk ? 120 : 90, exercises: fetched, context: context)
        }
        try? context.save()
        onFinish()
    }
}
