import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let scale: CGFloat
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    init(
        url: URL?,
        scale: CGFloat = 1.0,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.scale = scale
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
                    .transition(.opacity)
            } else {
                placeholder()
                    .task {
                        await loadImage()
                    }
            }
        }
        .animation(.easeIn(duration: 0.2), value: image != nil)
    }

    private func loadImage() async {
        guard let url = url, image == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // 1. Memory cache — instant
        if let cached = ImageCache.shared.get(forKey: url.absoluteString) {
            self.image = cached
            return
        }

        // 2. Disk cache + optimization on background thread
        let resolved = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            if let diskCached = Self.loadFromDisk(url: url) {
                return diskCached
            }
            // 3. Download through the rate-limited shared loader (high priority = jumps prefetch queue)
            guard let (data, _) = try? await ImageLoader.shared.data(from: url, highPriority: true),
                  let downloaded = UIImage(data: data) else { return nil }
            let optimized = Self.optimize(downloaded)
            Self.saveToDisk(image: optimized, url: url)
            return optimized
        }.value

        if let resolved {
            ImageCache.shared.set(resolved, forKey: url.absoluteString)
            self.image = resolved
        }
    }

    // MARK: - Background helpers (static so Task.detached has no self capture)

    private static func loadFromDisk(url: URL) -> UIImage? {
        let fileURL = diskCacheURL(for: url)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    private static func saveToDisk(image: UIImage, url: URL) {
        let imagesDir = diskCacheDir()
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        guard let data = image.jpegData(compressionQuality: 0.75) else { return }
        try? data.write(to: diskCacheURL(for: url))
    }

    private static func optimize(_ image: UIImage) -> UIImage {
        // Cap at screen-width * 2 for retina — no bigger than needed
        let screenWidth = UIScreen.main.bounds.width * UIScreen.main.scale
        let maxDimension = min(screenWidth, 900)
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    private static func diskCacheDir() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("img_cache")
    }

    private static func diskCacheURL(for url: URL) -> URL {
        let key = url.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? url.lastPathComponent
        return diskCacheDir().appendingPathComponent(key)
    }
}

// Memory cache for images
class ImageCache {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }
    
    func get(forKey key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    func clear() {
        cache.removeAllObjects()
    }
}

// Shared image loader with optimized URLSession + concurrency limiter
class ImageLoader {
    static let shared = ImageLoader()

    let session: URLSession

    /// Limits simultaneous image downloads so the connection pool isn't saturated.
    /// 4 concurrent downloads is a good balance: fast enough to fill the screen,
    /// low enough to avoid queuing 100 requests and hitting timeouts.
    private let semaphore = DownloadSemaphore(limit: 4)

    private init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 200 * 1024 * 1024, directory: nil)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = 6
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }

    func data(from url: URL, highPriority: Bool = false) async throws -> (Data, URLResponse) {
        await semaphore.wait(highPriority: highPriority)
        defer { Task { await semaphore.signal() } }
        return try await session.data(from: url)
    }
}

/// Actor-based semaphore that serves high-priority waiters before low-priority ones.
/// This ensures visible images (userInitiated) always load before background prefetch tasks.
actor DownloadSemaphore {
    private let limit: Int
    private var running = 0
    private var highPriorityWaiters: [CheckedContinuation<Void, Never>] = []
    private var lowPriorityWaiters:  [CheckedContinuation<Void, Never>] = []

    init(limit: Int) { self.limit = limit }

    func wait(highPriority: Bool = false) async {
        if running < limit {
            running += 1
        } else {
            await withCheckedContinuation { continuation in
                if highPriority {
                    highPriorityWaiters.append(continuation)
                } else {
                    lowPriorityWaiters.append(continuation)
                }
            }
        }
    }

    func signal() {
        // Always drain high-priority queue first
        if let next = highPriorityWaiters.first {
            highPriorityWaiters.removeFirst()
            next.resume()
        } else if let next = lowPriorityWaiters.first {
            lowPriorityWaiters.removeFirst()
            next.resume()
        } else {
            running -= 1
        }
    }
}
