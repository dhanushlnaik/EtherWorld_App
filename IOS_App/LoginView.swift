import SwiftUI
import AuthenticationServices
import Combine

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var email: String = ""
    @State private var otp: String = ""
    @State private var showingSuccess: Bool = false
    @State private var showOTPField: Bool = false
    @State private var resendAvailableAt: Date = .distantPast
    @State private var now: Date = Date()
    @FocusState private var isEmailFocused: Bool
    @FocusState private var isOTPFocused: Bool
    @AppStorage("newsletterOptIn") private var newsletterOptIn: Bool = false

    private let resendCooldownSeconds: TimeInterval = 30
    private var resendSecondsRemaining: Int {
        max(0, Int(resendAvailableAt.timeIntervalSince(now)).advanced(by: 0))
    }
    
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
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 32)
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
                        Text(showOTPField ? "Enter Verification Code" : "login.email.title")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if !showOTPField {
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
                            
                            Text("We'll send you a verification code")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            // Show email as read-only
                            HStack {
                                Text(email)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("Change") {
                                    showOTPField = false
                                    otp = ""
                                    authManager.errorMessage = nil
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                            
                            // OTP Input
                            TextField("Enter 6-digit code", text: $otp)
                                .textContentType(.oneTimeCode)
                                .keyboardType(.numberPad)
                                .focused($isOTPFocused)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .onChange(of: otp) { _, newValue in
                                    // Limit to 6 digits
                                    if newValue.count > 6 {
                                        otp = String(newValue.prefix(6))
                                    }
                                }
                            
                            Text("Code sent to \(email)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

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
                        isOTPFocused = false
                        Task {
                            authManager.errorMessage = nil
                            
                            if !showOTPField {
                                // Send OTP
                                await authManager.sendOTP(email: email)
                                if authManager.otpSent {
                                    showOTPField = true
                                    resendAvailableAt = Date().addingTimeInterval(resendCooldownSeconds)
                                    // Auto-focus OTP field
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        isOTPFocused = true
                                    }
                                }
                            } else {
                                // Verify OTP
                                await authManager.verifyOTP(email: email, code: otp)
                                if authManager.isAuthenticated {
                                    showSuccess()
                                }
                            }
                        }
                    } label: {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(showOTPField ? "Verify Code" : "login.continue")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background((showOTPField ? otp.count != 6 : email.isEmpty) ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled((showOTPField ? otp.count != 6 : email.isEmpty) || authManager.isLoading)
                    
                    // Resend OTP button
                    if showOTPField {
                        Button {
                            Task {
                                otp = ""
                                await authManager.sendOTP(email: email)
                                if authManager.otpSent {
                                    resendAvailableAt = Date().addingTimeInterval(resendCooldownSeconds)
                                }
                            }
                        } label: {
                            Text(resendSecondsRemaining > 0 ? "Resend in \(resendSecondsRemaining)s" : "Resend Code")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .disabled(authManager.isLoading || resendSecondsRemaining > 0)
                    }
                    
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
        .onAppear {
            // Clear any stale errors when the login screen is shown
            authManager.errorMessage = nil
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { value in
            now = value
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
