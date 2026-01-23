import SwiftUI

struct DataExportView: View {
    @EnvironmentObject var viewModel: ArticleViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var exportComplete = false
    @State private var shareURL: URL?
    
    enum ExportType: Hashable {
        case savedArticles
        case readingHistory
        case allData
        
        var titleKey: String {
            switch self {
            case .savedArticles: return "export.savedArticles"
            case .readingHistory: return "export.readingHistory"
            case .allData: return "export.allData"
            }
        }
        
        var descriptionKey: String {
            switch self {
            case .savedArticles: return "export.savedArticles.description"
            case .readingHistory: return "export.readingHistory.description"
            case .allData: return "export.allData.description"
            }
        }
        
        var icon: String {
            switch self {
            case .savedArticles: return "bookmark.fill"
            case .readingHistory: return "clock.fill"
            case .allData: return "doc.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach([ExportType.savedArticles, .readingHistory, .allData], id: \.self) { type in
                        Button {
                            exportData(type: type)
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: type.icon)
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizedStringKey(type.titleKey))
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(LocalizedStringKey(type.descriptionKey))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if isExporting {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .disabled(isExporting)
                    }
                } header: {
                    Text(LocalizedStringKey("export.options"))
                } footer: {
                    Text(LocalizedStringKey("export.description"))
                }
            }
            .navigationTitle(LocalizedStringKey("export.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text(LocalizedStringKey("general.close"))
                    }
                }
            }
            .alert(LocalizedStringKey("export.complete"), isPresented: $exportComplete) {
                Button(LocalizedStringKey("general.share")) {
                    if let url = shareURL {
                        shareFile(url: url)
                    }
                }
                Button(LocalizedStringKey("general.close"), role: .cancel) {}
            } message: {
                Text(LocalizedStringKey("export.success"))
            }
        }
    }
    
    private func exportData(type: ExportType) {
        isExporting = true
        
        Task {
            do {
                let data: Data
                let filename: String
                
                switch type {
                case .savedArticles:
                    let saved = viewModel.savedArticles.map { article in
                        [
                            "id": article.id,
                            "title": article.title,
                            "url": article.url,
                            "author": article.author ?? "",
                            "publishedAt": ISO8601DateFormatter().string(from: article.publishedAt)
                        ]
                    }
                    data = try JSONSerialization.data(withJSONObject: saved, options: .prettyPrinted)
                    filename = "saved-articles-\(Date().ISO8601Format()).json"
                    
                case .readingHistory:
                    let readIds = UserDefaults.standard.stringArray(forKey: "readArticles") ?? []
                    let history = readIds.map { id in
                        ["articleId": id, "readAt": Date().ISO8601Format()]
                    }
                    data = try JSONSerialization.data(withJSONObject: history, options: .prettyPrinted)
                    filename = "reading-history-\(Date().ISO8601Format()).json"
                    
                case .allData:
                    let themeRaw = UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.fromUserDefaults().rawValue
                    let resolvedTheme = AppTheme(rawValue: themeRaw) ?? .system
                    let allData: [String: Any] = [
                        "savedArticles": viewModel.savedArticles.map { ["id": $0.id, "title": $0.title] },
                        "readArticles": UserDefaults.standard.stringArray(forKey: "readArticles") ?? [],
                        "preferences": [
                            "theme": resolvedTheme.rawValue,
                            "darkMode": resolvedTheme == .dark,
                            "notifications": UserDefaults.standard.bool(forKey: "notificationsEnabled"),
                            "analytics": UserDefaults.standard.bool(forKey: "analyticsEnabled"),
                            "newsletter": UserDefaults.standard.bool(forKey: "newsletterOptIn")
                        ],
                        "exportedAt": Date().ISO8601Format()
                    ]
                    data = try JSONSerialization.data(withJSONObject: allData, options: .prettyPrinted)
                    filename = "etherworld-data-export-\(Date().ISO8601Format()).json"
                }
                
                // Save to temporary directory
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try data.write(to: tempURL)
                
                await MainActor.run {
                    shareURL = tempURL
                    isExporting = false
                    exportComplete = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                }
            }
        }
    }
    
    private func shareFile(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first,
           let rootVC = window.rootViewController {
            activityVC.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(activityVC, animated: true)
        }
    }
}

#Preview {
    DataExportView()
        .environmentObject(ArticleViewModel())
}
