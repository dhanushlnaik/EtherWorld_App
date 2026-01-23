import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(LocalizedStringKey("privacy.title"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.bottom, 8)
                    
                    // Data Collection
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(LocalizedStringKey("privacy.whatWeCollect"), systemImage: "info.circle")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text(LocalizedStringKey("privacy.minimal"))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                BulletPoint(textKey: "privacy.bullet.savedArticles")
                                BulletPoint(textKey: "privacy.bullet.preferences")
                                BulletPoint(textKey: "privacy.bullet.lastUpdated")
                                BulletPoint(textKey: "privacy.bullet.notificationPreferences")
                                BulletPoint(textKey: "privacy.bullet.analytics")
                            }
                            .padding(.top, 8)
                            
                            Text(LocalizedStringKey("privacy.dataSync"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                    }
                    
                    Divider()
                    
                    // Local Storage
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(LocalizedStringKey("privacy.localStorage"), systemImage: "externaldrive")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text(LocalizedStringKey("privacy.storageDescription"))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                BulletPoint(textKey: "privacy.bullet.userDefaults")
                                BulletPoint(textKey: "privacy.bullet.fileCache")
                                BulletPoint(textKey: "privacy.bullet.urlCache")
                                BulletPoint(textKey: "privacy.bullet.nsCache")
                            }
                            .padding(.top, 8)
                            
                            Text(LocalizedStringKey("privacy.clearData"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                    }
                    
                    Divider()
                    
                    // Notifications
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(LocalizedStringKey("privacy.notifications"), systemImage: "bell")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text(LocalizedStringKey("privacy.notificationsDescription"))
                                .font(.body)
                        }
                    }
                    
                    Divider()
                    
                    // Analytics & Diagnostics
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(LocalizedStringKey("privacy.analytics"), systemImage: "chart.bar")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text(LocalizedStringKey("privacy.analyticsDescription"))
                                .font(.body)
                        }
                    }
                    
                    Divider()
                    
                    // Full Policy Link
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(LocalizedStringKey("privacy.fullPolicy"), systemImage: "doc.text")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Link(LocalizedStringKey("privacy.fullPolicyAction"), destination: URL(string: "https://etherworld.co/privacy")!)
                                .font(.body)
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    Divider()
                    
                    // Data Deletion
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(LocalizedStringKey("privacy.clearYourData"), systemImage: "trash")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text(LocalizedStringKey("privacy.clearInstructions"))
                                .font(.body)
                        }
                    }
                    
                    Spacer()
                    
                    Text(LocalizedStringKey("privacy.lastUpdated"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 16)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .navigationTitle(LocalizedStringKey("privacy.title"))
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
    let textKey: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.headline)
            Text(LocalizedStringKey(textKey))
                .font(.body)
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
