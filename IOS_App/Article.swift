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
        // Prefer translated title when available, otherwise fall back to original
        let raw = translatedTitle ?? title

        // First try standard percent-decoding (handles %20, %23, etc.)
        var decoded = raw.removingPercentEncoding ?? raw

        // If any percent sequences remain, clean up common ones manually so
        // that titles like "ACDC%20%23173" render nicely for the user.
        if decoded.contains("%") {
            decoded = decoded
                .replacingOccurrences(of: "%20", with: " ")
                .replacingOccurrences(of: "% 20", with: " ")
                .replacingOccurrences(of: "%23", with: "#")
                .replacingOccurrences(of: "% 23", with: "#")
                .replacingOccurrences(of: "%2C", with: ",")
                .replacingOccurrences(of: "% 2C", with: ",")
                .replacingOccurrences(of: "%2E", with: ".")
                .replacingOccurrences(of: "% 2E", with: ".")
                .replacingOccurrences(of: "%2D", with: "-")
                .replacingOccurrences(of: "% 2D", with: "-")

            // As a final safety net, strip any remaining percent-escape
            // sequences of the form "%.." (with optional space) so raw
            // codes never appear in the UI.
            if decoded.contains("%") {
                decoded = Article.cleanResidualPercents(in: decoded)
            }
        }

        // Guard against cases where the translation API returned an error
        let upper = decoded.uppercased()
        if upper.contains("INVALID SOURCE") || upper.contains("'AUTO'") || upper.contains("LANGPAIR=") {
            // Fall back to the original title, also cleaned just in case
            let fallbackDecoded = title.removingPercentEncoding ?? title
            let cleanedFallback = Article.cleanResidualPercents(in:
                fallbackDecoded
                    .replacingOccurrences(of: "%20", with: " ")
                    .replacingOccurrences(of: "% 20", with: " ")
            )
            return cleanedFallback
        }
        
        return decoded
    }
    
    // Helper property to get display excerpt (translated or original)
    var displayExcerpt: String {
        // Prefer translated excerpt when available, otherwise fall back to original
        let raw = translatedExcerpt ?? excerpt

        // First try standard percent-decoding
        var decoded = raw.removingPercentEncoding ?? raw

        if decoded.contains("%") {
            decoded = decoded
                .replacingOccurrences(of: "%20", with: " ")
                .replacingOccurrences(of: "% 20", with: " ")
                .replacingOccurrences(of: "%23", with: "#")
                .replacingOccurrences(of: "% 23", with: "#")
                .replacingOccurrences(of: "%2C", with: ",")
                .replacingOccurrences(of: "% 2C", with: ",")
                .replacingOccurrences(of: "%2E", with: ".")
                .replacingOccurrences(of: "% 2E", with: ".")
                .replacingOccurrences(of: "%2D", with: "-")
                .replacingOccurrences(of: "% 2D", with: "-")

            if decoded.contains("%") {
                decoded = Article.cleanResidualPercents(in: decoded)
            }
        }

        let upper = decoded.uppercased()
        if upper.contains("INVALID SOURCE") || upper.contains("'AUTO'") || upper.contains("LANGPAIR=") {
            let fallbackDecoded = excerpt.removingPercentEncoding ?? excerpt
            let cleanedFallback = Article.cleanResidualPercents(in:
                fallbackDecoded
                    .replacingOccurrences(of: "%20", with: " ")
                    .replacingOccurrences(of: "% 20", with: " ")
            )
            return cleanedFallback
        }
        
        return decoded
    }

    /// Remove any remaining percent-escape fragments like "%20" or "% 20"
    /// by replacing them with a single space, so the user never sees raw
    /// encoding codes in titles or excerpts.
    private static func cleanResidualPercents(in text: String) -> String {
        var result = ""
        var index = text.startIndex

        while index < text.endIndex {
            if text[index] == "%" {
                // Skip the "%" and up to one optional space plus two
                // following characters (which are usually hex digits), and
                // insert a single space instead.
                var next = text.index(after: index)
                if next < text.endIndex, text[next] == " " {
                    next = text.index(after: next)
                }
                var consumed = 0
                while consumed < 2, next < text.endIndex {
                    next = text.index(after: next)
                    consumed += 1
                }
                result.append(" ")
                index = next
            } else {
                result.append(text[index])
                index = text.index(after: index)
            }
        }

        return result
    }
    
    // Helper property to get display content (translated or original)
    var displayContent: String {
        return translatedContent ?? contentHTML
    }
}