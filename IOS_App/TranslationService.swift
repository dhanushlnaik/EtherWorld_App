import Foundation

protocol TranslationService {
    func translate(_ text: String, to targetLang: String) async throws -> String
    func translateBatch(_ texts: [String], to targetLang: String) async throws -> [String]
    func translateHTML(_ html: String, to targetLang: String) async throws -> String
    func clearCache()
}

struct NoOpTranslationService: TranslationService {
    func translate(_ text: String, to targetLang: String) async throws -> String { text }
    func translateBatch(_ texts: [String], to targetLang: String) async throws -> [String] { texts }
    func translateHTML(_ html: String, to targetLang: String) async throws -> String { html }
    func clearCache() {}
}

// Actor to manage thread-safe translation cache in async context
actor TranslationCacheManager {
    private var cache: [String: String] = [:]
    
    func getCached(key: String) -> String? {
        return cache[key]
    }
    
    func setCached(_ value: String, for key: String) {
        cache[key] = value
    }
    
    func clearAll() {
        cache.removeAll()
    }
}

struct HTTPTranslationService: TranslationService {
    let endpoint: URL
    let apiKey: String?
    private static let cacheManager = TranslationCacheManager()
    
    // MyMemory language code mapping
    private static let languageCodeMap: [String: String] = [
        "en": "en",
        "es": "es",
        "fr": "fr",
        "de": "de",
        "hi": "hi",
        "pt": "pt",
        "it": "it",
        "ja": "ja",
        "ko": "ko",
        "zh": "zh",
        "ar": "ar",
        "ru": "ru",
    ]

    init?(endpointString: String, apiKey: String?) {
        guard let url = URL(string: endpointString), !endpointString.isEmpty else { return nil }
        self.endpoint = url
        self.apiKey = apiKey
    }

    func translate(_ text: String, to targetLang: String) async throws -> String {
        let results = try await translateBatch([text], to: targetLang)
        return results.first ?? text
    }

    func translateBatch(_ texts: [String], to targetLang: String) async throws -> [String] {
        // Map language code to MyMemory format
        let mappedLang = Self.languageCodeMap[targetLang] ?? targetLang

        print("🌐 HTTPTranslationService: requested translation for \(texts.count) texts → \(targetLang) (mapped: \(mappedLang))")

        // MyMemory API format: /get?q=TEXT&langpair=auto|TARGET
        var results: [String] = []

        for (index, text) in texts.enumerated() {
            guard !text.isEmpty else {
                results.append(text)
                continue
            }
            
            guard let encodedText = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                results.append(text)
                continue
            }
            
            let urlString = "\(endpoint.absoluteString)?q=\(encodedText)&langpair=auto|\(mappedLang)"
            guard let url = URL(string: urlString) else {
                results.append(text)
                continue
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    print("⚠️ HTTPTranslationService: non-2xx status \(http.statusCode) for item #\(index)")

                    // If we get rate-limited (429), stop hammering the API and
                    // return originals for the remaining items.
                    if http.statusCode == 429 {
                        print("⏳ HTTPTranslationService: received 429 (rate limited), skipping remaining \(texts.count - index) items")
                        results.append(contentsOf: texts[index...])
                        break
                    }

                    results.append(text)
                    continue
                }
                
                // Parse MyMemory response format: {"responseStatus":200,"responseData":{"translatedText":"..."}}
                if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let responseData = obj["responseData"] as? [String: Any],
                   let translatedText = responseData["translatedText"] as? String,
                   !translatedText.isEmpty {
                    if index == 0 {
                        print("✅ HTTPTranslationService: sample translation → \(translatedText.prefix(80))...")
                    }
                    results.append(translatedText)
                } else {
                    print("⚠️ HTTPTranslationService: unable to parse translation response for item #\(index), returning original text")
                    results.append(text)
                }
            } catch {
                print("❌ HTTPTranslationService: request failed for item #\(index) with error: \(error)")
                results.append(text)
            }
        }
        
        return results
    }
    
    func translateHTML(_ html: String, to targetLang: String) async throws -> String {
        // Create cache key
        let cacheKey = "\(html.prefix(100))-\(targetLang)"
        
        // Check cache first
        if let cached = await HTTPTranslationService.cacheManager.getCached(key: cacheKey) {
            return cached
        }
        
        // Extract text content from HTML to translate
        let plainText = stripHTML(html)
        
        // If very short, just translate as-is
        if plainText.count < 50 {
            let translated = try await translate(html, to: targetLang)
            await HTTPTranslationService.cacheManager.setCached(translated, for: cacheKey)
            return translated
        }
        
        // For longer HTML, split into sentences and translate
        let sentences = splitIntoSentences(plainText)
        let translatedSentences = try await translateBatch(sentences, to: targetLang)
        
        // Reconstruct HTML with translated text
        let result = replaceHTMLContent(html, with: translatedSentences)
        
        await HTTPTranslationService.cacheManager.setCached(result, for: cacheKey)
        
        return result
    }
    
    func clearCache() {
        Task {
            await HTTPTranslationService.cacheManager.clearAll()
        }
    }
    
    // MARK: - Helper Methods
    
    private func stripHTML(_ html: String) -> String {
        let pattern = "<[^>]*>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let result = regex?.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "")
        return (result ?? html)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
    
    private func splitIntoSentences(_ text: String) -> [String] {
        // Simple sentence splitting on periods, question marks, exclamation marks
        let sentences = text.split(separator: ".", omittingEmptySubsequences: true).map { String($0) }
            + text.split(separator: "!", omittingEmptySubsequences: true).map { String($0) }
            + text.split(separator: "?", omittingEmptySubsequences: true).map { String($0) }
        
        // Remove duplicates and empty strings, limit to reasonable chunks
        return Array(sentences.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .prefix(100)) // Limit to first 100 sentences to avoid huge requests
    }
    
    private func replaceHTMLContent(_ html: String, with sentences: [String]) -> String {
        // For simplicity, if we can translate the plain text, return a modified version
        // This is a best-effort approach - ideally translate tags separately
        var result = html
        let plainText = stripHTML(html)
        let sentencesInText = splitIntoSentences(plainText)
        
        // Replace original sentences with translated ones in the HTML
        for (index, originalSentence) in sentencesInText.enumerated() {
            if index < sentences.count {
                let translatedSentence = sentences[index]
                // Escape special regex characters
                let escaped = NSRegularExpression.escapedPattern(for: originalSentence)
                if let regex = try? NSRegularExpression(pattern: escaped) {
                    let range = NSRange(result.startIndex..<result.endIndex, in: result)
                    result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: translatedSentence)
                }
            }
        }
        
        return result
    }
}
