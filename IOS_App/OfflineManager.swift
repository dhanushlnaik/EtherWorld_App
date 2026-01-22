import Foundation
import UIKit
import SwiftUI

enum OfflineManager {
    private static var offlineDir: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("offline")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func storageUsageBytes() -> Int64 {
        var total: Int64 = 0
        if let files = try? FileManager.default.contentsOfDirectory(at: offlineDir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
            for url in files {
                if let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) { total += Int64(size) }
            }
        }
        return total
    }

    static func clear() {
        if let files = try? FileManager.default.contentsOfDirectory(at: offlineDir, includingPropertiesForKeys: nil) {
            for url in files { try? FileManager.default.removeItem(at: url) }
        }
    }

    static func prefetch(articles: [Article], imageOnly: Bool = false) async {
        await withTaskGroup(of: Void.self) { group in
            for article in articles {
                group.addTask { await cacheArticle(article: article, imageOnly: imageOnly) }
            }
        }
    }

    static func cacheArticle(article: Article, imageOnly: Bool = false) async {
        if let imageURL = article.imageURL { _ = try? await download(url: imageURL) }
        if imageOnly { return }
        // Save HTML content as file
        let html = article.contentHTML
        let path = offlineDir.appendingPathComponent("\(article.id).html")
        try? html.data(using: .utf8)?.write(to: path)
    }

    private static func download(url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        // Also place a copy on disk for deterministic offline access
        let fileURL = offlineDir.appendingPathComponent(url.lastPathComponent)
        try? data.write(to: fileURL)
        return data
    }
}

struct OfflineControlsSection: View {
    @AppStorage("offlineAutoDownload") private var autoDownload = false
    @AppStorage("offlineLimit") private var offlineLimit: Int = 30
    @State private var usage: Int64 = 0
    @EnvironmentObject var viewModel: ArticleViewModel

    var body: some View {
        Section {
            Toggle(isOn: $autoDownload) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.green)
                        .frame(width: 28)
                        .font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("offline.title"))
                            .fontWeight(.medium)
                        Text(LocalizedStringKey("offline.description"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Text(LocalizedStringKey("offline.articlesCount"))
                Spacer()
                Picker(LocalizedStringKey("offline.articlesCount"), selection: $offlineLimit) {
                    ForEach([10, 20, 30, 50, 100], id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!autoDownload)
            }

            HStack {
                Text(LocalizedStringKey("offline.storage"))
                Spacer()
                Text(byteCount(usage))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Download Now") { Task { await downloadNow() } }
                    .disabled(!autoDownload)
                Spacer()
                Button("Clear Offline Data", role: .destructive) { clear() }
            }
        } header: {
            Text(LocalizedStringKey("offline.storageLabel"))
        }
        .onAppear { usage = OfflineManager.storageUsageBytes() }
    }

    private func downloadNow() async {
        let slice = Array(viewModel.articles.prefix(offlineLimit))
        await OfflineManager.prefetch(articles: slice)
        usage = OfflineManager.storageUsageBytes()
        HapticFeedback.light()
    }

    private func clear() {
        OfflineManager.clear()
        usage = OfflineManager.storageUsageBytes()
        HapticFeedback.light()
    }

    private func byteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
