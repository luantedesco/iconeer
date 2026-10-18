import Foundation
import Testing

@testable import IconeerCore

let day: TimeInterval = 24 * 60 * 60
let start = Date(timeIntervalSince1970: 1_800_000_000)

func samplePage(_ id: String) -> SearchPage {
    SearchPage(
        hits: [
            SearchHit(
                objectID: id, appName: "Spotify", icnsURL: nil,
                pngURL: URL(string: "https://cdn.test/\(id).png")!, author: nil)
        ],
        page: 1, totalPages: 1, totalHits: 1)
}

// Counts the requests that would reach the API.
final class Fetches: @unchecked Sendable {
    var count = 0
    func next() -> SearchPage {
        count += 1
        return samplePage("fetch\(count)")
    }
}

@Test func repeatedSearchWithin30DaysCostsNoRequest() async throws {
    let cache = SearchCache(directory: try temporaryFolder())
    let fetches = Fetches()

    let first = try await cache.search("Spotify", page: 1, now: start) { fetches.next() }
    let again = try await cache.search(" spotify ", page: 1, now: start + 29 * day) { fetches.next() }

    #expect(fetches.count == 1)
    #expect(again == first)
}

@Test func anotherPageIsAnotherRequest() async throws {
    let cache = SearchCache(directory: try temporaryFolder())
    let fetches = Fetches()

    _ = try await cache.search("Spotify", page: 1, now: start) { fetches.next() }
    _ = try await cache.search("Spotify", page: 2, now: start) { fetches.next() }

    #expect(fetches.count == 2)
}

@Test func after30DaysTheSearchIsFetchedAgain() async throws {
    let cache = SearchCache(directory: try temporaryFolder())
    let fetches = Fetches()

    _ = try await cache.search("Spotify", page: 1, now: start) { fetches.next() }
    let later = try await cache.search("Spotify", page: 1, now: start + 31 * day) { fetches.next() }

    #expect(fetches.count == 2)
    #expect(later == samplePage("fetch2"))
}

@Test func failedFetchIsNotCached() async throws {
    let cache = SearchCache(directory: try temporaryFolder())
    let fetches = Fetches()

    await #expect(throws: APIError.quotaExceeded) {
        _ = try await cache.search("Spotify", page: 1, now: start) { throw APIError.quotaExceeded }
    }
    _ = try await cache.search("Spotify", page: 1, now: start) { fetches.next() }

    #expect(fetches.count == 1)
}

@Test func purgeDeletesOnlyExpiredEntries() async throws {
    let directory = try temporaryFolder()
    let cache = SearchCache(directory: directory)
    _ = try await cache.search("Old", page: 1, now: start) { samplePage("old") }
    _ = try await cache.search("New", page: 1, now: start + 20 * day) { samplePage("new") }

    cache.purge(now: start + 31 * day)

    let left = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(left == [cache.file(for: "New", page: 1).lastPathComponent])
}
