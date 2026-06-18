import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

enum SpotlightIndexer {
    static func index(articles: [Article]) {
        let items: [CSSearchableItem] = articles.map { article in
            let attributeSet = CSSearchableItemAttributeSet(itemContentType: UTType.text.identifier)
            attributeSet.title = article.title
            attributeSet.contentDescription = article.excerpt
            attributeSet.keywords = article.tags
            if let url = article.imageURL { attributeSet.thumbnailURL = url }
            return CSSearchableItem(uniqueIdentifier: article.id, domainIdentifier: "co.etherworld.articles", attributeSet: attributeSet)
        }
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error = error { print("Spotlight indexing error: \(error)") }
        }
    }

    static func clear() {
        CSSearchableIndex.default().deleteAllSearchableItems { error in
            if let error = error { print("Spotlight clear error: \(error)") }
        }
    }
}
