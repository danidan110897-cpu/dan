import SwiftUI
import SwiftData

struct AddFoodSheet: View {
    let meal: Meal
    let day: Date

    enum Mode: String, CaseIterable, Identifiable {
        case search = "Cerca", recent = "Recenti", favorites = "Preferiti", manual = "Nuovo"
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.lastUsed, order: .reverse) private var items: [FoodItem]
    @AppStorage("usdaKey") private var usdaKey = "DEMO_KEY"

    @State private var mode: Mode = .search
    @State private var query = ""
    @State private var results: [FoodResult] = []
    @State private var loading = false
    @State private var message: String?
    @State private var showScanner = false
    @State private var selected: FoodResult?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Modalità", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                switch mode {
                case .search: searchList
                case .recent: foodList(items.filter { $0.lastUsed != nil }.prefix(40).map(FoodResult.init(item:)),
                                       empty: "Qui compariranno gli alimenti che registri.")
                case .favorites: foodList(items.filter(\.isFavorite).map(FoodResult.init(item:)),
                                          empty: "Tocca la stella su un alimento per salvarlo qui.")
                case .manual: ManualFoodForm { selected = $0 }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(meal.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Scansiona", systemImage: "barcode.viewfinder") { showScanner = true }
                }
            }
            .sheet(item: $selected) { food in
                FoodDetailSheet(food: food, meal: meal, day: day) { dismiss() }
            }
            .fullScreenCover(isPresented: $showScanner) {
                ScannerScreen { code in
                    showScanner = false
                    lookup(barcode: code)
                }
            }
        }
    }

    private var searchList: some View {
        List {
            Section {
                TextField("Cerca un alimento o un prodotto", text: $query)
                    .submitLabel(.search)
                    .onSubmit(runSearch)
                    .autocorrectionDisabled()
            }
            .listRowBackground(Theme.card)

            if loading {
                HStack { ProgressView(); Text("Cerco…").foregroundStyle(Theme.secondaryText) }
                    .listRowBackground(Color.clear)
            }
            if let message {
                Text(message).font(.footnote).foregroundStyle(Theme.secondaryText).listRowBackground(Color.clear)
            }
            Section {
                ForEach(results) { food in row(food) }
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
    }

    private func foodList(_ foods: [FoodResult], empty: String) -> some View {
        List {
            if foods.isEmpty {
                Text(empty).font(.footnote).foregroundStyle(Theme.secondaryText).listRowBackground(Color.clear)
            }
            Section {
                ForEach(foods) { row($0) }
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
    }

    private func row(_ food: FoodResult) -> some View {
        Button { selected = food } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name).foregroundStyle(.white).lineLimit(2)
                Text("\(food.brand.isEmpty ? "" : food.brand + " · ")\(Int(food.kcal100)) kcal · P \(Int(food.protein100)) C \(Int(food.carbs100)) G \(Int(food.fat100)) per 100 g")
                    .font(.caption).foregroundStyle(Theme.secondaryText)
                Text(food.source).font(.caption2).foregroundStyle(Theme.recover)
            }
        }
        .buttonStyle(.plain)
    }

    private func runSearch() {
        searchTask?.cancel()
        message = nil
        loading = true
        let q = query
        searchTask = Task {
            let found = await FoodAPI.search(q, usdaKey: usdaKey)
            if Task.isCancelled { return }
            withAnimation(Motion.snappy) {
                results = found
                loading = false
                if found.isEmpty { message = "Nessun risultato. Controlla la connessione o crea l'alimento a mano (scheda Nuovo)." }
            }
        }
    }

    private func lookup(barcode: String) {
        mode = .search
        loading = true
        message = nil
        Task {
            let food = await FoodAPI.barcode(barcode)
            loading = false
            if let food { selected = food } else {
                message = "Prodotto \(barcode) non trovato. Puoi crearlo a mano nella scheda Nuovo."
            }
        }
    }
}

private struct ScannerScreen: View {
    let onCode: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var manualCode = ""

    var body: some View {
        NavigationStack {
            Group {
                if BarcodeScannerView.isAvailable {
                    BarcodeScannerView(onCode: onCode).ignoresSafeArea()
                } else {
                    Form {
                        Section("Scanner non disponibile su questo dispositivo") {
                            TextField("Inserisci il codice a barre", text: $manualCode).keyboardType(.numberPad)
                            Button("Cerca") { onCode(manualCode) }.disabled(manualCode.isEmpty)
                        }
                    }
                }
            }
            .navigationTitle("Codice a barre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } } }
        }
    }
}

private struct ManualFoodForm: View {
    let onCreate: (FoodResult) -> Void
    @State private var name = ""
    @State private var kcal: Double?
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?

    var body: some View {
        Form {
            Section {
                TextField("Nome", text: $name)
            }
            Section("Valori per 100 g") {
                field("Calorie (kcal)", $kcal)
                field("Proteine (g)", $protein)
                field("Carboidrati (g)", $carbs)
                field("Grassi (g)", $fat)
            }
            Button("Continua") {
                onCreate(FoodResult(key: "custom:\(UUID().uuidString)", name: name.trimmingCharacters(in: .whitespaces),
                                    kcal100: kcal ?? 0, protein100: protein ?? 0, carbs100: carbs ?? 0, fat100: fat ?? 0,
                                    source: "Creato da te"))
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || kcal == nil)
        }
        .scrollContentBackground(.hidden)
    }

    private func field(_ title: String, _ value: Binding<Double?>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number).keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing).frame(width: 90)
        }
    }
}

struct FoodDetailSheet: View {
    let food: FoodResult
    let meal: Meal
    let day: Date
    let onDone: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var stored: [FoodItem]
    @State private var grams: Double

    init(food: FoodResult, meal: Meal, day: Date, onDone: @escaping () -> Void) {
        self.food = food
        self.meal = meal
        self.day = day
        self.onDone = onDone
        let key = food.key
        _stored = Query(filter: #Predicate<FoodItem> { $0.key == key })
        _grams = State(initialValue: food.servingGrams > 0 ? food.servingGrams : 100)
    }

    private var isFavorite: Bool { stored.first?.isFavorite ?? false }

    var body: some View {
        let v = food.scaled(grams)
        NavigationStack {
            Form {
                Section {
                    Text(food.name).font(.headline)
                    if !food.brand.isEmpty { Text(food.brand).foregroundStyle(Theme.secondaryText) }
                }
                Section("Quantità") {
                    HStack {
                        Text("Grammi")
                        Spacer()
                        TextField("0", value: $grams, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            if food.servingGrams > 0 { preset("Porzione \(formatWeight(food.servingGrams)) g", food.servingGrams) }
                            ForEach([50.0, 100, 150, 200], id: \.self) { preset("\(Int($0)) g", $0) }
                        }
                    }
                }
                Section("Per questa quantità") {
                    LabeledContent("Calorie", value: "\(Int(v.kcal)) kcal")
                    LabeledContent("Proteine", value: "\(formatWeight(v.protein)) g")
                    LabeledContent("Carboidrati", value: "\(formatWeight(v.carbs)) g")
                    LabeledContent("Grassi", value: "\(formatWeight(v.fat)) g")
                }
            }
            .navigationTitle("Aggiungi a \(meal.label)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button(isFavorite ? "Rimuovi preferito" : "Preferito", systemImage: isFavorite ? "star.fill" : "star") {
                        let item = FoodLogger.upsert(food, context: context)
                        item.isFavorite.toggle()
                    }
                    .symbolEffect(.bounce, value: isFavorite)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    FoodLogger.add(food, grams: grams, meal: meal, day: day, context: context)
                    dismiss()
                    onDone()
                } label: {
                    Text("Aggiungi · \(Int(v.kcal)) kcal").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(.black)
                .disabled(grams <= 0)
                .padding()
                .sensoryFeedback(.success, trigger: grams)
            }
        }
        .presentationDetents([.large])
    }

    private func preset(_ title: String, _ value: Double) -> some View {
        Button { withAnimation(Motion.snappy) { grams = value } } label: {
            Text(title).font(.footnote.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(grams == value ? Theme.accent : Color.white.opacity(0.08), in: Capsule())
                .foregroundStyle(grams == value ? .black : .white)
        }
        .buttonStyle(PressableStyle())
    }
}
