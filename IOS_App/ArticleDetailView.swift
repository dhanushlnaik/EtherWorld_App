import SwiftUI
import WebKit

struct ArticleDetailView: View {
    let article: Article
    @EnvironmentObject var viewModel: ArticleViewModel
    @StateObject private var detailVM: ArticleDetailViewModel
    @State private var isSaved: Bool = false
    @State private var isRead: Bool = false
    @State private var scrollOffset: CGFloat = 0
    @State private var isExcerptExpanded: Bool = false
    @State private var showingTranslationOptions: Bool = false
    @AppStorage("appLanguage") private var appLanguageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    
    private var excerptWords: [String] {
        article.displayExcerpt.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    }
    
    private var displayedExcerpt: String {
        if isExcerptExpanded || excerptWords.count <= 30 {
            return article.displayExcerpt
        } else {
            return excerptWords.prefix(30).joined(separator: " ") + "..."
        }
    }
    
    init(article: Article) {
        self.article = article
        _detailVM = StateObject(wrappedValue: ArticleDetailViewModel(article: article))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image
                if let imageURL = article.imageURL {
                    CachedAsyncImage(url: imageURL) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(LocalizedStringKey("article.coverImageAccessibility"))
                            .transition(.opacity)
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
                        .frame(height: 250)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(article.displayTitle)
                        .font(.title)
                        .bold()
                        .accessibilityAddTraits(.isHeader)
                    
                    // Expandable Excerpt
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayedExcerpt)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        if excerptWords.count > 30 {
                            Button(action: {
                                withAnimation {
                                    isExcerptExpanded.toggle()
                                }
                            }) {
                                Text(LocalizedStringKey(isExcerptExpanded ? "article.showLess" : "article.showMore"))
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                        .bold()
                                }
                            }
                        }
                        
                        HStack(spacing: 12) {
                            if let author = article.author, let authorSlug = article.authorSlug {
                                NavigationLink(destination: AuthorProfileView(authorSlug: authorSlug)) {
                                    HStack(spacing: 8) {
                                        if let profileImage = article.authorProfileImage {
                                            CachedAsyncImage(url: profileImage) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 32, height: 32)
                                                    .clipShape(Circle())
                                            } placeholder: {
                                                Circle()
                                                    .fill(Color.gray.opacity(0.2))
                                                    .frame(width: 32, height: 32)
                                            }
                                        } else {
                                            Circle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(width: 32, height: 32)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(author)
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                                .bold()
                                            Text(article.publishedAt.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            } else if let author = article.author {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 32, height: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(author)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                        Text(article.publishedAt.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            Spacer()
                        }
                        
                        Divider()
                            .padding(.vertical, 8)

                        DynamicHTMLContentView(html: detailVM.article.displayContent)
                    }
                    .padding()
                }
            }
            .navigationTitle(LocalizedStringKey("article.articleTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: 
                HStack(spacing: 16) {
                    ShareLink(item: URL(string: article.url) ?? URL(fileURLWithPath: ""), subject: Text(article.displayTitle), message: Text(article.displayExcerpt)) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel(LocalizedStringKey("article.share"))
                    .accessibilityHint(LocalizedStringKey("article.shareHint"))
                    
                    Button(action: {
                        isSaved.toggle()
                        viewModel.toggleSaved(article: article)
                        HapticFeedback.medium()
                    }) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel(LocalizedStringKey(isSaved ? "article.removeBookmark" : "article.bookmark"))
                    .accessibilityHint(LocalizedStringKey(isSaved ? "article.removeBookmarkHint" : "article.addBookmarkHint"))
                }
            )
            .onAppear {
                isSaved = article.isSaved
                isRead = article.isRead
                // Mark as read when user opens the article
                self.viewModel.markAsRead(article: article)
                AnalyticsManager.shared.log(.articleOpen, params: ["id": article.id])
            }
            .task {
                await detailVM.loadContentIfNeeded(service: viewModel.articleService)
            }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct DynamicHTMLContentView: View {
    let html: String
    @State private var contentHeight: CGFloat = 500
    
    var body: some View {
        WebViewContainer(html: html, contentHeight: $contentHeight)
            .frame(height: contentHeight)
    }
}

struct WebViewContainer: UIViewRepresentable {
    let html: String
    @Binding var contentHeight: CGFloat
    
    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "heightHandler")
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        
        let htmlString = """
        <html>
        <head>
            <meta charset=\"UTF-8\">
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
            <style>
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, \"Segoe UI\", Roboto; 
                    font-size: 16px; 
                    line-height: 1.6; 
                    margin: 0; 
                    padding: 10px; 
                    color: #333; 
                }
                img { max-width: 100%; height: auto; margin: 10px 0; }
                a { color: #007AFF; }
                h1, h2, h3 { color: #000; margin-top: 16px; }
                p { margin: 10px 0; }
            </style>
            <script>
                function sendHeight() {
                    window.webkit.messageHandlers.heightHandler.postMessage(document.documentElement.scrollHeight);
                }
                window.addEventListener('load', sendHeight);
                window.addEventListener('resize', sendHeight);
                new ResizeObserver(sendHeight).observe(document.body);
                // Recalculate after images/layout settle
                window.addEventListener('load', function() {
                    setTimeout(sendHeight, 50);
                    setTimeout(sendHeight, 200);
                    setTimeout(sendHeight, 500);
                });
            </script>
        </head>
        <body>\(html)</body>
        </html>
        """
        webView.loadHTMLString(htmlString, baseURL: nil)
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(contentHeight: $contentHeight)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        @Binding var contentHeight: CGFloat
        
        init(contentHeight: Binding<CGFloat>) {
            _contentHeight = contentHeight
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.documentElement.scrollHeight") { (result, _) in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self.contentHeight = height
                    }
                } else if let number = result as? NSNumber {
                    DispatchQueue.main.async {
                        self.contentHeight = CGFloat(truncating: number)
                    }
                }
            }
        }
        
        // Listen for height updates from ResizeObserver
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightHandler" {
                if let height = message.body as? CGFloat {
                    DispatchQueue.main.async { self.contentHeight = height }
                } else if let number = message.body as? NSNumber {
                    DispatchQueue.main.async { self.contentHeight = CGFloat(truncating: number) }
                } else if let doubleVal = message.body as? Double {
                    DispatchQueue.main.async { self.contentHeight = CGFloat(doubleVal) }
                }
            }
        }
    }
}

struct HTMLContentView: UIViewRepresentable {
    let html: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        
        let htmlString = """
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto; 
                    font-size: 16px; 
                    line-height: 1.6; 
                    margin: 0; 
                    padding: 10px; 
                    color: #333; 
                }
                img { max-width: 100%; height: auto; margin: 10px 0; }
                a { color: #007AFF; }
                h1, h2, h3 { color: #000; margin-top: 16px; }
                p { margin: 10px 0; }
            </style>
            <script>
                window.addEventListener('load', function() {
                    var height = document.body.scrollHeight;
                    window.webkit.messageHandlers.heightHandler.postMessage(height);
                });
            </script>
        </head>
        <body>\(html)</body>
        </html>
        """
        webView.loadHTMLString(htmlString, baseURL: nil)
        
        let coordinator = Coordinator()
        webView.configuration.userContentController.add(coordinator, name: "heightHandler")
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKScriptMessageHandler {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            // Height message received but we don't need to do anything
            // The content will naturally expand
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
}

#Preview {
    NavigationStack {
        ArticleDetailView(article: Article(
            id: "1",
            title: "Sample Title",
            excerpt: "Short excerpt for preview purposes.",
            contentHTML: "<p>Full content</p>",
            publishedAt: .now,
            url: "https://example.com",
            author: "Preview",
            authorSlug: "preview",
            authorProfileImage: nil,
            imageURL: nil,
            tags: ["Swift"],
            readingTimeMinutes: 5
        ))
    }
}

