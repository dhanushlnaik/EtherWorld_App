import SwiftUI

struct SessionManagementView: View {
    @State private var sessions: [DeviceSession] = []
    
    struct DeviceSession: Identifiable {
        let id = UUID()
        let deviceName: String
        let deviceType: String
        let lastActive: Date
        let isCurrentDevice: Bool
        let location: String?
        
        var icon: String {
            switch deviceType {
            case "iPhone": return "iphone"
            case "iPad": return "ipad"
            case "Mac": return "laptopcomputer"
            default: return "desktopcomputer"
            }
        }
    }
    
    var body: some View {
        List {
            Section {
                ForEach(sessions) { session in
                    HStack(spacing: 12) {
                        Image(systemName: session.icon)
                            .font(.title2)
                            .foregroundStyle(.blue)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(session.deviceName)
                                    .font(.headline)
                                if session.isCurrentDevice {
                                    Text(LocalizedStringKey("session.thisDevice"))
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                            
                            Text(String(format: NSLocalizedString("session.lastActive", comment: "Last active"), session.lastActive.formatted(date: .abbreviated, time: .shortened)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if let location = session.location {
                                Text(location)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        if !session.isCurrentDevice {
                            Button(role: .destructive) {
                                revokeSession(session)
                            } label: {
                                Text(LocalizedStringKey("session.revoke"))
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundStyle(.red)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            } header: {
                Text(LocalizedStringKey("session.title"))
            } footer: {
                Text(LocalizedStringKey("session.description"))
            }
        }
        .navigationTitle(LocalizedStringKey("session.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSessions()
        }
    }
    
    private func loadSessions() {
        // Mock current device session (in production, fetch from backend)
        let currentDevice = DeviceSession(
            deviceName: deviceName(),
            deviceType: deviceType(),
            lastActive: Date(),
            isCurrentDevice: true,
            location: nil
        )
        
        sessions = [currentDevice]
        
        // Load additional sessions from UserDefaults or backend
        // For now, just show current device
    }
    
    private func revokeSession(_ session: DeviceSession) {
        sessions.removeAll { $0.id == session.id }
        // In production: call backend API to revoke session token
        HapticFeedback.medium()
    }
    
    private func deviceName() -> String {
        #if os(iOS)
        return UIDevice.current.name
        #else
        return "Mac"
        #endif
    }
    
    private func deviceType() -> String {
        #if os(iOS)
        switch UIDevice.current.userInterfaceIdiom {
        case .phone: return "iPhone"
        case .pad: return "iPad"
        default: return "iOS Device"
        }
        #else
        return "Mac"
        #endif
    }
}

#Preview {
    NavigationStack {
        SessionManagementView()
    }
}
