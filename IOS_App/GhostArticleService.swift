import Foundation

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
    
    nonisolated init(baseURL: String = Configuration.ghostBaseURL, apiKey: String = Configuration.ghostAPIKey) {
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
        // Ghost CMS filter syntax for search (approximated)
        let filter = "title:~'\(query)'|custom_excerpt:~'\(query)'"
        var urlString = "\(baseURL)/ghost/api/v3/content/posts/?key=\(apiKey)&include=authors,tags&fields=id,title,html,excerpt,custom_excerpt,feature_image,published_at,reading_time&page=1&limit=20&order=published_at%20desc"

        let encodedFilter = filter.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? filter
        urlString += "&filter=\(encodedFilter)"

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
        return ghostResponse.posts.map(mapPostToArticle(_:))
    }

    func fetchArticles() async throws -> [Article] {
        return try await fetchArticles(page: 1, limit: 100)
    }
    
    func fetchArticles(page: Int, limit: Int = 50) async throws -> [Article] {
        print("🔍 Fetching articles...")
        let urlString = "\(baseURL)/ghost/api/v3/content/posts/?key=\(apiKey)&include=authors,tags&fields=id,title,html,excerpt,custom_excerpt,feature_image,published_at,reading_time&page=\(page)&limit=\(limit)&order=published_at%20desc"
        
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
        return ghostResponse.posts.map(mapPostToArticle(_:))
    }

    private func mapPostToArticle(_ post: GhostPost) -> Article {
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
        return single.posts.first?.html ?? ""
    }
}


