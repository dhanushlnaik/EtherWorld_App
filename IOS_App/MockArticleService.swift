import Foundation

struct MockArticleService: ArticleService {
    func fetchArticles() async throws -> [Article] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return getMockArticles()
    }
    
    func searchArticles(query: String) async throws -> [Article] {
        try await Task.sleep(nanoseconds: 500_000_000)
        let normalizedQuery = query.lowercased()
        return getMockArticles().filter { 
            $0.title.lowercased().contains(normalizedQuery) || 
            $0.excerpt.lowercased().contains(normalizedQuery) 
        }
    }
    
    func getMockArticles() -> [Article] {
        return [
            Article(
                id: "1",
                title: "The Future of Web3 and Decentralized Internet",
                excerpt: "Exploring how blockchain technology is reshaping digital ownership and trust on the internet.",
                contentHTML: "<p>Web3 represents a fundamental shift in how we think about digital ownership...</p>",
                publishedAt: Date(timeIntervalSinceNow: -86400),
                url: "https://etherworld.co/web3-future",
                author: "Alice Chen",
                authorSlug: "alice-chen",
                authorProfileImage: nil,
                imageURL: URL(string: "https://via.placeholder.com/800x600?text=Web3+Future"),
                tags: ["Web3", "Blockchain", "Decentralization"],
                readingTimeMinutes: 8
            ),
            Article(
                id: "2",
                title: "Smart Contracts: From Theory to Real-World Applications",
                excerpt: "A deep dive into how smart contracts are transforming industries beyond finance.",
                contentHTML: "<p>Smart contracts have evolved from theoretical concepts to practical tools...</p>",
                publishedAt: Date(timeIntervalSinceNow: -172800),
                url: "https://etherworld.co/smart-contracts",
                author: "Bob Kumar",
                authorSlug: "bob-kumar",
                authorProfileImage: nil,
                imageURL: URL(string: "https://via.placeholder.com/800x600?text=Smart+Contracts"),
                tags: ["Ethereum", "SmartContracts", "DeFi"],
                readingTimeMinutes: 12
            )
        ]
    }
}
