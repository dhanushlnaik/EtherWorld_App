import Foundation
import Combine
import SwiftUI

@MainActor
final class ArticleDetailViewModel: ObservableObject {
    @Published var article: Article
    @Published var isLoading = false
    
    init(article: Article) {
        self.article = article
    }
    
    func loadContentIfNeeded(service: ArticleService) async {
        // Avoid overlapping loads
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            guard let ghost = service as? GhostArticleService else { return }
            // Determine the base HTML for this article: use the existing
            // content if present, otherwise fetch it from Ghost.
            let baseHTML: String
            if article.contentHTML.isEmpty {
                baseHTML = try await ghost.fetchArticleContent(id: article.id)
            } else {
                baseHTML = article.contentHTML
            }

            // Rebuild the Article value with the resolved HTML content.
            let updated = Article(
                id: article.id,
                title: article.title,
                excerpt: article.excerpt,
                contentHTML: baseHTML,
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

            article = updated
        } catch {
            // Keep existing article state on failure
        }
    }
}

