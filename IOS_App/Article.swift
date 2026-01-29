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
    
    // Helper property to get display title
    var displayTitle: String {
        return title
    }
    
    // Helper property to get display excerpt
    var displayExcerpt: String {
        return excerpt
    }
    
    // Helper property to get display content
    var displayContent: String {
        return contentHTML
    }
}