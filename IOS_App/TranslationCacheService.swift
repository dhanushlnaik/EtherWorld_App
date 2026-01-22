import Foundation

/// Stores article translations locally per language to enable instant language switching
/// Structure: translations_[articleId]_[languageCode] = {title, excerpt, content}
actor TranslationCacheService {
    static let shared = TranslationCacheService()
    
    private let userDefaults = UserDefaults.standard
    private let cachePrefix = "translations"
    
    /// Cache key format: translations_articleId_languageCode
    private func cacheKey(articleId: String, languageCode: String) -> String {
        return "\(cachePrefix)_\(articleId)_\(languageCode)"
    }
    
    /// Store translated article data
    func saveTranslation(
        articleId: String,
        languageCode: String,
        title: String,
        excerpt: String,
        content: String? = nil
    ) {
        let key = cacheKey(articleId: articleId, languageCode: languageCode)
        let data = [
            "title": title,
            "excerpt": excerpt,
            "content": content ?? "",
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        userDefaults.set(data, forKey: key)
    }
    
    /// Retrieve cached translation if available
    func getTranslation(articleId: String, languageCode: String) -> (title: String, excerpt: String, content: String?)? {
        let key = cacheKey(articleId: articleId, languageCode: languageCode)
        guard let data = userDefaults.dictionary(forKey: key) else {
            return nil
        }
        
        guard
            let title = data["title"] as? String,
            let excerpt = data["excerpt"] as? String
        else {
            return nil
        }
        
        let content = data["content"] as? String
        return (title, excerpt, content)
    }
    
    /// Check if we have translation for article in target language
    func hasTranslation(articleId: String, languageCode: String) -> Bool {
        let key = cacheKey(articleId: articleId, languageCode: languageCode)
        return userDefaults.dictionary(forKey: key) != nil
    }
    
    /// Get all cached translations for an article across all languages
    func getAllTranslationsForArticle(articleId: String) -> [String: [String: Any]] {
        var result: [String: [String: Any]] = [:]
        
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let prefix = "\(cachePrefix)_\(articleId)_"
        
        for key in allKeys {
            if key.hasPrefix(prefix) {
                let parts = key.split(separator: "_").map(String.init)
                if parts.count >= 3 {
                    let languageCode = parts[2]
                    if let data = userDefaults.dictionary(forKey: key) {
                        result[languageCode] = data
                    }
                }
            }
        }
        
        return result
    }
    
    /// Clear translations for specific article
    func clearTranslationsForArticle(articleId: String) {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let prefix = "\(cachePrefix)_\(articleId)_"
        
        for key in allKeys {
            if key.hasPrefix(prefix) {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    /// Clear all translations (when switching languages or resetting)
    func clearAllTranslations() {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        for key in allKeys {
            if key.hasPrefix(cachePrefix) {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    /// Get cache statistics
    func getCacheStats() -> (articleCount: Int, totalEntries: Int, approximateSizeKB: Int) {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let translationKeys = allKeys.filter { $0.hasPrefix(cachePrefix) }
        
        var articleIds = Set<String>()
        var totalSize = 0
        
        for key in translationKeys {
            let parts = key.split(separator: "_").map(String.init)
            if parts.count >= 3 {
                articleIds.insert(parts[1])
            }
            
            if let data = userDefaults.dictionary(forKey: key) {
                // Rough estimation of serialized size
                if let jsonData = try? JSONSerialization.data(withJSONObject: data) {
                    totalSize += jsonData.count
                }
            }
        }
        
        return (articleIds.count, translationKeys.count, totalSize / 1024)
    }
}
