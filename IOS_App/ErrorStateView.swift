import SwiftUI

struct ErrorStateView: View {
    let errorMessage: String
    let retryAction: () async -> Void
    let isOffline: Bool
    
    @State private var isRetrying = false
    @State private var scale: CGFloat = 0.95
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack(alignment: .center) {
                Circle()
                    .fill(isOffline ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: isOffline ? "wifi.slash" : "exclamationmark.triangle")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(isOffline ? .blue : .orange)
            }
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    scale = 1.0
                }
            }
            
            VStack(spacing: 12) {
                Text(isOffline ? LocalizedStringKey("error.noConnection") : LocalizedStringKey("error.failedToLoad"))
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            if isOffline {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(LocalizedStringKey("error.usingCached"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            Button(action: {
                isRetrying = true
                Task {
                    await retryAction()
                    isRetrying = false
                }
            }) {
                HStack {
                    if isRetrying {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(LocalizedStringKey("general.retry"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(10)
            }
            .disabled(isRetrying)
            .opacity(isRetrying ? 0.7 : 1.0)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

#Preview {
    VStack(spacing: 32) {
        ErrorStateView(
            errorMessage: "Network timeout. Check your connection.",
            retryAction: { },
            isOffline: false
        )
        
        Divider()
        
        ErrorStateView(
            errorMessage: "You're offline. Last updated 5 minutes ago.",
            retryAction: { },
            isOffline: true
        )
    }
}
