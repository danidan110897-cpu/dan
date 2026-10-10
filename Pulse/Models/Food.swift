import SwiftData
import Foundation

enum Meal: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var label: String {
        switch self {
        case .breakfast: "Colazione"
        case .lunch: "Pranzo"
        case .dinner: "Cena"
        case .snack: "Spuntini"
        }
    }
    var symbol: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snack: "carrot.fill"
        }
    }
}

/// A food known to the app (searched, scanned or created by hand). Values are per 100 g.
@Model
final class FoodItem {
    @Attribute(.unique) var key: String
    var name: String
    var brand: String
    var kcal100: Double
    var protein100: Double
    var carbs100: Double
    var fat100: Double
    var servingGrams: Double
    var barcode: String
    var source: String
    var isFavorite: Bool
    var lastUsed: Date?

    init(from r: FoodResult) {
        key = r.key
        name = r.name
        brand = r.brand
        kcal100 = r.kcal100
        protein100 = r.protein100
        carbs100 = r.carbs100
        fat100 = r.fat100
        servingGrams = r.servingGrams
        barcode = r.barcode
        source = r.source
        isFavorite = false
        lastUsed = nil
    }
}

/// One logged portion. Macros are stored as totals so later edits to the food never change history.
@Model
final class FoodEntry {
    var date: Date
    var mealRaw: String
    var name: String
    var grams: Double
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var itemKey: String

    init(date: Date, meal: Meal, name: String, grams: Double, kcal: Double, protein: Double, carbs: Double, fat: Double, itemKey: String) {
        self.date = date
        self.mealRaw = meal.rawValue
        self.name = name
        self.grams = grams
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.itemKey = itemKey
    }

    var meal: Meal { Meal(rawValue: mealRaw) ?? .snack }
}

/// A food coming from a search, a barcode scan or a stored item, before it is logged.
struct FoodResult: Identifiable, Hashable {
    var id: String { key }
    let key: String
    let name: String
    let brand: String
    let kcal100: Double
    let protein100: Double
    let carbs100: Double
    let fat100: Double
    let servingGrams: Double
    let barcode: String
    let source: String

    init(key: String, name: String, brand: String = "", kcal100: Double, protein100: Double, carbs100: Double,
         fat100: Double, servingGrams: Double = 0, barcode: String = "", source: String) {
        self.key = key
        self.name = name
        self.brand = brand
        self.kcal100 = kcal100
        self.protein100 = protein100
        self.carbs100 = carbs100
        self.fat100 = fat100
        self.servingGrams = servingGrams
        self.barcode = barcode
        self.source = source
    }

    init(item: FoodItem) {
        self.init(key: item.key, name: item.name, brand: item.brand, kcal100: item.kcal100,
                  protein100: item.protein100, carbs100: item.carbs100, fat100: item.fat100,
                  servingGrams: item.servingGrams, barcode: item.barcode, source: item.source)
    }

    func scaled(_ grams: Double) -> (kcal: Double, protein: Double, carbs: Double, fat: Double) {
        let f = grams / 100
        return (kcal100 * f, protein100 * f, carbs100 * f, fat100 * f)
    }
}

enum FoodLogger {
    /// Stores the food (for recents and favorites) and logs one portion of it.
    @MainActor
    @discardableResult
    static func add(_ food: FoodResult, grams: Double, meal: Meal, day: Date, context: ModelContext) -> FoodEntry {
        let item = upsert(food, context: context)
        item.lastUsed = .now
        let v = food.scaled(grams)
        let date = Calendar.current.isDateInToday(day) ? Date() : (Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day)
        let entry = FoodEntry(date: date, meal: meal, name: food.name, grams: grams,
                              kcal: v.kcal, protein: v.protein, carbs: v.carbs, fat: v.fat, itemKey: food.key)
        context.insert(entry)
        try? context.save()
        return entry
    }

    @MainActor
    @discardableResult
    static func upsert(_ food: FoodResult, context: ModelContext) -> FoodItem {
        let key = food.key
        var d = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.key == key })
        d.fetchLimit = 1
        if let existing = try? context.fetch(d).first { return existing }
        let item = FoodItem(from: food)
        context.insert(item)
        return item
    }
}
