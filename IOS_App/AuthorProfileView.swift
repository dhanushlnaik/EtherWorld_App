import SwiftUI

struct AuthorProfileView: View {
    let authorSlug: String
    @StateObject private var viewModel = AuthorProfileViewModel()
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView(LocalizedStringKey("author.loading"))
                    .padding()
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(LocalizedStringKey("author.failedToLoad"))
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button(LocalizedStringKey("author.retry")) {
                        Task { await viewModel.loadAuthor(slug: authorSlug) }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if let author = viewModel.author {
                VStack(spacing: 0) {
                    // Cover Image
                    if let coverImage = author.coverImage {
                        CachedAsyncImage(url: coverImage) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                                .frame(height: 200)
                        }
                    }
                    
                    // Profile Section
                    VStack(spacing: 16) {
                        // Profile Image
                        if let profileImage = author.profileImage {
                            CachedAsyncImage(url: profileImage) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 120, height: 120)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
                            }
                            .offset(y: -60)
                            .padding(.bottom, -60)
                        }
                        
                        // Author Info
                        VStack(spacing: 8) {
                            Text(author.name)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            if let location = author.location {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.circle")
                                        .font(.caption)
                                    Text(location)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let website = author.website {
                                Link(destination: website) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "link")
                                            .font(.caption)
                                        Text(website.absoluteString)
                                            .font(.subheadline)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        
                        // Social Links
                        HStack(spacing: 16) {
                            if let twitter = author.twitter {
                                Link(destination: URL(string: "https://twitter.com/\(twitter)")!) {
                                    HStack {
                                        Image(systemName: "bird")
                                        Text(LocalizedStringKey("author.twitter"))
                                    }
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            }
                            
                            if let postCount = author.postCount {
                                HStack {
                                    Image(systemName: "doc.text")
                                    Text(String(format: NSLocalizedString("author.posts", comment: ""), postCount))
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                        
                        if let bio = author.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                    
                    Divider()
                        .padding(.vertical)
                    
                    // Articles Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text(String(format: NSLocalizedString("author.storiesBy", comment: ""), author.name.uppercased()))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.teal)
                            .cornerRadius(8)
                            .shadow(color: Color.teal.opacity(0.3), radius: 8, x: 0, y: 2)
                            .padding(.horizontal)
                        
                        if viewModel.articles.isEmpty {
                            Text(LocalizedStringKey("author.noArticles"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(viewModel.articles) { article in
                                NavigationLink(destination: ArticleDetailView(article: article)) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        if let imageURL = article.imageURL {
                                            CachedAsyncImage(url: imageURL) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(height: 200)
                                                    .clipped()
                                                    .cornerRadius(12)
                                            } placeholder: {
                                                ZStack {
                                                    LinearGradient(
                                                        colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                    ProgressView()
                                                }
                                                .frame(height: 200)
                                                .cornerRadius(12)
                                            }
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 6) {
                                            if !article.tags.isEmpty {
                                                Text(article.tags.first!)
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.blue)
                                                    .textCase(.uppercase)
                                            }
                                            
                                            Text(article.title)
                                                .font(.headline)
                                                .fontWeight(.semibold)
                                                .lineLimit(2)
                                                .foregroundColor(.primary)
                                            
                                            Text(article.excerpt)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .lineLimit(3)
                                            
                                            Text(article.publishedAt.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .padding(.top, 2)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("author.profileTitle"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadAuthor(slug: authorSlug)
        }
    }
}
