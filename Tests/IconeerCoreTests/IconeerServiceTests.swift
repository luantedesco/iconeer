import Foundation
import Testing

@testable import IconeerCore

// Stands in for the network and the Dock, and records what the service asked of them.
final class FakeWorld: @unchecked Sendable {
    var searches: [(query: String, page: Int, key: String)] = []
    var downloads: [URL] = []
    var refreshed: [URL] = []

    func search(_ query: String, _ page: Int, _ key: String) throws -> SearchPage {
        searches.append((query, page, key))
        if key.isEmpty { throw APIError.missingKey }
        return SearchPage(hits: [catalogHit], page: page, totalPages: 3, totalHits: 250)
    }
}

let catalogHit = SearchHit(
    objectID: "a1", appName: "Sample", icnsURL: URL(string: "https://cdn.test/a1.icns"),
    pngURL: URL(string: "https://cdn.test/a1.png")!, author: "Jane")

@MainActor
func makeService(_ world: FakeWorld, keychain: KeychainStore, roots: [URL] = []) throws -> IconeerService {
    IconeerService(
        dataDirectory: try temporaryFolder(), roots: roots, keychain: keychain,
        search: { try world.search($0, $1, $2) },
        download: {
            world.downloads.append($0)
            return try Data(contentsOf: sampleIcon)
        },
        refresh: {
            world.refreshed.append($0)
            return .refreshed
        })
}

@MainActor
func supportedApp() throws -> InstalledApp {
    let url = try signedAppCopy()
    return try #require(scanApps(in: [url.deletingLastPathComponent()]).first)
}

@MainActor @Test func defaultSearchIsTheAppName() throws {
    let keychain = testKeychain()
    let service = try makeService(FakeWorld(), keychain: keychain)

    #expect(service.defaultQuery(for: try supportedApp()) == "Sample")
}

@MainActor @Test func searchSendsTheSavedKeyAndReusesTheCache() async throws {
    let keychain = testKeychain()
    defer { keychain.delete() }
    let world = FakeWorld()
    let service = try makeService(world, keychain: keychain)
    try service.saveKey("  user-key \n")

    let page = try await service.search("Spotify")
    _ = try await service.search("Spotify")

    #expect(page.hits == [catalogHit])
    #expect(world.searches.count == 1)
    #expect(world.searches.first?.key == "user-key")
}

@MainActor @Test func searchWithoutKeyAsksForOne() async throws {
    let keychain = testKeychain()
    let service = try makeService(FakeWorld(), keychain: keychain)

    #expect(!service.hasKey)
    await #expect(throws: APIError.missingKey) { try await service.search("Spotify") }
}

@MainActor @Test func deletingTheKeyAsksForOneAgainEvenForACachedSearch() async throws {
    let keychain = testKeychain()
    defer { keychain.delete() }
    let world = FakeWorld()
    let service = try makeService(world, keychain: keychain)
    try service.saveKey("user-key")
    _ = try await service.search("Spotify")

    service.deleteKey()

    #expect(!service.hasKey)
    await #expect(throws: APIError.missingKey) { try await service.search("Spotify") }
    #expect(world.searches.count == 1)
}

@MainActor @Test func applyingFromTheCatalogDownloadsTheIcnsAndRecordsTheCredit() async throws {
    let world = FakeWorld()
    let service = try makeService(world, keychain: testKeychain())
    let app = try supportedApp()

    let refresh = try await service.apply(catalogHit, to: app)

    #expect(refresh == .refreshed)
    #expect(world.downloads == [catalogHit.icnsURL])
    #expect(world.refreshed == [app.url])
    #expect(isCustomized(app.url))
    #expect(service.store.all().first?.source == .catalog(objectID: "a1", appName: "Sample", author: "Jane"))
}

@MainActor @Test func applyingFromAFileRecordsTheFile() throws {
    let service = try makeService(FakeWorld(), keychain: testKeychain())
    let app = try supportedApp()

    _ = try service.apply(file: sampleIcon, to: app)

    #expect(isCustomized(app.url))
    #expect(service.store.all().first?.source == .file(originalName: "AlertStopIcon.icns"))
}

@MainActor @Test func unsupportedAppIsNeverTried() async throws {
    let world = FakeWorld()
    let service = try makeService(world, keychain: testKeychain())
    var app = try supportedApp()
    app.support = .appStore

    await #expect(throws: ApplyError.unsupported(.appStore)) { try await service.apply(catalogHit, to: app) }
    #expect(world.downloads.isEmpty)
    #expect(!isCustomized(app.url))
}

@MainActor @Test func revertRemovesTheIconAndTheRecord() throws {
    let world = FakeWorld()
    let service = try makeService(world, keychain: testKeychain())
    let app = try supportedApp()
    _ = try service.apply(file: sampleIcon, to: app)

    _ = try service.revert(app)

    #expect(!isCustomized(app.url))
    #expect(service.store.all().isEmpty)
    #expect(world.refreshed == [app.url, app.url])
}

@MainActor @Test func keyNeverLandsInADataFile() async throws {
    let keychain = testKeychain()
    defer { keychain.delete() }
    let service = try makeService(FakeWorld(), keychain: keychain)
    let secret = "super-secret-key-\(UUID().uuidString)"
    try service.saveKey(secret)

    let page = try await service.search("Spotify")
    _ = try await service.apply(page.hits[0], to: try supportedApp())

    let directory = service.store.directory
    let files = try FileManager.default.subpathsOfDirectory(atPath: directory.path)
    #expect(!files.isEmpty)
    for file in files {
        let data = (try? Data(contentsOf: directory.appendingPathComponent(file))) ?? Data()
        #expect(data.range(of: Data(secret.utf8)) == nil, "\(file) contains the key")
    }
}

@Test func everyFailureHasItsOwnMessage() {
    let errors: [Error] = [
        ApplyError.unsupported(.appStore), ApplyError.unsupported(.system), ApplyError.unsupported(.notWritable),
        ApplyError.invalidImage, ApplyError.writeFailed,
        APIError.missingKey, APIError.invalidKey, APIError.quotaExceeded, APIError.invalidResponse,
        APIError.http(status: 500, message: "down"),
    ]

    let messages = errors.map { IconeerService.message(for: $0) }

    #expect(Set(messages).count == errors.count)
    #expect(messages.allSatisfy { !$0.isEmpty })
}

@Test func termsSayIconsBelongToTheirCreators() {
    #expect(IconeerService.terms.contains("remain the property of their creators"))
}

@Test func creditNamesTheAuthorAndMacOSicons() {
    #expect(IconeerService.credit(of: catalogHit) == "by Jane · macOSicons.com")
    var anonymous = catalogHit
    anonymous.author = nil
    #expect(IconeerService.credit(of: anonymous) == "macOSicons.com")
}

@Test func nextPageFollowsUntilTheLastOne() {
    let middle = SearchPage(hits: [], page: 2, totalPages: 3, totalHits: 250)
    let last = SearchPage(hits: [], page: 3, totalPages: 3, totalHits: 250)
    let empty = SearchPage(hits: [], page: 1, totalPages: 0, totalHits: 0)

    #expect(IconeerService.nextPage(after: middle) == 3)
    #expect(IconeerService.nextPage(after: last) == nil)
    #expect(IconeerService.nextPage(after: empty) == nil)
}

@MainActor @Test func nextPageIsRequestedWithItsNumber() async throws {
    let keychain = testKeychain()
    defer { keychain.delete() }
    let world = FakeWorld()
    let service = try makeService(world, keychain: keychain)
    try service.saveKey("user-key")

    let first = try await service.search("Spotify")
    _ = try await service.search("Spotify", page: try #require(IconeerService.nextPage(after: first)))

    #expect(world.searches.map(\.page) == [1, 2])
}
