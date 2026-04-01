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
        let lastUpdated: Date
    }

    struct NewsletterSubscriber: Encodable {
        let email: String
        let name: String?
        let subscribed: Bool
        let authMethod: String // "email", "apple", "google"
        let subscribedAt: Date = Date()
        
        enum CodingKeys: String, CodingKey {
            case email
            case name
            case subscribed
            case authMethod = "auth_method"
            case subscribedAt = "subscribed_at"
        }
    }
    
    func logEmail(email: String, name: String?) async {
        guard let baseURL = seededSupabaseURL(), let anonKey = seededSupabaseAnonKey() else {
            print("⚠️ Supabase not configured – email not logged (check SupabaseURL/SupabaseAnonKey in Secrets.xcconfig)")
            return
        }
        let endpoint = baseURL.appendingPathComponent("rest/v1/emails")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let payload = [EmailRecord(email: email.lowercased(), name: name)]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try? encoder.encode(payload)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("⚠️ Supabase logEmail HTTP \(http.statusCode): \(body)")
            } else {
                print("✅ Supabase logEmail succeeded for \(email)")
            }
        } catch {
            print("⚠️ Supabase logEmail network error: \(error.localizedDescription)")
        }
    }

    func syncUserPreferences(_ prefs: UserPreferences) async {
        guard let baseURL = seededSupabaseURL(), let anonKey = seededSupabaseAnonKey() else {
            print("⚠️ Supabase not configured – preferences not synced")
            return
        }
        let endpoint = baseURL.appendingPathComponent("rest/v1/user_preferences")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try? encoder.encode([prefs])

        if let (data, response) = try? await URLSession.shared.data(for: request) {
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("⚠️ Supabase syncPreferences HTTP \(http.statusCode): \(body)")
            }
        } else {
            print("⚠️ Supabase syncPreferences network error")
        }
    }

    func logNewsletterPreference(email: String, name: String?, subscribed: Bool, authMethod: String) async {
        guard let baseURL = seededSupabaseURL(), let anonKey = seededSupabaseAnonKey() else {
            print("⚠️ Supabase not configured – newsletter preference not logged")
            return
        }
        let endpoint = baseURL.appendingPathComponent("rest/v1/newsletter_subscribers")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let payload = [NewsletterSubscriber(email: email.lowercased(), name: name, subscribed: subscribed, authMethod: authMethod)]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try? encoder.encode(payload)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let body = String(data: data, encoding: .utf8) ?? ""
                print("⚠️ Supabase newsletter HTTP \(http.statusCode): \(body)")
            } else {
                print("✅ Newsletter preference logged for \(email) [subscribed=\(subscribed)]")
            }
        } catch {
            print("⚠️ Supabase newsletter network error: \(error.localizedDescription)")
        }
    }
}
