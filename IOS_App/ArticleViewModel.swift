import Foundation
import SwiftUI
import Combine

@MainActor
final class ArticleViewModel: ObservableObject {
    @Published private(set) var articles: [Article] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isLoadingMore: Bool = false
    @Published private(set) var hasMoreArticles: Bool = true
    @Published var errorMessage: String?
    @Published private(set) var lastUpdated: Date?
    @AppStorage("appLanguage") private var appLanguageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    private let service: ArticleService
    private let paginatedService: PaginatedArticleService?
    private let saveKey = "savedArticles"
    private let readKey = "readArticles"
    private let lastUpdatedKey = "lastArticlesUpdate"
    private var currentPage: Int = 1
    private let pageSize: Int = 50
    private var languageObserver: AnyCancellable?
    private let cacheURL: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("articles-cache.json")
    }()
    
    init(service: ArticleService = ServiceFactory.makeArticleService(environment: .production)) {
        self.service = service
        self.paginatedService = service as? PaginatedArticleService
        loadCachedArticles()
        loadSavedState()
        loadReadState()
        loadLastUpdated()
        setupLanguageObserver()
    }

    var articleService: ArticleService { service }
    
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        currentPage = 1
        hasMoreArticles = true
        defer { isLoading = false }
        do {
            let result = try await service.fetchArticles()
            self.articles = result.map { article in
                var mutableArticle = article
                mutableArticle.isSaved = isSaved(articleId: article.id)
                return mutableArticle
            }
            saveCache(articles)
            // Prefetch images for first screen to accelerate rendering
            await prefetchImages(count: 10)
            self.errorMessage = nil
            saveLastUpdated()
            // Check if we got fewer than expected (means no more pages)
            if result.count < pageSize {
                hasMoreArticles = false
            }
            SpotlightIndexer.index(articles: self.articles)
        } catch {
            self.errorMessage = "Failed to load articles. Please try again."
        }
    }
    
    func loadMore() async {
        guard !isLoadingMore, !isLoading, hasMoreArticles else { return }
        guard let paginatedService = paginatedService else { return }
        
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        currentPage += 1
        do {
            let result = try await paginatedService.fetchArticles(page: currentPage, limit: pageSize)
            if result.isEmpty {
                hasMoreArticles = false
            } else {
                let newArticles = result.map { article in
                    var mutableArticle = article
                    mutableArticle.isSaved = isSaved(articleId: article.id)
                    return mutableArticle
                }
                // Filter out duplicates
                let existingIds = Set(articles.map { $0.id })
                let uniqueNew = newArticles.filter { !existingIds.contains($0.id) }
                articles.append(contentsOf: uniqueNew)
                
                if result.count < pageSize {
                    hasMoreArticles = false
                }
            }
            SpotlightIndexer.index(articles: self.articles)
        } catch {
            currentPage -= 1 // Revert on error
            errorMessage = "Failed to load more articles."
        }
    }
    
    func toggleSaved(article: Article) {
        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            articles[index].isSaved.toggle()
            saveSavedState()
        }
    }
    
    func toggleRead(article: Article) {
        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            articles[index].isRead.toggle()
            saveReadState()
        }
    }
    
    func markAsRead(article: Article) {
        if let index = articles.firstIndex(where: { $0.id == article.id }), !articles[index].isRead {
            articles[index].isRead = true
            saveReadState()
        }
    }
    
    var savedArticles: [Article] {
        articles.filter { $0.isSaved }
    }
    
    private func isSaved(articleId: String) -> Bool {
        let saved = UserDefaults.standard.stringArray(forKey: saveKey) ?? []
        return saved.contains(articleId)
    }
    
    private func loadSavedState() {
        // Load saved article IDs from UserDefaults
        let saved = UserDefaults.standard.stringArray(forKey: saveKey) ?? []
        articles = articles.map { article in
            var mutableArticle = article
            mutableArticle.isSaved = saved.contains(article.id)
            return mutableArticle
        }
    }
    
    private func saveSavedState() {
        let savedIds = articles.filter { $0.isSaved }.map { $0.id }
        UserDefaults.standard.set(savedIds, forKey: saveKey)
    }
    
    private func isRead(articleId: String) -> Bool {
        let read = UserDefaults.standard.stringArray(forKey: readKey) ?? []
        return read.contains(articleId)
    }
    
    private func loadReadState() {
        let read = UserDefaults.standard.stringArray(forKey: readKey) ?? []
        articles = articles.map { article in
            var mutableArticle = article
            mutableArticle.isRead = read.contains(article.id)
            return mutableArticle
        }
    }
    
    private func saveReadState() {
        let readIds = articles.filter { $0.isRead }.map { $0.id }
        UserDefaults.standard.set(readIds, forKey: readKey)
    }

    private func loadCachedArticles() {
        guard let data = try? Data(contentsOf: cacheURL) else { return }
        if let decoded = try? JSONDecoder().decode([Article].self, from: data) {
            self.articles = decoded
        }
    }
    
    private func saveCache(_ articles: [Article]) {
        guard let data = try? JSONEncoder().encode(articles) else { return }
        try? data.write(to: cacheURL)
    }
    
    private func prefetchImages(count: Int) async {
        let session = URLSession(configuration: {
            let c = URLSessionConfiguration.default
            c.requestCachePolicy = .returnCacheDataElseLoad
            c.urlCache = URLCache.shared
            return c
        }())
        let targets = articles.prefix(count)
        await withTaskGroup(of: Void.self) { group in
            for article in targets {
                if let url = article.imageURL {
                    group.addTask {
                        if let (data, _) = try? await session.data(from: url), let img = UIImage(data: data) {
                            ImageCache.shared.set(img, forKey: url.absoluteString)
                        }
                    }
                }
                if let url = article.authorProfileImage {
                    group.addTask {
                        if let (data, _) = try? await session.data(from: url), let img = UIImage(data: data) {
                            ImageCache.shared.set(img, forKey: url.absoluteString)
                        }
                    }
                }
            }
        }
    }
    
    private func loadLastUpdated() {
        if let timestamp = UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date {
            self.lastUpdated = timestamp
        }
    }
    
    private func saveLastUpdated() {
        let now = Date()
        UserDefaults.standard.set(now, forKey: lastUpdatedKey)
        self.lastUpdated = now
    }
    
    func lastUpdatedText() -> String {
        guard let lastUpdated = lastUpdated else { return "" }
        let interval = Date().timeIntervalSince(lastUpdated)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
    
    private func setupLanguageObserver() {
        // Observe UserDefaults changes for app language
        languageObserver = NotificationCenter.default
            .publisher(for: UserDefaults.didChangeNotification)
            .compactMap { _ in UserDefaults.standard.string(forKey: "appLanguage") }
            .removeDuplicates()
            .dropFirst() // Skip initial value
            .sink { [weak self] newLanguage in
                Task { @MainActor [weak self] in
                    print("🌍 Language changed to \(newLanguage), reloading articles...")
                    await self?.load()
                }
            }
    }
}

