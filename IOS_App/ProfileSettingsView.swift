import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingLogoutConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var showingExportSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    if let user = authManager.currentUser {
                        HStack(spacing: 16) {
                            // Avatar
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(user.name?.prefix(1).uppercased() ?? user.email.prefix(1).uppercased())
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name ?? "User")
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: providerIcon(user.authProvider))
                                        .font(.caption2)
                                    Text(providerName(user.authProvider))
                                        .font(.caption2)
                                }
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Profile")
                }
                
                // Account Management
                Section {
                    NavigationLink {
                        SessionManagementView()
                    } label: {
                        Label("Active Sessions", systemImage: "laptopcomputer.and.iphone")
                    }
                    
                    Button {
                        showingExportSheet = true
                    } label: {
                        Label("Export My Data", systemImage: "square.and.arrow.up")
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("Account Management")
                }
                
                // Settings Sections
                SettingsSectionsView()
                
                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showingLogoutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Account", systemImage: "trash")
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("Deleting your account will permanently remove all your data.")
                }
            }
            .navigationTitle("My EW")
            .navigationBarTitleDisplayMode(.large)
            .alert("Sign Out", isPresented: $showingLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("Are you sure you want to sign out? Your saved articles and preferences will be preserved.")
            }
            .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
            .sheet(isPresented: $showingExportSheet) {
                DataExportView()
            }
        }
    }
    
    private func providerIcon(_ provider: AuthenticationManager.AuthProvider) -> String {
        switch provider {
        case .email: return "envelope.fill"
        case .apple: return "applelogo"
        case .google: return "g.circle.fill"
        }
    }
    
    private func providerName(_ provider: AuthenticationManager.AuthProvider) -> String {
        switch provider {
        case .email: return "Email"
        case .apple: return "Apple"
        case .google: return "Google"
        }
    }
    
    private func deleteAccount() {
        // Clear all local data
        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        _ = KeychainHelper.shared.delete(forKey: "authToken")
        
        // Clear caches
        URLCache.shared.removeAllCachedResponses()
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        try? FileManager.default.removeItem(at: cacheURL.appendingPathComponent("articles-cache.json"))
        
        // Logout
        authManager.logout()
    }
}

// Extracted settings sections to reuse existing SettingsView components
struct SettingsSectionsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("quietStartHour") private var quietStartHour: Int = 23
    @AppStorage("quietEndHour") private var quietEndHour: Int = 7
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("appLanguage") private var appLanguageCode: String = Locale.current.language.languageCode?.identifier ?? "en"
    @AppStorage("analyticsEnabled") private var analyticsEnabled = false
    @AppStorage("newsletterOptIn") private var newsletterOptIn = false
    @EnvironmentObject var viewModel: ArticleViewModel
    @State private var showingPrivacyPolicy = false

    private var themeBinding: Binding<AppTheme> {
        Binding(
            get: { AppTheme(rawValue: appThemeRaw) ?? .system },
            set: { newValue in
                appThemeRaw = newValue.rawValue
            }
        )
    }
    
    var body: some View {
        // Notifications
        Section {
            Toggle(isOn: $notificationsEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notifications")
                            .fontWeight(.medium)
                        Text("Get notified about new articles")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onChange(of: notificationsEnabled) { _, newValue in
                if newValue {
                    notificationManager.requestPermission { granted in
                        if !granted {
                            notificationsEnabled = false
                        }
                    }
                    HapticFeedback.light()
                } else {
                    notificationManager.cancelAllNotifications()
                }
            }
            
            if notificationsEnabled {
                NavigationLink {
                    NotificationPreferencesView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        Text("Notification Preferences")
                    }
                }
            }
        } header: {
            Text("Notifications")
        }
        
        // Appearance
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("Theme")
                        .fontWeight(.medium)
                } icon: {
                    Image(systemName: "circle.lefthalf.filled")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                }

                ThemeSelectionCardsView(selection: themeBinding)
            }
            .padding(.vertical, 6)
            .onChange(of: appThemeRaw) { _, _ in
                HapticFeedback.light()
            }
        } header: {
            Text("Appearance")
        }
        
        // Language Section
        Section {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .foregroundStyle(.blue)
                    .frame(width: 28)
                    .font(.system(size: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text("settings.language.title")
                        .fontWeight(.medium)
                    Text("settings.language.subtitle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Language", selection: $appLanguageCode) {
                    Text("English").tag("en")
                    Text("हिन्दी").tag("hi")
                    Text("Español").tag("es")
                    Text("Français").tag("fr")
                    Text("Deutsch").tag("de")
                    Text("Português").tag("pt")
                }
                .pickerStyle(.menu)
            }
            .padding(.vertical, 4)
            .onChange(of: appLanguageCode) { _, _ in
                HapticFeedback.light()
            }
        } header: {
            Text("settings.language.section")
        }
        
        // Newsletter
        Section {
            Toggle(isOn: $newsletterOptIn) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(.orange)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weekly Newsletter")
                            .fontWeight(.medium)
                        Text("Get a recap via email")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onChange(of: newsletterOptIn) { _, _ in
                HapticFeedback.light()
            }
        } header: {
            Text("Newsletter")
        }
        
        // Privacy
        Section {
            Button {
                showingPrivacyPolicy = true
            } label: {
                Label("Privacy Policy", systemImage: "lock.fill")
            }
            .foregroundStyle(.primary)
            
            Toggle(isOn: $analyticsEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Analytics")
                            .fontWeight(.medium)
                        Text("Help improve the app")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onChange(of: analyticsEnabled) { _, _ in
                HapticFeedback.light()
            }
        } header: {
            Text("Privacy")
        }
        
        // Offline & Storage
        OfflineControlsSection()
        
        // About
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }
            
            Link(destination: URL(string: "https://etherworld.co")!) {
                Label("Visit EtherWorld", systemImage: "globe")
            }
        } header: {
            Text("About")
        }
        
        .sheet(isPresented: $showingPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }
}

#Preview {
    ProfileSettingsView()
        .environmentObject(AuthenticationManager())
        .environmentObject(ArticleViewModel())
}
