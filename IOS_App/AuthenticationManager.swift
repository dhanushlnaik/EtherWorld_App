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
    @Published var otpSent: Bool = false
    
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
        // Firebase listener will be set up after Firebase.configure() is called
    }
    
    #if canImport(FirebaseAuth)
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    func setupFirebaseAuthListener() {
        // Only set up listener if not already configured
        guard authStateListener == nil else { return }
        
        // Check if Firebase is configured before accessing Auth
        guard FirebaseAuth.Auth.auth().app != nil else {
            print("⚠️ Firebase not yet configured, skipping Auth listener setup")
            return
        }
        
        authStateListener = FirebaseAuth.Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
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
            FirebaseAuth.Auth.auth().removeStateDidChangeListener(listener)
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
    
    func sendOTP(email: String) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = trimmed.lowercased()
        guard !normalizedEmail.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        otpSent = false
        defer { isLoading = false }

        // Log the request to Supabase for analytics/throttling (non-blocking)
        let extractedName = extractName(from: normalizedEmail)
        Task { await SupabaseService.shared.logEmail(email: normalizedEmail, name: extractedName) }

        do {
            _ = try await NetworkManager.shared.sendOTP(email: normalizedEmail)
            UserDefaults.standard.set(normalizedEmail, forKey: "emailForOTP")
            print("✅ OTP sent via backend to \(normalizedEmail)")
            otpSent = true
        } catch {
            if let networkError = error as? NetworkManager.NetworkError {
                switch networkError {
                case .serverError(let message):
                    errorMessage = message
                default:
                    errorMessage = "Couldn't send code. Please try again."
                }
            } else {
                errorMessage = "Couldn't send code. Please try again."
            }
            print("❌ OTP send error: \(error)")
        }
    }
    
    func verifyOTP(email: String, code: String) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedEmail = trimmed.lowercased()
        guard !normalizedEmail.isEmpty, code.count == 6 else {
            errorMessage = "Please enter a valid 6-digit code"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let authResponse = try await NetworkManager.shared.verifyOTP(email: normalizedEmail, code: code)

            let user = User(
                id: authResponse.user.id,
                email: authResponse.user.email,
                name: authResponse.user.name,
                authProvider: .email
            )

            _ = KeychainHelper.shared.save(authResponse.token, forKey: tokenKey)
            saveUserData(user)
            isAuthenticated = true
            currentUser = user
            UserDefaults.standard.removeObject(forKey: "emailForOTP")
            print("✅ Successfully signed in with OTP: \(normalizedEmail)")

            #if canImport(FirebaseAuth)
            if let firebaseToken = authResponse.firebaseToken {
                Task {
                    do {
                        _ = try await FirebaseAuth.Auth.auth().signIn(withCustomToken: firebaseToken)
                        print("✅ Firebase authenticated with custom token")
                    } catch {
                        print("⚠️ Firebase auth failed but user logged in: \(error)")
                    }
                }
            }
            #endif
        } catch {
            if let networkError = error as? NetworkManager.NetworkError {
                switch networkError {
                case .serverError(let message):
                    errorMessage = message
                case .unauthorized:
                    errorMessage = "Invalid or expired verification code"
                default:
                    errorMessage = "Verification failed. Please try again."
                }
            } else {
                errorMessage = "Verification failed. Please try again."
            }
            print("❌ OTP verification error: \(error)")
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
                let result = try await FirebaseAuth.Auth.auth().signIn(with: credential)
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

            let authResult = try await FirebaseAuth.Auth.auth().signIn(with: credential)

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
        AnalyticsManager.shared.log(.logout)
        do {
            try FirebaseAuth.Auth.auth().signOut()
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

    func deleteAccount() async {
        #if canImport(FirebaseAuth)
        guard let user = FirebaseAuth.Auth.auth().currentUser else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await user.delete()
            print("✅ Account deleted successfully from Firebase")
            logout()
        } catch {
            errorMessage = "Deletion failed: \(error.localizedDescription)"
            print("❌ Firebase account deletion error: \(error)")
            
            // If it requires recent login, show specific error
            if (error as NSError).code == AuthErrorCode.requiresRecentLogin.rawValue {
                errorMessage = "Please sign out and sign back in before deleting your account for security reasons."
            }
        }
        #else
        logout()
        #endif
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
