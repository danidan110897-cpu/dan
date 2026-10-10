import Foundation

/// Food lookups. Barcodes and packaged products come from Open Food Facts, generic foods from USDA FoodData Central.
/// Both are public, free APIs; values are per 100 g.
enum FoodAPI {
    private static let userAgent = "Pulse/0.1 (personal fitness app)"

    // MARK: Public

    static func search(_ query: String, usdaKey: String) async -> [FoodResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return [] }
        async let off = try? searchOpenFoodFacts(q)
        async let usda = try? searchUSDA(translate(q), key: usdaKey)
        let (o, u) = await (off, usda)
        return (u ?? []) + (o ?? [])
    }

    static func barcode(_ code: String) async -> FoodResult? {
        let digits = code.filter(\.isNumber)
        guard !digits.isEmpty,
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(digits).json?fields=code,product_name,brands,nutriments,serving_quantity") else { return nil }
        guard let json = try? await fetchJSON(url),
              (json["status"] as? Int) == 1,
              let product = json["product"] as? [String: Any] else { return nil }
        return parseOFF(product)
    }

    // MARK: Open Food Facts

    private static func searchOpenFoodFacts(_ q: String) async throws -> [FoodResult] {
        var c = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        c.queryItems = [
            .init(name: "search_terms", value: q),
            .init(name: "search_simple", value: "1"),
            .init(name: "action", value: "process"),
            .init(name: "json", value: "1"),
            .init(name: "page_size", value: "20"),
            .init(name: "fields", value: "code,product_name,brands,nutriments,serving_quantity"),
        ]
        let json = try await fetchJSON(c.url!)
        let products = json["products"] as? [[String: Any]] ?? []
        return products.compactMap(parseOFF)
    }

    private static func parseOFF(_ p: [String: Any]) -> FoodResult? {
        let name = (p["product_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty, let n = p["nutriments"] as? [String: Any], let code = p["code"] as? String else { return nil }
        let protein = number(n["proteins_100g"]) ?? 0
        let carbs = number(n["carbohydrates_100g"]) ?? 0
        let fat = number(n["fat_100g"]) ?? 0
        let kcal = number(n["energy-kcal_100g"])
            ?? number(n["energy_100g"]).map { $0 / 4.184 }
            ?? (protein * 4 + carbs * 4 + fat * 9)
        guard kcal > 0 || protein > 0 || carbs > 0 || fat > 0 else { return nil }
        let brand = ((p["brands"] as? String) ?? "").components(separatedBy: ",").first ?? ""
        return FoodResult(key: "off:\(code)", name: name, brand: brand.trimmingCharacters(in: .whitespaces),
                          kcal100: kcal, protein100: protein, carbs100: carbs, fat100: fat,
                          servingGrams: number(p["serving_quantity"]) ?? 0, barcode: code, source: "Open Food Facts")
    }

    // MARK: USDA

    private static func searchUSDA(_ q: String, key: String) async throws -> [FoodResult] {
        var c = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        c.queryItems = [
            .init(name: "query", value: q),
            .init(name: "pageSize", value: "15"),
            .init(name: "dataType", value: "Foundation,SR Legacy"),
            .init(name: "api_key", value: key.isEmpty ? "DEMO_KEY" : key),
        ]
        let json = try await fetchJSON(c.url!)
        let foods = json["foods"] as? [[String: Any]] ?? []
        return foods.compactMap { f in
            guard let id = f["fdcId"] as? Int, let desc = f["description"] as? String,
                  let nutrients = f["foodNutrients"] as? [[String: Any]] else { return nil }
            func value(_ nutrientID: Int) -> Double? {
                nutrients.first { ($0["nutrientId"] as? Int) == nutrientID }.flatMap { number($0["value"]) }
            }
            let protein = value(1003) ?? 0
            let fat = value(1004) ?? 0
            let carbs = value(1005) ?? 0
            let kcal = value(1008) ?? (protein * 4 + carbs * 4 + fat * 9)
            guard kcal > 0 else { return nil }
            return FoodResult(key: "usda:\(id)", name: desc, kcal100: kcal, protein100: protein,
                              carbs100: carbs, fat100: fat, source: "USDA")
        }
    }

    /// USDA is English only: map a few very common Italian words so base foods are found.
    static func translate(_ q: String) -> String {
        let map = [
            "pollo": "chicken", "petto di pollo": "chicken breast", "manzo": "beef", "maiale": "pork", "tacchino": "turkey",
            "tonno": "tuna", "salmone": "salmon", "uovo": "egg", "uova": "egg", "riso": "rice", "pasta": "pasta",
            "pane": "bread", "patate": "potato", "patata": "potato", "latte": "milk", "yogurt": "yogurt",
            "formaggio": "cheese", "mela": "apple", "banana": "banana", "arancia": "orange", "avena": "oats",
            "fiocchi d'avena": "oats", "olio": "olive oil", "burro": "butter", "mandorle": "almonds", "noci": "walnuts",
            "broccoli": "broccoli", "spinaci": "spinach", "pomodoro": "tomato", "carote": "carrot", "lenticchie": "lentils",
            "ceci": "chickpeas", "fagioli": "beans", "zucchero": "sugar", "miele": "honey",
        ]
        let lower = q.lowercased()
        return map[lower] ?? q
    }

    // MARK: Helpers

    private static func fetchJSON(_ url: URL) async throws -> [String: Any] {
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false else {
            throw URLError(.badServerResponse)
        }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private static func number(_ v: Any?) -> Double? {
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String { return Double(s.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }
}
