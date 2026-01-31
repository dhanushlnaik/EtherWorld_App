import Foundation

// MARK: - Network Manager for API calls

final class NetworkManager {
    static let shared = NetworkManager()
    private init() {}
    
    private var baseURLString: String {
        // Prefer a configured backend URL (e.g. https://your-app.railway.app)
        if let configured: String = try? Configuration.value(for: "OTPBackendBaseURL") {
            let trimmed = configured.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        #if DEBUG
        #if targetEnvironment(simulator)
        // Local development default (simulator -> Mac localhost)
        return "http://localhost:3000"
        #else
        // On a physical device, "localhost" points to the phone (no server).
        return ""
        #endif
        #else
        // In production we require a real HTTPS backend.
        return ""
        #endif
    }

    private func makeURL(path: String) throws -> URL {
        let base = baseURLString
        guard !base.isEmpty else {
            throw NetworkError.notConfigured
        }
        guard let url = URL(string: "\(base)\(path)") else {
            throw NetworkError.invalidURL
        }
        return url
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
    
    enum NetworkError: Error {
        case notConfigured
        case invalidURL
        case invalidResponse
        case unauthorized
        case serverError(String)
    }
    
    // MARK: - OTP Authentication
    
    func sendOTP(email: String) async throws -> Bool {
        let url = try makeURL(path: "/auth/send-otp")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if let serverMessage = decodeServerError(data) {
                throw NetworkError.serverError(serverMessage)
            }
            throw NetworkError.serverError("Failed to send OTP")
        }
        
        return true
    }
    
    func verifyOTP(email: String, code: String) async throws -> AuthResponse {
        let url = try makeURL(path: "/auth/verify-otp")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "code": code]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.unauthorized
        }
        
        let decoder = makeDecoder()
        let authResponse = try decoder.decode(AuthResponse.self, from: data)
        return authResponse
    }
    
    // MARK: - Token Management
    
    func refreshToken(_ token: String) async throws -> AuthResponse {
        let url = try makeURL(path: "/auth/refresh")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.unauthorized
        }
        
        let decoder = makeDecoder()
        let authResponse = try decoder.decode(AuthResponse.self, from: data)
        return authResponse
    }
    
    // MARK: - Session Management
    
    func getSessions(token: String) async throws -> [SessionData] {
        let url = try makeURL(path: "/auth/sessions")
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError("Failed to fetch sessions")
        }
        
        let decoder = makeDecoder()
        let sessions = try decoder.decode([SessionData].self, from: data)
        return sessions
    }
    
    func revokeSession(sessionId: String, token: String) async throws {
        let url = try makeURL(path: "/auth/sessions/\(sessionId)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError("Failed to revoke session")
        }
    }
    
    // MARK: - Newsletter Subscription
    
    func subscribeNewsletter(email: String) async throws {
        let url = try makeURL(path: "/newsletter/subscribe")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["email": email, "tags": ["weekly"]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw NetworkError.serverError("Failed to subscribe")
        }
    }
}

// MARK: - Response Models

struct AuthResponse: Codable {
    let token: String
    let user: UserData
    let expiresAt: Date?
    let firebaseToken: String?  // Optional Firebase custom token
}

struct UserData: Codable {
    let id: String
    let email: String
    let name: String?
    let authProvider: String
    let createdAt: Date?
}

struct SessionData: Codable {
    let id: String
    let deviceName: String
    let deviceType: String
    let lastActive: Date
    let location: String?
}

private func decodeServerError(_ data: Data) -> String? {
    struct ServerError: Codable { let error: String?; let message: String? }
    let decoder = JSONDecoder()
    if let server = try? decoder.decode(ServerError.self, from: data) {
        return server.error ?? server.message
    }
    return nil
}
