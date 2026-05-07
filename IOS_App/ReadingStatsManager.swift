import Foundation
import SwiftUI

struct ReadingDayLog: Codable, Identifiable, Hashable {
    var id: String { dayKey }
    let dayKey: String          // YYYY-MM-DD
    var articlesRead: Int
    var minutesRead: Double     // approximate, accumulated client-side

    static func key(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

@MainActor
final class ReadingStatsManager: ObservableObject {
    static let shared = ReadingStatsManager()

    @Published private(set) var logs: [String: ReadingDayLog] = [:]
    @Published private(set) var totalArticlesRead: Int = 0
    @Published private(set) var totalMinutesRead: Double = 0
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var longestStreak: Int = 0
    @Published private(set) var topicCounts: [String: Int] = [:]

    private let storeURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("reading-stats.json")
    }()

    private struct PersistedStats: Codable {
        var logs: [String: ReadingDayLog]
        var topicCounts: [String: Int]
        var totalArticlesRead: Int
        var totalMinutesRead: Double
    }

    private init() {
        load()
        recomputeStreaks()
    }

    func recordArticleRead(article: Article) {
        let key = ReadingDayLog.key(for: Date())
        var log = logs[key] ?? ReadingDayLog(dayKey: key, articlesRead: 0, minutesRead: 0)
        log.articlesRead += 1
        log.minutesRead += Double(article.readingTimeMinutes ?? 4)
        logs[key] = log

        totalArticlesRead += 1
        totalMinutesRead += Double(article.readingTimeMinutes ?? 4)

        for tag in article.tags {
            let normalized = tag.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { continue }
            topicCounts[normalized, default: 0] += 1
        }

        recomputeStreaks()
        persist()
    }

    func reset() {
        logs.removeAll()
        topicCounts.removeAll()
        totalArticlesRead = 0
        totalMinutesRead = 0
        currentStreak = 0
        longestStreak = 0
        persist()
    }

    /// Recent N days (default 14), oldest first.
    func recentDays(count: Int = 14) -> [ReadingDayLog] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<count).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let key = ReadingDayLog.key(for: day)
            return logs[key] ?? ReadingDayLog(dayKey: key, articlesRead: 0, minutesRead: 0)
        }
    }

    func topTopics(limit: Int = 5) -> [(topic: String, count: Int)] {
        topicCounts
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { ($0.key.capitalized, $0.value) }
    }

    private func recomputeStreaks() {
        let cal = Calendar.current
        var streak = 0
        var date = cal.startOfDay(for: Date())
        while logs[ReadingDayLog.key(for: date)] != nil {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        currentStreak = streak

        // Longest streak: scan all keys
        let sortedKeys = logs.keys.sorted()
        var longest = 0
        var run = 0
        var lastDate: Date?
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        for key in sortedKeys {
            guard let d = formatter.date(from: key) else { continue }
            if let prev = lastDate {
                let diff = cal.dateComponents([.day], from: prev, to: d).day ?? 0
                if diff == 1 { run += 1 } else { run = 1 }
            } else {
                run = 1
            }
            longest = max(longest, run)
            lastDate = d
        }
        longestStreak = longest
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode(PersistedStats.self, from: data) else {
            return
        }
        self.logs = decoded.logs
        self.topicCounts = decoded.topicCounts
        self.totalArticlesRead = decoded.totalArticlesRead
        self.totalMinutesRead = decoded.totalMinutesRead
    }

    private func persist() {
        let payload = PersistedStats(
            logs: logs,
            topicCounts: topicCounts,
            totalArticlesRead: totalArticlesRead,
            totalMinutesRead: totalMinutesRead
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: storeURL)
    }
}

// MARK: - Stats UI

struct ReadingStatsView: View {
    @ObservedObject private var manager = ReadingStatsManager.shared
    @State private var showResetConfirm = false

    private var weeklyMinutes: Double {
        manager.recentDays(count: 7).reduce(0) { $0 + $1.minutesRead }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hero streak card
                streakCard

                // Stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statCard(
                        icon: "doc.text.fill",
                        title: "Articles read",
                        value: "\(manager.totalArticlesRead)",
                        color: .blue
                    )
                    statCard(
                        icon: "clock.fill",
                        title: "Total minutes",
                        value: String(format: "%.0f", manager.totalMinutesRead),
                        color: .orange
                    )
                    statCard(
                        icon: "calendar",
                        title: "This week",
                        value: String(format: "%.0f min", weeklyMinutes),
                        color: .green
                    )
                    statCard(
                        icon: "trophy.fill",
                        title: "Longest streak",
                        value: "\(manager.longestStreak) days",
                        color: .purple
                    )
                }

                // Weekly bar chart
                weeklyChart

                // Top topics
                topTopics

                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Reset reading stats", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Reading Stats")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset reading stats?",
               isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) { manager.reset() }
        } message: {
            Text("This clears your streak, totals, and topic history on this device.")
        }
    }

    private var streakCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.orange, Color.pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 70, height: 70)
                Image(systemName: "flame.fill")
                    .foregroundStyle(.white)
                    .font(.system(size: 30, weight: .bold))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(manager.currentStreak)-day streak")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(manager.currentStreak == 0
                     ? "Read an article today to start your streak."
                     : "Keep reading daily to grow your streak.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.1), Color.pink.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
    }

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last 14 days")
                .font(.headline)
            let days = manager.recentDays(count: 14)
            let maxArticles = max(1, days.map(\.articlesRead).max() ?? 1)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(days) { day in
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(height: 90)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(day.articlesRead > 0 ? Color.indigo : Color.clear)
                                .frame(height: max(2, CGFloat(day.articlesRead) / CGFloat(maxArticles) * 90))
                        }
                        .frame(maxWidth: .infinity)
                        Text(dayInitial(for: day.dayKey))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var topTopics: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top topics")
                .font(.headline)
            let topics = manager.topTopics()
            if topics.isEmpty {
                Text("Read more articles to see your top topics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(topics, id: \.topic) { item in
                    HStack {
                        Text(item.topic)
                            .font(.subheadline)
                        Spacer()
                        Text("\(item.count)")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.indigo.opacity(0.15))
                            .foregroundStyle(.indigo)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func statCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }

    private func dayInitial(for dayKey: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: dayKey) else { return "" }
        let g = DateFormatter()
        g.dateFormat = "EEEEE"
        return g.string(from: d)
    }
}

#Preview {
    NavigationStack {
        ReadingStatsView()
    }
}
