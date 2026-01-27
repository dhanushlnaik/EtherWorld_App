import Foundation

// Lightweight Supabase REST client for logging email + optional name.
// Uses PostgREST insert with upsert semantics (Prefer: resolution=merge-duplicates).
final class SupabaseService {
    static let shared = SupabaseService()
    private init() {}
    
    private enum Keys {
        static let supabaseURL = "supabase.url"
        static let supabaseAnonKey = "supabase.anonKey"
    }

    private func seededSupabaseURL() -> URL? {
        if let stored = KeychainHelper.shared.get(forKey: Keys.supabaseURL),
           let url = URL(string: stored), !stored.isEmpty {
            return url
        }

        let fromConfig = Configuration.supabaseURL
        if !fromConfig.isEmpty, let url = URL(string: fromConfig) {
            _ = KeychainHelper.shared.save(fromConfig, forKey: Keys.supabaseURL)
            return url
        }

        return nil
    }

    private func seededSupabaseAnonKey() -> String? {
        if let stored = KeychainHelper.shared.get(forKey: Keys.supabaseAnonKey), !stored.isEmpty {
            return stored
        }

        let fromConfig = Configuration.supabaseAnonKey
        if !fromConfig.isEmpty {
            _ = KeychainHelper.shared.save(fromConfig, forKey: Keys.supabaseAnonKey)
            return fromConfig
        }

        return nil
    }
    
    struct EmailRecord: Encodable {
        let email: String
        let name: String?
        let status: String = "pending"
        let last_sent_at: Date = Date()
    }

    struct UserPreferences: Codable {
        let userId: String
        let notificationsEnabled: Bool
        let appTheme: String
        let analyticsEnabled: Bool
        let newsletterOptIn: Bool
        let appLanguage: String
        let lastUpdated: Date
    }
    
    func logEmail(email: String, name: String?) async {
        guard let baseURL = seededSupabaseURL(), let anonKey = seededSupabaseAnonKey() else { return }
        let endpoint = baseURL.appendingPathComponent("rest/v1/emails")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("upsert", forHTTPHeaderField: "Prefer")
        
        let payload = [EmailRecord(email: email.lowercased(), name: name)]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try? encoder.encode(payload)
        
        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            return
        }
    }

    func syncUserPreferences(_ prefs: UserPreferences) async {
        guard let baseURL = seededSupabaseURL(), let anonKey = seededSupabaseAnonKey() else { return }
        let endpoint = baseURL.appendingPathComponent("rest/v1/user_preferences")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("upsert", forHTTPHeaderField: "Prefer")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try? encoder.encode([prefs])

        _ = try? await URLSession.shared.data(for: request)
    }
}
