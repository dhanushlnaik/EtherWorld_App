import Foundation
import SwiftUI
import Combine

struct ArticleHighlight: Identifiable, Codable, Hashable {
    let id: UUID
    let articleId: String
    let articleTitle: String
    let articleURL: String
    var text: String
    var note: String
    var color: HighlightColor
    let createdAt: Date

    init(id: UUID = UUID(),
         articleId: String,
         articleTitle: String,
         articleURL: String,
         text: String,
         note: String = "",
         color: HighlightColor = .yellow,
         createdAt: Date = Date()) {
        self.id = id
        self.articleId = articleId
        self.articleTitle = articleTitle
        self.articleURL = articleURL
        self.text = text
        self.note = note
        self.color = color
        self.createdAt = createdAt
    }
}

enum HighlightColor: String, Codable, CaseIterable, Identifiable {
    case yellow, green, blue, pink, orange
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .yellow: return .yellow
        case .green:  return .green
        case .blue:   return .blue
        case .pink:   return .pink
        case .orange: return .orange
        }
    }

    var label: String {
        rawValue.capitalized
    }
}

@MainActor
final class HighlightsManager: ObservableObject {
    static let shared = HighlightsManager()

    @Published private(set) var highlights: [ArticleHighlight] = []

    private let storeURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("highlights.json")
    }()

    private init() {
        load()
    }

    func add(_ highlight: ArticleHighlight) {
        highlights.insert(highlight, at: 0)
        persist()
    }

    func remove(_ highlight: ArticleHighlight) {
        highlights.removeAll { $0.id == highlight.id }
        persist()
    }

    func update(_ highlight: ArticleHighlight) {
        guard let idx = highlights.firstIndex(where: { $0.id == highlight.id }) else { return }
        highlights[idx] = highlight
        persist()
    }

    func highlights(for articleId: String) -> [ArticleHighlight] {
        highlights.filter { $0.articleId == articleId }
    }

    func clearAll() {
        highlights.removeAll()
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([ArticleHighlight].self, from: data) else {
            return
        }
        self.highlights = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(highlights) else { return }
        try? data.write(to: storeURL)
    }
}

// MARK: - Add Highlight Sheet

struct AddHighlightSheet: View {
    let article: Article
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = HighlightsManager.shared

    @State private var passage: String = ""
    @State private var note: String = ""
    @State private var color: HighlightColor = .yellow

    var body: some View {
        NavigationStack {
            Form {
                Section("Passage") {
                    TextEditor(text: $passage)
                        .frame(minHeight: 120)
                        .accessibilityIdentifier("highlight-passage-editor")
                }
                Section("Personal note (optional)") {
                    TextEditor(text: $note)
                        .frame(minHeight: 80)
                        .accessibilityIdentifier("highlight-note-editor")
                }
                Section("Color") {
                    HStack(spacing: 12) {
                        ForEach(HighlightColor.allCases) { c in
                            Button {
                                color = c
                                HapticFeedback.light()
                            } label: {
                                Circle()
                                    .fill(c.color)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary,
                                                    lineWidth: color == c ? 2 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(c.label) highlight")
                        }
                    }
                }
            }
            .navigationTitle("New Highlight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let trimmed = passage.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let h = ArticleHighlight(
                            articleId: article.id,
                            articleTitle: article.title,
                            articleURL: article.url,
                            text: trimmed,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            color: color
                        )
                        manager.add(h)
                        HapticFeedback.medium()
                        dismiss()
                    }
                    .accessibilityIdentifier("save-highlight-button")
                    .disabled(passage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Browse Highlights View

struct HighlightsView: View {
    @ObservedObject private var manager = HighlightsManager.shared
    @State private var searchText: String = ""
    @State private var selectedColor: HighlightColor?

    private var filtered: [ArticleHighlight] {
        manager.highlights.filter { h in
            (selectedColor == nil || h.color == selectedColor!) &&
            (searchText.isEmpty
             || h.text.localizedCaseInsensitiveContains(searchText)
             || h.note.localizedCaseInsensitiveContains(searchText)
             || h.articleTitle.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        Group {
            if manager.highlights.isEmpty {
                ContentUnavailableView(
                    "No highlights yet",
                    systemImage: "highlighter",
                    description: Text("Open an article and tap the highlighter icon to save a passage.")
                )
            } else {
                List {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(label: "All", selected: selectedColor == nil) {
                                    selectedColor = nil
                                }
                                ForEach(HighlightColor.allCases) { c in
                                    FilterChip(label: c.label,
                                               selected: selectedColor == c,
                                               accent: c.color) {
                                        selectedColor = (selectedColor == c) ? nil : c
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    ForEach(filtered) { h in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(h.color.color)
                                    .frame(width: 4)
                                Text(h.articleTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Text(h.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text("“\(h.text)”")
                                .font(.body)
                                .padding(.leading, 8)
                            if !h.note.isEmpty {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "note.text")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(h.note)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.leading, 8)
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                manager.remove(h)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $searchText, prompt: "Search highlights & notes")
            }
        }
        .navigationTitle("Highlights & Notes")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FilterChip: View {
    let label: String
    let selected: Bool
    var accent: Color = .blue
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selected ? accent.opacity(0.85) : Color(.systemGray5))
                .foregroundStyle(selected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

