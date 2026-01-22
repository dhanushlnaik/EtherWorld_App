import Foundation
import Combine
import SwiftUI

@MainActor
final class ArticleDetailViewModel: ObservableObject {
    @Published var article: Article
    @Published var isLoading = false
    @AppStorage("appLanguage") private var appLanguageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    
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

                // Build updated article with fetched HTML
                var updated = Article(
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
                    isRead: article.isRead,
                    translatedTitle: article.translatedTitle,
                    translatedExcerpt: article.translatedExcerpt,
                    translatedContent: article.translatedContent,
                    isTranslated: article.isTranslated,
                    translationLanguage: article.translationLanguage
                )

                // If the app language is not English, attempt to translate the full HTML and store it on the article
                if appLanguageCode != "en" {
                    do {
                        let translatedHTML = try await ghost.translateArticleContent(updated, to: appLanguageCode)
                        updated.translatedContent = translatedHTML
                        updated.isTranslated = true
                        updated.translationLanguage = appLanguageCode
                    } catch {
                        print("⚠️ Article full-text translation failed: \(error)")
                        // keep original content if translation fails
                    }
                }

                article = updated
            }
        } catch {
            // Keep existing article without content on failure
        }
    }
}
