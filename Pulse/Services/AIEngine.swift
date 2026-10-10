import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleIntelligenceStatus: Equatable {
    case available
    case deviceNotEligible
    case notEnabled
    case notReady
    case osTooOld
    case sdkMissing

    var isAvailable: Bool { self == .available }

    var label: String {
        switch self {
        case .available: "Disponibile"
        case .deviceNotEligible: "Questo iPhone non è compatibile"
        case .notEnabled: "Non attivata: Impostazioni → Apple Intelligence e Siri"
        case .notReady: "Il modello si sta ancora scaricando, riprova più tardi"
        case .osTooOld: "Serve iOS 26 o successivo"
        case .sdkMissing: "Questa versione dell'app è stata compilata senza Apple Intelligence"
        }
    }
}

/// Decides which AI to use. Apple Intelligence is detected at runtime (not from the phone model), so it also covers
/// the case where it is supported but switched off or still downloading.
enum AIEngine {
    enum Choice {
        case apple, claude, local

        var label: String {
            switch self {
            case .apple: "Apple Intelligence (sul telefono)"
            case .claude: "Claude (con la tua chiave)"
            case .local: "Regole sul telefono (gratis)"
            }
        }
    }

    static var appleStatus: AppleIntelligenceStatus {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible: return .deviceNotEligible
                case .appleIntelligenceNotEnabled: return .notEnabled
                case .modelNotReady: return .notReady
                @unknown default: return .notReady
                }
            @unknown default:
                return .notReady
            }
        }
        return .osTooOld
        #else
        return .sdkMissing
        #endif
    }

    /// Best free option first: Apple Intelligence, then Claude (if the user added a key), then plain rules.
    static var automatic: Choice {
        if appleStatus.isAvailable { return .apple }
        if ClaudeClient.hasKey { return .claude }
        return .local
    }
}
