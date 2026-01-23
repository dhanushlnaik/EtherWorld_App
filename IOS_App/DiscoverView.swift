import SwiftUI

struct DiscoverView: View {
    @StateObject private var discoverViewModel = ArticleViewModel()
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var debounceWorkItem: DispatchWorkItem?
    @State private var selectedTags: Set<String> = []
    @State private var sortOption: SortOption = .newest
    @State private var displayLimit: Int = 20
    @State private var allTagsCache: [String] = []

    private let ignoredTags: Set<String> = ["ew-promoted-top", "ew-promoted-bottom", "#ew-promoted-top", "#ew-promoted-bottom"]
    
    var allTags: [String] {
        // Count tag occurrences across all articles
        var tagCounts: [String: Int] = [:]
        for article in discoverViewModel.articles {
            for tag in cleanTags(for: article) {
                tagCounts[tag, default: 0] += 1
            }
        }
        // Sort by frequency (most used first), then alphabetically
        return tagCounts.keys.sorted { lhs, rhs in 
            let lCount = tagCounts[lhs] ?? 0
            let rCount = tagCounts[rhs] ?? 0
            if lCount != rCount {
                return lCount > rCount
            }
            return lhs < rhs
        }
    }

    var matchingAuthors: [AuthorResult] {
        guard !debouncedSearchText.isEmpty, debouncedSearchText.count >= 2 else { return [] }
        
        let searchWord = debouncedSearchText.split(separator: " ").first.map(String.init) ?? debouncedSearchText
        
        var seen = Set<String>()
        var authors: [AuthorResult] = []
        
        for article in discoverViewModel.articles {
            guard let name = article.author, let slug = article.authorSlug else { continue }
            if seen.contains(slug) { continue }
            
            let firstName = name.split(separator: " ").first.map(String.init) ?? name
            if firstName.localizedCaseInsensitiveContains(searchWord) {
                seen.insert(slug)
                authors.append(AuthorResult(
                    name: name,
                    slug: slug,
                    profileImage: article.authorProfileImage
                ))
            }
        }
        
        return authors.sorted { $0.name < $1.name }
    }
    
    var filteredArticles: [Article] {
        var result = discoverViewModel.articles
        
        if !debouncedSearchText.isEmpty {
            result = result.filter { article in
                matchesSearch(article)
            }
        }
        
        if !selectedTags.isEmpty {
            let exactMatches = result.filter { article in
                let tags = Set(cleanTags(for: article))
                return selectedTags.allSatisfy { tags.contains($0) }
            }
            
            let partialMatches = result.filter { article in
                let tags = Set(cleanTags(for: article))
                return !selectedTags.allSatisfy { tags.contains($0) } &&
                selectedTags.contains(where: { tags.contains($0) })
            }
            
            var seen = Set<String>()
            result = (exactMatches + partialMatches).filter { article in
                if seen.contains(article.id) { return false }
                seen.insert(article.id)
                return true
            }
        }
        
        result.sort { lhs, rhs in
            let lScore = relevanceScore(for: lhs)
            let rScore = relevanceScore(for: rhs)
            if lScore != rScore { return lScore > rScore }
            switch sortOption {
            case .newest:
                return lhs.publishedAt > rhs.publishedAt
            case .oldest:
                return lhs.publishedAt < rhs.publishedAt
            case .author:
                return (lhs.author ?? "") < (rhs.author ?? "")
            }
        }
        
        return result
    }

    var paginatedArticles: [Article] {
        Array(filteredArticles.prefix(displayLimit))
    }

    private func loadMore() {
        displayLimit += 15
    }

    private func matchesSearch(_ article: Article) -> Bool {
        let searchWord = debouncedSearchText.split(separator: " ").first.map(String.init) ?? debouncedSearchText
        guard !searchWord.isEmpty else { return true }
        
        let contentMatches = article.contentHTML.localizedCaseInsensitiveContains(searchWord)
        let titleMatches = article.title.localizedCaseInsensitiveContains(searchWord)
        let excerptMatches = article.excerpt.localizedCaseInsensitiveContains(searchWord)
        let tagMatches = cleanTags(for: article).contains(where: { $0.localizedCaseInsensitiveContains(searchWord) })
        let authorMatches = article.author?.localizedCaseInsensitiveContains(searchWord) ?? false
        return titleMatches || excerptMatches || contentMatches || tagMatches || authorMatches
    }

    private func relevanceScore(for article: Article) -> Int {
        guard !debouncedSearchText.isEmpty else { return 0 }
        let searchWord = debouncedSearchText.split(separator: " ").first.map(String.init) ?? debouncedSearchText
        guard !searchWord.isEmpty else { return 0 }
        
        var score = 0
        if article.title.localizedCaseInsensitiveContains(searchWord) { score += 6 }
        if article.excerpt.localizedCaseInsensitiveContains(searchWord) { score += 3 }
        if article.contentHTML.localizedCaseInsensitiveContains(searchWord) { score += 2 }
        if cleanTags(for: article).contains(where: { $0.localizedCaseInsensitiveContains(searchWord) }) { score += 4 }
        if article.author?.localizedCaseInsensitiveContains(searchWord) ?? false { score += 5 }
        if !selectedTags.isEmpty {
            let tags = Set(cleanTags(for: article))
            if selectedTags.allSatisfy({ tags.contains($0) }) {
                score += 5
            } else if selectedTags.contains(where: { tags.contains($0) }) {
                score += 2
            }
        }
        return score
    }

    private func cleanTags(for article: Article) -> [String] {
        article.tags.filter { tag in
            let normalizedTag = tag.lowercased().trimmingCharacters(in: .whitespaces)
            let tagWithoutHash = normalizedTag.hasPrefix("#") ? String(normalizedTag.dropFirst()) : normalizedTag
            return !ignoredTags.contains(tagWithoutHash) && !ignoredTags.contains(normalizedTag)
        }
    }

    private func recomputeAllTags() {
        var tagCounts: [String: Int] = [:]
        for article in discoverViewModel.articles {
            for tag in cleanTags(for: article) {
                tagCounts[tag, default: 0] += 1
            }
        }
        let sorted = tagCounts.keys.sorted { lhs, rhs in
            let lCount = tagCounts[lhs] ?? 0
            let rCount = tagCounts[rhs] ?? 0
            if lCount != rCount { return lCount > rCount }
            return lhs < rhs
        }
        allTagsCache = sorted
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(LocalizedStringKey("search.placeholder"), text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                .onChange(of: searchText) { _, newValue in
                    debounceWorkItem?.cancel()
                    let workItem = DispatchWorkItem {
                        debouncedSearchText = newValue
                    }
                    debounceWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
                }
                
                // Sort and Tag Controls
                HStack {
                    Menu {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button {
                                sortOption = option
                            } label: {
                                HStack {
                                    switch option {
                                    case .newest:
                                        Text(LocalizedStringKey("discover.sort.newest"))
                                    case .oldest:
                                        Text(LocalizedStringKey("discover.sort.oldest"))
                                    case .author:
                                        Text(LocalizedStringKey("discover.sort.author"))
                                    }
                                    if sortOption == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            switch sortOption {
                            case .newest:
                                Text(LocalizedStringKey("discover.sort.newest"))
                            case .oldest:
                                Text(LocalizedStringKey("discover.sort.oldest"))
                            case .author:
                                Text(LocalizedStringKey("discover.sort.author"))
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    if !selectedTags.isEmpty {
                        Button {
                            selectedTags.removeAll()
                        } label: {
                            Text(LocalizedStringKey("discover.clear"))
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Tag Chips
                if !allTagsCache.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(allTagsCache.prefix(15), id: \.self) { tag in
                                TagChip(
                                    tag: tag,
                                    isSelected: selectedTags.contains(tag)
                                ) {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    .transition(.opacity)
                }
                
                Divider()
                
                // Results
                if discoverViewModel.isLoading && discoverViewModel.articles.isEmpty {
                    Spacer()
                    ProgressView(LocalizedStringKey("discover.loading"))
                    Spacer()
                } else if let error = discoverViewModel.errorMessage, discoverViewModel.articles.isEmpty {
                    ErrorStateView(
                        errorMessage: error,
                        retryAction: { await discoverViewModel.load() },
                        isOffline: error.localizedCaseInsensitiveContains("offline") || error.localizedCaseInsensitiveContains("connection")
                    )
                } else if !matchingAuthors.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(LocalizedStringKey("discover.authors"))
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            VStack(spacing: 16) {
                                ForEach(matchingAuthors, id: \.slug) { author in
                                    NavigationLink(value: author.slug) {
                                        HStack(spacing: 12) {
                                            if let profileImage = author.profileImage {
                                                CachedAsyncImage(url: profileImage) { image in
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 40, height: 40)
                                                        .clipShape(Circle())
                                                } placeholder: {
                                                    Image(systemName: "person.crop.circle.fill")
                                                        .resizable()
                                                        .scaledToFit()
                                                        .foregroundStyle(.secondary)
                                                        .frame(width: 40, height: 40)
                                                }
                                            } else {
                                                Image(systemName: "person.crop.circle.fill")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .foregroundStyle(.secondary)
                                                    .frame(width: 40, height: 40)
                                            }
                                            
                                            Text(author.name)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            if !filteredArticles.isEmpty {
                                Text(LocalizedStringKey("discover.articles"))
                                    .font(.headline)
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                
                                LazyVStack(spacing: 16) {
                                    ForEach(filteredArticles, id: \.id) { article in
                                        NavigationLink(value: article) {
                                            SearchResultCard(article: article)
                                        }
                                        .buttonStyle(.plain)
                                        .onAppear {
                                            if article.id == filteredArticles.last?.id {
                                                Task {
                                                    await discoverViewModel.loadMore()
                                                }
                                            }
                                        }
                                    }
                                    
                                    if discoverViewModel.isLoadingMore {
                                        ProgressView()
                                            .padding()
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } else if filteredArticles.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        LocalizedStringKey("discover.noResultsTitle"),
                        systemImage: "magnifyingglass",
                        description: Text(LocalizedStringKey("discover.noResults"))
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredArticles, id: \.id) { article in
                                NavigationLink(value: article) {
                                    SearchResultCard(article: article)
                                }
                                .buttonStyle(.plain)
                                .onAppear {
                                    // Load more when near the end
                                    if article.id == filteredArticles.last?.id {
                                        Task {
                                            await discoverViewModel.loadMore()
                                        }
                                    }
                                }
                            }
                            
                            if discoverViewModel.isLoadingMore {
                                ProgressView()
                                    .padding()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Compute tags from any cached articles immediately
                recomputeAllTags()
            }
            .task {
                await discoverViewModel.load()
            }
            .onChange(of: discoverViewModel.articles) { _, _ in
                // Recompute when articles update (e.g., after network load or pagination)
                recomputeAllTags()
            }
            .navigationDestination(for: Article.self) { article in
                ArticleDetailView(article: article)
            }
            .navigationDestination(for: String.self) { slug in
                AuthorProfileView(authorSlug: slug)
            }
        }
    }
}

struct TagChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            action()
            HapticFeedback.light()
        }) {
            Text(tag)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isSelected 
                        ? Color.blue 
                        : Color(.systemGray5)
                )
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(18)
                .opacity(isPressed ? 0.7 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onLongPressGesture(minimumDuration: .infinity, perform: {}, onPressingChanged: { pressed in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressed
            }
        })
    }
}

struct SearchResultCard: View {
    let article: Article
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Thumbnail
            if let imageURL = article.imageURL {
                CachedAsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipped()
                        .cornerRadius(12)
                } placeholder: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.15))
                        ProgressView()
                    }
                    .frame(width: 100, height: 100)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(article.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                
                Spacer()
                
                HStack(spacing: 8) {
                    if let author = article.author {
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if article.author != nil {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(article.publishedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 100)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

enum SortOption: String, CaseIterable {
    case newest = "newest"
    case oldest = "oldest"
    case author = "author"
    
    var displayName: LocalizedStringKey {
        switch self {
        case .newest: return LocalizedStringKey("discover.sort.newest")
        case .oldest: return LocalizedStringKey("discover.sort.oldest")
        case .author: return LocalizedStringKey("discover.sort.author")
        }
    }
}

struct AuthorResult {
    let name: String
    let slug: String
    let profileImage: URL?
}

#Preview {
    DiscoverView()
}
