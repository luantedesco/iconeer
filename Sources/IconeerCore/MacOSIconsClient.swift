import Foundation

public struct SearchHit: Codable, Equatable, Sendable {
    public var objectID: String
    public var appName: String
    public var icnsURL: URL?
    public var pngURL: URL
    public var author: String?
}

public struct SearchPage: Codable, Equatable, Sendable {
    public var hits: [SearchHit]
    public var page: Int
    public var totalPages: Int
    public var totalHits: Int
}

public enum APIError: Error, Equatable, Sendable {
    case missingKey
    case invalidKey
    case quotaExceeded
    case http(status: Int, message: String)
    case invalidResponse
}

// The macOSicons search API. Each call costs one request of the user's monthly quota.
public struct MacOSIconsClient: Sendable {
    static let endpoint = URL(string: "https://api.macosicons.com/api/v1/search")!
    static let hitsPerPage = 100
    let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    // `page` starts at 1.
    public func search(_ query: String, page: Int, apiKey: String) async throws -> SearchPage {
        guard !apiKey.isEmpty else { throw APIError.missingKey }
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("Iconeer (macOS)", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(
            Body(query: query, searchOptions: .init(hitsPerPage: Self.hitsPerPage, page: page)))

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300:
            guard let result = try? JSONDecoder().decode(Response.self, from: data) else { throw APIError.invalidResponse }
            return SearchPage(
                hits: result.hits.compactMap(\.hit), page: result.page,
                totalPages: result.totalPages, totalHits: result.totalHits)
        // Without a valid key the API answers 403; 401 and 429 are the usual codes for the rest.
        case 401, 403: throw APIError.invalidKey
        case 429: throw APIError.quotaExceeded
        default:
            let body = try? JSONDecoder().decode(ErrorBody.self, from: data)
            throw APIError.http(status: status, message: body?.message ?? body?.statusMessage ?? "")
        }
    }

    struct Body: Encodable {
        struct Options: Encodable {
            var hitsPerPage: Int
            var page: Int
        }
        var query: String
        var searchOptions: Options
    }

    struct Response: Decodable {
        struct Hit: Decodable {
            var objectID: String?
            var appName: String?
            var icnsUrl: URL?
            var lowResPngUrl: URL?
            var credit: String?
            var usersName: String?

            // Hits without a name or a preview cannot be shown, and are left out.
            var hit: SearchHit? {
                guard let objectID, let appName, let lowResPngUrl else { return nil }
                return SearchHit(
                    objectID: objectID, appName: appName, icnsURL: icnsUrl,
                    pngURL: lowResPngUrl, author: credit ?? usersName)
            }
        }
        var hits: [Hit]
        var page: Int
        var totalPages: Int
        var totalHits: Int
    }

    struct ErrorBody: Decodable {
        var message: String?
        var statusMessage: String?
    }
}
