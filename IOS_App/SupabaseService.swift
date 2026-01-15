import Foundation

// Lightweight Supabase REST client for logging email + optional name.
// Uses PostgREST insert with upsert semantics (Prefer: resolution=merge-duplicates).
final class SupabaseService {
    static let shared = SupabaseService()
    private init() {}
    
    // TODO: Move these secrets into a secure config (not source control).
    private let supabaseURL = URL(string: "https://enlobybupevetrtfzomu.supabase.co")
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVubG9ieWJ1cGV2ZXRydGZ6b211Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0NzI3NDUsImV4cCI6MjA4NDA0ODc0NX0.5lZCR_WygSfcdS3TjZcQcqiETtorvK6ZWLpbT4O_zAA"
    
    struct EmailRecord: Encodable {
        let email: String
        let name: String?
        let status: String = "pending"
        let last_sent_at: Date = Date()
    }
    
    func logEmail(email: String, name: String?) async {
        guard let baseURL = supabaseURL else { return }
        let endpoint = baseURL.appendingPathComponent("rest/v1/emails")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("upsert", forHTTPHeaderField: "Prefer") // prefer: resolution=merge-duplicates is implied for unique keys
        
        let payload = [EmailRecord(email: email.lowercased(), name: name)]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try? encoder.encode(payload)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return
            }
        } catch {
            // Swallow errors to avoid blocking auth flows.
            return
        }
    }
}
