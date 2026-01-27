import SwiftUI

struct ArticleRowView: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cover Image
            if let imageURL = article.imageURL {
                CachedAsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(16)
                } placeholder: {
                    ZStack {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.gray.opacity(0.1),
                                        Color.gray.opacity(0.2),
                                        Color.gray.opacity(0.1)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        ProgressView()
                    }
                    .frame(height: 200)
                    .cornerRadius(16)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(article.displayTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                Text(article.displayExcerpt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 0) {
                if let author = article.author, let authorSlug = article.authorSlug {
                    NavigationLink(destination: AuthorProfileView(authorSlug: authorSlug)) {
                        HStack(spacing: 8) {
                            if let profileImage = article.authorProfileImage {
                                CachedAsyncImage(url: profileImage) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 28, height: 28)
                                        .clipShape(Circle())
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 28, height: 28)
                                }
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 28, height: 28)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(author)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                
                                Text(article.publishedAt, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Article: \(article.displayTitle). Author: \(article.author ?? "Unknown author").")
    }
}

#Preview {
    NavigationStack {
        ArticleRowView(article: Article(
            id: "1",
            title: "Sample Title",
            excerpt: "Short excerpt for preview purposes.",
            contentHTML: "<p>Content</p>",
            publishedAt: .now,
            url: "https://example.com",
            author: "Preview",
            authorSlug: "preview",
            authorProfileImage: nil,
            imageURL: nil,
            tags: ["Swift"],
            readingTimeMinutes: 5
        ))
        .padding()
    }
}
