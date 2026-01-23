import SwiftUI

struct NotificationPreferencesView: View {
    @EnvironmentObject var viewModel: ArticleViewModel
    // Persist tag selections manually via UserDefaults (AppStorage doesn't support [String])
    @State private var notificationTags: [String] = []
    @AppStorage("quietStartHour") private var quietStartHour: Int = 23
    @AppStorage("quietEndHour") private var quietEndHour: Int = 7
    @State private var allTags: [String] = []

    private let ignoredTags: Set<String> = ["ew-promoted-top", "ew-promoted-bottom", "#ew-promoted-top", "#ew-promoted-bottom"]

    var body: some View {
        List {
            Section(LocalizedStringKey("notifications.topics")) {
                if allTags.isEmpty {
                    Text(LocalizedStringKey("notifications.noTopics")).foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(allTags, id: \.self) { tag in
                                TagToggleChip(tag: tag, isSelected: notificationTags.contains(tag)) {
                                    if let idx = notificationTags.firstIndex(of: tag) {
                                        notificationTags.remove(at: idx)
                                    } else {
                                        notificationTags.append(tag)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    if !notificationTags.isEmpty {
                        Text(String(format: NSLocalizedString("notifications.selected", comment: "Selected topics"), notificationTags.joined(separator: ", ")))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(LocalizedStringKey("notifications.quietHours")) {
                HStack {
                    Text(LocalizedStringKey("notifications.startTime"))
                    Spacer()
                    HourPicker(selectedHour: $quietStartHour)
                }
                HStack {
                    Text(LocalizedStringKey("notifications.endTime"))
                    Spacer()
                    HourPicker(selectedHour: $quietEndHour)
                }
                Text(LocalizedStringKey("notifications.muteHours"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(LocalizedStringKey("settings.notifications.prefs.title"))
        .onAppear {
            computeAllTags()
            notificationTags = UserDefaults.standard.stringArray(forKey: "notificationTags") ?? []
        }
        .onChange(of: viewModel.articles) { _, _ in computeAllTags() }
        .onChange(of: notificationTags) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "notificationTags")
        }
    }

    private func computeAllTags() {
        var tagCounts: [String: Int] = [:]
        for article in viewModel.articles {
            for tag in cleanTags(article.tags) { tagCounts[tag, default: 0] += 1 }
        }
        allTags = tagCounts.keys.sorted { lhs, rhs in
            let l = tagCounts[lhs] ?? 0, r = tagCounts[rhs] ?? 0
            if l != r { return l > r }
            return lhs < rhs
        }
    }

    private func cleanTags(_ tags: [String]) -> [String] {
        tags.compactMap { t in
            let n = t.lowercased().trimmingCharacters(in: .whitespaces)
            let stripped = n.hasPrefix("#") ? String(n.dropFirst()) : n
            return (ignoredTags.contains(n) || ignoredTags.contains(stripped)) ? nil : stripped
        }
    }
}

private struct HourPicker: View {
    @Binding var selectedHour: Int
    var body: some View {
        Picker(LocalizedStringKey("notifications.hour"), selection: $selectedHour) {
            ForEach(0..<24, id: \.self) { hour in
                Text(String(format: "%02d:00", hour)).tag(hour)
            }
        }
        .pickerStyle(.menu)
    }
}

private struct TagToggleChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(18)
        }
        .buttonStyle(.plain)
    }
}
