import CryptoKit
import Foundation

// One file per search term and page. The API terms allow caching responses for up to 30 days,
// and a repeated search inside that window costs no quota.
public struct SearchCache: Sendable {
    public static let lifetime: TimeInterval = 30 * 24 * 60 * 60
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    struct Entry: Codable {
        var fetchedAt: Date
        var result: SearchPage
    }

    public func search(
        _ query: String, page: Int, now: Date = Date(),
        fetch: @Sendable () async throws -> SearchPage
    ) async throws -> SearchPage {
        let file = self.file(for: query, page: page)
        if let data = try? Data(contentsOf: file),
            let entry = try? JSONDecoder().decode(Entry.self, from: data),
            now.timeIntervalSince(entry.fetchedAt) < Self.lifetime
        {
            return entry.result
        }
        let result = try await fetch()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(Entry(fetchedAt: now, result: result)).write(to: file, options: .atomic)
        return result
    }

    // Deletes every entry older than the lifetime.
    public func purge(now: Date = Date()) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files {
            let entry = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(Entry.self, from: $0) }
            if entry.map({ now.timeIntervalSince($0.fetchedAt) >= Self.lifetime }) ?? true {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // "Spotify" and " spotify " are the same search.
    func file(for query: String, page: Int) -> URL {
        let key = query.trimmingCharacters(in: .whitespaces).lowercased() + "\n\(page)"
        let name = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name + ".json")
    }
}
