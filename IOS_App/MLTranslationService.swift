import Foundation

#if canImport(Translate)
import Translate
#endif

/// On-device ML translation wrapper.
///
/// NOTE: Apple provides an on-device Translate framework on supported OS versions.
/// This implementation is a guarded stub that can be extended to call the
/// real Apple Translate APIs when available. Keeping the API here allows the
/// HybridTranslationService to prefer on-device translation without causing
/// unconditional compile or runtime failures on older OS versions.
@available(iOS 16.0, *)
actor MLTranslationService {
    static let shared = MLTranslationService()

    /// Attempt to translate a single string.
    ///
    /// Returns an optional translated string. `nil` indicates this stub couldn't
    /// produce an on-device translation and callers should fall back to HTTP-based
    /// translation or the original text.
    func translate(_ text: String, to languageCode: String) async -> String? {
        // If the Translate framework is available, we would call into it here.
        // This is intentionally conservative — add a concrete implementation when
        // targeting an iOS version where the Translate API surface is stable.
        if #available(iOS 16.0, *) {
            if NSClassFromString("Translate.Translator") != nil {
                // TODO: Implement actual Translator usage here.
                print("ℹ️ MLTranslationService: Translate framework present but not wired up yet.")
                return nil
            }
        }

        // Default: no on-device translation available
        print("ℹ️ MLTranslationService.translate called, no on-device model configured. Returning nil.")
        return nil
    }

    /// Attempt to translate a batch of strings.
    func translateBatch(_ texts: [String], to languageCode: String) async -> [String] {
        // By default, return originals. Replace with on-device batch calls when implemented.
        print("ℹ️ MLTranslationService.translateBatch called, no on-device model configured. Returning originals.")
        return texts
    }

    /// Clear any internal caches (no-op for the stub implementation).
    func clearCache() {
        print("ℹ️ MLTranslationService.clearCache called (no-op for stub implementation).")
    }
}
