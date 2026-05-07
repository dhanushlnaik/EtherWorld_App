import Foundation

/// Lightweight client for the CoinGecko public market endpoint.
/// No API key is required for low-volume usage.
final class CryptoMarketService {
    static let shared = CryptoMarketService()

    private let baseURL = URL(string: "https://api.coingecko.com/api/v3")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    /// Fetches market data for the given list of coin ids (e.g. ["bitcoin","ethereum"]).
    /// Falls back to default top coins when ids is empty.
    func fetchMarkets(ids: [String]? = nil, vsCurrency: String = "usd") async throws -> [Coin] {
        var components = URLComponents(url: baseURL.appendingPathComponent("coins/markets"),
                                       resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "vs_currency", value: vsCurrency),
            URLQueryItem(name: "order", value: "market_cap_desc"),
            URLQueryItem(name: "per_page", value: "50"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "sparkline", value: "true"),
            URLQueryItem(name: "price_change_percentage", value: "24h,7d")
        ]
        if let ids, !ids.isEmpty {
            items.append(URLQueryItem(name: "ids", value: ids.joined(separator: ",")))
        }
        components.queryItems = items
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        return try decoder.decode([Coin].self, from: data)
    }

    /// Search coins by query (used to add to watchlist).
    func searchCoins(query: String) async throws -> [CoinSearchResult] {
        var components = URLComponents(url: baseURL.appendingPathComponent("search"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "query", value: query)]
        guard let url = components.url else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        let wrapper = try JSONDecoder().decode(SearchResponse.self, from: data)
        return wrapper.coins
    }

    private struct SearchResponse: Codable {
        let coins: [CoinSearchResult]
    }
}

struct CoinSearchResult: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let thumb: String?
    let marketCapRank: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, symbol, thumb
        case marketCapRank = "market_cap_rank"
    }
}
