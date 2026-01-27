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

            // For non-English app languages, attempt to translate the
            // title/excerpt and full article content when we don't already have them.
            if appLanguageCode != "en" {
                if updated.translatedTitle == nil || updated.translatedTitle?.isEmpty == true || updated.translatedExcerpt == nil || updated.translatedExcerpt?.isEmpty == true {
                    do {
                        let pair = try await ghost.translateTitleAndExcerpt(updated, to: appLanguageCode)
                        updated.translatedTitle = pair.title
                        updated.translatedExcerpt = pair.excerpt
                        updated.isTranslated = true
                        updated.translationLanguage = appLanguageCode
                    } catch {
                        print("⚠️ Article title/excerpt translation failed: \(error)")
                    }
                }

                if updated.translatedContent == nil || updated.translatedContent?.isEmpty == true {
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
            }

            article = updated
        } catch {
            // Keep existing article state on failure
        }
    }
}

