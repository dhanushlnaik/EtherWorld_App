import Foundation
import SwiftUI

struct GhostArticleService: PaginatedArticleService {
    enum ServiceError: Error {
        case invalidURL
        case networkError
        case decodingError
    }
    
    // MARK: - Codable Models
    private struct GhostResponse: Codable {
        let posts: [GhostPost]
        let meta: GhostMeta?
    }
    
    private struct GhostMeta: Codable {
        let pagination: GhostPagination
    }
    
    private struct GhostPagination: Codable {
        let page: Int
        let limit: Int
        let pages: Int
        let total: Int
        let next: Int?
        let prev: Int?
    }
    
    private struct GhostAuthor: Codable {
        let name: String
        let slug: String
        let profile_image: String?
    }
    
    private struct GhostTag: Codable {
        let name: String
    }
    
    private struct GhostPost: Codable {
        let id: String
        let title: String
        let html: String
        let excerpt: String?
        let custom_excerpt: String?
        let feature_image: String?
        let published_at: Date
        let reading_time: Int?
        let authors: [GhostAuthor]?
        let tags: [GhostTag]?
    }
    
    private struct SinglePostResponse: Codable {
        let posts: [GhostPost]
    }
    
    private let baseURL: String
    private let apiKey: String
    private let session: URLSession
    private let translationService: TranslationService
    @AppStorage("appLanguage") private var appLanguageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    init(baseURL: String = Configuration.ghostBaseURL, apiKey: String = Configuration.ghostAPIKey, translationService: TranslationService = ServiceFactory.makeTranslationService()) {
        self.translationService = translationService
        self.baseURL = baseURL
        self.apiKey = apiKey
        let config = URLSessionConfiguration.default
        // Aggressive HTTP caching for list payloads
        config.urlCache = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024, directory: nil)
        config.requestCachePolicy = .reloadRevalidatingCacheData
        config.waitsForConnectivity = true
        config.httpAdditionalHeaders = [
            "Accept": "application/json"
        ]
        self.session = URLSession(configuration: config)
    }
    
    func searchArticles(query: String) async throws -> [Article] {
        let languageTag = "lang-\(appLanguageCode)"
        // Ghost CMS filter syntax for search (approximated)
        let filter = "tag:\(languageTag)+(title:~'\(query)'|custom_excerpt:~'\(query)')"
        return try await fetchArticlesWithFilter(filter, page: 1, limit: 20)
    }

    func fetchArticles() async throws -> [Article] {
        return try await fetchArticles(page: 1, limit: 100)
    }
    
    func fetchArticles(page: Int, limit: Int = 50) async throws -> [Article] {
        // Build language filter tag - format: tag:lang-es
        let languageTag = "lang-\(appLanguageCode)"
        let filter = "tag:\(languageTag)"
        
        let articles = try await fetchArticlesWithFilter(filter, page: page, limit: limit)
        
        // If no articles found for selected language, try fallback strategies
        if articles.isEmpty {
            print("⚠️ No articles found for language '\(appLanguageCode)'")
            
            // First try English if not already tried
            if appLanguageCode != "en" {
                print("   → Trying English articles...")
                let englishArticles = try await fetchArticlesWithFilter("tag:lang-en", page: page, limit: limit)
                if !englishArticles.isEmpty {
                    return englishArticles
                }
            }
            
            // If still no articles, fetch without language filter (all articles)
            print("   → Fetching all articles without language filter")
            return try await fetchArticlesWithFilter(nil, page: page, limit: limit)
        }
        
        return articles
    }

    private func fetchArticlesWithFilter(_ filter: String?, page: Int, limit: Int) async throws -> [Article] {
        var urlString = "\(baseURL)/ghost/api/v3/content/posts/?key=\(apiKey)&include=authors,tags&fields=id,title,html,excerpt,custom_excerpt,feature_image,published_at,reading_time&page=\(page)&limit=\(limit)&order=published_at%20desc"
        
        if let filter = filter {
            let encodedFilter = filter.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? filter
            urlString += "&filter=\(encodedFilter)"
        }
        
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ServiceError.networkError
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let ghostResponse = try decoder.decode(GhostResponse.self, from: data)
        var mapped = ghostResponse.posts.map { post in
            let excerpt: String = {
                if let customExcerpt = post.custom_excerpt, !customExcerpt.isEmpty {
                    return customExcerpt
                }
                if let autoExcerpt = post.excerpt, !autoExcerpt.isEmpty {
                    return autoExcerpt
                }
                let plainText = post.html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if plainText.count <= 200 {
                    return plainText
                }
                let truncated = String(plainText.prefix(200))
                if let lastSpace = truncated.lastIndex(of: " ") {
                    return String(truncated[..<lastSpace]) + "..."
                }
                return truncated + "..."
            }()
            
            return Article(
                id: post.id,
                title: post.title,
                excerpt: excerpt,
                contentHTML: post.html,
                publishedAt: post.published_at,
                url: "\(baseURL)/\(post.id)",
                author: post.authors?.first?.name,
                authorSlug: post.authors?.first?.slug,
                authorProfileImage: post.authors?.first?.profile_image.flatMap { URL(string: $0) },
                imageURL: post.feature_image.flatMap { URL(string: $0) },
                tags: post.tags?.map { $0.name } ?? [],
                readingTimeMinutes: post.reading_time
            )
        }

        // If Ghost doesn't provide per-language posts, translate titles/excerpts to the app language
        if appLanguageCode != "en" {
            let titles = mapped.map { $0.title }
            let excerpts = mapped.map { $0.excerpt }
            do {
                let tTitles = try await translationService.translateBatch(titles, to: appLanguageCode)
                let tExcerpts = try await translationService.translateBatch(excerpts, to: appLanguageCode)
                // Merge translations back into articles
                mapped = zip(zip(mapped, tTitles), tExcerpts).map { pair in
                    var article = pair.0.0
                    article = Article(id: article.id,
                                      title: pair.0.1,
                                      excerpt: pair.1,
                                      contentHTML: article.contentHTML,
                                      publishedAt: article.publishedAt,
                                      url: article.url,
                                      author: article.author,
                                      authorSlug: article.authorSlug,
                                      authorProfileImage: article.authorProfileImage,
                                      imageURL: article.imageURL,
                                      tags: article.tags,
                                      readingTimeMinutes: article.readingTimeMinutes)
                    return article
                }
            } catch {
                print("⚠️ Translation failed, showing original text: \(error)")
            }
        }

        return mapped
    }

    // Fetch full content HTML for a specific article by id on demand
    func fetchArticleContent(id: String) async throws -> String {
        let urlString = "\(baseURL)/ghost/api/v3/content/posts/\(id)/?key=\(apiKey)&fields=html"
        guard let url = URL(string: urlString) else {
            throw ServiceError.invalidURL
        }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ServiceError.networkError
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let single = try decoder.decode(SinglePostResponse.self, from: data)
        let html = single.posts.first?.html ?? ""

        if appLanguageCode != "en" {
            // Try to translate the HTML content; fall back to original on error
            do {
                let translated = try await translationService.translate(html, to: appLanguageCode)
                return translated
            } catch {
                print("⚠️ Article content translation failed: \(error)")
                return html
            }
        }

        return html
    }
}


