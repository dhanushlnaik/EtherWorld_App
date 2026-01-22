import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ArticleViewModel()
    
    var body: some View {
        TabView {
            HomeFeedView()
                .tabItem {
                    Label {
                        Text(LocalizedStringKey("tab.home"))
                    } icon: {
                        Image(systemName: "house.fill")
                    }
                }
            
            DiscoverView()
                .tabItem {
                    Label {
                        Text(LocalizedStringKey("tab.search"))
                    } icon: {
                        Image(systemName: "magnifyingglass")
                    }
                }
            
            SavedArticlesView()
                .tabItem {
                    Label {
                        Text(LocalizedStringKey("tab.saved"))
                    } icon: {
                        Image(systemName: "bookmark.fill")
                    }
                }
            
            SettingsView()
                .tabItem {
                    Label {
                        Text(LocalizedStringKey("tab.profile"))
                    } icon: {
                        Image(systemName: "person.crop.circle.fill")
                    }
                }
        }
        .environmentObject(viewModel)
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
}

#Preview {
    ContentView()
}
