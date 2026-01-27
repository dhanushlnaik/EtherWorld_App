import Foundation

/// Hybrid translation service combining multiple strategies:
/// 1. Local cache (TranslationCacheService) - instant, no API calls
/// 2. External API (HTTPTranslationService via MyMemory) - high quality, requires internet
/// 3. On-device (MLTranslationService iOS 26+) - offline, requires downloaded language packs
/// 4. Original text - last resort fallback
class HybridTranslationService: TranslationService {
    static let shared = HybridTranslationService()
    
    private let cacheService = TranslationCacheService.shared
    private let httpService: HTTPTranslationService
    @available(iOS 16.0, *)
    private let mlService = MLTranslationService.shared
    
    init() {
        // Initialize HTTP service with MyMemory endpoint
        let httpSvc = HTTPTranslationService(
            endpointString: Configuration.translationAPIURL,
            apiKey: Configuration.translationAPIKey
        ) ?? HTTPTranslationService(
            endpointString: "https://api.mymemory.translated.net/get",
            apiKey: nil
        )
        
        if let httpSvc = httpSvc {
            self.httpService = httpSvc
        } else {
            // This should never happen, but as a last resort
            fatalError("Failed to initialize HTTPTranslationService")
        }
    }
    
    /// Translate text through the hybrid pipeline
    func translate(_ text: String, to targetLang: String) async throws -> String {
        // Skip if already in target language
        let currentLang = Locale.current.language.languageCode?.identifier ?? "en"
        if targetLang == "en" || targetLang == currentLang {
            return text
        }

        // Try HTTP API (can check its own cache)
        do {
            print("🔄 Attempting HTTP translation for \(targetLang)...")
            let translated = try await httpService.translate(text, to: targetLang)
            return translated
        } catch {
            print("⚠️ HTTP translation failed: \(error)")
        }

        // Fallback to ML translation
        if #available(iOS 26.0, *) {
            if let translated = await mlService.translate(text, to: targetLang) {
                print("✅ ML translation fallback successful")
                return translated
            }
        }

        // Final fallback: return original
        print("❌ All translation attempts failed, returning original text")
        return text
    }

    /// Translate batch of texts
    func translateBatch(_ texts: [String], to targetLang: String) async throws -> [String] {
        // For batch, use HTTP API's batch method first
        do {
            print("📡 Attempting batch HTTP translation for \(targetLang) (\(texts.count) items)...")
            return try await httpService.translateBatch(texts, to: targetLang)
        } catch {
            print("⚠️ Batch HTTP translation failed: \(error)")
        }

        // Fallback: translate individually through ML
        if #available(iOS 26.0, *) {
            return await mlService.translateBatch(texts, to: targetLang)
        }

        // Final fallback: return originals
        return texts
    }

    /// Translate HTML content (delegates to underlying HTTP service with safe fallback)
    func translateHTML(_ html: String, to targetLang: String) async throws -> String {
        do {
            return try await httpService.translateHTML(html, to: targetLang)
        } catch {
            // If HTML-aware translation fails, log and return original HTML
            print("⚠️ HTML translation failed: \(error). Returning original HTML.")
            return html
        }
    }
    
    /// Clear all caches
    func clearCache() {
        httpService.clearCache()
        if #available(iOS 26.0, *) {
            Task {
                await mlService.clearCache()
            }
        }
        print("🗑️ Cleared all hybrid translation caches")
    }
}
