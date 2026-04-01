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
    var displayTitle: String { title }

    // Helper property to get display excerpt
    var displayExcerpt: String { excerpt }

    // Helper property to get display content
    var displayContent: String { contentHTML }

    /// Ghost image resizing uses path injection: insert /size/w{width}/ before the year segment.
    /// e.g. /content/images/2026/03/file.png → /content/images/size/w800/2026/03/file.png
    func thumbnailURL(width: Int = 800) -> URL? {
        guard let base = imageURL else { return nil }
        let path = base.path
        // Only inject if this looks like a Ghost content image path
        guard path.contains("/content/images/"),
              !path.contains("/size/") else { return base }
        let resized = path.replacingOccurrences(
            of: "/content/images/",
            with: "/content/images/size/w\(width)/"
        )
        var comps = URLComponents(url: base, resolvingAgainstBaseURL: false)
        comps?.path = resized
        return comps?.url ?? base
    }
}