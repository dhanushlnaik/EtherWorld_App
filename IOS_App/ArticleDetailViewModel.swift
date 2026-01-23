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
        // Avoid overlapping loads, but allow translation even when we
        // already have HTML content.
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
            var updated = Article(
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
                isRead: article.isRead,
                translatedTitle: article.translatedTitle,
                translatedExcerpt: article.translatedExcerpt,
                translatedContent: article.translatedContent,
                isTranslated: article.isTranslated,
                translationLanguage: article.translationLanguage
            )

            // For non-English app languages, always attempt to translate the
            // full article content when we don't already have a translation
            // for the current language.
            if appLanguageCode != "en" && updated.translationLanguage != appLanguageCode {
                do {
                    let translatedHTML = try await ghost.translateArticleContent(updated, to: appLanguageCode)
                    updated.translatedContent = translatedHTML
                    updated.isTranslated = true
                    updated.translationLanguage = appLanguageCode
                } catch {
                    print("⚠️ Article full-text translation failed: \(error)")
                    // Keep original HTML if translation fails
                }
            }
            
            // Mark article as translated for the current language to avoid re-translating
            if appLanguageCode != "en" {
                updated.isTranslated = true
                updated.translationLanguage = appLanguageCode
            }

            article = updated
        } catch {
            // Keep existing article state on failure
        }
    }
}

