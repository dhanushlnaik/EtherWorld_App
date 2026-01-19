import SwiftUI

struct AdaptiveContentView: View {
    @StateObject private var viewModel = ArticleViewModel()
    @StateObject private var authManager = AuthenticationManager()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: NavigationTab = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    
    enum NavigationTab: String, CaseIterable {
        case home = "tab.home"
        case search = "tab.search"
        case saved = "tab.saved"
        case profile = "tab.profile"
        
        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .search: return "magnifyingglass"
            case .saved: return "bookmark.fill"
            case .profile: return "person.crop.circle.fill"
            }
        }
    }
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad: NavigationSplitView with sidebar
                iPadLayout
            } else {
                // iPhone: TabView
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
    }
    
    @ViewBuilder
    private var iPadLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            VStack(spacing: 0) {
                // Sidebar Logo
                HStack {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .cornerRadius(8)
                    Text("EtherWorld")
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
                                Text(LocalizedStringKey(tab.rawValue))
                            } icon: {
                                Image(systemName: tab.icon)
                            }
                        }
                        .listRowBackground(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } detail: {
            // Detail view based on selection
            Group {
                switch selectedTab {
                case .home:
                    HomeFeedView()
                case .search:
                    DiscoverView()
                case .saved:
                    SavedArticlesView()
                case .profile:
                    ProfileSettingsView()
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
                        Text("tab.home")
                    } icon: {
                        Image(systemName: "house.fill")
                    }
                }
                .tag(NavigationTab.home)
            
            DiscoverView()
                .tabItem {
                    Label {
                        Text("tab.search")
                    } icon: {
                        Image(systemName: "magnifyingglass")
                    }
                }
                .tag(NavigationTab.search)
            
            SavedArticlesView()
                .tabItem {
                    Label {
                        Text("tab.saved")
                    } icon: {
                        Image(systemName: "bookmark.fill")
                    }
                }
                .tag(NavigationTab.saved)
            
            ProfileSettingsView()
                .tabItem {
                    Label {
                        Text("tab.profile")
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
