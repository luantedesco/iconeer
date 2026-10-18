import Foundation
import Testing

@testable import IconeerCore

// Records the commands instead of running them, so the tests never restart the real Dock.
final class CommandLog: @unchecked Sendable {
    var commands: [[String]] = []
    func run(_ path: String, _ args: [String]) { commands.append([path] + args) }
}

func modificationDate(of url: URL) throws -> Date {
    try #require(try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date)
}

@Test func closedAppGetsBundleTouchedAndDockRestarted() throws {
    let app = try fakeApp("Closed.app", in: try temporaryFolder())
    let old = Date(timeIntervalSince1970: 1_000_000_000)
    try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: app.path)
    let log = CommandLog()

    let result = refreshDock(for: app, isRunning: { _ in false }, run: log.run)

    #expect(result == .refreshed)
    #expect(log.commands == [["/usr/bin/killall", "Dock"]])
    #expect(try modificationDate(of: app) > old)
}

@Test func runningAppIsLeftForItsNextLaunch() throws {
    let app = try fakeApp("Open.app", in: try temporaryFolder())
    let old = Date(timeIntervalSince1970: 1_000_000_000)
    try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: app.path)
    let log = CommandLog()

    let result = refreshDock(for: app, isRunning: { _ in true }, run: log.run)

    #expect(result == .afterNextLaunch)
    #expect(log.commands.isEmpty)
    #expect(try modificationDate(of: app) == old)
}

@Test func runningCheckFindsTheDockButNotAnAppThatIsNotOpen() throws {
    #expect(isAppRunning(URL(fileURLWithPath: "/System/Library/CoreServices/Dock.app")))
    #expect(!isAppRunning(try fakeApp("NotOpen.app", in: try temporaryFolder())))
}
