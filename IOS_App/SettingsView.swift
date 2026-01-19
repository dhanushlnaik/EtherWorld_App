import SwiftUI
import UserNotifications

struct SettingsView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @EnvironmentObject var authManager: AuthenticationManager
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("quietStartHour") private var quietStartHour: Int = 23
    @AppStorage("quietEndHour") private var quietEndHour: Int = 7
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("analyticsEnabled") private var analyticsEnabled = false
    @AppStorage("newsletterOptIn") private var newsletterOptIn = false
    @State private var showingPrivacyPolicy = false
    @State private var showingLogoutConfirmation = false
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appLanguage") private var appLanguageCode: String = Locale.current.language.languageCode?.identifier ?? "en"

    private var themeBinding: Binding<AppTheme> {
        Binding(
            get: { AppTheme(rawValue: appThemeRaw) ?? .system },
            set: { newValue in
                appThemeRaw = newValue.rawValue
                syncPreferences()
            }
        )
    }

    private func syncPreferences() {
        guard let userId = authManager.currentUser?.id else { return }
        let prefs = SupabaseService.UserPreferences(
            userId: userId,
            notificationsEnabled: notificationsEnabled,
            appTheme: appThemeRaw,
            analyticsEnabled: analyticsEnabled,
            newsletterOptIn: newsletterOptIn,
            appLanguage: appLanguageCode,
            lastUpdated: Date()
        )
        Task {
            await SupabaseService.shared.syncUserPreferences(prefs)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Notifications Section
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                                .font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("settings.notifications.title")
                                    .fontWeight(.medium)
                                Text("settings.notifications.subtitle")
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
                                syncPreferences()
                            }
                            HapticFeedback.light()
                        } else {
                            notificationManager.cancelAllNotifications()
                            syncPreferences()
                        }
                    }

                    NavigationLink {
                        NotificationPreferencesView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                                .font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("settings.notifications.prefs.title")
                                    .fontWeight(.medium)
                                Text("settings.notifications.prefs.subtitle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .disabled(!notificationsEnabled)
                } header: {
                    Text("settings.notifications.section")
                }
                
                // Appearance Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label {
                            Text("settings.appearance.theme")
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
                    Text("settings.appearance.section")
                }
                
                // Privacy & Data Section
                Section {
                    Button {
                        showingPrivacyPolicy = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.green)
                                .frame(width: 28)
                                .font(.system(size: 16))
                            Text("settings.privacy.policy")
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Toggle(isOn: $analyticsEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.bar.fill")
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                                .font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("settings.privacy.analytics.title")
                                    .fontWeight(.medium)
                                Text("settings.privacy.analytics.subtitle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onChange(of: analyticsEnabled) { _, _ in
                        HapticFeedback.light()
                        syncPreferences()
                        AnalyticsManager.shared.setEnabled(analyticsEnabled)
                    }
                } header: {
                    Text("settings.privacy.section")
                }

                // Newsletter Section
                Section {
                    Toggle(isOn: $newsletterOptIn) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(.orange)
                                .frame(width: 28)
                                .font(.system(size: 16))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("settings.newsletter.title")
                                    .fontWeight(.medium)
                                Text("settings.newsletter.subtitle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onChange(of: newsletterOptIn) { _, _ in
                        HapticFeedback.light()
                        syncPreferences()
                    }
                } header: {
                    Text("settings.newsletter.section")
                }
                
                // About Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.gray)
                            .frame(width: 28)
                            .font(.system(size: 16))
                        Text("settings.about.version")
                            .fontWeight(.medium)
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://etherworld.co")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                                .font(.system(size: 16))
                            Text("settings.about.visit")
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Link(destination: URL(string: "https://twitter.com/AayushS20298601")!) {
                        HStack(spacing: 12) {
                            Image(systemName: "at")
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                                .font(.system(size: 16))
                            Text("settings.about.twitter")
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("settings.about.section")
                }
                
                // Account Section
                Section {
                    if let user = authManager.currentUser {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("settings.account.signedInAs")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(user.email)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    Button(role: .destructive) {
                        showingLogoutConfirmation = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(.red)
                                .frame(width: 28)
                                .font(.system(size: 16))
                            Text("settings.account.signOut")
                                .fontWeight(.medium)
                        }
                    }
                } header: {
                    Text("settings.account.section")
                }
                
                // Offline & Cache Section
                OfflineControlsSection()

                // Developer Section (Debug Tools)
                Section {
                    Button {
                        Task { await BackgroundRefreshManager.performRefresh() }
                    } label: {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(.orange)
                                .frame(width: 28)
                            Text("settings.developer.trigger")
                        }
                    }
                    .disabled(!notificationManager.isAuthorized)
                    .accessibilityLabel("Trigger background refresh")
                    .accessibilityHint("Manually triggers the background refresh to check for new articles and send a test notification")
                } header: {
                    Text("settings.developer.section")
                } footer: {
                    Text("settings.developer.footer")
                }
            }
            .navigationTitle(Text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .alert("settings.account.signOut", isPresented: $showingLogoutConfirmation) {
                Button("common.cancel", role: .cancel) {}
                Button("common.signOut", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("Are you sure you want to sign out? Your saved articles and preferences will be preserved.")
            }
        }
    }
    
    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        // Clear JSON article cache
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("articles-cache.json")
        try? FileManager.default.removeItem(at: cacheURL)
        // Clear image cache
        ImageCache.shared.clear()
        let imagesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("images")
        try? FileManager.default.removeItem(at: imagesDir)
    }
}

#Preview {
    SettingsView()
}
