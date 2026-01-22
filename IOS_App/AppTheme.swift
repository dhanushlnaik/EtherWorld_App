import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return NSLocalizedString("theme.system", comment: "System theme")
        case .light: return NSLocalizedString("theme.light", comment: "Light theme")
        case .dark: return NSLocalizedString("theme.dark", comment: "Dark theme")
        }
    }
    
    var localizedTitle: LocalizedStringKey {
        switch self {
        case .system: return LocalizedStringKey("theme.system")
        case .light: return LocalizedStringKey("theme.light")
        case .dark: return LocalizedStringKey("theme.dark")
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    static func fromUserDefaults() -> AppTheme {
        let defaults = UserDefaults.standard

        if let stored = defaults.string(forKey: "appTheme"), let theme = AppTheme(rawValue: stored) {
            return theme
        }

        // Migration/compat:
        // If the legacy key exists, preserve the old behavior (forced light or forced dark).
        if defaults.object(forKey: "darkModeEnabled") != nil {
            return defaults.bool(forKey: "darkModeEnabled") ? .dark : .light
        }

        // Fresh install default.
        return .system
    }

    func persist() {
        UserDefaults.standard.set(rawValue, forKey: "appTheme")
        // Keep legacy key in sync for existing parts of the app and exports.
        UserDefaults.standard.set(self == .dark, forKey: "darkModeEnabled")
    }
}

struct ThemePreviewCard: View {
    let theme: AppTheme

    @Environment(\.colorScheme) private var systemColorScheme

    private var previewColorScheme: ColorScheme {
        switch theme {
        case .system:
            return systemColorScheme
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: theme.icon)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(LocalizedStringKey("theme.preview"))
                        .font(.headline)
                    Spacer()
                    Text(LocalizedStringKey("theme.\(theme.rawValue)"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 42)
                        .overlay(
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(width: 22, height: 22)
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(height: 14)
                                Spacer()
                            }
                                .padding(.horizontal, 10)
                        )

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 42)
                        .overlay(
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(width: 56, height: 14)
                                Spacer()
                                Circle()
                                    .fill(Color.accentColor.opacity(0.25))
                                    .frame(width: 22, height: 22)
                            }
                                .padding(.horizontal, 10)
                        )
                }

                Text(LocalizedStringKey("theme.applies"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .frame(height: 140)
        .environment(\.colorScheme, previewColorScheme)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(LocalizedStringKey("theme.preview"))
        .accessibilityValue(LocalizedStringKey("theme.\(theme.rawValue)"))
    }
}

struct ThemeSelectionCardsView: View {
    @Binding var selection: AppTheme

    var body: some View {
        HStack(spacing: 14) {
            ForEach([AppTheme.system, AppTheme.light, AppTheme.dark]) { theme in
                ThemeCard(theme: theme, isSelected: selection == theme) {
                    selection = theme
                }
            }
        }
    }
}

private struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ThemePhonePreview(theme: theme)

                Text(theme.localizedTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                ZStack {
                    Circle()
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: 16, height: 16)
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                    }
                }
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color(.systemBackground) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: isSelected ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(LocalizedStringKey("theme.preview"))
        .accessibilityValue(theme.localizedTitle)
        .accessibilityHint(LocalizedStringKey("general.confirm"))
    }
}

private struct ThemePhonePreview: View {
    let theme: AppTheme
    @Environment(\.colorScheme) private var systemColorScheme

    private var phoneBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemGray5))

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
                .padding(8)
                .overlay(
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(.tertiarySystemFill))
                            .frame(height: 10)
                            .padding(.top, 2)

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor.opacity(0.35))
                            .frame(height: 34)

                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color(.tertiarySystemFill))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color(.tertiarySystemFill))
                                .frame(height: 8)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color(.tertiarySystemFill))
                                .frame(height: 8)
                                .opacity(0.8)
                        }
                        .padding(.top, 2)

                        Spacer(minLength: 0)

                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(.tertiarySystemFill))
                                .frame(width: 12, height: 12)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color(.tertiarySystemFill))
                                .frame(height: 8)
                        }
                    }
                        .padding(14)
                )
        }
        .frame(width: 92, height: 132)
    }

    var body: some View {
        switch theme {
        case .system:
            ZStack {
                phoneBody
                    .environment(\.colorScheme, .light)
                phoneBody
                    .environment(\.colorScheme, .dark)
                    .mask(
                        Rectangle()
                            .rotationEffect(.degrees(-12))
                            .offset(x: 18)
                    )
                    .overlay(
                        Rectangle()
                            .fill(.black.opacity(0.12))
                            .rotationEffect(.degrees(-12))
                            .offset(x: 18)
                            .blendMode(.multiply)
                    )
            }
        case .light:
            phoneBody
                .environment(\.colorScheme, .light)
        case .dark:
            phoneBody
                .environment(\.colorScheme, .dark)
        }
    }
}
