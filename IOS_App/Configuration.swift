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
        return (try? value(for: "SupabaseURL")) ?? "https://enlobybupevetrtfzomu.supabase.co"
    }

    static var supabaseAnonKey: String {
        return (try? value(for: "SupabaseAnonKey")) ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVubG9ieWJ1cGV2ZXRydGZ6b211Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg0NzI3NDUsImV4cCI6MjA4NDA0ODc0NX0.5lZCR_WygSfcdS3TjZcQcqiETtorvK6ZWLpbT4O_zAA"
    }

    static var translationAPIURL: String {
        return (try? value(for: "TranslationAPIURL")) ?? "https://api.mymemory.translated.net/get"
    }

    static var translationAPIKey: String {
        return (try? value(for: "TranslationAPIKey")) ?? ""
    }
}
