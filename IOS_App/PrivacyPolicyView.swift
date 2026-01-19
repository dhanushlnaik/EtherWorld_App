import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy & Data Practices")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.bottom, 8)
                    
                    // Data Collection
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("What We Collect", systemImage: "info.circle")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text("EtherWorld collects minimal data:")
                            
                            VStack(alignment: .leading, spacing: 4) {
                                BulletPoint(text: "Saved articles list")
                                BulletPoint(text: "App preferences (theme, language)")
                                BulletPoint(text: "Last updated timestamp for refresh tracking")
                                BulletPoint(text: "Notification preferences")
                                BulletPoint(text: "Anonymous analytics (opt-in)")
                            }
                            .padding(.top, 8)
                            
                            Text("Your preferences and saved articles are synced to our secure backend to provide a consistent experience across your devices.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                    }
                    
                    Divider()
                    
                    // Local Storage
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Local Storage", systemImage: "externaldrive")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text("All data is stored locally on your device using:")
                            
                            VStack(alignment: .leading, spacing: 4) {
                                BulletPoint(text: "UserDefaults for settings and preferences")
                                BulletPoint(text: "File cache for article content")
                                BulletPoint(text: "URLCache for network caching")
                                BulletPoint(text: "NSCache for in-memory image caching")
                            }
                            .padding(.top, 8)
                            
                            Text("You can clear all cached data anytime from Settings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                    }
                    
                    Divider()
                    
                    // Notifications
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Notifications", systemImage: "bell")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text("Background refresh checks for new articles periodically and sends local notifications to your device. No data is sent to external servers for this feature—all processing happens locally.")
                                .font(.body)
                        }
                    }
                    
                    Divider()
                    
                    // Analytics & Diagnostics
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Analytics & Diagnostics", systemImage: "chart.bar")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text("We use anonymous analytics and crash reporting to improve the app. This data is not linked to your identity. You can disable this anytime in Settings.")
                                .font(.body)
                        }
                    }
                    
                    Divider()
                    
                    // Full Policy Link
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Full Privacy Policy", systemImage: "doc.text")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Link("Read our full privacy policy", destination: URL(string: "https://etherworld.co/privacy")!)
                                .font(.body)
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    Divider()
                    
                    // Data Deletion
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Clear Your Data", systemImage: "trash")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text("Visit Settings → Developer Tools → Clear Cache to remove all locally stored data, including saved articles, cache, and images.")
                                .font(.body)
                        }
                    }
                    
                    Spacer()
                    
                    Text("Last Updated: January 2026")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 16)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .navigationTitle("Privacy Policy")
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
        }
    }
}

struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.headline)
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
