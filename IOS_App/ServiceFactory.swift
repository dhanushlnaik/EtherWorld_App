import Foundation

struct ServiceFactory {
    enum Environment {
        case mock
        case production
    }
    
    static func makeArticleService(environment: Environment = .production) -> ArticleService {
        switch environment {
        case .mock:
            return MockArticleService()
        case .production:
            return GhostArticleService()
        }
    }

    static func makeTranslationService() -> TranslationService {
        let url = Configuration.translationAPIURL
        let key = Configuration.translationAPIKey
        if let http = HTTPTranslationService(endpointString: url, apiKey: key) {
            return http
        }
        return NoOpTranslationService()
    }
}
