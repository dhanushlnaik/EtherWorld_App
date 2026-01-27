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

        func encodeQueryParam(_ value: String) -> String? {
            // urlQueryAllowed does NOT escape "&" which would terminate the q= parameter.
            // Use a stricter allowed set so q= is always one parameter.
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "&=?+\n")
            return value.addingPercentEncoding(withAllowedCharacters: allowed)
        }

        func translateSingle(_ text: String, itemIndex: Int) async -> String {
            guard !text.isEmpty else { return text }

            guard let encodedText = encodeQueryParam(text) else {
                return text
            }

            let urlString = "\(endpoint.absoluteString)?q=\(encodedText)&langpair=en|\(mappedLang)"
            guard let url = URL(string: urlString) else {
                return text
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    print("⚠️ HTTPTranslationService: non-2xx status \(http.statusCode) for item #\(itemIndex)")
                    return text
                }

                if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let status = obj["responseStatus"] as? Int, status != 200 {
                        print("⚠️ HTTPTranslationService: API responseStatus=\(status) for item #\(itemIndex), returning original text")
                        return text
                    }

                    if let responseData = obj["responseData"] as? [String: Any],
                       let translatedText = responseData["translatedText"] as? String,
                       !translatedText.isEmpty {
                        let upper = translatedText.uppercased()
                        if upper.contains("INVALID SOURCE") || upper.contains("'AUTO'") || upper.contains("INVALID SOURCE LANGUAGE") {
                            print("⚠️ HTTPTranslationService: API returned invalid-source message for item #\(itemIndex): \(translatedText)")
                            return text
                        }
                        return decodeAndCleanText(translatedText)
                    }
                }

                return text
            } catch {
                print("❌ HTTPTranslationService: request failed for item #\(itemIndex) with error: \(error)")
                return text
            }
        }

        func translateJoined(_ joined: String, chunkIndex: Int) async throws -> String {
            guard let encodedText = encodeQueryParam(joined) else {
                return joined
            }

            let urlString = "\(endpoint.absoluteString)?q=\(encodedText)&langpair=en|\(mappedLang)"
            guard let url = URL(string: urlString) else {
                return joined
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                if http.statusCode == 429 {
                    throw URLError(.cannotLoadFromNetwork)
                }
                print("⚠️ HTTPTranslationService: non-2xx status \(http.statusCode) for chunk #\(chunkIndex)")
                return joined
            }

            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let status = obj["responseStatus"] as? Int, status != 200 {
                    if status == 429 {
                        throw URLError(.cannotLoadFromNetwork)
                    }
                    print("⚠️ HTTPTranslationService: API responseStatus=\(status) for chunk #\(chunkIndex), returning original")
                    return joined
                }

                if let responseData = obj["responseData"] as? [String: Any],
                   let translatedText = responseData["translatedText"] as? String,
                   !translatedText.isEmpty {
                    let upper = translatedText.uppercased()
                    if upper.contains("INVALID SOURCE") || upper.contains("'AUTO'") || upper.contains("INVALID SOURCE LANGUAGE") {
                        print("⚠️ HTTPTranslationService: API returned invalid-source message for chunk #\(chunkIndex): \(translatedText)")
                        return joined
                    }
                    return decodeAndCleanText(translatedText)
                }
            }

            return joined
        }

        // Real batching strategy: join multiple strings with a delimiter and translate in fewer calls.
        // This dramatically reduces 429s compared to 1-call-per-item.
        let delimiter = "\n<<<EW_DELIM_9f3b9b>>>\n"
        let maxJoinedChars = 1200

        var results: [String] = []
        results.reserveCapacity(texts.count)

        var i = 0
        var chunkIndex = 0
        while i < texts.count {
            var current: [String] = []
            current.reserveCapacity(12)
            var currentLen = 0

            // Build a chunk by character budget
            while i < texts.count {
                let t = texts[i]
                let addLen = t.count + (current.isEmpty ? 0 : delimiter.count)
                if !current.isEmpty, currentLen + addLen > maxJoinedChars {
                    break
                }
                // Always include at least one item
                if current.isEmpty || currentLen + addLen <= maxJoinedChars {
                    current.append(t)
                    currentLen += addLen
                    i += 1
                } else {
                    break
                }
            }

            // If the chunk is a single item, do the normal single-item flow.
            if current.count == 1 {
                let translated = await translateSingle(current[0], itemIndex: results.count)
                if results.isEmpty {
                    print("✅ HTTPTranslationService: sample translation → \(translated.prefix(80))...")
                }
                results.append(translated)
                chunkIndex += 1
                continue
            }

            let joined = current.joined(separator: delimiter)

            do {
                let translatedJoined = try await translateJoined(joined, chunkIndex: chunkIndex)
                let parts = translatedJoined.components(separatedBy: delimiter)
                if parts.count == current.count {
                    if results.isEmpty, let first = parts.first {
                        print("✅ HTTPTranslationService: sample translation → \(first.prefix(80))...")
                    }
                    results.append(contentsOf: parts)
                } else {
                    // If delimiter got altered by translation, fall back to per-item for this chunk.
                    print("⚠️ HTTPTranslationService: delimiter split mismatch (got \(parts.count), expected \(current.count)); falling back to per-item for chunk #\(chunkIndex)")
                    for (offset, t) in current.enumerated() {
                        let translated = await translateSingle(t, itemIndex: results.count + offset)
                        results.append(translated)
                    }
                }
            } catch {
                // If rate-limited or failed, return originals for this chunk.
                print("⏳ HTTPTranslationService: batch chunk #\(chunkIndex) failed (\(error)), returning originals")
                results.append(contentsOf: current)
            }

            chunkIndex += 1
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

        guard !plainText.isEmpty else {
            return html
        }

        // Split into sentences/chunks and translate
        var sentences = splitIntoSentences(plainText)
        if sentences.isEmpty {
            sentences = [plainText]
        }

        let translatedSentences = try await translateBatch(sentences, to: targetLang)
        let cleanedTranslatedSentences = translatedSentences.map { decodeAndCleanText($0) }

        // Reconstruct HTML with translated text (best effort, avoids touching href/src, etc.)
        let result = replaceHTMLContent(html, with: cleanedTranslatedSentences)
        
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

    private func decodeAndCleanText(_ text: String) -> String {
        // Decode percent-encoding when present
        var decoded = text.removingPercentEncoding ?? text

        // Common percent escapes that we see leak into UI as literals
        if decoded.contains("%") {
            decoded = decoded
                .replacingOccurrences(of: "%20", with: " ")
                .replacingOccurrences(of: "% 20", with: " ")
                .replacingOccurrences(of: "%23", with: "#")
                .replacingOccurrences(of: "% 23", with: "#")
                .replacingOccurrences(of: "%2C", with: ",")
                .replacingOccurrences(of: "% 2C", with: ",")
                .replacingOccurrences(of: "%2E", with: ".")
                .replacingOccurrences(of: "% 2E", with: ".")
                .replacingOccurrences(of: "%2D", with: "-")
                .replacingOccurrences(of: "% 2D", with: "-")

            // Remove any remaining percent-escapes like "%3A" or "% 3A"
            if let regex = try? NSRegularExpression(pattern: "%\\s?[0-9A-Fa-f]{2}") {
                let range = NSRange(decoded.startIndex..<decoded.endIndex, in: decoded)
                decoded = regex.stringByReplacingMatches(in: decoded, options: [], range: range, withTemplate: " ")
            }
        }

        // Collapse excessive whitespace introduced by cleaning
        decoded = decoded
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return decoded
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
