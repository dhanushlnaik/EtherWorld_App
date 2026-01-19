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
    private let saveKey = "savedArticlesIds"
    private let savedArticlesListKey = "savedArticlesList"
    private let readKey = "readArticles"
    private let lastUpdatedKey = "lastArticlesUpdate"
    private var currentPage: Int = 1
    private let pageSize: Int = 50
    private var languageObserver: AnyCancellable?
    
    private let cacheURL: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("articles-cache.json")
    }()
    
    private let savedArticlesURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("saved-articles.json")
    }()
    
    @Published private(set) var fullSavedArticles: [Article] = []
    @Published private(set) var searchResults: [Article] = []
    @Published var searchText: String = ""
    
    private var searchCancellable: AnyCancellable?
    
    init(service: ArticleService = ServiceFactory.makeArticleService(environment: .production)) {
        self.service = service
        self.paginatedService = service as? PaginatedArticleService
        loadCachedArticles()
        loadSavedArticlesFromFile()
        loadSavedState()
        loadReadState()
        loadLastUpdated()
        setupLanguageObserver()
        setupSearch()
    }
    
    private func setupSearch() {
        searchCancellable = $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                if query.count >= 2 {
                    Task { [weak self] in
                        await self?.performSearch(query: query)
                    }
                } else {
                    self?.searchResults = []
                }
            }
    }
    
    private func performSearch(query: String) async {
        do {
            let results = try await service.searchArticles(query: query)
            self.searchResults = results.map { article in
                var mutableArticle = article
                mutableArticle.isSaved = isSaved(articleId: article.id)
                return mutableArticle
            }
        } catch {
            print("Search error: \(error)")
        }
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
            let isNowSaved = articles[index].isSaved
            
            if isNowSaved {
                if !fullSavedArticles.contains(where: { $0.id == article.id }) {
                    fullSavedArticles.append(articles[index])
                }
            } else {
                fullSavedArticles.removeAll(where: { $0.id == article.id })
            }
        } else {
            // Article might not be in the current feed but is being toggled from elsewhere
            if let savedIndex = fullSavedArticles.firstIndex(where: { $0.id == article.id }) {
                fullSavedArticles.remove(at: savedIndex)
            } else {
                var newSaved = article
                newSaved.isSaved = true
                fullSavedArticles.append(newSaved)
            }
        }
        saveSavedArticlesToFile()
        saveSavedState()
        
        // Haptic feedback
        HapticFeedback.shared.impact(.light)
    }
    
    var savedArticles: [Article] {
        fullSavedArticles
    }
    
    private func loadSavedArticlesFromFile() {
        guard let data = try? Data(contentsOf: savedArticlesURL) else { return }
        if let decoded = try? JSONDecoder().decode([Article].self, from: data) {
            self.fullSavedArticles = decoded
        }
    }
    
    private func saveSavedArticlesToFile() {
        guard let data = try? JSONEncoder().encode(fullSavedArticles) else { return }
        try? data.write(to: savedArticlesURL)
    }
    
    private func isSaved(articleId: String) -> Bool {
        return fullSavedArticles.contains(where: { $0.id == articleId })
    }
    
    private func loadSavedState() {
        // Just sync current feed with fullSavedArticles
        for i in 0..<articles.count {
            articles[i].isSaved = isSaved(articleId: articles[i].id)
        }
    }
    
    private func saveSavedState() {
        // IDs are now derived from fullSavedArticles
        let savedIds = fullSavedArticles.map { $0.id }
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

    func markAsRead(article: Article) {
        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            articles[index].isRead = true
        }
        if let searchIndex = searchResults.firstIndex(where: { $0.id == article.id }) {
            searchResults[searchIndex].isRead = true
        }
        
        // Persist read state
        var readIds = UserDefaults.standard.stringArray(forKey: readKey) ?? []
        if !readIds.contains(article.id) {
            readIds.append(article.id)
            UserDefaults.standard.set(readIds, forKey: readKey)
        }
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

