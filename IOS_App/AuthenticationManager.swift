import Foundation
import SwiftUI
import Combine
import AuthenticationServices
import CryptoKit
import FirebaseAuth

@MainActor
final class AuthenticationManager: ObservableObject {
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var currentUser: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let tokenKey = "authToken"
    private let userKey = "currentUser"
    
    // For Apple Sign-In nonce
    private var currentNonce: String?
    
    struct User: Codable {
        let id: String
        let email: String
        let name: String?
        let authProvider: AuthProvider
    }
    
    enum AuthProvider: String, Codable {
        case email
        case apple
        case google
    }
    
    init() {
        checkAuthStatus()
        #if canImport(FirebaseAuth)
        setupFirebaseAuthListener()
        #endif
    }
    
    #if canImport(FirebaseAuth)
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    private func setupFirebaseAuthListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor [weak self] in
                if let firebaseUser = firebaseUser {
                    self?.handleFirebaseUser(firebaseUser)
                } else if self?.isAuthenticated == true {
                    // User signed out from Firebase
                    self?.logout()
                }
            }
        }
    }
    
    private func handleFirebaseUser(_ firebaseUser: FirebaseAuth.User) {
        let provider: AuthProvider = {
            if let providerData = firebaseUser.providerData.first {
                switch providerData.providerID {
                case "apple.com": return .apple
                case "google.com": return .google
                default: return .email
                }
            }
            return .email
        }()
        
        let user = User(
            id: firebaseUser.uid,
            email: firebaseUser.email ?? "",
            name: firebaseUser.displayName,
            authProvider: provider
        )
        
        firebaseUser.getIDToken { [weak self] token, error in
            guard let token = token, error == nil else { return }
            Task { @MainActor [weak self] in
                _ = KeychainHelper.shared.save(token, forKey: self?.tokenKey ?? "authToken")
                self?.saveUserData(user)
                self?.isAuthenticated = true
            }
        }
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    #endif
    
    func checkAuthStatus() {
        if let token = KeychainHelper.shared.get(forKey: tokenKey),
           !token.isEmpty {
            isAuthenticated = true
            loadUserData()
        } else {
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    func sendMagicLink(email: String) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Log the request to Supabase for analytics/throttling (non-blocking)
        let extractedName = extractName(from: trimmed)
        Task { await SupabaseService.shared.logEmail(email: trimmed, name: extractedName) }

        #if canImport(FirebaseAuth)
        // Firebase Auth: Send sign-in link to email
        let actionCodeSettings = ActionCodeSettings()
        actionCodeSettings.url = URL(string: "https://etherworld.co/auth/callback")
        actionCodeSettings.handleCodeInApp = true
        actionCodeSettings.setIOSBundleID(Bundle.main.bundleIdentifier ?? "com.etherworld.app")
        
        do {
            try await Auth.auth().sendSignInLink(toEmail: trimmed, actionCodeSettings: actionCodeSettings)
            // Save email for link verification
            UserDefaults.standard.set(trimmed, forKey: "emailForSignIn")
            print("✅ Magic link sent via Firebase to \(trimmed)")
        } catch {
            errorMessage = "Failed to send magic link: \(error.localizedDescription)"
            print("❌ Firebase magic link error: \(error)")
        }
        #else
        // DEMO MODE: Allow entry without Firebase
        try? await Task.sleep(nanoseconds: 250_000_000)

        let token = UUID().uuidString
        let user = User(
            id: UUID().uuidString,
            email: trimmed,
            name: extractName(from: trimmed),
            authProvider: .email
        )

        _ = KeychainHelper.shared.save(token, forKey: tokenKey)
        saveUserData(user)
        isAuthenticated = true
        currentUser = user
        print("✅ Demo login successful for \(trimmed)")
        #endif
    }
    
    func verifyMagicLinkToken(_ token: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let response = try await NetworkManager.shared.verifyMagicLink(token: token)
            
            let user = User(
                id: response.user.id,
                email: response.user.email,
                name: response.user.name,
                authProvider: .email
            )
            
            if KeychainHelper.shared.save(response.token, forKey: tokenKey) {
                saveUserData(user)
                isAuthenticated = true
                currentUser = user
            } else {
                errorMessage = "Failed to save authentication token"
            }
        } catch {
            errorMessage = "Invalid or expired magic link"
        }
    }
    
    func signInWithApple(authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Failed to get Apple ID credentials"
            return
        }
        
        #if canImport(FirebaseAuth)
        // Firebase Auth: Sign in with Apple
        guard let idTokenData = appleIDCredential.identityToken,
              let idTokenString = String(data: idTokenData, encoding: .utf8) else {
            errorMessage = "Failed to get Apple ID token"
            return
        }
        
        // Use the stored nonce from the request
        guard let nonce = currentNonce else {
            errorMessage = "Invalid nonce state. Please try again."
            return
        }
        
        // Firebase 12+: use the dedicated Apple helper for OIDC credential
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                let result = try await Auth.auth().signIn(with: credential)
                print("✅ Apple Sign-In successful via Firebase: \(result.user.email ?? "no email")")
                // Firebase listener will handle the rest
            } catch {
                await MainActor.run {
                    errorMessage = "Apple Sign-In failed: \(error.localizedDescription)"
                }
                print("❌ Firebase Apple Sign-In error: \(error)")
            }
        }
        #else
        // DEMO MODE: Allow Apple sign-in without Firebase
        let userID = appleIDCredential.user
        let email = appleIDCredential.email ?? "\(userID)@privaterelay.appleid.com"
        let fullName = appleIDCredential.fullName
        let name = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        
        let token = UUID().uuidString
        let user = User(
            id: userID,
            email: email,
            name: name.isEmpty ? nil : name,
            authProvider: .apple
        )
        
        if KeychainHelper.shared.save(token, forKey: tokenKey) {
            saveUserData(user)
            isAuthenticated = true
            currentUser = user
        } else {
            errorMessage = "Failed to save authentication token"
        }
        print("✅ Demo Apple Sign-In successful")
        #endif
    }
    
    func signInWithGoogle() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let provider = OAuthProvider(providerID: "google.com")
            provider.scopes = ["email", "profile"]

            // Bridge the callback-based API to async/await
            let credential = try await withCheckedThrowingContinuation { continuation in
                provider.getCredentialWith(nil) { credential, error in
                    if let credential {
                        continuation.resume(returning: credential)
                    } else {
                        let nsError = error ?? NSError(
                            domain: "GoogleSignIn",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Unable to create Google credential"]
                        )
                        continuation.resume(throwing: nsError)
                    }
                }
            }

            let authResult = try await Auth.auth().signIn(with: credential)

            await MainActor.run {
                isLoading = false
            }
            print("✅ Google Sign-In successful via Firebase: \(authResult.user.email ?? "no email")")
            // Firebase listener will handle the rest

        } catch let error as NSError {
            await MainActor.run {
                if let code = AuthErrorCode(rawValue: error.code) {
                    switch code {
                    case .operationNotAllowed:
                        errorMessage = "Google Sign-In is disabled in Firebase Console. Enable Google provider and try again."
                    case .webContextCancelled, .webSignInUserInteractionFailure:
                        errorMessage = "Sign-in was cancelled"
                    default:
                        errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
                    }
                } else {
                    errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
                }
                isLoading = false
            }
            print("❌ Firebase Google Sign-In error: \(error)")
        }
    }
    
    func logout() {
        #if canImport(FirebaseAuth)
        do {
            try Auth.auth().signOut()
            print("✅ Firebase sign-out successful")
        } catch {
            print("❌ Firebase sign-out error: \(error)")
        }
        #endif
        
        _ = KeychainHelper.shared.delete(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        isAuthenticated = false
        currentUser = nil
    }
    
    private func loadUserData() {
        guard let data = UserDefaults.standard.data(forKey: userKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return
        }
        currentUser = user
    }
    
    private func saveUserData(_ user: User) {
        guard let data = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(data, forKey: userKey)
        currentUser = user
    }
    
    private func extractName(from email: String) -> String? {
        let name = email.components(separatedBy: "@").first?
            .replacingOccurrences(of: ".", with: " ")
            .capitalized
        return name
    }
    
    // MARK: - Apple Sign-In Helpers
    
    /// Generates a cryptographically secure random nonce for Apple Sign-In
    func generateNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        return sha256(nonce)
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}
