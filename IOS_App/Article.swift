import Foundation

struct Article: Identifiable, Hashable, Codable {
    let id: String
    let title: String
    let excerpt: String
    let contentHTML: String
    let publishedAt: Date
    let url: String
    let author: String?
    let authorSlug: String?
    let authorProfileImage: URL?
    let imageURL: URL?
    let tags: [String]
    let readingTimeMinutes: Int?
    var isSaved: Bool = false
    var isRead: Bool = false
    
    // Translation properties
    var translatedTitle: String?
    var translatedExcerpt: String?
    var translatedContent: String?
    var isTranslated: Bool = false
    var translationLanguage: String?
    
    // Helper property to get display title (translated or original)
    var displayTitle: String {
        return translatedTitle ?? title
    }
    
    // Helper property to get display excerpt (translated or original)
    var displayExcerpt: String {
        return translatedExcerpt ?? excerpt
    }
    
    // Helper property to get display content (translated or original)
    var displayContent: String {
        return translatedContent ?? contentHTML
    }
}