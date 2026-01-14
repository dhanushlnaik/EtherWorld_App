import SwiftUI
import Combine

// MARK: - Supporting Views

struct FeedHeaderView: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text("home.today")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

struct HeroArticleCard: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageURL = article.imageURL {
                CachedAsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: UIScreen.main.bounds.width - 40, height: 160)
                        .clipped()
                        .cornerRadius(12)
                        .opacity(article.isRead ? 0.6 : 1.0)
                } placeholder: {
                    heroImagePlaceholder
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if let minutes = article.readingTimeMinutes {
                        Text("\(minutes) \(Text("home.minRead"))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if article.isRead {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Text(article.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(article.isRead ? .secondary : .primary)
                    .lineLimit(2)
                
                Text(article.excerpt)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: UIScreen.main.bounds.width - 40, alignment: .leading)
        }
    }
    
    private var heroImagePlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
            ProgressView()
        }
        .frame(width: UIScreen.main.bounds.width - 40, height: 160)
        .cornerRadius(12)
    }
}

struct TopStoryRow: View {
    let article: Article
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let imageURL = article.imageURL {
                CachedAsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipped()
                        .cornerRadius(8)
                } placeholder: {
                    thumbnailPlaceholder
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if !article.tags.isEmpty {
                    Text(article.tags.first!)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                
                HStack {
                    Text(article.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(article.isRead ? .secondary : .primary)
                        .lineLimit(2)
                    
                    if article.isRead {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                
                if let author = article.author {
                    Text(author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .opacity(article.isRead ? 0.7 : 1.0)
            
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var thumbnailPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .frame(width: 80, height: 80)
        .cornerRadius(8)
    }
}

struct EmptyFeedView: View {
    let onRefresh: () async -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text("home.today")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 16) {
                Circle()
                    .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                    )
                
                Text("home.allCaughtUp")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("home.noStories")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    Task { await onRefresh() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("home.refreshFeed")
                    }
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black)
                    .cornerRadius(24)
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding(.top)
    }
}

struct LoadingFeedView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    Text("home.today")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    ZStack {
                        LinearGradient(
                            colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                    .frame(height: 200)
                    .cornerRadius(16)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 12)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 20)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 14)
                            .frame(width: 250)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top)
        }
    }
}

// MARK: - Main View

struct HomeFeedView: View {
    @EnvironmentObject var viewModel: ArticleViewModel
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var navigationPath = NavigationPath()
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            contentView
                .navigationBarTitleDisplayMode(.inline)
                .task {
                    if notificationsEnabled {
                        NotificationManager.shared.checkForNewArticles(articles: viewModel.articles)
                    }
                }
                .onReceive(notificationManager.$selectedArticleId.compactMap { $0 }) { articleId in
                    Task { await handleDeepLink(articleId: articleId) }
                }
                .navigationDestination(for: Article.self) { article in
                    ArticleDetailView(article: article)
                }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.articles.isEmpty {
            LoadingFeedView()
        } else if let error = viewModel.errorMessage, viewModel.articles.isEmpty {
            ErrorStateView(
                errorMessage: error,
                retryAction: { await viewModel.load() },
                isOffline: error.localizedCaseInsensitiveContains("offline") || error.localizedCaseInsensitiveContains("connection")
            )
        } else if viewModel.articles.isEmpty {
            EmptyFeedView(onRefresh: { await viewModel.load() })
        } else {
            feedContentView
        }
    }
    
    private var feedContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                FeedHeaderView()
                
                // Horizontal scrolling hero section
                if !viewModel.articles.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(viewModel.articles.prefix(10)) { article in
                                NavigationLink(value: article) {
                                    HeroArticleCard(article: article)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // All articles in vertical list
                if viewModel.articles.count > 0 {
                    topStoriesSection
                }
            }
            .padding(.top)
        }
        .refreshable {
            await viewModel.load()
        }
    }
    
    private var topStoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 8, height: 8)
                
                Text("home.topStories")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)
            .padding(.top, 24)
            
            ForEach(Array(viewModel.articles.enumerated()), id: \.element.id) { index, article in
                NavigationLink(value: article) {
                    TopStoryRow(article: article)
                }
                .buttonStyle(.plain)
                .onAppear {
                    // Load more when reaching near the end
                    if index == viewModel.articles.count - 3 {
                        Task {
                            await viewModel.loadMore()
                        }
                    }
                }
                
                Divider()
                    .padding(.leading)
            }
            
            if viewModel.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            }
        }
    }

    private func handleDeepLink(articleId: String) async {
        // Ensure articles are loaded
        if viewModel.articles.isEmpty {
            await viewModel.load()
        }
        if let article = viewModel.articles.first(where: { $0.id == articleId }) {
            navigationPath.append(article)
            return
        }
        // Attempt a refresh if not found
        await viewModel.load()
        if let article = viewModel.articles.first(where: { $0.id == articleId }) {
            navigationPath.append(article)
        }
    }
}

#Preview {
    HomeFeedView()
}
