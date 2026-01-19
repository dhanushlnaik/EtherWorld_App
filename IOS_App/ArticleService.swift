import Foundation

protocol ArticleService {
    func fetchArticles() async throws -> [Article]
    func searchArticles(query: String) async throws -> [Article]
}

protocol PaginatedArticleService: ArticleService {
    func fetchArticles(page: Int, limit: Int) async throws -> [Article]
}
