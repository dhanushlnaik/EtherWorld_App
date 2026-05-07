import SwiftUI

// MARK: - Sparkline (lightweight inline chart, no Charts framework dependency)

struct SparklineView: View {
    let prices: [Double]
    let positive: Bool

    var body: some View {
        GeometryReader { geo in
            let path = sparklinePath(in: geo.size)
            ZStack {
                path
                    .stroke(positive ? Color.green : Color.red,
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                LinearGradient(
                    colors: [
                        (positive ? Color.green : Color.red).opacity(0.25),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .mask(
                    sparklineFillPath(in: geo.size)
                )
            }
        }
    }

    private func sparklinePath(in size: CGSize) -> Path {
        guard prices.count > 1,
              let minVal = prices.min(),
              let maxVal = prices.max(),
              maxVal != minVal else {
            return Path { p in
                p.move(to: CGPoint(x: 0, y: size.height / 2))
                p.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            }
        }
        let stepX = size.width / CGFloat(prices.count - 1)
        let range = maxVal - minVal
        return Path { path in
            for (i, price) in prices.enumerated() {
                let x = CGFloat(i) * stepX
                let y = size.height - CGFloat((price - minVal) / range) * size.height
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private func sparklineFillPath(in size: CGSize) -> Path {
        var p = sparklinePath(in: size)
        p.addLine(to: CGPoint(x: size.width, y: size.height))
        p.addLine(to: CGPoint(x: 0, y: size.height))
        p.closeSubpath()
        return p
    }
}

// MARK: - Coin Row

struct CoinRowView: View {
    let coin: Coin

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: coin.image)) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Circle().fill(Color.gray.opacity(0.2))
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(coin.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(coin.displaySymbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let prices = coin.sparklineIn7d?.price, !prices.isEmpty {
                SparklineView(
                    prices: prices,
                    positive: (coin.priceChangePercentage7dInCurrency ?? 0) >= 0
                )
                .frame(width: 80, height: 36)
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(coin.formattedPrice)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text(coin.formattedChange24h)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle((coin.priceChangePercentage24h ?? 0) >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Main Watchlist View

struct CryptoWatchlistView: View {
    @StateObject private var viewModel = CryptoMarketViewModel()
    @State private var showingAdd = false
    @State private var selectedCoin: Coin?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.coins.isEmpty && viewModel.isLoading {
                    ProgressView("Loading prices…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.coins.isEmpty, let err = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text(err)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    listContent
                }
            }
            .navigationTitle("Markets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add coin")
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !viewModel.coins.isEmpty {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .principal) {
                    if !viewModel.coins.isEmpty {
                        Text("Updated \(viewModel.lastUpdatedText())")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddCoinSearchView { coinId in
                    Task { await viewModel.addToWatchlist(coinId: coinId) }
                }
            }
            .sheet(item: $selectedCoin) { coin in
                NavigationStack {
                    CoinDetailView(coin: coin)
                }
            }
            .refreshable {
                await viewModel.load()
            }
            .onAppear { viewModel.startAutoRefresh() }
            .onDisappear { viewModel.stopAutoRefresh() }
        }
    }

    private var listContent: some View {
        List {
            Section {
                ForEach(viewModel.coins) { coin in
                    Button {
                        selectedCoin = coin
                    } label: {
                        CoinRowView(coin: coin)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await viewModel.removeFromWatchlist(coinId: coin.id) }
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
                .onMove { source, destination in
                    viewModel.move(from: source, to: destination)
                }
            } header: {
                Text("Your Watchlist")
            } footer: {
                Text("Live data from CoinGecko. Updates every minute. Tap Edit to reorder or swipe to remove.")
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Add Coin Search

struct AddCoinSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var results: [CoinSearchResult] = []
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>?
    let onAdd: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                if results.isEmpty && !isSearching {
                    ContentUnavailableView(
                        "Search Coins",
                        systemImage: "magnifyingglass",
                        description: Text("Find any cryptocurrency to add to your watchlist.")
                    )
                }
                ForEach(results) { coin in
                    Button {
                        onAdd(coin.id)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            if let thumb = coin.thumb, let url = URL(string: thumb) {
                                AsyncImage(url: url) { img in
                                    img.resizable().scaledToFit()
                                } placeholder: {
                                    Circle().fill(Color.gray.opacity(0.2))
                                }
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(coin.name).fontWeight(.medium)
                                Text(coin.symbol.uppercased())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let rank = coin.marketCapRank {
                                Text("#\(rank)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Add to Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Search e.g. bitcoin")
            .onChange(of: query) { _, newValue in
                searchTask?.cancel()
                guard newValue.count >= 2 else {
                    results = []
                    return
                }
                searchTask = Task { await performSearch(newValue) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func performSearch(_ q: String) async {
        try? await Task.sleep(nanoseconds: 350_000_000)
        if Task.isCancelled { return }
        await MainActor.run { isSearching = true }
        defer { Task { @MainActor in isSearching = false } }
        do {
            let r = try await CryptoMarketService.shared.searchCoins(query: q)
            if Task.isCancelled { return }
            await MainActor.run { results = Array(r.prefix(20)) }
        } catch {
            await MainActor.run { results = [] }
        }
    }
}

// MARK: - Coin Detail

struct CoinDetailView: View {
    let coin: Coin
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    AsyncImage(url: URL(string: coin.image)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())

                    VStack(alignment: .leading) {
                        Text(coin.name).font(.title2).fontWeight(.bold)
                        Text(coin.displaySymbol).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let rank = coin.marketCapRank {
                        Text("Rank #\(rank)")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(coin.formattedPrice)
                        .font(.system(size: 36, weight: .bold))
                        .monospacedDigit()
                    HStack(spacing: 8) {
                        Image(systemName: (coin.priceChangePercentage24h ?? 0) >= 0
                              ? "arrow.up.right" : "arrow.down.right")
                        Text(coin.formattedChange24h)
                        Text("(24h)").foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle((coin.priceChangePercentage24h ?? 0) >= 0 ? .green : .red)
                }

                if let prices = coin.sparklineIn7d?.price, !prices.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("7-day price")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        SparklineView(
                            prices: prices,
                            positive: (coin.priceChangePercentage7dInCurrency ?? 0) >= 0
                        )
                        .frame(height: 140)
                    }
                }

                StatGrid(coin: coin)

                Text("Data provided by CoinGecko. Prices may be delayed up to 60 seconds.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle(coin.displaySymbol)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

private struct StatGrid: View {
    let coin: Coin
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(title: "Market Cap", value: coin.formattedMarketCap)
            statCard(title: "24h Volume", value: Coin.compact(coin.totalVolume ?? 0))
            statCard(title: "24h High", value: Coin.compact(coin.high24h ?? 0))
            statCard(title: "24h Low", value: Coin.compact(coin.low24h ?? 0))
            if let p = coin.priceChangePercentage7dInCurrency {
                statCard(title: "7d Change",
                         value: String(format: "%@%.2f%%", p >= 0 ? "+" : "", p),
                         color: p >= 0 ? .green : .red)
            }
        }
    }

    private func statCard(title: String, value: String, color: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    CryptoWatchlistView()
}
