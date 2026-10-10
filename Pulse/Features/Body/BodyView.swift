import SwiftUI
import Charts

struct BodyView: View {
    @Environment(ProfileStore.self) private var store
    @State private var showEditor = false
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let a = store.analysis
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    compositionCard(a).entrance(0, shown: shown, reduceMotion: reduceMotion)
                    caloriesCard(a).entrance(1, shown: shown, reduceMotion: reduceMotion)
                    macrosCard(a).entrance(2, shown: shown, reduceMotion: reduceMotion)
                    weightCard(a).entrance(3, shown: shown, reduceMotion: reduceMotion)
                    waistCard.entrance(4, shown: shown, reduceMotion: reduceMotion)
                    NavigationLink { ProgressPhotosView() } label: {
                        HStack {
                            Label("Foto progressi", systemImage: "photo.on.rectangle.angled").font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.secondaryText)
                        }
                        .padding(20)
                        .card()
                    }
                    .buttonStyle(PressableStyle())
                    .entrance(5, shown: shown, reduceMotion: reduceMotion)
                    Text("Sono stime, non consigli medici. In caso di dubbi parla con un medico.")
                        .font(.caption).foregroundStyle(Theme.secondaryText).multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Corpo")
            .toolbar {
                Button("Modifica dati", systemImage: "slider.horizontal.3") { showEditor = true }
            }
            .sheet(isPresented: $showEditor) { ProfileEditor(store: store) }
            .onAppear { shown = true }
        }
        .animation(Motion.smooth, value: store.profile)
    }

    private func compositionCard(_ a: BodyAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 20) {
                ZStack {
                    ProgressRing(progress: a.bodyFat.percent / 40, color: Theme.move, lineWidth: 14)
                    VStack(spacing: 0) {
                        Text("\(a.bodyFat.percent, format: .number.precision(.fractionLength(1)))%")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .contentTransition(.numericText())
                        Text("grasso").font(.caption2).foregroundStyle(Theme.secondaryText)
                    }
                }
                .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 10) {
                    row("BMI", String(format: "%.1f · %@", a.bmi, a.bmiCategory))
                    row("Massa magra", String(format: "%.1f kg", a.leanMassKg))
                    row("Massa grassa", String(format: "%.1f kg", a.fatMassKg))
                    row("Peso ideale", String(format: "%.0f–%.0f kg", a.idealWeightRange.lowerBound, a.idealWeightRange.upperBound))
                }
            }
            Text("\(a.bodyFatLabel) · \(a.bodyFat.method)").font(.footnote).foregroundStyle(Theme.secondaryText)
            if let r = a.waistToHeight {
                Text(r > 0.5 ? "Vita/altezza \(r, format: .number.precision(.fractionLength(2))): sopra 0,5, vale la pena tenerla d'occhio."
                             : "Vita/altezza \(r, format: .number.precision(.fractionLength(2))): nella zona buona (sotto 0,5).")
                    .font(.footnote).foregroundStyle(Theme.secondaryText)
            }
            Text(store.profile.bodyType.tip).font(.footnote).foregroundStyle(Theme.recover)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func row(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption).foregroundStyle(Theme.secondaryText)
            Text(value).font(.subheadline.weight(.semibold)).contentTransition(.numericText())
        }
    }

    private func caloriesCard(_ a: BodyAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("OBIETTIVO CALORICO").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            Text("\(Int(a.targetCalories)) kcal")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
                .contentTransition(.numericText())
            HStack {
                row("Metabolismo basale", "\(Int(a.bmr)) kcal")
                Spacer()
                row("Mantenimento", "\(Int(a.tdee)) kcal")
                Spacer()
                row("Acqua", String(format: "%.1f L", a.waterLiters))
            }
            Text("Obiettivo: \(store.profile.goal.label.lowercased()) (\(Int(store.profile.goal.adjustment * 100))% sul mantenimento)")
                .font(.footnote).foregroundStyle(Theme.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func macrosCard(_ a: BodyAnalysis) -> some View {
        let total = max(a.proteinG * 4 + a.carbsG * 4 + a.fatG * 9, 1)
        return VStack(alignment: .leading, spacing: 14) {
            Text("MACRO GIORNALIERI").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            macroBar("Proteine", a.proteinG, a.proteinG * 4 / total, Theme.move)
            macroBar("Carboidrati", a.carbsG, a.carbsG * 4 / total, Theme.train)
            macroBar("Grassi", a.fatG, a.fatG * 9 / total, Theme.recover)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func macroBar(_ name: String, _ grams: Double, _ fraction: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.subheadline)
                Spacer()
                Text("\(Int(grams)) g").font(.subheadline.weight(.semibold)).contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(color).frame(width: shown ? geo.size.width * fraction : 0)
                }
            }
            .frame(height: 8)
        }
    }

    @ViewBuilder
    private var waistCard: some View {
        let points = store.weights.filter { $0.waistCm != nil }
        if points.count >= 2 {
            VStack(alignment: .leading, spacing: 12) {
                Text("VITA (cm)").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                Chart(points) { w in
                    LineMark(x: .value("Data", w.date), y: .value("cm", w.waistCm ?? 0))
                        .foregroundStyle(Theme.recover).interpolationMethod(.catmullRom)
                    PointMark(x: .value("Data", w.date), y: .value("cm", w.waistCm ?? 0)).foregroundStyle(Theme.recover)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 140)
            }
            .padding(20)
            .card()
        }
    }

    private func weightCard(_ a: BodyAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PESO").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                Spacer()
                Button("Registra \(store.profile.weightKg, format: .number.precision(.fractionLength(1))) kg oggi") {
                    store.logWeight(store.profile.weightKg)
                }
                .font(.footnote.weight(.semibold))
                .buttonStyle(.bordered)
                .sensoryFeedback(.success, trigger: store.weights.count)
            }
            if store.weights.count >= 2 {
                Chart(store.weights) { w in
                    LineMark(x: .value("Data", w.date), y: .value("kg", w.kg))
                        .foregroundStyle(Theme.accent).interpolationMethod(.catmullRom)
                    PointMark(x: .value("Data", w.date), y: .value("kg", w.kg)).foregroundStyle(Theme.accent)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 160)
            } else {
                Text("Registra il peso in giorni diversi per vedere il trend.")
                    .font(.footnote).foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(20)
        .card()
    }
}

private struct ProfileEditor: View {
    let store: ProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section("Dati base") {
                    Picker("Sesso", selection: $store.profile.sex) {
                        ForEach(Sex.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Stepper("Età: \(store.profile.age)", value: $store.profile.age, in: 14...90)
                    Stepper("Altezza: \(Int(store.profile.heightCm)) cm", value: $store.profile.heightCm, in: 120...230)
                    Stepper("Peso: \(store.profile.weightKg, format: .number.precision(.fractionLength(1))) kg",
                            value: $store.profile.weightKg, in: 35...250, step: 0.5)
                }
                Section {
                    TextField("Vita (cm)", value: $store.profile.waistCm, format: .number).keyboardType(.decimalPad)
                    TextField("Collo (cm)", value: $store.profile.neckCm, format: .number).keyboardType(.decimalPad)
                    if store.profile.sex == .female {
                        TextField("Fianchi (cm)", value: $store.profile.hipCm, format: .number).keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Misure (opzionali)")
                } footer: {
                    Text("Con vita e collo la stima del grasso corporeo è molto più precisa. Misura la vita all'altezza dell'ombelico.")
                }
                Section("Stile di vita") {
                    Picker("Attività", selection: $store.profile.activity) {
                        ForEach(ActivityLevel.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Obiettivo", selection: $store.profile.goal) {
                        ForEach(Goal.allCases) { Text($0.label).tag($0) }
                    }
                    Picker("Corporatura", selection: $store.profile.bodyType) {
                        ForEach(BodyType.allCases) { Text($0.label).tag($0) }
                    }
                }
            }
            .navigationTitle("I tuoi dati")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fine") { dismiss() } }
        }
        .presentationDetents([.large])
    }
}
