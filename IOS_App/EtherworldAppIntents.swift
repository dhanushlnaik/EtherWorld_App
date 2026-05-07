import AppIntents
import SwiftUI

// MARK: - Open Latest Article Intent

@available(iOS 16.0, *)
struct OpenLatestArticleIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Latest EtherWorld Article"
    static var description = IntentDescription("Opens the most recent article in the EtherWorld app.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // The app's main view automatically loads the latest articles on launch.
        // We post a notification that AdaptiveContentView observes.
        await MainActor.run {
            NotificationCenter.default.post(name: .etherworldOpenLatest, object: nil)
        }
        return .result()
    }
}

// MARK: - Open Watchlist Intent

@available(iOS 16.0, *)
struct OpenCryptoWatchlistIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Crypto Watchlist"
    static var description = IntentDescription("Opens your EtherWorld crypto markets watchlist.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .etherworldOpenWatchlist, object: nil)
        }
        return .result()
    }
}

// MARK: - Read Latest Aloud Intent

@available(iOS 16.0, *)
struct ReadLatestArticleIntent: AppIntent {
    static var title: LocalizedStringResource = "Read Latest Article Aloud"
    static var description = IntentDescription("Opens the latest article and starts the listen mode in EtherWorld.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .etherworldReadLatestAloud, object: nil)
        }
        return .result()
    }
}

// MARK: - App Shortcuts Provider

@available(iOS 16.0, *)
struct EtherworldShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenLatestArticleIntent(),
            phrases: [
                "Open the latest article in \(.applicationName)",
                "Show me the latest \(.applicationName) story"
            ],
            shortTitle: "Latest Article",
            systemImageName: "newspaper.fill"
        )
        AppShortcut(
            intent: OpenCryptoWatchlistIntent(),
            phrases: [
                "Show my crypto watchlist in \(.applicationName)",
                "Open markets in \(.applicationName)"
            ],
            shortTitle: "Watchlist",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
        AppShortcut(
            intent: ReadLatestArticleIntent(),
            phrases: [
                "Read me the latest \(.applicationName) article",
                "Listen to \(.applicationName)"
            ],
            shortTitle: "Listen Mode",
            systemImageName: "headphones"
        )
    }
}

// MARK: - Notifications used to drive in-app navigation from intents

extension Notification.Name {
    static let etherworldOpenLatest      = Notification.Name("etherworld.openLatest")
    static let etherworldOpenWatchlist   = Notification.Name("etherworld.openWatchlist")
    static let etherworldReadLatestAloud = Notification.Name("etherworld.readLatestAloud")
}
