import Foundation
#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

enum AnalyticsEvent: String {
    case appOpen = "app_open"
    case articleOpen = "article_view"
    case articleSave = "article_save"
    case share = "share"
    case notificationReceived = "notification_received"
    case search = "search"
    case login = "login"
    case logout = "logout"
}

final class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    // Default to true for App Store production unless user opt-out is implemented
    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "analyticsEnabled") || !UserDefaults.standard.dictionaryRepresentation().keys.contains("analyticsEnabled")
    }

    private init() {
        if !UserDefaults.standard.dictionaryRepresentation().keys.contains("analyticsEnabled") {
            UserDefaults.standard.set(true, forKey: "analyticsEnabled")
        }
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "analyticsEnabled")
        #if canImport(FirebaseAnalytics)
        Analytics.setAnalyticsCollectionEnabled(enabled)
        #endif
    }

    func log(_ event: AnalyticsEvent, params: [String: Any]? = nil) {
        guard isEnabled else { return }
        
        #if DEBUG
        print("[Analytics] \(event.rawValue): \(params ?? [:])")
        #endif
        
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(event.rawValue, parameters: params)
        #endif
    }
    
    func setUser(_ userId: String?) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserID(userId)
        #endif
    }
}
