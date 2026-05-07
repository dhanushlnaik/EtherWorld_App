import Foundation
import SwiftUI

@MainActor
final class CryptoMarketViewModel: ObservableObject {
    @Published private(set) var coins: [Coin] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var lastUpdated: Date?

    @AppStorage("watchlistIds") private var watchlistIdsJSON: String = "[\"bitcoin\",\"ethereum\",\"solana\",\"cardano\",\"polkadot\"]"

    private let service = CryptoMarketService.shared
    private var refreshTimer: Timer?

    var watchlistIds: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: Data(watchlistIdsJSON.utf8))) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                watchlistIdsJSON = json
            }
        }
    }

    func startAutoRefresh() {
        refreshTimer?.invalidate()
        Task { await load() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { await self?.load() }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let ids = watchlistIds
            let result = try await service.fetchMarkets(ids: ids.isEmpty ? nil : ids)
            // Maintain the user's chosen order of the watchlist
            if !ids.isEmpty {
                self.coins = ids.compactMap { id in result.first { $0.id == id } }
            } else {
                self.coins = result
            }
            self.errorMessage = nil
            self.lastUpdated = Date()
        } catch {
            self.errorMessage = "Couldn't refresh prices. Pull down to retry."
        }
    }

    func addToWatchlist(coinId: String) async {
        var ids = watchlistIds
        guard !ids.contains(coinId) else { return }
        ids.append(coinId)
        watchlistIds = ids
        await load()
    }

    func removeFromWatchlist(coinId: String) async {
        var ids = watchlistIds
        ids.removeAll { $0 == coinId }
        watchlistIds = ids
        coins.removeAll { $0.id == coinId }
    }

    func move(from source: IndexSet, to destination: Int) {
        var ids = watchlistIds
        ids.move(fromOffsets: source, toOffset: destination)
        watchlistIds = ids
        coins.move(fromOffsets: source, toOffset: destination)
    }

    func isInWatchlist(coinId: String) -> Bool {
        watchlistIds.contains(coinId)
    }

    func lastUpdatedText() -> String {
        guard let lastUpdated else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }
}
