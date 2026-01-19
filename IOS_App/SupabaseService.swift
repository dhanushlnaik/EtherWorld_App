import Foundation

// Lightweight Supabase REST client for logging email + optional name.
// Uses PostgREST insert with upsert semantics (Prefer: resolution=merge-duplicates).
final class SupabaseService {
    static let shared = SupabaseService()
    private init() {}
    
    // TODO: Move these secrets into a secure config (not source control).
    private let supabaseURL = URL(string: Configuration.supabaseURL)
    private let supabaseAnonKey = Configuration.supabaseAnonKey
    
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
        guard let baseURL = supabaseURL else { return }
        let endpoint = baseURL.appendingPathComponent("rest/v1/emails")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
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
        guard let baseURL = supabaseURL else { return }
        let endpoint = baseURL.appendingPathComponent("rest/v1/user_preferences")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("upsert", forHTTPHeaderField: "Prefer")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try? encoder.encode([prefs])

        _ = try? await URLSession.shared.data(for: request)
    }
}
