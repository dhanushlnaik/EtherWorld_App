import Foundation

#if canImport(Translation)
import Translation
#endif

/// On-device translation wrapper.
///
/// Uses Apple’s `Translation` framework when available.
///
/// Note: Programmatic `TranslationSession(installedSource:target:)` is only available on
/// iOS 26.0+, so on-device translation is a best-effort feature gated by OS version.
@available(iOS 16.0, *)
actor MLTranslationService {
    static let shared = MLTranslationService()

    /// Attempt to translate a single string.
    ///
    /// Returns an optional translated string. `nil` indicates this stub couldn't
    /// produce an on-device translation and callers should fall back to HTTP-based
    /// translation or the original text.
    func translate(_ text: String, to languageCode: String) async -> String? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return text }

#if canImport(Translation)
        if #available(iOS 26.0, *) {
            let source = Locale.Language(identifier: "en")
            let target = Locale.Language(identifier: languageCode)
            let session = TranslationSession(installedSource: source, target: target)

            if session.canRequestDownloads {
                try? await session.prepareTranslation()
            }

            do {
                let response = try await session.translate(text)
                return response.targetText
            } catch {
                print("⚠️ MLTranslationService.translate failed: \(error)")
                return nil
            }
        }
#endif

        return nil
    }

    /// Attempt to translate a batch of strings.
    func translateBatch(_ texts: [String], to languageCode: String) async -> [String] {
        guard !texts.isEmpty else { return [] }

#if canImport(Translation)
        if #available(iOS 26.0, *) {
            let source = Locale.Language(identifier: "en")
            let target = Locale.Language(identifier: languageCode)
            let session = TranslationSession(installedSource: source, target: target)

            if session.canRequestDownloads {
                try? await session.prepareTranslation()
            }

            let requests = texts.map { TranslationSession.Request(sourceText: $0) }
            do {
                let responses = try await session.translations(from: requests)
                return responses.map { $0.targetText }
            } catch {
                print("⚠️ MLTranslationService.translateBatch failed: \(error)")
                return texts
            }
        }
#endif

        return texts
    }

    /// Clear any internal caches (no-op for the stub implementation).
    func clearCache() {
        // No persistent on-device session is retained in this implementation.
    }
}
