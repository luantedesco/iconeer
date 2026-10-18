import Foundation

// What the window does: list apps, search macOSicons, apply an icon from the catalog or from a
// file, revert. Network calls come in as closures, so tests run without the real API.
@MainActor
public final class IconeerService {
    public typealias Search = @Sendable (_ query: String, _ page: Int, _ apiKey: String) async throws -> SearchPage
    public typealias Download = @Sendable (URL) async throws -> Data
    public typealias Refresh = (URL) -> DockRefresh

    nonisolated public static let terms = String(
        localized: """
            Icons from macOSicons.com remain the property of their creators. Iconeer shows each \
            creator's credit and macOSicons.com as the source, and applies icons for your personal \
            customization only.
            """)

    public let store: CustomizationStore
    public let cache: SearchCache
    let roots: [URL]
    let keychain: KeychainStore
    let searchAPI: Search
    let download: Download
    let refresh: Refresh

    public init(
        dataDirectory: URL, roots: [URL], keychain: KeychainStore = KeychainStore(),
        search: @escaping Search = { try await MacOSIconsClient().search($0, page: $1, apiKey: $2) },
        download: @escaping Download = { try await URLSession.shared.data(from: $0).0 },
        refresh: @escaping Refresh = { refreshDock(for: $0) }
    ) {
        store = CustomizationStore(directory: dataDirectory)
        cache = SearchCache(directory: dataDirectory.appendingPathComponent("cache"))
        self.roots = roots
        self.keychain = keychain
        self.searchAPI = search
        self.download = download
        self.refresh = refresh
    }

    public func apps() -> [InstalledApp] { scanApps(in: roots) }

    public func defaultQuery(for app: InstalledApp) -> String { app.name }

    public var hasKey: Bool { keychain.read()?.isEmpty == false }
    public func saveKey(_ key: String) throws { try keychain.save(key.trimmingCharacters(in: .whitespacesAndNewlines)) }
    public func deleteKey() { keychain.delete() }

    public func search(_ query: String, page: Int = 1) async throws -> SearchPage {
        // Checked before the cache, so a cleared key is asked for again even for a cached search.
        guard let key = keychain.read(), !key.isEmpty else { throw APIError.missingKey }
        let searchAPI = searchAPI
        return try await cache.search(query, page: page) { try await searchAPI(query, page, key) }
    }

    public func apply(_ hit: SearchHit, to app: InstalledApp) async throws -> DockRefresh {
        guard app.support == .supported else { throw ApplyError.unsupported(app.support) }
        let source = hit.icnsURL ?? hit.pngURL
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + source.pathExtension)
        try await download(source).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        return try apply(image: file, to: app, source: .catalog(objectID: hit.objectID, appName: hit.appName, author: hit.author))
    }

    public func apply(file: URL, to app: InstalledApp) throws -> DockRefresh {
        guard app.support == .supported else { throw ApplyError.unsupported(app.support) }
        return try apply(image: file, to: app, source: .file(originalName: file.lastPathComponent))
    }

    public func revert(_ app: InstalledApp) throws -> DockRefresh {
        try revertIcon(of: app.url)
        try store.remove(app: app.url)
        return refresh(app.url)
    }

    func apply(image: URL, to app: InstalledApp, source: IconSource) throws -> DockRefresh {
        try applyIcon(from: image, to: app.url)
        try store.add(app: app.url, bundleID: app.bundleID, image: image, source: source)
        return refresh(app.url)
    }

    // nil on the last page.
    nonisolated public static func nextPage(after page: SearchPage) -> Int? {
        page.page < page.totalPages ? page.page + 1 : nil
    }

    nonisolated public static func credit(of hit: SearchHit) -> String {
        hit.author.map { String(localized: "by \($0) · macOSicons.com") } ?? "macOSicons.com"
    }

    // One message per cause: the user needs to know whether to retry, fix the key, wait for
    // the quota, or give up on that app.
    nonisolated public static func message(for error: Error) -> String {
        switch error {
        case ApplyError.unsupported(.appStore): String(localized: "App Store apps can't be changed: macOS blocks writing to them.")
        case ApplyError.unsupported(.system): String(localized: "Apple's own apps can't be changed.")
        case ApplyError.unsupported(.notWritable), ApplyError.unsupported(.supported):
            String(localized: "You don't have permission to change this app.")
        case ApplyError.invalidImage: String(localized: "The image could not be read.")
        case ApplyError.writeFailed: String(localized: "macOS refused to change the icon.")
        case APIError.missingKey: String(localized: "Add your macOSicons API key to search.")
        case APIError.invalidKey: String(localized: "macOSicons rejected the API key. Check it and save it again.")
        case APIError.quotaExceeded:
            String(localized: "This month's macOSicons quota is used up. It resets next month; an image file still works.")
        case APIError.invalidResponse: String(localized: "macOSicons sent a response Iconeer can't read.")
        case APIError.http(let status, let message):
            message.isEmpty
                ? String(localized: "macOSicons error \(status).") : String(localized: "macOSicons error \(status): \(message).")
        default: error.localizedDescription
        }
    }
}
