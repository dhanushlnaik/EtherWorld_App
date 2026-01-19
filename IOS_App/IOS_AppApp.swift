//
//  IOS_AppApp.swift
//  IOS_App
//
//  Created by Ayush Shetty on 05/01/26.
//

import SwiftUI
import SwiftData
import BackgroundTasks

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Firebase before any Firebase services are used
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        print("✅ Firebase configured successfully")
        #endif
        
        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        #endif
        
        // Set up notification handling
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        
        // Register for remote notifications
        application.registerForRemoteNotifications()
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Set up Firebase Auth listener after configuration is complete
        #if canImport(FirebaseAuth)
        // Notify AuthenticationManager to set up listener if needed
        NotificationCenter.default.post(name: NSNotification.Name("FirebaseConfigured"), object: nil)
        #endif
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #endif
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for remote notifications: \(error)")
    }
}

#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🚀 Firebase registration token: \(String(describing: fcmToken))")
        // Sync token to Supabase/Backend if needed for user-targeted pushes
        if let token = fcmToken {
            UserDefaults.standard.set(token, forKey: "fcmToken")
        }
    }
}
#endif

@main
struct IOS_AppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var authManager = AuthenticationManager()
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("darkModeEnabled") private var legacyDarkModeEnabled: Bool = false
    @AppStorage("appLanguage") private var appLanguageCode: String = Locale.current.language.languageCode?.identifier ?? "en"

    private var resolvedTheme: AppTheme {
        AppTheme(rawValue: appThemeRaw) ?? AppTheme.fromUserDefaults()
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    AdaptiveContentView()
                        .environmentObject(authManager)
                        .environment(\.locale, Locale(identifier: appLanguageCode))
                        .id(appLanguageCode)
                } else {
                    LoginView()
                        .environmentObject(authManager)
                        .environment(\.locale, Locale(identifier: appLanguageCode))
                        .id(appLanguageCode)
                }
            }
            // Force full view swap when auth state changes so login screen appears immediately after sign-out
            .id(authManager.isAuthenticated ? "authed" : "loggedOut")
            .preferredColorScheme(resolvedTheme.preferredColorScheme)
            .onAppear {
                // Set up Firebase Auth listener once view appears (after Firebase is configured)
                #if canImport(FirebaseAuth)
                authManager.setupFirebaseAuthListener()
                #endif
            }
            .onOpenURL { url in
                // Handle OAuth callbacks from Google and other providers
                #if canImport(FirebaseAuth)
                if Auth.auth().canHandle(url) {
                    print("🔗 Handling Firebase OAuth callback: \(url)")
                } else {
                    // Check if it's a magic link
                    Task {
                        await authManager.verifyMagicLink(url: url)
                    }
                }
                #endif
            }
            .onChange(of: appThemeRaw) { _, newValue in
                // Keep legacy key consistent for any existing code paths.
                let resolved = AppTheme(rawValue: newValue) ?? .system
                legacyDarkModeEnabled = (resolved == .dark)
            }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Schedule next refresh when app becomes active
                BackgroundRefreshManager.scheduleNextRefresh(hoursFromNow: 6)
                AnalyticsManager.shared.log(.appOpen)
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefreshManager.taskIdentifier)) {
            await BackgroundRefreshManager.performRefresh()
        }
    }
}
