import Foundation

protocol TranslationService {
    func translate(_ text: String, to targetLang: String) async throws -> String
    func translateBatch(_ texts: [String], to targetLang: String) async throws -> [String]
}

struct NoOpTranslationService: TranslationService {
    func translate(_ text: String, to targetLang: String) async throws -> String { text }
    func translateBatch(_ texts: [String], to targetLang: String) async throws -> [String] { texts }
}

struct HTTPTranslationService: TranslationService {
    let endpoint: URL
    let apiKey: String?

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
        // Try a simple LibreTranslate-compatible endpoint: {q, source, target, format}
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let key = apiKey, !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        // The API may accept either a single string or array; we'll send a joined payload and split responses.
        // Prefer sending first as array of q values if supported.
        let body: [String: Any] = [
            "q": texts,
            "source": "auto",
            "target": targetLang,
            "format": "text"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "Translation", code: 1, userInfo: [NSLocalizedDescriptionKey: "Translation request failed"])
        }

        // Expect response to be either {translatedText: "..."} or [{translatedText: "..."}, ...]
        if let obj = try? JSONSerialization.jsonObject(with: data) {
            if let arr = obj as? [[String: Any]] {
                return arr.compactMap { $0["translatedText"] as? String }
            }
            if let dict = obj as? [String: Any], let txt = dict["translatedText"] as? String {
                return [txt]
            }
        }

        // Fallback: decode as array of strings
        if let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return decoded
        }

        // If all parsing fails, throw
        throw NSError(domain: "Translation", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to parse translation response"])
    }
}
