import Foundation

/// Minimal stub for on-device ML translation.
/// iOS does not provide a full offline translation API, so this
/// type exists only to keep the HybridTranslationService fallback
/// architecture compiling cleanly.
@available(iOS 16.0, *)
actor MLTranslationService {
    static let shared = MLTranslationService()

    /// Attempt to translate a single string.
    /// Currently returns `nil` to indicate that no ML translation
    /// is available and that callers should fall back to other
    /// translation mechanisms (HTTP API or original text).
    func translate(_ text: String, to languageCode: String) async -> String? {
        print("ℹ️ MLTranslationService.translate called, but no on-device model is configured. Returning nil.")
        return nil
    }

    /// Attempt to translate a batch of strings.
    /// Returns the original texts, acting as a no-op.
    func translateBatch(_ texts: [String], to languageCode: String) async -> [String] {
        print("ℹ️ MLTranslationService.translateBatch called, but no on-device model is configured. Returning originals.")
        return texts
    }

    /// Clear any internal caches (no-op for the stub implementation).
    func clearCache() {
        print("ℹ️ MLTranslationService.clearCache called (no-op for stub implementation).")
    }
}
