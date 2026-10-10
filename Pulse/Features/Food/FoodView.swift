import SwiftUI
import SwiftData

struct FoodView: View {
    @State private var day = Calendar.current.startOfDay(for: .now)

    var body: some View {
        NavigationStack {
            FoodDayView(day: day)
                .background(Theme.background.ignoresSafeArea())
                .navigationTitle("Cibo")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Giorno prima", systemImage: "chevron.left") { shift(-1) }
                    }
                    ToolbarItem(placement: .principal) {
                        Button(dayTitle) { day = Calendar.current.startOfDay(for: .now) }
                            .font(.headline)
                            .contentTransition(.numericText())
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Giorno dopo", systemImage: "chevron.right") { shift(1) }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var dayTitle: String {
        if Calendar.current.isDateInToday(day) { return "Oggi" }
        if Calendar.current.isDateInYesterday(day) { return "Ieri" }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private func shift(_ delta: Int) {
        withAnimation(Motion.snappy) {
            day = Calendar.current.date(byAdding: .day, value: delta, to: day) ?? day
        }
    }
}

private struct FoodDayView: View {
    let day: Date
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var profile
    @Query private var entries: [FoodEntry]
    @State private var addingTo: Meal?
    @State private var editing: FoodEntry?

    init(day: Date) {
        self.day = day
        let start = Calendar.current.startOfDay(for: day)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _entries = Query(filter: #Predicate<FoodEntry> { $0.date >= start && $0.date < end }, sort: \FoodEntry.date)
    }

    private var eaten: (kcal: Double, p: Double, c: Double, f: Double) {
        var t = (kcal: 0.0, p: 0.0, c: 0.0, f: 0.0)
        for e in entries {
            t.kcal += e.kcal
            t.p += e.protein
            t.c += e.carbs
            t.f += e.fat
        }
        return t
    }

    var body: some View {
        let a = profile.analysis
        ScrollView {
            VStack(spacing: 16) {
                summary(a)
                ForEach(Meal.allCases) { meal in
                    mealCard(meal)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .sheet(item: $addingTo) { meal in AddFoodSheet(meal: meal, day: day) }
        .sheet(item: $editing) { EntryEditor(entry: $0) }
    }

    private func summary(_ a: BodyAnalysis) -> some View {
        let target = max(a.targetCalories, 1)
        let remaining = target - eaten.kcal
        return VStack(spacing: 16) {
            HStack(spacing: 20) {
                ZStack {
                    ProgressRing(progress: eaten.kcal / target, color: remaining >= 0 ? Theme.accent : Theme.move, lineWidth: 14)
                    VStack(spacing: 0) {
                        Text("\(Int(abs(remaining)))")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .contentTransition(.numericText())
                        Text(remaining >= 0 ? "rimaste" : "oltre").font(.caption2).foregroundStyle(Theme.secondaryText)
                    }
                }
                .frame(width: 120, height: 120)
                .animation(Motion.smooth, value: eaten.kcal)

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(Int(eaten.kcal)) / \(Int(target)) kcal").font(.headline).contentTransition(.numericText())
                    Text("Obiettivo: \(profile.profile.goal.label.lowercased())").font(.caption).foregroundStyle(Theme.secondaryText)
                }
                Spacer(minLength: 0)
            }
            macroRow("Proteine", eaten.p, a.proteinG, Theme.move)
            macroRow("Carboidrati", eaten.c, a.carbsG, Theme.train)
            macroRow("Grassi", eaten.f, a.fatG, Theme.recover)
        }
        .padding(20)
        .card()
    }

    private func macroRow(_ name: String, _ value: Double, _ target: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(.caption)
                Spacer()
                Text("\(Int(value)) / \(Int(target)) g").font(.caption.weight(.semibold)).contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(color).frame(width: geo.size.width * min(value / max(target, 1), 1))
                }
            }
            .frame(height: 6)
            .animation(Motion.smooth, value: value)
        }
    }

    private func mealCard(_ meal: Meal) -> some View {
        let items = entries.filter { $0.meal == meal }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(meal.label, systemImage: meal.symbol).font(.headline)
                Spacer()
                Text("\(Int(items.reduce(0) { $0 + $1.kcal })) kcal")
                    .font(.subheadline).foregroundStyle(Theme.secondaryText)
                    .contentTransition(.numericText())
                Menu {
                    Button("Copia da ieri", systemImage: "doc.on.doc") { copyFromYesterday(meal) }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(Theme.secondaryText)
                }
                Button { addingTo = meal } label: {
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Theme.accent)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Aggiungi a \(meal.label)")
            }
            ForEach(items) { entry in
                HStack {
                    Button { editing = entry } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(entry.name).font(.subheadline).lineLimit(1).foregroundStyle(.white)
                            Text("\(formatWeight(entry.grams)) g · P \(Int(entry.protein)) C \(Int(entry.carbs)) G \(Int(entry.fat))")
                                .font(.caption).foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text("\(Int(entry.kcal))").font(.subheadline.weight(.semibold))
                    Button { withAnimation(Motion.snappy) { context.delete(entry) } } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Elimina \(entry.name)")
                }
                .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .animation(Motion.snappy, value: items.count)
    }

    private func copyFromYesterday(_ meal: Meal) {
        let cal = Calendar.current
        guard let yStart = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: day)) else { return }
        let yEnd = cal.startOfDay(for: day)
        let mealRaw = meal.rawValue
        let d = FetchDescriptor<FoodEntry>(predicate: #Predicate { $0.date >= yStart && $0.date < yEnd && $0.mealRaw == mealRaw })
        let old = (try? context.fetch(d)) ?? []
        let when = cal.isDateInToday(day) ? Date() : (cal.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day)
        for e in old {
            context.insert(FoodEntry(date: when, meal: meal, name: e.name, grams: e.grams, kcal: e.kcal,
                                     protein: e.protein, carbs: e.carbs, fat: e.fat, itemKey: e.itemKey))
        }
        try? context.save()
    }
}

extension Meal: Hashable {}

private struct EntryEditor: View {
    let entry: FoodEntry
    @Environment(\.dismiss) private var dismiss
    @State private var grams: Double

    init(entry: FoodEntry) {
        self.entry = entry
        _grams = State(initialValue: entry.grams)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(entry.name) {
                    HStack {
                        Text("Quantità (g)")
                        Spacer()
                        TextField("0", value: $grams, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
                    }
                }
            }
            .navigationTitle("Modifica porzione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        guard grams > 0, entry.grams > 0 else { return }
                        let f = grams / entry.grams
                        entry.kcal *= f
                        entry.protein *= f
                        entry.carbs *= f
                        entry.fat *= f
                        entry.grams = grams
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
