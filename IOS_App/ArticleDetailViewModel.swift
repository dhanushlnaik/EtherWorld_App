import Foundation
import Combine

@MainActor
final class ArticleDetailViewModel: ObservableObject {
    @Published var article: Article
    @Published var isLoading = false
    
    init(article: Article) {
        self.article = article
    }
    
    func loadContentIfNeeded(service: ArticleService) async {
        guard article.contentHTML.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if let ghost = service as? GhostArticleService {
                let html = try await ghost.fetchArticleContent(id: article.id)
                article = Article(
                    id: article.id,
                    title: article.title,
                    excerpt: article.excerpt,
                    contentHTML: html,
                    publishedAt: article.publishedAt,
                    url: article.url,
                    author: article.author,
                    authorSlug: article.authorSlug,
                    authorProfileImage: article.authorProfileImage,
                    imageURL: article.imageURL,
                    tags: article.tags,
                    readingTimeMinutes: article.readingTimeMinutes,
                    isSaved: article.isSaved,
                    isRead: article.isRead
                )
            }
        } catch {
            // Keep existing article without content on failure
        }
    }
}
