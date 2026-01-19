import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var email: String = ""
    @State private var showingSuccess: Bool = false
    @State private var showMagicLinkAlert: Bool = false
    @FocusState private var isEmailFocused: Bool
    @AppStorage("newsletterOptIn") private var newsletterOptIn: Bool = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Logo/Icon
                VStack(spacing: 16) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    Text("app.name")
                        .font(.system(size: 36, weight: .bold, design: .default))
                    
                    Text("login.tagline")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Login Options
                VStack(spacing: 20) {
                    // Apple Sign In
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = authManager.generateNonce()
                        },
                        onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                authManager.signInWithApple(authorization: authorization)
                                showSuccess()
                            case .failure(let error):
                                authManager.errorMessage = error.localizedDescription
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(12)
                    
                    // Google Sign In (Placeholder)
                    Button {
                        Task {
                            await authManager.signInWithGoogle()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 20))
                            Text("login.google")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                        Text("login.or")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.vertical, 8)
                    
                    // Email Sign In
                    VStack(alignment: .leading, spacing: 8) {
                        Text("login.email.title")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("login.email.placeholder", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .focused($isEmailFocused)
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        Text("login.email.note")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Toggle(isOn: $newsletterOptIn) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("login.newsletter.title")
                                    .fontWeight(.semibold)
                                Text("login.newsletter.subtitle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .padding(.top, 4)
                    }
                    
                    Button {
                        isEmailFocused = false
                        Task {
                            authManager.errorMessage = nil
                            authManager.showMagicLinkSent = false
                            await authManager.sendMagicLink(email: email)
                            if authManager.isAuthenticated {
                                showSuccess()
                            } else if authManager.showMagicLinkSent {
                                showMagicLinkAlert = true
                            }
                        }
                    } label: {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("login.continue")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(email.isEmpty ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(email.isEmpty || authManager.isLoading)
                    
                    if let error = authManager.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // DEV: Skip login button (remove before production)
                    Button {
                        authManager.skipLogin()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Skip Login (Dev Mode)")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.orange.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Footer
                VStack(spacing: 8) {
                    Text("login.footer.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Link("login.footer.link", destination: URL(string: "https://etherworld.co/privacy")!)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.bottom, 32)
            }
        }
        .overlay {
            if showingSuccess {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("login.success")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(40)
                    .background(Color(.systemBackground))
                    .cornerRadius(20)
                    .shadow(radius: 20)
                }
                .transition(.opacity)
            }
        }
        .alert("Magic Link Sent!", isPresented: $showMagicLinkAlert) {
            Button("OK", role: .cancel) {
                showMagicLinkAlert = false
            }
        } message: {
            Text("We've sent a magic link to \(email). Please check your Gmail inbox and click the link to sign in.")
        }
        .onAppear {
            // Clear any stale errors when the login screen is shown
            authManager.errorMessage = nil
        }
        .animation(.easeInOut, value: showingSuccess)
    }
    
    private func showSuccess() {
        showingSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showingSuccess = false
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager())
}
