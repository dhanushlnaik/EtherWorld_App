import Foundation

enum Configuration {
    enum Error: Swift.Error {
        case missingKey, invalidValue
    }

    static func value<T>(for key: String) throws -> T where T: LosslessStringConvertible {
        guard let object = Bundle.main.object(forInfoDictionaryKey: key) else {
            throw Error.missingKey
        }

        // If the value comes from build settings (e.g. "$(FOO)"), Xcode will substitute it.
        // When not substituted, we must treat it as invalid so callers can safely fall back.
        if let string = object as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                throw Error.invalidValue
            }
            if trimmed.contains("$(") {
                throw Error.invalidValue
            }
            guard let value = T(trimmed) else {
                throw Error.invalidValue
            }
            return value
        }

        if let value = object as? T {
            return value
        }

        throw Error.invalidValue
    }
}

extension Configuration {
    static var ghostAPIKey: String {
        return (try? value(for: "GhostAPIKey")) ?? "5b9aefe2ea7623b8fd81c52dec"
    }

    static var ghostBaseURL: String {
        return (try? value(for: "GhostBaseURL")) ?? "https://etherworld.co"
    }

    static var supabaseURL: String {
        // Intentionally no in-code default. Provide via Info.plist/build settings.
        return (try? value(for: "SupabaseURL")) ?? ""
    }

    static var supabaseAnonKey: String {
        // Intentionally no in-code default. Provide via Info.plist/build settings.
        return (try? value(for: "SupabaseAnonKey")) ?? ""
    }
}
