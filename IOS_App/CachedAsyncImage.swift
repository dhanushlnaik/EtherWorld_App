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
            } else {
                placeholder()
                    .task {
                        await loadImage()
                    }
            }
        }
    }
    
    private func loadImage() async {
        guard let url = url, image == nil, !isLoading else { return }
        isLoading = true
        
        // Check memory cache first
        if let cached = ImageCache.shared.get(forKey: url.absoluteString) {
            await MainActor.run {
                self.image = cached
            }
            isLoading = false
            return
        }
        
        // Check disk cache
        if let diskCached = loadFromDiskSync(url: url) {
            await MainActor.run {
                self.image = diskCached
                ImageCache.shared.set(diskCached, forKey: url.absoluteString)
            }
            isLoading = false
            return
        }
        
        // Download with URLSession that respects cache
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache.shared
        config.requestCachePolicy = .returnCacheDataElseLoad
        let session = URLSession(configuration: config)
        
        do {
            let (data, _) = try await session.data(from: url)
            if let downloaded = UIImage(data: data) {
                // Optimize size on background thread
                let optimized = optimizeImageSync(downloaded)
                await MainActor.run {
                    self.image = optimized
                    ImageCache.shared.set(optimized, forKey: url.absoluteString)
                }
                Task.detached {
                    await self.saveToDiskAsync(image: optimized, url: url)
                }
            }
        } catch {
            // Fail silently
        }
        isLoading = false
    }
    
    private func loadFromDiskSync(url: URL) -> UIImage? {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let fileName = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        let fileURL = cacheDir.appendingPathComponent("images").appendingPathComponent(fileName)
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }
    
    private func saveToDiskAsync(image: UIImage, url: URL) async {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let imagesDir = cacheDir.appendingPathComponent("images")
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        
        let fileName = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        let fileURL = imagesDir.appendingPathComponent(fileName)
        
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        try? data.write(to: fileURL)
    }
    
    private func optimizeImageSync(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1200
        let size = image.size
        
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }
        
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// Memory cache for images
@MainActor
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
