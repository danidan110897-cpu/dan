import SwiftData
import SwiftUI
import UIKit

@Model
final class ProgressPhoto {
    var date: Date
    var filename: String
    var note: String
    var weightKg: Double?

    init(date: Date, filename: String, note: String = "", weightKg: Double? = nil) {
        self.date = date
        self.filename = filename
        self.note = note
        self.weightKg = weightKg
    }
}

/// Progress photos live in the app's Documents folder only; they are never uploaded anywhere.
enum PhotoStorage {
    private static let cache = NSCache<NSString, UIImage>()

    private static var directory: URL {
        let dir = URL.documentsDirectory.appending(path: "ProgressPhotos", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Saves a downscaled JPEG and returns its file name.
    static func save(_ data: Data) -> String? {
        guard let original = UIImage(data: data) else { return nil }
        let maxSide: CGFloat = 1600
        let scale = min(1, maxSide / max(original.size.width, original.size.height))
        let size = CGSize(width: original.size.width * scale, height: original.size.height * scale)
        let image = UIGraphicsImageRenderer(size: size).image { _ in original.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpeg = image.jpegData(compressionQuality: 0.8) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: directory.appending(path: name), options: .completeFileProtection)
            return name
        } catch {
            return nil
        }
    }

    static func image(_ filename: String) -> UIImage? {
        if let cached = cache.object(forKey: filename as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: directory.appending(path: filename).path) else { return nil }
        cache.setObject(image, forKey: filename as NSString)
        return image
    }

    static func delete(_ filename: String) {
        cache.removeObject(forKey: filename as NSString)
        try? FileManager.default.removeItem(at: directory.appending(path: filename))
    }
}
