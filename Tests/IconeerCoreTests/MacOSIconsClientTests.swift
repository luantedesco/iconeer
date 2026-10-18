import Foundation
import Testing

@testable import IconeerCore

// Answers every request with a canned response and keeps the last request, so the tests never
// reach the real API or spend quota.
final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var lastRequest: URLRequest?
    nonisolated(unsafe) static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastBody = request.httpBodyStream.map { stream in
            stream.open()
            defer { stream.close() }
            var data = Data()
            var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            return data
        }
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

func stubbedClient(status: Int, body: String) -> MacOSIconsClient {
    StubProtocol.status = status
    StubProtocol.body = Data(body.utf8)
    StubProtocol.lastRequest = nil
    StubProtocol.lastBody = nil
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubProtocol.self]
    return MacOSIconsClient(session: URLSession(configuration: configuration))
}

let searchResponse = """
    {"hits": [
      {"objectID": "a1", "appName": "Spotify", "icnsUrl": "https://cdn.test/a1.icns",
       "lowResPngUrl": "https://cdn.test/a1.png", "credit": "Jane", "downloads": 10},
      {"objectID": "b2", "appName": "Spotify", "lowResPngUrl": "https://cdn.test/b2.png", "usersName": "joe"},
      {"objectID": "c3", "appName": "No preview"}
     ],
     "query": "Spotify", "page": 2, "totalPages": 3, "totalHits": 250}
    """

@Suite(.serialized) struct MacOSIconsClientTests {
    @Test func sendsKeyQueryAndPage() async throws {
        let client = stubbedClient(status: 200, body: searchResponse)

        _ = try await client.search("Spotify", page: 2, apiKey: "secret")

        let request = try #require(StubProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://api.macosicons.com/api/v1/search")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "secret")
        #expect(request.value(forHTTPHeaderField: "User-Agent")?.isEmpty == false)
        let sent = try #require(StubProtocol.lastBody)
        let body = try #require(try JSONSerialization.jsonObject(with: sent) as? [String: Any])
        #expect(body["query"] as? String == "Spotify")
        let options = try #require(body["searchOptions"] as? [String: Any])
        #expect(options["page"] as? Int == 2)
        #expect(options["hitsPerPage"] as? Int == 100)
    }

    @Test func readsHitsWithAuthorAndPagination() async throws {
        let page = try await stubbedClient(status: 200, body: searchResponse).search("Spotify", page: 2, apiKey: "secret")

        #expect(
            page.hits == [
                SearchHit(
                    objectID: "a1", appName: "Spotify", icnsURL: URL(string: "https://cdn.test/a1.icns"),
                    pngURL: URL(string: "https://cdn.test/a1.png")!, author: "Jane"),
                SearchHit(
                    objectID: "b2", appName: "Spotify", icnsURL: nil,
                    pngURL: URL(string: "https://cdn.test/b2.png")!, author: "joe"),
            ])
        #expect(page.page == 2)
        #expect(page.totalPages == 3)
        #expect(page.totalHits == 250)
    }

    @Test func emptyKeyFailsWithoutCallingTheAPI() async throws {
        let client = stubbedClient(status: 200, body: searchResponse)

        await #expect(throws: APIError.missingKey) { try await client.search("Spotify", page: 1, apiKey: "") }
        #expect(StubProtocol.lastRequest == nil)
    }

    @Test(arguments: [401, 403])
    func rejectedKeyIsInvalidKey(status: Int) async throws {
        let client = stubbedClient(status: status, body: #"{"error": true, "statusCode": 403, "statusMessage": "Server Error"}"#)

        await #expect(throws: APIError.invalidKey) { try await client.search("Spotify", page: 1, apiKey: "bad") }
    }

    @Test func tooManyRequestsIsQuotaExceeded() async throws {
        let client = stubbedClient(status: 429, body: "")

        await #expect(throws: APIError.quotaExceeded) { try await client.search("Spotify", page: 1, apiKey: "secret") }
    }

    @Test func otherErrorsCarryTheMessage() async throws {
        let client = stubbedClient(status: 500, body: #"{"message": "Search is down"}"#)

        await #expect(throws: APIError.http(status: 500, message: "Search is down")) {
            try await client.search("Spotify", page: 1, apiKey: "secret")
        }
    }

    @Test func unreadableBodyIsInvalidResponse() async throws {
        let client = stubbedClient(status: 200, body: "<html>")

        await #expect(throws: APIError.invalidResponse) { try await client.search("Spotify", page: 1, apiKey: "secret") }
    }
}
