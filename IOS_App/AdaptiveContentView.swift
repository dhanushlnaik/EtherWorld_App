import SwiftUI

struct AdaptiveContentView: View {
    @StateObject private var viewModel = ArticleViewModel()
    @StateObject private var authManager = AuthenticationManager()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: NavigationTab = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    enum NavigationTab: String, CaseIterable {
        case home = "tab.home"
        case markets = "tab.markets"
        case search = "tab.search"
        case saved = "tab.saved"
        case profile = "tab.profile"

        var icon: String {
            switch self {
            case .home:    return "house.fill"
            case .markets: return "chart.line.uptrend.xyaxis"
            case .search:  return "magnifyingglass"
            case .saved:   return "bookmark.fill"
            case .profile: return "person.crop.circle.fill"
            }
        }

        var localizedTitle: String {
            switch self {
            case .home:    return "Home"
            case .markets: return "Markets"
            case .search:  return "Search"
            case .saved:   return "Saved"
            case .profile: return "Profile"
            }
        }
    }
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .environmentObject(viewModel)
        .environmentObject(authManager)
        .onOpenURL { url in
            guard url.scheme == "etherworld" else { return }
            if url.host == "article" {
                let articleId = url.lastPathComponent
                NotificationManager.shared.selectedArticleId = articleId
            }
        }
        .task {
            await viewModel.load()
        }
        // Wire up Siri / App Intents notifications
        .onReceive(NotificationCenter.default.publisher(for: .etherworldOpenLatest)) { _ in
            selectedTab = .home
            Task { await openLatestArticleIfAvailable(playAudio: false) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .etherworldOpenWatchlist)) { _ in
            selectedTab = .markets
        }
        .onReceive(NotificationCenter.default.publisher(for: .etherworldReadLatestAloud)) { _ in
            selectedTab = .home
            Task { await openLatestArticleIfAvailable(playAudio: true) }
        }
    }

    private func openLatestArticleIfAvailable(playAudio: Bool) async {
        if viewModel.articles.isEmpty {
            await viewModel.load()
        }
        if let latest = viewModel.articles.first {
            // Reuse the deep-link mechanism the existing Home flow already understands.
            NotificationManager.shared.selectedArticleId = latest.id
            if playAudio {
                AudioReaderManager.shared.play(article: latest)
            }
        }
    }
    
    @ViewBuilder
    private var iPadLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(spacing: 0) {
                HStack {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                    Text(LocalizedStringKey("app.name"))
                        .font(.headline)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)

                List {
                    ForEach(NavigationTab.allCases, id: \.self) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            Label {
                                Text(tab.localizedTitle)
                            } icon: {
                                Image(systemName: tab.icon)
                            }
                        }
                        .listRowBackground(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                        .accessibilityIdentifier("sidebar-tab-\(tab.rawValue)")
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            Group {
                switch selectedTab {
                case .home:    HomeFeedView()
                case .markets: CryptoWatchlistView()
                case .search:  DiscoverView()
                case .saved:   SavedArticlesView()
                case .profile: ProfileSettingsView()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    @ViewBuilder
    private var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            HomeFeedView()
                .tabItem {
                    Label {
                        Text(LocalizedStringKey("tab.home"))
                    } icon: {
                        Image(systemName: "house.fill")
                    }
                }
                .tag(NavigationTab.home)

            CryptoWatchlistView()
                .tabItem {
                    Label {
                        Text("Markets")
                    } icon: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                }
                .tag(NavigationTab.markets)
                .accessibilityIdentifier("tab-markets")

            DiscoverView()
                .tabItem {
                    Label {
                        Text(LocalizedStringKey("tab.search"))
                    } icon: {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .tag(NavigationTab.search)

            SavedArticlesView()
                .tabItem {
                    Label {
                        Text(LocalizedStringKey("tab.saved"))
                    } icon: {
                        Image(systemName: "bookmark.fill")
                    }
                }
                .tag(NavigationTab.saved)

            ProfileSettingsView()
                .tabItem {
                    Label {
                        Text(LocalizedStringKey("tab.profile"))
                    } icon: {
                        Image(systemName: "person.crop.circle.fill")
                    }
                }
                .tag(NavigationTab.profile)
        }
    }
}

#Preview {
    AdaptiveContentView()
}
