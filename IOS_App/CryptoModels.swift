import Foundation

// MARK: - Coin (CoinGecko /coins/markets response shape)

struct Coin: Identifiable, Codable, Hashable {
    let id: String
    let symbol: String
    let name: String
    let image: String
    let currentPrice: Double
    let priceChangePercentage24h: Double?
    let priceChangePercentage7dInCurrency: Double?
    let marketCap: Double?
    let marketCapRank: Int?
    let totalVolume: Double?
    let high24h: Double?
    let low24h: Double?
    let sparklineIn7d: SparklineData?

    enum CodingKeys: String, CodingKey {
        case id
        case symbol
        case name
        case image
        case currentPrice = "current_price"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case priceChangePercentage7dInCurrency = "price_change_percentage_7d_in_currency"
        case marketCap = "market_cap"
        case marketCapRank = "market_cap_rank"
        case totalVolume = "total_volume"
        case high24h = "high_24h"
        case low24h = "low_24h"
        case sparklineIn7d = "sparkline_in_7d"
    }
}

struct SparklineData: Codable, Hashable {
    let price: [Double]
}

extension Coin {
    var displaySymbol: String { symbol.uppercased() }

    var change24hColor: String {
        guard let change = priceChangePercentage24h else { return "secondary" }
        return change >= 0 ? "green" : "red"
    }

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        if currentPrice < 1 {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 6
        } else {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        }
        return formatter.string(from: NSNumber(value: currentPrice)) ?? "$\(currentPrice)"
    }

    var formattedChange24h: String {
        guard let change = priceChangePercentage24h else { return "—" }
        let sign = change >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, change)
    }

    var formattedMarketCap: String {
        guard let cap = marketCap else { return "—" }
        return Self.compact(cap)
    }

    static func compact(_ value: Double) -> String {
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        switch absValue {
        case 1_000_000_000_000...:
            return String(format: "%@$%.2fT", sign, absValue / 1_000_000_000_000)
        case 1_000_000_000...:
            return String(format: "%@$%.2fB", sign, absValue / 1_000_000_000)
        case 1_000_000...:
            return String(format: "%@$%.2fM", sign, absValue / 1_000_000)
        case 1_000...:
            return String(format: "%@$%.2fK", sign, absValue / 1_000)
        default:
            return String(format: "%@$%.2f", sign, absValue)
        }
    }
}
