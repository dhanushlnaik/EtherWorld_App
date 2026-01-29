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
                    Text(LocalizedStringKey("profile.title"))
                }
                
                // Account Management
                Section {
                    NavigationLink {
                        SessionManagementView()
                    } label: {
                        Label(LocalizedStringKey("profile.activeSessions"), systemImage: "laptopcomputer.and.iphone")
                    }
                    
                    Button {
                        showingExportSheet = true
                    } label: {
                        Label(LocalizedStringKey("profile.exportData"), systemImage: "square.and.arrow.up")
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text(LocalizedStringKey("account.accountManagement"))
                }
                
                // Settings Sections
                SettingsSectionsView()
                
                // Danger Zone
                Section {
                    Button(role: .destructive) {
                        showingLogoutConfirmation = true
                    } label: {
                        Label(LocalizedStringKey("profile.signOut"), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label(LocalizedStringKey("profile.deleteAccount"), systemImage: "trash")
                    }
                } header: {
                    Text(LocalizedStringKey("profile.dangerZone"))
                } footer: {
                    Text(LocalizedStringKey("profile.deleteWarning"))
                }
            }
            .navigationTitle(LocalizedStringKey("profile.title"))
            .navigationBarTitleDisplayMode(.large)
            .alert(LocalizedStringKey("profile.signOut"), isPresented: $showingLogoutConfirmation) {
                Button(role: .cancel) { } label: { Text(LocalizedStringKey("common.cancel")) }
                Button(role: .destructive) {
                    authManager.logout()
                } label: { Text(LocalizedStringKey("common.signOut")) }
            } message: {
                Text(LocalizedStringKey("profile.signOutConfirm"))
            }
            .alert(LocalizedStringKey("profile.deleteAccount"), isPresented: $showingDeleteConfirmation) {
                Button(role: .cancel) { } label: { Text(LocalizedStringKey("common.cancel")) }
                Button(role: .destructive) {
                    deleteAccount()
                } label: { Text(LocalizedStringKey("profile.deleteAccount")) }
            } message: {
                Text(LocalizedStringKey("profile.deleteConfirm"))
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
        Task {
            // Clear all local data
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            _ = KeychainHelper.shared.delete(forKey: "authToken")
            
            // Clear caches
            URLCache.shared.removeAllCachedResponses()
            let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            try? FileManager.default.removeItem(at: cacheURL.appendingPathComponent("articles-cache.json"))
            
            // Logout & Delete from Firebase
            await authManager.deleteAccount()
        }
    }
}

// Extracted settings sections to reuse existing SettingsView components
struct SettingsSectionsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("quietStartHour") private var quietStartHour: Int = 23
    @AppStorage("quietEndHour") private var quietEndHour: Int = 7
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
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
                        Text(LocalizedStringKey("settings.notifications.title"))
                            .fontWeight(.medium)
                        Text(LocalizedStringKey("settings.notifications.subtitle"))
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
                        Text(LocalizedStringKey("settings.notifications.prefs.title"))
                    }
                }
            }
        } header: {
            Text(LocalizedStringKey("settings.notifications.section"))
        }
        
        // Appearance
        Section {
            VStack(alignment: .leading, spacing: 12) {
                    Label {
                    Text(LocalizedStringKey("settings.appearance.theme"))
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
            Text(LocalizedStringKey("settings.appearance.section"))
        }
        
        // Newsletter
        Section {
            Toggle(isOn: $newsletterOptIn) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(.orange)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("settings.newsletter.title"))
                            .fontWeight(.medium)
                        Text(LocalizedStringKey("settings.newsletter.subtitle"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onChange(of: newsletterOptIn) { _, _ in
                HapticFeedback.light()
            }
        } header: {
            Text(LocalizedStringKey("settings.newsletter.section"))
        }
        
        // Privacy
        Section {
            Button {
                showingPrivacyPolicy = true
            } label: {
                Label(LocalizedStringKey("settings.privacy.policy"), systemImage: "lock.fill")
            }
            .foregroundStyle(.primary)
            
            Toggle(isOn: $analyticsEnabled) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("settings.privacy.analytics.title"))
                            .fontWeight(.medium)
                        Text(LocalizedStringKey("settings.privacy.analytics.subtitle"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onChange(of: analyticsEnabled) { _, _ in
                HapticFeedback.light()
            }
        } header: {
            Text(LocalizedStringKey("settings.privacy.section"))
        }
        
        // Offline & Storage
        OfflineControlsSection()
        
        // About
        Section {
            HStack {
                Text(LocalizedStringKey("settings.about.version"))
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }
            
            Link(destination: URL(string: "https://etherworld.co")!) {
                Label(LocalizedStringKey("settings.about.visit"), systemImage: "globe")
            }
        } header: {
            Text(LocalizedStringKey("settings.about.section"))
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
